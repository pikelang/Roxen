// This file is part of ChiliMoon.
// Copyright © 1996 - 2001, Roxen IS.
// $Id: read_config.pike,v 1.68 2002/11/02 17:56:36 mani Exp $

#include <module.h>
#include <module_constants.h>

// #define DEBUG_CONFIG

inherit "newdecode";

#define COPY( X ) ((X||([])) + ([]))

mapping (string:array(int)) config_stat_cache = ([]);
string configuration_dir; // NGSERVER: Remove this

array(string) list_all_configurations()
{
  array (string) fii = r_get_dir("$CONFIGDIR");

  if(!fii)
  {
    mkdirhier("$CONFIGDIR/test"); // removes the last element..
    fii=get_dir("$CONFIGDIR");
    if(!fii)
    {
      report_fatal("I cannot read from the configurations directory ("+
		   combine_path(getcwd(), roxen_path("$CONFIGDIR"))+")\n");
      exit(-1);	// Restart.
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

private string config_file(string cl) {
  return "$CONFIGDIR/" + replace(string_to_utf8(cl), " ", "_");
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

#ifdef DEBUG_CONFIG
  report_debug("CONFIG: Writing configuration file for cl "+cl+"\n");
#endif

  string f = config_file(cl);
  string new = f + ".new~";
  Stdio.File fd = open(new, "wct");

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

    if( !r_mv(new, f) )
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
  r_rm( new);
  throw( err );
}

Stat config_is_modified(string cl)
{
  Stat st = r_file_stat(config_file(cl));
  if(st)
    if( !config_stat_cache[ cl ] )
      return st;
    else
      foreach( ({ 1, 3, 5, 6 }), int i)
	if(st[i] != config_stat_cache[cl][i])
	  return st;
  return 0;
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

  string base = config_file(cl);
  if( string data = try_read( base ) )
    return decode_config_file( data );

  if (err) {
    string backup_file;
    if (r_file_stat (base + "~")) backup_file = base + "~";
    if (r_file_stat (base + "~2~")) backup_file = base + "~2~";
    report_error("Failed to read configuration file (%s) for %O.%s\n"
		 "%s\n",
		 base, cl,
		 backup_file ? " There is a backup file " + backup_file + ". "
		 "You can try it instead by moving it to the original name. " : "",
		 describe_backtrace(err));
  }

  return ([]);
}


void remove( string reg, Configuration current_configuration )
{
  string cl;
  if(!current_configuration)
    cl="Global Variables";
  else
    cl=current_configuration->name;
#ifdef DEBUG_CONFIG
  report_debug("CONFIG: Remove "+reg+" in "+cl+"\n");
#endif
  mapping data = read_it(cl);
  m_delete( data, reg );
  save_it( cl, data );
}

void remove_configuration( string name )
{
  string f = config_file(name);

#ifdef DEBUG_CONFIG
  report_debug("CONFIG: Remove "+f+"\n");
#endif
  catch(r_rm( f+"~2~" ));   catch(r_mv( f+"~", f+"~2~" ));
  catch(r_rm( f+"~" ));     catch(r_mv( f, f+"~" ));
  catch(r_rm( f ));
  last_read = 0; last_data = 0;

  if( r_file_stat( f ) )
    error("Failed to remove configuration file ("+f+")!\n");
}

void store( string reg, mapping vars, int q,
	    Configuration current_configuration )
{
  string cl;
  mapping m;

  if(!current_configuration)
    cl="Global Variables";
  else
    cl=current_configuration->name;
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
    foreach(vars; mixed var; mixed val) {
      if (val->save) {
	// Support for special save callbacks.
	savers[val->save] = 1;
      } else {
	m[ var ] = val->query();
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
  if(!current_configuration)
    cl="Global Variables";
  else
    cl=current_configuration->name;

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
