// This file is part of Roxen Webserver.
// Copyright © 1996 - 2000, Roxen IS.
// $Id: module_support.pike,v 1.71 2000/07/04 03:45:42 per Exp $

#include <roxen.h>
#include <module_constants.h>
#include <stat.h>

inherit "basic_defvar";

mixed save()
{
  roxenp()->store( "Variables", variables, 0, 0 );
}


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
      string q;
      if( q = name[ roxenp()->locale->get()->name ] )
        return q;
      return name[ "standard" ];
    }
  }

  string get_description()
  {
    if( stringp( description ) )
      return description;
    if( mappingp( description ) )
    {
      string q;
      if( q = description[ roxenp()->locale->get()->name ] )
        return q;
      return description[ "standard" ];
    }
  }

  object instance( object conf, void|int silent )
  {
#if constant(Java.jvm)
    if( filename[sizeof(filename)-6..]==".class" )
      return ((program)"javamodule.pike")(conf, filename);
#endif
    return load( filename, silent )( conf );
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


  void update_with( object mod, string what )
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
	       "class"
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
  map( possible, find_module );
  array(ModuleInfo) tmp = values( modules ) - ({ 0 });
  sort( tmp->get_name(), tmp );
  return all_modules_cache = tmp;
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
