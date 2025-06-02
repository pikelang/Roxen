#charset utf-8
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
             s[0] == '_' || s[0] == '.' || s[0] == '#' || s[-1] == '~')
            return 0;
          return 1;
        }), lambda(string s) {
          if (has_suffix(s, "~")) {
            if (has_suffix(s, "~2~"))
              s = s[..<3];
            else if (has_suffix(s, ".new~"))
              s = s[..<5];
            else
              s = s[..<1];
          }
          return replace(utf8_to_string(s), "_", " ");
        }));
}


private	mapping call_outs = ([]);
private	Thread.Mutex call_outs_mutex = Thread.Mutex();
private	int counter = 0;
void save_it(string cl, array(mapping) data)
{
  Thread.MutexKey lock = call_outs_mutex->lock();
  if( call_outs[ cl ] ) {
#ifdef DEBUG_CONFIG
    report_debug ("CONFIG: save_it removing call out for %O, count %O\n",
                  cl, call_outs[cl]->counter);
#endif
    remove_call_out( call_outs[ cl ]->callout );
  }
  data = ({ COPY(data[0]), COPY(data[1]) });
  counter++;
  call_outs[ cl ] = ([ "callout" : call_out( really_save_it, 0.1,
                                             cl, data, counter ),
                       "data" : data,
                       "counter" : counter ]);
#ifdef DEBUG_CONFIG
  report_debug ("CONFIG: save_it added call out for %O, count %O\n", cl, counter);
#endif
}

private void safe_save_config_file(string(8bit) conf_file, string(8bit) data)
{
  string f = configuration_dir + conf_file;

  // Check if noop.
  string(8bit) read_data = Stdio.read_file(f);
  if (read_data == data) return;

  string new = f + ".new~";
  Stdio.File fd = open(new, "wct");

  if(!fd)
    error("Creation of new config file ("+new+") failed"
          " ("+strerror(errno())+")"
          "\n");

  // Store data.
  int num = fd->write( data );

  mixed err = catch {
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

      // Verify content.
      fd = open( new, "r" );

      if(!fd)
        error("Failed to open new config file (" + new + ") for reading"
              " (" + strerror (errno()) + ")\n" );
      config_stat_cache[conf_file] = fd->stat();

      read_data = fd->read();
      if (!read_data)
        error ("Failed to read new config file (" + new + ")"
               " (" + strerror (fd->errno()) + ")\n");
      if( read_data != data )
        error("Config file differs from expected result");
      fd->close();

      // Rotate backup files.
      if( file_stat(f+"~") && !mv(f+"~", f+"~2~") )
        rm( f+"~" ); // no error needed here, really...

      if( file_stat(f) && !mv(f, f+"~") )
        error("Failed to move current config file (" + f + ") "
              "to backup file (" + f + "~)"
              " (" + strerror (errno()) + ")\n");

      // Activate the new config file.
      if( !mv(new, f) )
      {
        string msg = "Failed to move new config file (" + new + ") "
          "to current file (" + f + ")"
          " (" + strerror (errno()) + ")\n";
        if( !mv( f+"~", f ) )
          error(msg + "Failed to move restore backup file (" + f + "~)"
                " (" + strerror (errno()) + ")!\n");
        Stdio.cp( f+"~2~", f+"~" );
        error(msg);
      }

      if( !file_stat( f ) ) // Oups. Gone.
      {
        if (!mv( f+"~", f ))
          report_debug ("Failed to restore backup file (" + f + "~)"
                        " (" + strerror (errno()) + ")!\n");
        Stdio.cp( f+"~2~", f+"~" );
      }
    };
  if (err) {
    catch { fd->close(); };
    rm(new);
    throw(err);
  }
}

private void really_save_it( string cl, array(mapping) data, int counter )
{
#ifdef DEBUG_CONFIG
  report_debug("CONFIG: Writing configuration file for cl %O, count %O\n",
               cl, counter);
#endif

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

  // First the main configuration file.
  string(8bit) config_name = replace(string_to_utf8(cl), " ", "_");
  string enc_data = encode_regions( data[0], config );
  safe_save_config_file(config_name, enc_data);

  // Then any volatile variables.
  enc_data = encode_regions(data[1], config);
  safe_save_config_file("_volatile/" + config_name, enc_data);

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
}

Stat config_is_modified(string cl)
{
  string(8bit) conf_file = replace(string_to_utf8(cl), " ", "_");
  Stat st = file_stat(configuration_dir + conf_file);
  if(st)
    if( !config_stat_cache[ conf_file ] )
      return st;
    else
      foreach( ({ 1, 3, 5, 6 }), int i)
        if(st[i] != config_stat_cache[conf_file][i])
          return st;
}

private mapping safe_read_config_file(string(8bit) config_file)
{
  string(8bit) base = configuration_dir + config_file;
  foreach(({ "", ".new~", "~", "~2~" }), string suffix) {
    Stdio.File fd;
    mixed err = catch {
#ifdef DEBUG_CONFIG
        report_debug("CONFIG: Trying " + base + suffix + "\n");
#endif
        fd = open(base + suffix, "r");
        if (!fd) {
          // NB: Do not complain about not finding ephemeral file (*.new~),
          //     or volatile files (it is not an error for volatile files
          //     to be deleted).
          if ((suffix != ".new~") && !has_prefix(config_file, "_volatile")) {
            report_warning("Failed to open configuration %sfile %O.\n",
                           sizeof(suffix)?"backup ":"",
                           base + suffix);
          }
          continue;
        }

        string data = fd->read();
        if (!sizeof(data || "")) {
          if (suffix != ".new~") {
            report_error("Configuration %sfile %O is truncated.\n",
                         sizeof(suffix)?"backup ":"",
                         base + suffix);
          }
          continue;
        }

        config_stat_cache[config_file] = fd->stat();
        fd->close();
        mapping res = decode_config_file( data );
        if (sizeof(suffix)) {
#ifdef DEBUG_CONFIG
          report_debug("CONFIG: Restoring " + base + " from " +
                       base + suffix + "\n");
#endif
          mv(base + suffix, base);
        }
        return res;
      };

    catch (fd->close());

    if (err) {
      report_error("Failed to read configuration %sfile %O.\n"
                   "%s\n",
                   sizeof(suffix)?"backup ":"",
                   base + suffix,
                   describe_backtrace(err));
    }
  }

  return ([]);
}

//! Return an array of mappings where the first contains the
//! non-volatile variables for all modules, and the second
//! the volatile variables.
//!
//! @param cl
//!   Base configuration file name.
//!
//! @note
//!   This differs from Roxen 8.2 and earlier, where it
//!   simply returned a mapping.
array(mapping) read_it(string cl)
{
  Thread.MutexKey lock = call_outs_mutex->lock();
  mapping cl_info;
  if ((cl_info = call_outs[cl])) {
#ifdef DEBUG_CONFIG
    report_debug ("CONFIG: Reading data for %O count %O from call out list.\n",
                  cl, cl_info->counter);
#endif
    return cl_info->data;
  }
  lock = 0;

  if (cl == last_read) return last_data;

#ifdef DEBUG_CONFIG
  report_debug("CONFIG: Read configuration file for cl "+cl+"\n");
#endif

  string(8bit) config_file = replace(string_to_utf8(cl), " ", "_");

  mapping data = safe_read_config_file(config_file);

  mapping volatile_data = safe_read_config_file("_volatile/" + config_file);

  array(mapping) ret = ({ data, volatile_data });

  last_read = cl;
  last_data = ret;

  return ret;
}

//! Remove a region (ie typically a module) from a configuration.
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
  array(mapping) data = read_it(cl);
  m_delete( data[0], reg );
  m_delete( data[1], reg );
  save_it( cl, data );
}

void remove_configuration( string name )
{
  string f;
  string volatile_f;
  f = configuration_dir + replace(name, " ", "_");
  volatile_f = configuration_dir + "_volatile/" + replace(name, " ", "_");
  if(!file_stat( f ))
    f = configuration_dir+name;
#ifdef DEBUG_CONFIG
  report_debug("CONFIG: Remove "+f+"\n");
#endif

  rm(volatile_f + "~2~");
  rm(volatile_f + "~");
  rm(volatile_f);

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
//! Store the settings for a configuration region.
//!
//! @param reg
//!   Region name. This is typically a module local identifier
//!   (as returned by eg @[module()->module_local-id()]), but
//!   may also be one of a few special values (like eg
//!   @expr{"EnabledModules"@} or @expr{"Variables"@}). For
//!   historical reasons the value @expr{"spider#0"@} refers
//!   to the configuration itself.
//!
//! @param vars
//!   Variables. Either
//!   @mixed
//!     @type mapping(string:Variable)
//!       A mapping of configuration variables. This is used
//!       when @[q] is @expr{0@}.
//!
//!     @type mapping(string:mixed)
//!       A mapping from string to raw values. This is used
//!       when @[q] is @expr{1@}. This is typically only used
//!       for the @expr{"EnabledModules"@} region.
//!       Note that this variant does NOT support volatile variables.
//!   @endmixed
//!
//! @param q
//!   @[vars] mode, see above.
//!
//! @param current_configuration
//!   Configuration that the settings belong to.
{
  string cl;
  mapping m;
  mapping volatile_m;

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
  array(mapping) data;
  if( cl == last_read )
    data = last_data;
  else
    data = read_it(cl);

  mapping old_reg = data[0][ reg ];
  mapping old_volatile_reg = data[1][ reg ];

  mapping(function(:void):int(1..1)) savers = ([]);

  if(q) {
    data[0][ reg ] = m = vars;
    volatile_m = old_volatile_reg;
  } else
  {
    m = ([ ]);
    volatile_m = ([ ]);
    foreach ([mapping(string:Variable.Variable)] vars;
             string name; Variable.Variable var) {
      if (var->save) {
        // Support for special save callbacks.
        savers[var->save] = 1;
      } else {
        if (var->check_volatile()) {
          volatile_m[ name ] = var->encode();
        } else {
          m[ name ] = var->encode();
        }
      }
    }
    data[0][ reg ] = m;
    if(!sizeof( m ))
      m_delete( data[0], reg );
    data[1][ reg ] = volatile_m;
    if(!sizeof( volatile_m ))
      m_delete( data[1], reg );
  }

#ifdef DEBUG_CONFIG
  report_debug("CONFIG: Vars: %O\n"
               "CONFIG: M: %O\n"
               "CONFIG: Volatile_M: %O\n",
               vars, m, volatile_m);
#endif

  // Call any potential special save callbacks.
  indices(savers)();

  if( equal( old_reg, m ) &&  equal( old_volatile_reg, volatile_m ) ) {
#ifdef DEBUG_CONFIG
    report_debug ("CONFIG: Not storing %O in %O since data is equal.\n", reg, cl);
#endif
    return;
  }
  last_read = 0; last_data = 0;
  save_it(cl, data);
}

string last_read;
array(mapping) last_data;

//! Retrieve configuration settings for a region of a configuration.
//!
//! @param reg
//!   Region of interest. Typically @expr{"EnabledModules"@} or
//!   @expr{"Variables"@}.
//!
//! @param current_configuration
//!   @[Configuration] containing the settings. @expr{0@} for
//!   the global settings.
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

  array(mapping) res = read_it( cl );
  if( res ) {
    mapping ret = COPY( res[0][reg] );
    if (res[1] && res[1][reg]) {
      ret += res[1][reg];
    }
    return ret;
  }
  return ([]);
}
