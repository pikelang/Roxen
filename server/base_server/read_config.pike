// This file is part of Roxen WebServer.
// Copyright © 1996 - 2009, Roxen IS.
// $Id$

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

mapping (string:Stdio.Stat) config_stat_cache = ([]);
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
  return Array.uniq(map(filter(fii, lambda(string s){
	  if(s == "CVS" || s == "Global_Variables" || s == "Global Variables" ||
	     s == "global_variables" || s == "global variables" ||
	     s == "server_version" ||
	     s[0] == '_' || s[0] == '.' || s[0] == '#')
	    return 0;
	  return 1;
	}), lambda(string s) {
	  if (has_suffix(s, "~")) {
	    if (has_suffix(s, "~2~"))
	      s = s[..<3];
	    else
	      s = s[..<1];
	  }
	  return replace(utf8_to_string(s), "_", " ");
	}));
}


private	mapping call_outs = ([]);
private	Thread.Mutex call_outs_mutex = Thread.Mutex();
private	int counter = 0;
void save_it(string cl, mapping data)
{
  Thread.MutexKey lock = call_outs_mutex->lock();
  if( call_outs[ cl ] ) {
#ifdef DEBUG_CONFIG
    report_debug ("CONFIG: save_it removing call out for %O, count %O\n",
		  cl, call_outs[cl]->counter);
#endif
    remove_call_out( call_outs[ cl ]->callout );
  }
  data = COPY(data);
  counter++;
  call_outs[ cl ] = ([ "callout" : call_out( really_save_it, 0.1,
                                             cl, data, counter ),
                       "data" : data,
		       "counter" : counter ]);
#ifdef DEBUG_CONFIG
  report_debug ("CONFIG: save_it added call out for %O, count %O\n", cl, counter);
#endif
}

private void really_save_it( string cl, mapping data, int counter )
{
  Stdio.File fd;
  string f, new;

#ifdef DEBUG_CONFIG
  report_debug("CONFIG: Writing configuration file for cl %O, count %O\n",
	       cl, counter);
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

    if (fd->sync) {
      // Make sure that the data is synced to the filesystem,
      // some filesystems (eg ext4) otherwise may lose data
      // on reboot due to inodes being updated before data.
      fd->sync();
    }
    fd->close();

    fd = open( new, "r" );
    
    if(!fd)
      error("Failed to open new config file (" + new + ") for reading"
	    " (" + strerror (errno()) + ")\n" );
    config_stat_cache[cl] = fd->stat();

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
  Thread.MutexKey lock = call_outs_mutex->lock();
  if (call_outs[cl]) {
#ifdef DEBUG_CONFIG
    report_debug ("CONFIG: Reading data for %O count %O from call out list.\n",
		  cl, call_outs[cl]->counter);
#endif
    return call_outs[cl]->data;
  }
  lock = 0;

#ifdef DEBUG_CONFIG
  report_debug("CONFIG: Read configuration file for cl "+cl+"\n");
#endif

  string base = configuration_dir + replace(cl, " ", "_");
  Stdio.File fd;

  foreach(({ "", "~", "~2~" }), string suffix) {
    mixed err = catch {
#ifdef DEBUG_CONFIG
	report_debug("CONFIG: Trying " + base + suffix + "\n");
#endif
	fd = open(base + suffix, "r");
	if (!fd) {
	  report_warning("Failed to open configuration %sfile %O for %O.\n",
			 sizeof(suffix)?"backup ":"",
			 base + suffix, cl);
	  continue;
	}

	string data = fd->read();
	if (!sizeof(data || "")) {
	  report_error("Configuration %sfile %O for %O is truncated.\n",
		       sizeof(suffix)?"backup ":"",
		       base + suffix, cl);
	  continue;
	}

	config_stat_cache[cl] = fd->stat();
	fd->close();
	mapping res = decode_config_file( data );
	if (sizeof(suffix)) {
#ifdef DEBUG_CONFIG

	  report_debug("CONFIG: Restoring " + base + "\n");
#endif
	  mv(base + suffix, base);
	}
	return res;
      };

    catch (fd->close());

    if (err) {
      report_error("Failed to read configuration %sfile %O for %O.\n"
		   "%s\n",
		   sizeof(suffix)?"backup ":"",
		   base + suffix, cl,
		   describe_backtrace(err));
    }
  }

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

  rm (f + "~2~");
  if( file_stat(f+"~") && !mv(f+"~", f+"~2~") )
    rm( f+"~" ); // no error needed here, really...

  if( file_stat(f) && !mv(f, f+"~") ) {
    report_warning("Failed to move current config file (" + f + ") "
		   "to backup file (" + f + "~)"
		   " (" + strerror (errno()) + ")\n");
    if (file_stat (f) && !rm (f))
      error ("Failed to remove config file (" + f + ") "
	     "(" + strerror (errno()) + ")\n");
  }

  last_read = 0; last_data = 0;
}

void store( string reg, mapping(string:mixed) vars, int q,
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
    m = ([ ]);
    foreach ([mapping(string:Variable.Variable)] vars;
	     string name; Variable.Variable var) {
      if (var->save) {
	// Support for special save callbacks.
	savers[var->save] = 1;
      } else {
	m[ name ] = var->query();
      }
    }
    data[ reg ] = m;
    if(!sizeof( m ))
      m_delete( data, reg );
  }

  // Call any potential special save callbacks.
  indices(savers)();

  if( equal( old_reg, m ) ) {
#ifdef DEBUG_CONFIG
    report_debug ("CONFIG: Not storing %O in %O since data is equal.\n", reg, cl);
#endif
    return;
  }
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
