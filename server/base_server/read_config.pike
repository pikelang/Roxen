// This file is part of Roxen Webserver.
// Copyright © 1996 - 2000, Roxen IS.
// $Id: read_config.pike,v 1.43 2000/08/20 03:25:23 per Exp $

#include <module.h>

#ifndef IN_INSTALL
inherit "newdecode";
#else
import spider;
# include "newdecode.pike"
#endif

#include <module_constants.h>

mapping (string:array(int)) config_stat_cache = ([]);
string configuration_dir; // Set by Roxen.

array(string) list_all_configurations()
{
  array (string) fii;
  fii=get_dir(configuration_dir);
  if(!fii)
  {
    mkdirhier(configuration_dir+"test"); // removes the last element..
    fii=get_dir(configuration_dir);
    if(!fii)
    {
      report_fatal("I cannot read from the configurations directory ("+
		   combine_path(getcwd(), configuration_dir)+")\n");
      exit(-1);	// Restart.
    }
    return ({});
  }
  return map(filter(fii, lambda(string s){
    if(s=="CVS" || s=="Global_Variables" || s=="Global Variables"
       || s=="global_variables" || s=="global variables" || s[0] == '_')
      return 0;
    return (s[-1]!='~' && s[0]!='#' && s[0]!='.');
  }), lambda(string s) { return replace(s, "_", " "); });
}


mapping call_outs = ([]);
void save_it(string cl, mapping data)
{
  if( call_outs[ cl ] )
    remove_call_out( call_outs[ cl ] );
  call_outs[ cl ] = call_out( really_save_it, 0.5, cl, (data+([])) );
}

void really_save_it( string cl, mapping data )
{
  Stdio.File fd;
  string f;

#ifdef DEBUG_CONFIG
  werror("CONFIG: Writing configuration file for cl "+cl+"\n");
#endif

  f = configuration_dir + replace(cl, " ", "_");
  fd = open(f+".new", "wct");

  if(!fd)
    error("Creation of configuration file failed ("+f+") "
	  " ("+strerror(errno())+")"
	  "\n");

  mixed err = catch 
  {
    object config;
#if constant( roxenp )
    config = roxenp();
    foreach(config->configurations||({}), object c)
      if(c->name == cl)
      {
        config = c;
        break;
      }
#endif
    string data = encode_regions( data, config );
    int num = fd->write( data );

    if(num != strlen(data))
      error("Failed to write all data to configuration file ("+f+") "
            " ("+strerror(fd->errno())+")"
            "\n");

    config_stat_cache[cl] = fd->stat();

    destruct(fd);

    fd = open( f+".new", "r" );
    
    if(!fd)
      error("Failed to open new config file for reading\n" );
    
    if( fd->read() != data )
      error("Config file differs from expected result");

    if( file_stat(f+"~") && !mv(f+"~", f+"~2~") )
      error("Failed to move backup config file to backup2 file\n");

    if( file_stat(f) && !mv(f, f+"~") )
      error("Failed to move current config file to backup file\n");

    if( !mv(f+".new", f) )
    {
      if( !mv( f+"~", f ) )
        error("Failed to move new config file to current file\n"
              "Failed to restore backup file!\n");
      error("Failed to move new config file to current file\n");
    }
    return;
  };
  if( !file_stat( f ) ) // Oups. Gone.
    mv( f+"~", f );
  rm( f+".new");
  throw( err );
}

array config_is_modified(string cl)
{
  array st = file_stat(configuration_dir + replace(cl, " ", "_"));

  if(st)
    if( !config_stat_cache[ cl ] )
      return st;
    else
      foreach( ({ 1, 3, 5, 6 }), int i)
	if(st[i] != config_stat_cache[cl][i])
	  return st;
}

mapping read_it(string cl)
{
  mixed err;
  string try_read( string f )
  {
    Stdio.File fd;
    err = catch
    {
      fd = open(f, "r");
      if( fd )
      {
        string data =  fd->read();
        if( strlen( data ) )
        {
          config_stat_cache[cl] = fd->stat();
          return data;
        }
      }
    };
  };

  string base = configuration_dir + replace(cl, " ", "_");
  foreach( ({ base, base+"~", base+"~1~" }), string attempt )
    if( string data = try_read( attempt ) )
      return decode_config_file( data );

  if (err) 
    report_error("Failed to read configuration file for %O\n"
                 "%s\n", cl, describe_backtrace(err));
  else
    report_error( "Failed to read configuration file for %O\n", cl );

  return ([]);
}


void remove( string reg , object current_configuration)
{
  string cl;
#ifndef IN_INSTALL
  if(!current_configuration)
#endif
    cl="Global Variables";
#ifndef IN_INSTALL
  else
    cl=current_configuration->name;
#endif

  mapping data = read_it(cl);
  m_delete( data, reg );
  save_it( cl, data );
}

void remove_configuration( string name )
{
  string f;
  f = configuration_dir + replace(name, " ", "_");
  if(!file_stat( f ))   
    f = configuration_dir+name;
  if( !rm(f) && file_stat(f) )
    error("Failed to remove configuration file ("+f+")!\n");
}

void store( string reg, mapping vars, int q, object current_configuration )
{
  string cl;
  mapping m;

#ifndef IN_INSTALL
  if(!current_configuration)
#endif
    cl="Global Variables";
#ifndef IN_INSTALL
  else
    cl=current_configuration->name;
#endif
  mapping data;
  if( cl == last_read )
    data = last_data;
  else 
    data = read_it(cl);



  mapping old_reg = (data[reg]||([])) + ([]);

  if(q)
    if( data[reg] )
      data[ reg ] |= vars;
    else
      data[ reg ] = vars;
  else
  {
    mixed var;
    m = ([ ]);
    foreach(indices(vars), var)
      m[ var ] = vars[ var ]->query();
    if(!sizeof( m ))
      m_delete( data, reg );
    else 
    {
      if( data[reg] )
        data[reg] |= m;
      else
        data[reg] = m;
    }
  }
  if( equal( old_reg, data[reg] ) )
    return;

  last_read = cl;
  last_data = data+([]);

  save_it(cl, data);
}

string last_read;
mapping last_data;

mapping(string:mixed) retrieve(string reg, object current_configuration)
{
  string cl;
#ifndef IN_INSTALL
  if(!current_configuration)
#endif
    cl="Global Variables";
#ifndef IN_INSTALL
  else
    cl=current_configuration->name;
#endif

  if( cl == last_read )
    return (last_data[ reg ]||([])) + ([]);

  mapping res = read_it( cl );
  if( res )
  {
    last_read = cl;
    last_data = res;
    return (res[ reg ]||([]))+([]);
  }
  return ([]);
}
