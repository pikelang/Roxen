// string cvs_version = "$Id: module_support.pike,v 1.53 2000/02/02 16:10:58 stewa Exp $";
#include <roxen.h>
#include <module.h>
#include <stat.h>

/* Set later on to something better in roxen.pike::main() */
mapping (string:array) variables=([]);

string get_doc_for( string region, string variable )
{
  if(variables[ variable ])
    return variables[variable][VAR_NAME]+
      "\n"+variables[ variable ][ VAR_DOC_STR ];
}

/* Variable support for the main Roxen "module". Normally this is
 * inherited from module.pike, but this is not possible, or wanted, in
 * this case.  Instead we define a few support functions.
 */

int setvars( mapping (string:mixed) vars )
{
  string v;

  foreach( indices( vars ), v )
    if(variables[v])
      variables[v][ VAR_VALUE ] = vars[ v ];
  return 1;
}

class ConfigurableWrapper
{
  int mode;
  function f;

  int check(  int|void more, int|void expert, int|void devel,
              int|void initial )
  {
    if ((mode & VAR_MORE) && !more)
      return 1;
    if ((mode & VAR_DEVELOPER) && !devel)
      return 1;
    if ((mode & VAR_EXPERT) && !expert)
      return 1;
    if (initial && !(mode & VAR_INITIAL))
      return 1;
    return f();
  }

  void create(int mode_, function f_)
  {
    mode = mode_;
    f = f_;
  }
}

function reg_s_loc;
int globvar(string var, mixed value, string name, int type,
	    string|void doc_str, mixed|void misc,
	    int|function|void not_in_config)
{
  variables[var]                     = allocate( VAR_SIZE );
  variables[var][ VAR_VALUE ]        = value;
  variables[var][ VAR_TYPE ]         = type & VAR_TYPE_MASK;
  variables[var][ VAR_DOC_STR ]      = doc_str;
  variables[var][ VAR_NAME ]         = name;
  variables[var][ VAR_MISC ]         = misc;

  type &= ~VAR_TYPE_MASK;		// Probably not needed, but...
  type &= (VAR_EXPERT | VAR_MORE);
  if (functionp(not_in_config)) {
    if (type) {
      variables[var][ VAR_CONFIGURABLE ] =
	ConfigurableWrapper( type, not_in_config)->check;
    } else {
      variables[var][ VAR_CONFIGURABLE ] = not_in_config;
    }
  } else if (type) {
    variables[var][ VAR_CONFIGURABLE ] = type;
  } else if(intp(not_in_config)) {
    variables[var][ VAR_CONFIGURABLE ] = !not_in_config;
  }

  if(!reg_s_loc)
    reg_s_loc = master()->resolv("Locale")["Roxen"]["standard"]
              ->register_module_doc;
  reg_s_loc( this_object(), var, name, doc_str );
  variables[var][ VAR_SHORTNAME ] = var;
}

mapping locs = ([]);
void deflocaledoc( string locale, string variable,
		   string name, string doc, mapping|void translate)
{
  if(!locs[locale] )
    locs[locale] = master()->resolv("Locale")["Roxen"][locale]
                 ->register_module_doc;
  if(!locs[locale])
    report_debug("Invalid locale: "+locale+". Ignoring.\n");
  else
    locs[locale]( this_object(), variable, name, doc, translate );
}


public mixed query(void|string var)
{
  if(var && variables[var])
    return variables[var][ VAR_VALUE ];
  if(this_object()->current_configuration)
    return this_object()->current_configuration->query(var);
  error("query("+var+"). Unknown variable.\n");
  return 0;
}

mixed save()
{
  roxenp()->store( "Variables", variables, 0, 0 );
}

mixed set(string var, mixed val)
{
#if DEBUG_LEVEL > 30
  werror(sprintf("MAIN: set(\"%s\", %O)\n", var, val));
#endif
  if(variables[var])
  {
#if DEBUG_LEVEL > 28
    werror("MAIN:    Setting global variable.\n");
#endif
    return variables[var][VAR_VALUE] = val;
  }
  error("set("+var+"). Unknown variable.\n");
}

program my_compile_file(string file)
{
  if( file[0] != '/' )
    file = replace(getcwd()+"/"+file, "//", "/");

  string ofile = master()->make_ofilename( file );

  program p;

  ErrorContainer e = ErrorContainer();
  master()->set_inhibit_compile_errors(e);
  catch {
    p  = (program)( file );
  };
  master()->set_inhibit_compile_errors(0);

  string q = e->get();
  if( !p )
  {
    if( strlen( q ) )
      report_error("Failed to compile module %s:\n%s", file, q);
    throw( "" );
  }
  if ( strlen(q) )
  {
    report_debug(sprintf("Warnings during compilation of module %s:\n"
			 "%s", file, q));
  }
  if( !file_stat( ofile ) ||
      file_stat(ofile)[ST_MTIME] < file_stat(file)[ST_MTIME] )
    if( catch ( master()->dump_program( file, p ) ) )
    {
#ifdef MODULE_DEBUG
      report_debug("\b[nodump] \b");
#endif
      catch( Stdio.File( ofile, "wct" ) );
    } else {
#ifdef MODULE_DEBUG
      report_debug("\b[dump] \b");
#endif
    }
  return p;
}

function|program load( string what )
{
  return my_compile_file( what );
}

//
// Module load and finding system.
//
// Cache for module data.
//
// We need to store:
//   sname       (short name, such as 'gtext')
//   filename    (full file name)
//   last_checked
//   and then the information from register_module, and the new
//   module information constants:
//     type
//     multiple_copies
//     name
//     description
//
//  This is stored in a ConfigurationIFCache instance.
//
object module_cache;

class ModuleInfo
{
  string sname;
  string filename;

  int last_checked;
  int type, multiple_copies;
  mapping|string name;
  mapping|string description;

  string _sprintf()
  {
    return "ModuleInfo("+sname+")";
  }

  string get_name()
  {
    if( stringp( name ) )
      return name;
    if( mappingp( name ) )
    {
      if( name[ roxenp()->locale->get()->name ] )
        return name[ roxenp()->locale->get()->name ];
      return name[ "standard" ];
    }
  }

  string get_description()
  {
    if( stringp( description ) )
      return description;
    if( mappingp( description ) )
    {
      if( description[ roxenp()->locale->get()->name ] )
        return description[ roxenp()->locale->get()->name ];
      return description[ "standard" ];
    }
  }

  object instance( object conf )
  {
//     werror("Instantiate %O for %O.\n", this_object(), conf );
#if constant(Java.jvm)
    if( filename[sizeof(filename)-6..]==".class" )
      return ((program)"javamodule.pike")(conf, filename);
#endif
    return load( filename )( conf );
  }

  void save()
  {
    module_cache
      ->set( sname,
             ([ "filename":filename,
                "sname":sname,
                "last_checked":last_checked,
                "type":type,
                "multiple_copies":multiple_copies,
                "name":name,
                "description":description,
             ]) );
  }

  int init_module( string what )
  {
    filename = what;
    mixed q =catch
    {
      object mod = instance( 0 );
      if(!mod)
        throw(sprintf("Failed to instance %s (%s)\n", sname,what));
      if(!mod->register_module)
        throw(sprintf("The module %s (%s) has no register_module function\n",
                      sname, what ));
      array data = mod->register_module();
      if(!arrayp(data))
        throw(sprintf("register_module returned %O for %s (%s)\n", data, sname,
                      what));
      if( sizeof(data) < 3 )
        throw("register_module returned a too small array for "+sname+
              " ("+what+")\n");
      type = data[0];
      if( data[ 1 ] )
        name = data[1];
      if( data[ 2 ] )
        description = data[2];
      if( sizeof( data ) > 4 )
        multiple_copies = !data[4];
      else
        multiple_copies = 1;

      last_checked = file_stat( filename )[ ST_MTIME ];

      save();
      destruct( mod );
      return 1;
    };
    if( stringp( q ) )
      report_debug( q );
    else if( q && sizeof(q) )
      report_debug(describe_backtrace(q));
    return 0;
  }

  int rec_find_module( string what, string dir )
  {
    array dirlist = (get_dir(dir) || ({})) - ({"CVS"});

    if( (search( dirlist, ".nomodules" ) != -1) ||
        (search( dirlist, ".no_modules" ) != -1) )
      return 0;

    foreach( dirlist, string file )
      catch
      {
        if( file_stat( dir+file )[ ST_SIZE ] == -2
            && file != "." && file != ".." )
          if( rec_find_module( what, dir+file+"/" ) )
            return 1;
	  else
	    continue;

        if( strlen( file ) < 3 )
          continue;
        if( file[-1] == '~' )
          continue;
        if( file[-1] == 'o' && file[-2] == '.')
          continue;

        if( strip_extention(file) == what )
        {
          if( (search( file, ".pike" ) == strlen(file)-5 ) ||
              (search( file, ".so" ) == strlen(file)-3 ) ||
              (search( file, ".class" ) == strlen(file)-6 ) )
          {
            Stdio.File f = Stdio.File( dir+file, "r" );
            if( (f->read( 4 ) != "#!NO" ) )
              if( init_module( dir+file ) )
                return 1;
          }
        }
      };
  }

  int find_module( string sn )
  {
    foreach( roxenp()->query( "ModuleDirs" ), string dir )
      if( rec_find_module( sn, dir ) )
        return 1;
  }

  int check()
  {
    if( mapping data = module_cache->get( sname ) )
    {
      if( data->sname && data->sname != sname )
      {
        report_fatal( "Inconsistency in module cache. Ouch\n");
        return find_module(sname);
      }
      if( filename && (data->filename != filename ))
        report_debug("Possible module conflict for %s != %s\n",
                     data->filename, filename );
      else
      {
        filename = data->filename;
        array stat;
        if(!(stat = file_stat( filename ) ))
          filename=0;
        else
          if( data->last_checked >= stat[ ST_MTIME ] )
          {
            type = data->type;
            multiple_copies = data->multiple_copies;
            name = data->name;
            description = data->description;
            return 1;
          }
          else
          {
            last_checked = stat[ ST_MTIME ];
          }
      }
    }
    if( filename )
      return init_module( filename );
    else
      return find_module( sname );
  }

  void create( string sn, string|void fname )
  {
    if( sname )
    {
      report_fatal( "IDI\n");
      exit( 1 );
    }
    sname = sn;
    if( fname )
      filename = fname;
  }
}

string strip_extention( string from )
{
  from = reverse(from);
  sscanf(from, "%*[^.].%s", from );
  from = reverse(from);
  return from;
}

string extension( string from )
{
  from = reverse(from);
  sscanf(from, "%[^.].", from );
  from = reverse(from);
  return from||"";
}

mapping(string:ModuleInfo) modules;
array rec_find_all_modules( string dir )
{
  array modules = ({});
  catch
  {
    array dirlist = get_dir( dir ) - ({"CVS"});

    if( search( dirlist, ".nomodules" )  != -1)
      return ({});

    foreach( dirlist, string file )
      catch
      {
        if( file[0] == '.' ) continue;
        if( file[-1] == '~' ) continue;
        if( (< "so", "pike", "class" >)[ extension( file ) ] )
        {
          Stdio.File f = Stdio.File( dir+file, "r" );
          if( (f->read( 4 ) != "#!NO" ) )
            modules |= ({ strip_extention( file ) });
        }
        else if( file_stat( dir+file )[ ST_SIZE ] == -2 )
          modules |= rec_find_all_modules( dir+file+"/" );
      };
  };
  return modules;
}

array(ModuleInfo) all_modules()
{
  array possible = ({});
  foreach( roxenp()->query( "ModuleDirs" ), string dir )
    possible |= rec_find_all_modules( dir );

  foreach( possible, string p )
    modules[ p ] = find_module( p );

  array(ModuleInfo) tmp = values( modules ) - ({ 0 });
  sort( tmp->get_name(), tmp );
  return tmp;
}

ModuleInfo find_module( string name )
{
  if( !modules )
  {
    modules = ([]);
    module_cache = roxenp()->ConfigIFCache( "modules" );
  }

  if( modules[ name ] )
    return modules[ name ];

  modules[ name ] = ModuleInfo( name );

  if( !modules[ name ]->check() )
    m_delete( modules, name );

  return modules[ name ];
}
