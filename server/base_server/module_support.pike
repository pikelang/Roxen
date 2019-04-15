// This file is part of Roxen Webserver.
// Copyright © 1996 - 2000, Roxen IS.
// $Id$
#define IN_ROXEN
#include <roxen.h>
#include <module_constants.h>
#include <stat.h>

//<locale-token project="roxen_config"> LOCALE </locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

program my_compile_file(string file, void|int silent)
{
  if( file[0] != '/' )
    file = replace(getcwd()+"/"+file, "//", "/");

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

  string ofile = master()->make_ofilename( file );

  if (p->dont_dump_program) {
#ifdef MODULE_DEBUG
    if (!silent) report_debug("\b[dontdump] \b");
#endif
  }
  else if( !file_stat( ofile ) ||
	   file_stat(ofile)[ST_MTIME] < file_stat(file)[ST_MTIME] )
    if( catch ( master()->dump_program( file, p ) ) )
    {
#ifdef MODULE_DEBUG
      if (!silent) report_debug("\b[nodump] \b");
#endif
      catch( Stdio.File( ofile, "wct" ) );
    } else {
#ifdef MODULE_DEBUG
      if (!silent) report_debug("\b[dump] \b");
#endif
    }
  return p;
}

function|program load( string what, void|int silent )
{
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
//  This is stored in a ConfigurationIFCache instance.
//
object module_cache;

class BasicModule
{
  inherit RoxenModule;
  inherit "basic_defvar";
  mapping error_log = ([]);
  constant is_module = 1;
  constant faked = 1;
  static Configuration _my_configuration;

  void report_fatal( mixed ... args )  { predef::report_fatal( @args );  }
  void report_error( mixed ... args )  { predef::report_error( @args );  }
  void report_notice( mixed ... args ) { predef::report_notice( @args ); }
  void report_debug( mixed ... args )  { predef::report_debug( @args );  }

  string file_name_and_stuff() { return ""; }
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
  string name, description;
  
  void save()  { }
  void update_with( RoxenModule mod, string what )  { }
  int init_module( string what )  { }
  int rec_find_module( string what, string dir )  { }
  int find_module( string sn )  { }
  int check (void|int force) { }

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
    array register_module()
    {
      return ({
	0, // type
	"Unknown module '"+sname+"'",
	"The module "+sname+"  could not be found in the module path.",
	0,1
      });
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

  mapping|string name;
  mapping|string description;

  static string _sprintf()
  {
    return "ModuleInfo("+sname+")";
  }

  string get_name()
  {
    if( !mappingp( name ) )
      return name || (sname + " (failed to load)");
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
      return description || "";
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

    string get_compile_errors()
    {
      return ("<pre><font color='&usr.warncolor;'>"+
	      Roxen.html_encode_string( ec->get()+"\n"+
					ec->get_warnings() ) +
	      "</font></pre>");
    }

    array register_module()
    {
      return ({
	0, // type
	sprintf(LOCALE(0,"Load of %s (%s) failed"),
		sname,filename),
	sprintf(LOCALE(0,"The module %s (%s) could not be loaded."),
		sname, get_name()||"unknown")+
	get_compile_errors(),0,0
      });
    }
  }
  
  RoxenModule instance( Configuration conf, void|int silent )
  {
    roxenloader.ErrorContainer ec = roxenloader.ErrorContainer();
    roxenloader.push_compile_error_handler( ec );
    mixed err = catch
    {
#if constant(Java.jvm)
      if( filename[sizeof(filename)-6..]==".class" ||
	  filename[sizeof(filename)-4..]==".jar" )
	return ((program)"javamodule.pike")(conf, filename);
#endif
      return load( filename, silent )( conf );
    };
    roxenloader.pop_compile_error_handler( );
    if( !silent )
      return LoadFailed( ec );
    if( err )
      werror( describe_backtrace( err ) );
    return 0;
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


  void update_with( RoxenModule mod, string what )
  {
    if(!what)
      what = filename;
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
  }

  int init_module( string what )
  {
    filename = what;
    mixed q =catch
    {
      object mod = instance( 0, 1 );
      if(!mod)
        throw(sprintf("Failed to instance %s (%s)\n", sname,what));
      if(!mod->register_module)
        throw(sprintf("The module %s (%s) has no register_module function\n",
                      sname, what ));
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

  int rec_find_module( string what, string dir )
  {
    array dirlist = (r_get_dir(dir) || ({})) - ({"CVS"});

    if( (search( dirlist, ".nomodules" ) != -1) ||
        (search( dirlist, ".no_modules" ) != -1) )
      return 0;

    foreach( dirlist, string file )
      catch
      {
        if( r_file_stat( dir+file )[ ST_SIZE ] == -2
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
              (search( file, ".jar" ) == strlen(file)-4 ) ||
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
array rec_find_all_modules( string dir )
{
  array modules = ({});
  catch
  {
    array dirlist = r_get_dir( dir ) - ({"CVS"});

    if( (search( dirlist, ".nomodules" ) != -1) ||
        (search( dirlist, ".no_modules" ) != -1) )
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
        else if( r_file_stat( dir+file )[ ST_SIZE ] == -2 )
          modules |= rec_find_all_modules( dir+file+"/" );
      };
  };
  return modules;
}

array(ModuleInfo) all_modules_cache;

void clear_all_modules_cache()
{
  all_modules_cache = 0;
  master()->clear_compilation_failures();
  foreach( values( modules ), object o )
    if( !o || !o->check() )
      m_delete( modules, search( modules, o ) );
}

array(ModuleInfo) all_modules()
{
  if( all_modules_cache ) 
    return all_modules_cache;

  if( !modules )
  {
    modules = ([]);
    module_cache = roxenp()->ConfigIFCache( "modules" ); 
  }

  array possible = ({});

  foreach( roxenp()->query( "ModuleDirs" ), string dir )
    possible |= rec_find_all_modules( dir );
  map( possible, find_module, 1 );
  array(ModuleInfo) tmp = values( modules ) - ({ 0 });
  sort( tmp->get_name(), tmp );
  return all_modules_cache = tmp;
}

ModuleInfo find_module( string name, int|void noforce )
{
  if( !modules )
  {
    modules = ([]);
    module_cache = roxenp()->ConfigIFCache( "modules" ); 
  }

  if( modules[ name ] )
    return modules[ name ];

  modules[ name ] = ModuleInfo( name,0 );

  if( !modules[ name ]->check() )
    m_delete( modules, name );

  if( !modules[ name ] && !noforce )
    return FakeModuleInfo( name );
  
  return modules[ name ];
}
