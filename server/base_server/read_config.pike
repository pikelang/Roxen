// This file is part of Roxen WebServer.
// Copyright © 1996 - 2004, Roxen IS.
// $Id: read_config.pike,v 1.65 2004/06/30 16:58:39 mast Exp $

#include <module.h>

#ifndef IN_INSTALL
inherit "newdecode";
#else
import spider;
# include "newdecode.pike"
#endif

// #define DEBUG_CONFIG
#include <module_constants.h>

#define COPY( X ) ((X||([])) + ([]))

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
      roxenloader.real_exit(-1); // Restart.
    }
    return ({});
  }
  return map(filter(fii, lambda(string s){
    if(s=="CVS" || s=="Global_Variables" || s=="Global Variables"
       || s=="global_variables" || s=="global variables" || s=="server_version"
       || s[0] == '_')
      return 0;
    return (s[-1]!='~' && s[0]!='#' && s[0]!='.');
  }), lambda(string s) { return replace(utf8_to_string(s), "_", " "); });
}


mapping call_outs = ([]);
Thread.Mutex call_outs_mutex = Thread.Mutex();
int counter = 0;
void save_it(string cl, mapping data)
{
  Thread.MutexKey lock = call_outs_mutex->lock();
  if( call_outs[ cl ] )
    remove_call_out( call_outs[ cl ]->callout );
  data = COPY(data);
  counter++;
  call_outs[ cl ] = ([ "callout" : call_out( really_save_it, 0.1,
                                             cl, data, counter ),
                       "data" : data,
                       "counter" : counter ]);
}

void really_save_it( string cl, mapping data, int counter )
{
  Stdio.File fd;
  string f, new;

#ifdef DEBUG_CONFIG
  report_debug("CONFIG: Writing configuration file for cl "+cl+"\n");
#endif

  f = configuration_dir + replace(string_to_utf8(cl), " ", "_");
  new = f + ".new~";
  fd = open(new, "wct");

  if(!fd)
    error("Creation of new config file ("+new+") failed"
	  " ("+strerror(errno())+")"
	  "\n");

  mixed err = catch 
  {
    Configuration config;
#if constant( roxenp )
    config = roxenp();
    foreach(config->configurations||({}), Configuration c)
      if(c->name == cl)
      {
        config = c;
        break;
      }        
#endif
    string data = encode_regions( data, config );
    int num = fd->write( data );
    
    if(num != strlen(data))
      error("Failed to write all data to new config file ("+new+")"
            " ("+strerror(fd->errno())+")"
            "\n");

    fd->close();

    fd = open( new, "r" );
    config_stat_cache[cl] = fd->stat();
    
    if(!fd)
      error("Failed to open new config file (" + new + ") for reading"
	    " (" + strerror (errno()) + ")\n" );

    string read_data = fd->read();
    if (!read_data)
      error ("Failed to read new config file (" + new + ")"
	     " (" + strerror (fd->errno()) + ")\n");
    if( read_data != data )
      error("Config file differs from expected result");
    fd->close();

    if( file_stat(f+"~") && !mv(f+"~", f+"~2~") )
      rm( f+"~" ); // no error needed here, really...

    if( file_stat(f) && !mv(f, f+"~") )
      error("Failed to move current config file (" + f + ") "
	    "to backup file (" + f + "~)"
	    " (" + strerror (errno()) + ")\n");

    if( !mv(new, f) )
    {
      string msg = "Failed to move new config file (" + new + ") "
	"to current file (" + f + ")"
	" (" + strerror (errno()) + ")\n";
      if( !mv( f+"~", f ) )
        error(msg + "Failed to move back backup file (" + f + "~)"
	      " (" + strerror (errno()) + ")!\n");
      error(msg);
    }

    Thread.MutexKey lock = call_outs_mutex->lock();
    if( call_outs[ cl ] )
    {
      // Check if it's my entry in call_outs
      if (call_outs[ cl ]->counter == counter)
        m_delete( call_outs, cl );

#ifdef DEBUG_CONFIG
      report_debug("CONFIG: call_outs=%O\n",
                   mkmapping(indices(call_outs), values(call_outs)->counter));
#endif
    }

#ifdef DEBUG_CONFIG
    report_debug("CONFIG: Writing configuration file for cl "+cl+" DONE.\n");
#endif
    return;
  };
  if( !file_stat( f ) ) // Oups. Gone.
  {
    if (!mv( f+"~", f ))
      report_debug ("Failed to move back backup file (" + f + "~)"
		    " (" + strerror (errno()) + ")!\n");
    Stdio.cp( f+"~2~", f+"~" );
  }
  catch (fd->close());		// Can't remove open files on NT.
  rm( new);
  throw( err );
}

Stat config_is_modified(string cl)
{
  Stat st = file_stat(configuration_dir + replace(cl, " ", "_"));
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
  if (call_outs[cl])
    return call_outs[cl]->data;

#ifdef DEBUG_CONFIG
  report_debug("CONFIG: Read configuration file for cl "+cl+"\n");
#endif
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
	  fd->close();
          return data;
        }
	fd->close();
      }
    };
  };

  string base = configuration_dir + replace(cl, " ", "_");
  foreach( ({ base }), string attempt )
    if( string data = try_read( attempt ) )
      return decode_config_file( data );

  if (err) {
    string backup_file;
    if (file_stat (base + "~")) backup_file = base + "~";
    if (file_stat (base + "~2~")) backup_file = base + "~2~";
    report_error("Failed to read configuration file (%s) for %O.%s\n"
		 "%s\n",
		 base, cl,
		 backup_file ? " There is a backup file " + backup_file + ". "
		 "You can try it instead by moving it to the original name. " : "",
		 describe_backtrace(err));
  }
//else
//  report_error( "Failed to read configuration file for %O\n", cl );
  return ([]);
}


void remove( string reg , Configuration current_configuration )
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
#ifdef DEBUG_CONFIG
  report_debug("CONFIG: Remove "+reg+" in "+cl+"\n");
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
#ifdef DEBUG_CONFIG
  report_debug("CONFIG: Remove "+f+"\n");
#endif
  catch(rm( f+"~2~" ));   catch(mv( f+"~", f+"~2~" ));
  catch(rm( f+"~" ));     catch(mv( f, f+"~" ));
  catch(rm( f ));
  last_read = 0; last_data = 0;

  if( file_stat( f ) )
    error("Failed to remove configuration file ("+f+")!\n");
}

void store( string reg, mapping vars, int q,
	    Configuration current_configuration )
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
#ifdef DEBUG_CONFIG
  report_debug("CONFIG: Store "+reg+" in "+cl+"\n");
#endif
  mapping data;
  if( cl == last_read )
    data = last_data;
  else 
    data = read_it(cl);

  mapping old_reg = data[ reg ];

  mapping(function(:void):int(1..1)) savers = ([]);

  if(q)
    data[ reg ] = m = vars;
  else
  {
    mixed var;
    m = ([ ]);
    foreach(indices(vars), var) {
      if (vars[var]->save) {
	// Support for special save callbacks.
	savers[vars[var]->save] = 1;
      } else {
	m[ var ] = vars[ var ]->query();
      }
    }
    data[ reg ] = m;
    if(!sizeof( m ))
      m_delete( data, reg );
  }

  // Call any potential special save callbacks.
  indices(savers)();

  if( equal( old_reg, m ) )
    return;
  last_read = 0; last_data = 0;
  save_it(cl, data);
}

string last_read;
mapping last_data;

mapping(string:mixed) retrieve(string reg,
			       Configuration current_configuration)
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

#ifdef DEBUG_CONFIG
  report_debug("CONFIG: Retrieve "+reg+" in "+cl+"\n");
#endif
  if( cl == last_read )
    return COPY( last_data[ reg ] );

  mapping res = read_it( cl );
  if( res )
  {
    last_read = cl;
    last_data = res;
    return COPY( res[ reg ] );
  }
  return ([]);
}
