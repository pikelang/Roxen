// This file is part of ChiliMoon.
// Copyright © 1996 - 2001, Roxen IS.
// $Id: module_support.pike,v 1.122 2002/10/22 00:06:12 nilsson Exp $

#define IN_ROXEN
#include <module_constants.h>
#include <stat.h>
#include <roxen.h>

int dump( string file, program|void p );

program my_compile_file(string file, void|int silent)
{
  if( file[0] != '/' )
    file = combine_path(getcwd(), file);

  program p;

  ErrorContainer e = ErrorContainer();
  master()->set_inhibit_compile_errors(e);
  catch 
  {
    p  = (program)( file );
  };
  master()->set_inhibit_compile_errors(0);

  string q = e->get();
  if( !p )
  {
    if( strlen( q ) )
    {
      report_error("Failed to compile module %s:\n%s", file, q);
      if( strlen( e->get_warnings() ) )
        report_warning( e->get_warnings() );
    }
    throw( "" );
  }
  if ( strlen(q = e->get_warnings() ) )
  {
    report_warning(sprintf("Warnings during compilation of %s:\n"
                           "%s", file, q));
  }

  if (p->dont_dump_program)
  {
#ifdef MODULE_DEBUG
    if (!silent)
      report_debug("\b[dontdump] \b");
#endif
  }
#ifdef MODULE_DEBUG
  else
    dump( file, p );
//     switch (e->last_dump_status) {
//      case 1: // dumped
//        if (!silent) report_debug("\b[dump] \b");
//        break;
//      case -1:
//        if (!silent) report_debug("\b[nodump] \b");
//      case 0:
//     }
#endif
  return p;
}

function|program load( string what, void|int silent )
{
//   werror("Load "+what+"\n");
  return my_compile_file( what, silent );
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
//  This is stored in a AdminIFCache instance.
//
object module_cache; // Cannot be AdminIFCache, load order problems

class BasicModule
{
  inherit RoxenModule;
  inherit "basic_defvar";
  mapping error_log = ([]);
  constant is_module = 1;
  constant faked = 1;
  static Configuration _my_configuration;
  static string _module_local_identifier;
  static string _module_identifier =
    lambda() {
      mixed init_info = roxenp()->bootstrap_info->get();
      if (arrayp (init_info)) {
	[_my_configuration, _module_local_identifier] = init_info;
	return _my_configuration->name + "/" + _module_local_identifier;
      }
    }();

  void report_fatal( mixed ... args )  { predef::report_fatal( @args );  }
  void report_error( mixed ... args )  { predef::report_error( @args );  }
  void report_notice( mixed ... args ) { predef::report_notice( @args ); }
  void report_debug( mixed ... args )  { predef::report_debug( @args );  }

  string file_name_and_stuff() { return ""; }
  string module_identifier() {return _module_identifier;}
  string module_local_id() {return _module_local_identifier;}
  Configuration my_configuration() { return _my_configuration; }
  nomask void set_configuration(Configuration c)
  {
    if(_my_configuration && _my_configuration != c)
      error("set_configuration() called twice.\n");
    _my_configuration = c;
  }
  void start(void|int num, void|Configuration conf) {}

  string status() {}

  string info(Configuration conf)
  {
    return (this_object()->register_module()[2]);
  }

  void save_me() {}
  void save() {}
  string comment() { return ""; }
  array query_seclevels() { return ({}); }
  mapping api_functions() { return ([]); }
}

class FakeModuleInfo( string sname )
{
  int last_checked = time();
  constant filename = "NOFILE";
  constant type = 0;
  constant multiple_copies = 0;
  constant locked = 0;
  constant config_locked = ([]);
  string name, description;
  
  void save()  { }
  void update_with( RoxenModule mod, string what )  { }
  int init_module( string what )  { }
  int rec_find_module( string what, string dir )  { }
  int find_module( string sn )  { }
  int check (void|int force) { }
  int unlocked(object /*License.Key*/ key) { }

  static string _sprintf()
  {
    return "FakeModuleInfo("+sname+")";
  }

  string get_name()
  {
    return sname+" (not found)";
  }

  string get_description( )
  {
    return "This module was not found in the module path.";
  }

  class NotAModule
  {
    inherit BasicModule;
    constant not_a_module = 1;
    array register_module()
    {
      return ({
	0, // type
	"Unknown module '"+sname+"'",
	"The module "+sname+"  could not be found in the module path.",
	0,1
      });
    }
    string query_location()
    {
      return 0;
    }
    object query_tag_set()
    {
      return 0;
    }
    array(string)|multiset(string)|string query_provides()
    {
      return 0;
    }
  }

  RoxenModule instance( Configuration conf, void|int silent )
  {
    return NotAModule();
  }
}

class ModuleInfo( string sname, string filename )
{
  int last_checked;
  int type, multiple_copies;
  int|string locked;
  mapping(Configuration:int) config_locked = ([]);

  mapping|string name;
  mapping|string description;

  static string _sprintf()
  {
    return "ModuleInfo("+sname+")";
  }

  string get_name()
  {
    // NGSERVER cast to string due to LocaleString
    if( !mappingp( name ) )
      return (string)name;
    if( mappingp( name ) )
    {
      string q;
      if( q = name[ roxenp()->locale->get() ] )
        return q;
      return name[ "standard" ];
    }
  }

  string get_description()
  {
    if( !mappingp( description ) )
      return description;
    if( mappingp( description ) )
    {
      string q;
      if( q = description[ roxenp()->locale->get() ] )
        return q;
      return description[ "standard" ];
    }
  }

  static class LoadFailed(roxenloader.ErrorContainer ec) // faked module. 
  {
    inherit BasicModule;
    constant not_a_module = 1;

    string get_compile_errors()
    {
      return ("<pre><font color='&usr.warncolor;'>"+
	      Roxen.html_encode_string( ec->get()+"\n"+
					ec->get_warnings() ) +
	      "</font></pre>");
    }

    array register_module()
    {
      string locked_desc =
	(" The module is locked and not part of the license. "
	 "To enable this module please select a valid license "
	 "and restart the server.");
      return ({
	0, // type
	sprintf("Load of %s (%s) failed", sname, filename),
	sprintf("The module %s (%s) could not be loaded.",
		sname, get_name()||"unknown")+
	(sizeof(config_locked)?locked_desc:"")+
	get_compile_errors(),0,0
      });
    }
    
    string _sprintf()
    {
      return sprintf("LoadFailed(%s)", sname);
    }
  }
  
  RoxenModule instance( Configuration conf, void|int silent )
  {
    // werror("Instance %O <%O,%O,%O,%O,%O,%O>\n", this_object(),
    //        time()-last_checked,type,multiple_copies,name,description,locked);
    roxenloader.ErrorContainer ec = roxenloader.ErrorContainer();
    roxenloader.push_compile_error_handler( ec );
    mixed err = catch
    {
#if constant(Java.jvm)
      if( filename[sizeof(filename)-6..]==".class" ||
	  filename[sizeof(filename)-4..]==".jar" )
	return ((program)"javamodule.pike")(conf, filename);
#endif
      // Check if the module is locked. Throw an empty string to not
      // generate output, this is handled later.
      object key = conf && conf->getvar("license")->get_key();
      if(locked && !(key && unlocked(key))) {
	config_locked[conf] = 1;
	throw( "" );
      }
      return load( filename, silent )( conf );
    };
    roxenloader.pop_compile_error_handler( );
    if( err )
      if( stringp( err ) )
      {
	if( sizeof( err ) )
	  report_error(err+"\n");
      }
      else
	report_error( describe_backtrace( err ) );
    if( !silent )
      return LoadFailed( ec );
    return 0;
  }

  // NGSERVER: No localized module variables. Remove this function.
  static mixed encode_string( mixed what )
  {
    if( objectp( what ) && what->get_identifier ) // locale string.
      return (string)what;
    return what;
  }

  void save()
  {
    module_cache
      ->set( sname,
             ([
	       "filename":filename,
	       "sname":sname,
	       "last_checked":last_checked,
	       "type":type,
	       "multiple_copies":multiple_copies,
	       "name":encode_string(name),
	       "description":encode_string(description),
	       "locked":locked,
             ]) );
  }


  void update_with( RoxenModule mod, string what )
  {
    if(!what)
      what = filename;
    array data = mod->register_module();
    if(!arrayp(data))
      error("register_module returned %O for %s (%s)\n", data, sname,
	    what);
    if( sizeof(data) < 3 )
      error("register_module returned a too small array for %s (%s)\n",
	    sname, what);
    type = data[0];
    if( data[ 1 ] )
      name = data[1];
    if( data[ 2 ] )
      description = data[2];
    if( sizeof( data ) > 4 )
      multiple_copies = !data[4];
    else
      multiple_copies = 1;
    if( sizeof( data ) > 5)
      locked = data[5];
    last_checked = file_stat( filename )[ ST_MTIME ];
    save();
  }

  int init_module( string what )
  {
    filename = what;
    mixed q =catch
    {
      RoxenModule mod = instance( 0, 1 );
      if(!mod)
        error("Failed to instance %s (%s)\n", sname,what);
      if(!mod->register_module)
        error("The module %s (%s) has no register_module function\n",
	      sname, what );
      update_with( mod, what );
      destruct( mod );
      return 1;
    };
    if( stringp( q ) )
      report_debug( q );
    else if( q && sizeof(q) )
      report_debug(describe_backtrace(q));
    return 0;
  }


  static constant nomods = (< "pike-modules", "CVS" >);

  int rec_find_module( string what, string dir )
  {
    array dirlist = r_get_dir( dir );

    if( !dirlist || sizeof( dirlist & ({ ".nomodules", ".no_modules" }) ) )
      return 0;

    foreach( dirlist, string file )
      catch
      {
	Stdio.Stat s;
        if( file[0] != '.' &&
	    (s=file_stat( dir+file )) && s->isdir
	    && !nomods[file] )
          if( rec_find_module( what, dir+file+"/" ) )
            return 1;
	  else
	    continue;

        if( strlen( file ) < 3 )
	  continue;
        if( (< '~','#' >)[file[-1]] )
          continue;

        if( strip_extention(file) == what )
        {
	  
	  if( (< "pike", "so", "jar", "class" >)[ extension( file ) ] )
          {
            Stdio.File f = Stdio.File();
	    if( !f->open( dir+file, "r" ) )
	      throw( "Failed to open "+dir+file+"\n");
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

  int check (void|int force)
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
        Stat stat;
        if(!(stat = r_file_stat( filename ) ))
          filename=0;
        else
          if( data->last_checked >= stat[ ST_MTIME ] )
          {
            type = data->type;
            multiple_copies = data->multiple_copies;
            name = data->name;
            description = data->description;
	    locked = data->locked;
            return 1;
          }
          else
          {
            last_checked = stat[ ST_MTIME ];
          }
      }
    }
    if( filename )
      return init_module( roxen_path( filename ) );
    else
      return find_module( sname );
  }

  int unlocked(object /*License.Key*/ key)
  {
    return key->is_module_unlocked(stringp(locked)?locked:sname);
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
  string ext;
  sscanf(reverse(from), "%[^.].", ext);
  return ext ? reverse(ext) : "";
}

mapping(string:ModuleInfo) modules;
array(string) rec_find_all_modules( string dir )
{
  array(string) modules = ({});
  catch
  {
    Stdio.Stat s;
    array(string) dirlist = r_get_dir( dir ) - ({"CVS"});

    if( has_value( dirlist, ".nomodules" ) ||
        has_value( dirlist, ".no_modules" ) )
      return ({});

    foreach( dirlist, string file )
      catch
      {
        if( file[0] == '.' ) continue;
        if( file[-1] == '~' ) continue;
        if( (< "so", "pike",
#if constant(Java.jvm)
	       "class", "jar"
#endif
	>)[ extension( file ) ] )
        {
          Stdio.File f = open( dir+file, "r" );
          if( (f->read( 4 ) != "#!NO" ) )
            modules |= ({ strip_extention( file ) });
        }
        else if( (s = file_stat( dir+file )) &&
		 s->isdir &&
		 (file != "pike-modules") &&
		 (file != "CVS") )
          modules |= rec_find_all_modules( dir+file+"/" );
      };
  };
  return modules;
}

array(ModuleInfo) all_modules_cache;
array(string) all_pike_module_cache;

void clear_all_modules_cache()
{
  all_modules_cache = 0;
  all_pike_module_cache = 0;
  master()->clear_compilation_failures();
  foreach( modules; string m; RoxenModule o )
    if( !o || !o->check() )
      m_delete( modules, m );
}

array(ModuleInfo) all_modules()
{
  if( all_modules_cache ) 
    return all_modules_cache;

  report_debug("Searching for pike-modules directories ... \b");
  int t = gethrtime();
  foreach( find_all_pike_module_directories( ), string d )
    add_module_path( d );
  report_debug("\bDone [%dms]\n", (gethrtime()-t)/1000 );

  report_debug("Searching for roxen modules ... \b");
  t = gethrtime();
  if( !modules )
  {
    modules = ([]);
    module_cache = roxenp()->AdminIFCache( "modules" );
  }

  array(string) possible = ({});

  foreach( roxenp()->query( "ModuleDirs" ), string dir )
    possible |= rec_find_all_modules( dir );

  map( possible, find_module, 1 );
  array(ModuleInfo) tmp = values( modules ) - ({ 0 });
  tmp = filter( tmp, "get_name" );
  sort( (array(string))(tmp->get_name()), tmp );
  report_debug("\bDone [%dms]\n", (gethrtime()-t)/1000 );

  return all_modules_cache = tmp;
}


array(string) find_all_pike_module_directories()
{
  if( all_pike_module_cache ) return all_pike_module_cache;

  array(string) recurse( string dir )
  {
    Stdio.Stat st;
    array res = ({});
    foreach( get_dir( dir )||({}), string s )
      if( (st = file_stat( combine_path( dir, s ) )) && st->isdir )
	if( s == "pike-modules" )
	  res += ({ dir+"/pike-modules" });
	else if( s != "CVS" )
	  res += recurse( combine_path( dir, s ) );
    return res;
  };

  all_pike_module_cache = ({});
  foreach( roxenp()->query( "ModuleDirs" ), string dir )
    all_pike_module_cache += recurse( dir );
  return all_pike_module_cache;
}

// List of modules that have been renamed
static constant module_aliases = ([
  "whitespace_sucker":"whitespace_remover",
]);

ModuleInfo find_module( string name, int|void noforce )
{
  if( !modules )
  {
    modules = ([]);
    module_cache = roxenp()->AdminIFCache( "modules" );
  }

  if( modules[ name ] )
    return modules[ name ];

  modules[ name ] = ModuleInfo( name,0 );

  if( !modules[ name ]->check() ) {
    // Failed to load module.
    m_delete( modules, name );
    // Check for alias.
    if (module_aliases[name]) {
      report_notice("The module %s has been renamed %s.\n",
		    name, module_aliases[name]);
      return modules[ name ] = find_module(module_aliases[name], noforce);
    }
  }

  if( !modules[ name ] && !noforce )
    return FakeModuleInfo( name );
  
  return modules[ name ];
}
