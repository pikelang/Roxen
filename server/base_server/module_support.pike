// string cvs_version = "$Id: module_support.pike,v 1.29 1999/10/18 20:29:58 marcus Exp $";
#include <roxen.h>
#include <module.h>
#include <stat.h>

class Codec
{
  program p;
  string nameof(mixed x)
  {
    if(p!=x)
      if(mixed tmp=search(all_constants(),x))
	return "efun:"+tmp;

    switch(sprintf("%t",x))
    {
      case "program":
	if(p!=x)
	{
          mixed tmp;
	  if(tmp=search(master()->programs,x))
	    return tmp;

	  if((tmp=search(values(_static_modules), x))!=-1)
	    return "_static_modules."+(indices(_static_modules)[tmp]);
	}
	break;

      case "object":
	if(mixed tmp=search(master()->objects,x))
	{
	  if(tmp=search(master()->programs,tmp))
	  {
	    return tmp;
	  }
	}
	break;
    }

    return ([])[0];
  }

  function functionof(string x)
  {
    if(sscanf(x,"efun:%s",x))
      return all_constants()[x];

    werror("Failed to decode %s\n",x);
    return 0;
  }


  object objectof(string x)
  {
    if(sscanf(x,"efun:%s",x))
      return all_constants()[x];

    if(object tmp=(object)x) return tmp;
    werror("Failed to decode %s\n",x);
    return 0;
    
  }

  program programof(string x)
  {
    if(sscanf(x,"efun:%s",x))
      return all_constants()[x];

    if(sscanf(x,"_static_modules.%s",x))
    {
      return (program)_static_modules[x];
    }

    if(program tmp=(program)x) return tmp;
    werror("Failed to decode %s\n",x);
    return 0;
  }

  mixed encode_object(object x)
  {
    error("Cannot encode objects yet.\n");
  }

  mixed decode_object(object x)
  {
    error("Cannot encode objects yet.\n");
  }

  void create( program q )
  {
    p = q;
  }
}


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
//  perror("Setvars: %O\n", vars);
  foreach( indices( vars ), v )
    if(variables[v])
      variables[v][ VAR_VALUE ] = vars[ v ];
  return 1;
}

static class ConfigurableWrapper
{
  int mode;
  function f;
  object roxen;

  int check(object id )
  {
    if((mode & VAR_EXPERT) && !id->misc->expert_mode )
      return 1;
    if((mode & VAR_MORE) && !id->misc->more_mode )
      return 1;
    return f();
  }

  void create(object roxen_, int mode_, function f_)
  {
    roxen = roxen_;
    mode = mode_;
    f = f_;
  }
};

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
	ConfigurableWrapper(this_object(), type, not_in_config)->check;
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

mixed set(string var, mixed val)
{
#if DEBUG_LEVEL > 30
  perror(sprintf("MAIN: set(\"%s\", %O)\n", var, val));
#endif
  if(variables[var])
  {
#if DEBUG_LEVEL > 28
    perror("MAIN:    Setting global variable.\n");
#endif
    return variables[var][VAR_VALUE] = val;
  }
  error("set("+var+"). Unknown variable.\n");
}



program my_compile_file(string file)
{
  string ofile = file + ".o";
#if 0
  if (file_stat (ofile) &&
      file_stat (ofile)[ST_MTIME] < remove_dumped_mark)
    rm (ofile);
#endif
  program p  = (program)( file );
  if( !file_stat( ofile ) ||
      file_stat(ofile)[ST_MTIME] <
      file_stat(file)[ST_MTIME] )
    if( catch 
    {
      string data = encode_value( p, Codec(p) );
      if( strlen( data ) )
        Stdio.File( ofile, "wct" )->write( data );
    } )
    {
#ifdef MODULE_DEBUG
      werror(" [nodump] ");
#endif
      Stdio.File( ofile, "wct" );
    } else {
#ifdef MODULE_DEBUG
      werror(" [dump] ");
#endif
    }
  return p;
}

function|program load( string what )
{
#if constant( compile_module )
  if( search( what, ".so" ) == strlen(what)-3 )
  {
    object mod = compile_module( what );
    if( !mod->instance )
      report_error("The module "+what+" does not have a 'instance' method\n");
    return mod->instance;
  } else
#endif    
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

class Module
{
  string sname;
  string filename;

  int last_checked;
  int type, multiple_copies;
  mapping|string name;
  mapping|string description;

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
      return name;
    if( mappingp( description ) )
    {
      if( description[ roxenp()->locale->get()->name ] )
        return description[ roxenp()->locale->get()->name ];
      return description[ "standard" ];
    }
  }

  object instance( object conf )
  {
    return load( filename )( conf );
  }

  void save()
  {
    module_cache->set( sname, 
                       ([ "filename":filename,
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
      array data = mod->register_module();

      type = data[0];
      if( data[ 1 ] )
        name = data[1];
      if( data[ 2 ] )
        description = data[2];
      if( sizeof( data ) > 4 )
        multiple_copies = !!data[4];
      save();
      destruct( mod );
      return 1;
    };
    if( q )
      werror( describe_backtrace( q ) );
    return 0;
  }

  int rec_find_module( string what, string dir )
  {
    array dirlist = (get_dir(dir) || ({})) - ({"CVS"});
    if( search( dirlist, ".nomodules" ) != -1)
      return 0;
    foreach( dirlist, string file )
      catch 
      {
        if( file_stat( dir+file )[ ST_SIZE ] == -2 &&
	    file != "." && file != ".." )
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
        
        if( !search( file, what ) )
        {
          if( (search( file, ".pike" ) == strlen(file)-5 ) ||
              (search( file, ".so" ) == strlen(file)-3 ) )
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
      if( filename && (data->filename != filename ))
        report_debug("Possible module conflict for %s, %s != %s\n",
                     data->filename, filename );
      else
      {
        filename = data->filename;
        array stat;
        if(!(stat = file_stat( filename ) ))
          filename=0;
        else
          if( last_checked == stat[ ST_MTIME ] )
          {
            last_checked = stat[ ST_MTIME ];
            type = data->type;
            multiple_copies = data->multiple_copies;
            name = data->name;
            description = data->description;
            return 1;
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
    sname = sn;
    if( fname ) 
      filename = fname;
    if( !check( ) )
    {
      destruct( );
    }
  }
}

string strip_extention( string from )
{
  from = reverse(from);
  sscanf(from, "%*[^.].%s", from );
  from = reverse(from);
  return from;
}

mapping(string:Module) modules;
array rec_find_all_modules( string dir )
{
  array dirlist = get_dir( dir ) - ({"CVS"});
  array modules = ({});
  if( search( dirlist, ".nomodules" ) )
    return 0;

  foreach( dirlist, string file )
    catch 
    {
      if( file[-1] == '~' ) continue;
      if( (search( file, ".pike" ) == strlen(file)-5 ) ||
          (search( file, ".so" ) == strlen(file)-3 ) )
      {
        Stdio.File f = Stdio.File( dir+file, "r" );
        if( (f->read( 4 ) != "#!NO" ) )
          modules |= ({ strip_extention( file ) });
      }
      if( file_stat( file )[ ST_SIZE ] == -2 )
        modules |= rec_find_all_modules( dir+file+"/" );
    };
  return modules;
}

array(Module) all_modules()
{
  array possible = ({});
  foreach( roxenp()->query( "ModuleDirs" ), string dir )
    possible |= rec_find_all_modules( dir );
  foreach( possible, string p )
    modules[ p ] = Module( p );
  return values( modules ) - ({ 0 });
}
  
Module find_module( string name )
{
  if( !modules )
  {
    modules = ([]);
    module_cache = roxenp()->ConfigIFCache( "modules" );
  }
  if( modules[ name ] )
    return modules[ name ];
  modules[ name ] = Module( name );
  if( !zero_type( modules[ name ] ) )
    return modules[ name ];
  return 0;
}
