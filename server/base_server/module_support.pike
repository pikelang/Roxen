// This file is part of Roxen WebServer.
// Copyright © 1996 - 2009, Roxen IS.
// $Id$

#define IN_ROXEN
#include <roxen.h>
#include <module_constants.h>
#include <stat.h>

protected int got_java_flag = 0;	// 1: yes, -1: no, 0: unknown.

int got_java()
//! @appears roxen.got_java
//!
//! Used to check dynamically whether Java support is available. If it
//! is then this function will initialize a JVM.
{
  if (!got_java_flag) {
    object jvm;
    if (mixed err = catch (jvm = master()->resolv ("Java.jvm")))
      report_error ("Failed to initialize Java JVM: %s\n",
#ifdef DEBUG
		    describe_backtrace (err)
#else
		    describe_error (err)
#endif
		   );
    got_java_flag = jvm ? 1 : -1;
  }
  return got_java_flag > 0;
}

//<locale-token project="roxen_config"> LOCALE </locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

int dump( string file, program|void p );

// Throws strings.
protected program my_compile_file(string file, void|int silent)
{
  if( file[0] != '/' )
    file = combine_path(roxenloader.server_dir, file);

  program p;

  ErrorContainer e = ErrorContainer();
  master()->set_inhibit_compile_errors(e);
  mixed err = catch
  {
    p  = (program)( file );
  };
  master()->set_inhibit_compile_errors(0);
  if (err &&
      (!objectp (err) || (!err->is_cpp_error && !err->is_compilation_error)))
    throw (err);

  string q = e->get();
  if (sizeof (q))
  {
    if (!p)
      report_error ("Failed to compile module %s:\n%s", file, q);
    else
      report_error ("Errors during compilation of %s:\n%s", file, q);
    if( strlen( q = e->get_warnings() ) )
      report_warning (q);
  }
  else if ( strlen( q = e->get_warnings() ) )
  {
    report_warning ("Warnings during compilation of %s:\n%s", file, q);
  }

  if (!p) throw ("");

  if (p->dont_dump_program)
  {
#if defined (ENABLE_DUMPING) && defined (MODULE_DEBUG)
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

// Throws strings.
protected function|program load( string what, void|int silent )
{
//   werror("Load "+what+"\n");
  return my_compile_file( what, silent );
}

protected int check_ambiguous_module (string name, array(string) files)
// A module can be loaded from more than one file. Report this and see
// if it really is ambiguous.
{
  string module_code = master()->master_read_file (files[0]);

  foreach (files[1..], string file)
    if (master()->master_read_file (file) != module_code) {
      report_error ("Module %O occurs in several ambiguous places:\n"
		    "%{  %s\n%}"
		    "The content is different - "
		    "the module is ignored.\n", name, files);
      // NB: This can be a compat problem in really flaky installations
      // which just happen to load the right module consistently, or if
      // there are only insignificant differences between them.
      return 1;
    }

  report_warning ("Module %O occurs in several ambiguous places:\n"
		  "%{  %s\n%}"
		  "The content is the same - "
		  "one will be used at random.\n", name, files);
  return 0;
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
object module_cache; // Cannot be ConfigIFCache, load order problems

class BasicModule
{
  inherit RoxenModule;
  inherit "basic_defvar";
  mapping error_log = ([]);
  constant is_module = 1;
  constant faked = 1;
  protected Configuration _my_configuration;
  protected string _module_local_identifier;
  protected string _module_identifier =
    lambda() {
      mixed init_info = roxenp()->bootstrap_info->get();
      if (arrayp (init_info)) {
	[_my_configuration, _module_local_identifier] = init_info;
	return _my_configuration->name + "/" + _module_local_identifier;
      }
    }();

  void report_fatal(sprintf_format fmt, sprintf_args ... args)
    { predef::report_fatal(fmt, @args); }
  void report_error(sprintf_format fmt, sprintf_args ... args)
    { predef::report_error(fmt, @args); }
  void report_warning(sprintf_format fmt, sprintf_args ... args)
    { predef::report_warning(fmt, @args); }
  void report_notice(sprintf_format fmt, sprintf_args ... args)
    { predef::report_notice(fmt, @args); }
  void report_debug(sprintf_format fmt, sprintf_args ... args)
    { predef::report_debug(fmt, @args); }
  
  string file_name_and_stuff() { return ""; }
  string module_identifier() {return _module_identifier;}
  string module_local_id() {return _module_local_identifier;}
  Configuration my_configuration() { return _my_configuration; }
  final void set_configuration(Configuration c)
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
  function(RequestID:int|mapping) query_seclevels() { return 0; }
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
  int find_module( string sn )  { }
  int check (void|int force) { }
  int unlocked(object /*License.Key*/ key, Configuration|void conf) { }

  protected string _sprintf()
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

  RoxenModule instance( Configuration conf, void|int silent,
			void|int copy_num )
  {
    // conf is zero if we're making the dummy instance for the
    // ModuleInfo class. Find a fallback for bootstrap_info just to
    // avoid returning zero from RoxenModule.my_configuration().
    Configuration bootstrap_conf = conf ||
      roxenp()->get_admin_configuration() ||
      // There should be at least one configuration present here.
      roxenp()->configurations[0];

    roxenp()->bootstrap_info->set (({bootstrap_conf,
				     sname + "#" + copy_num}));
 
    RoxenModule ret = NotAModule();

    roxenp()->bootstrap_info->set (0);
    return ret;
  }
}

class ModuleInfo( string sname, string filename )
{
  int last_checked;
  int type, multiple_copies;
  array(string) locked;
  string counter;
  mapping(Configuration:int) config_locked = ([]);

  mapping|string name;
  mapping|string description;

  protected string _sprintf()
  {
    return "ModuleInfo("+sname+")";
  }

  string get_name()
  {
    if( !mappingp( name ) )
      return name;
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

  protected class LoadFailed(roxenloader.ErrorContainer ec) // faked module. 
  {
    inherit BasicModule;
    constant not_a_module = 1;

    string get_compile_errors()
    {
      return ec?("<pre><font color='&usr.warncolor;'>"+
		 Roxen.html_encode_string( ec->get()+"\n"+
					   ec->get_warnings() ) +
		 "</font></pre>"):"";
    }

    array register_module()
    {
      string locked_desc =
	LOCALE(511," The module is locked and not part of the license. "
	       "To enable this module please select a valid license "
	       "and restart the server.");
      if (filename) {
	return ({
	  0, // type
	  sprintf(LOCALE(350,"Load of %s (%s) failed"),
		  sname,filename),
	  sprintf(LOCALE(351,"The module %s (%s) could not be loaded."),
		  sname, get_name()||"unknown")+
	  (sizeof(config_locked)?locked_desc:"")+
	  get_compile_errors(),0,0
	});
      } else {
	return ({
	  0, // type
	  sprintf(LOCALE(357, "Load of %s failed: Module not found."), sname),
	  sprintf(LOCALE(351, "The module %s (%s) could not be loaded."),
		  sname, get_name()||"unknown")+
	  (sizeof(config_locked)?locked_desc:"")+
	  get_compile_errors(),0,0
	});
      }
    }
    
    string _sprintf()
    {
      return sprintf("LoadFailed(%s)", sname);
    }
  }

  protected class DisabledModule
  {
    inherit BasicModule;
    constant not_a_module = 1;
    constant module_is_disabled = 1;
    array register_module()
    {
      return ({
	0, // type
	"Disabled module '"+sname+"'",
	"The module "+sname+" is disabled.",
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
  
  RoxenModule instance( Configuration conf, void|int silent,
			void|int copy_num)
  {
    // werror("Instance %O <%O,%O,%O,%O,%O,%O>\n", this_object(),
    //        time()-last_checked,type,multiple_copies,name,description,locked);
    if (!filename && !find_module(sname)) {
      // Module not found.
      return silent?0:LoadFailed(0);
    }

    // conf is zero if we're making the dummy instance for the
    // ModuleInfo class. Find a fallback for bootstrap_info just to
    // avoid returning zero from RoxenModule.my_configuration().
    Configuration bootstrap_conf = conf ||
      roxenp()->get_admin_configuration() ||
      // There should be at least one configuration present here.
      roxenp()->configurations[0];

    roxenloader.ErrorContainer ec = roxenloader.ErrorContainer();
    roxenloader.push_compile_error_handler( ec );
    mixed err = catch
    {
      if( (has_suffix (filename, ".class") || has_suffix (filename, ".jar")) &&
	  got_java()) {
	program java_wrapper = (program)"javamodule.pike";
	roxenp()->bootstrap_info->set (({bootstrap_conf,
					 sname + "#" + copy_num}));
	RoxenModule ret = java_wrapper(conf, filename);
	roxenp()->bootstrap_info->set (0);
	return ret;
      }
      // Check if the module is locked. Throw an empty string to not
      // generate output, this is handled later.
      object key = conf && conf->getvar("license")->get_key();
      if(locked && !(key && unlocked(key, conf))) {
	config_locked[conf] = 1;
#ifdef RUN_SELF_TEST
	werror ("Locked module: %O lock: %O\n",
		(string) (name || sname), locked * ":");
#endif
	throw( "" );
      }
      else
	m_delete(config_locked, conf);
      function|program prog = load( filename, silent );
      roxenp()->bootstrap_info->set (({bootstrap_conf,
				       sname + "#" + copy_num}));
      RoxenModule ret = prog( conf );
      roxenp()->bootstrap_info->set (0);
      if (ret->module_is_disabled) {
	destruct (ret);
	return DisabledModule();
      }
      return ret;
    };
    roxenloader.pop_compile_error_handler( );
    roxenp()->bootstrap_info->set (0);
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

  protected mixed encode_string( mixed what )
  {
    if( objectp( what ) && what->get_identifier ) // locale string.
    {
      array t = what->get_identifier();
      t[1] = 0;
      return t;
    }
    return what;
  }

  protected LocaleString decode_string( mixed what )
  {
    if( arrayp( what ) )
    {
      what[1] = get_locale;
      return Locale.DeferredLocale( @what );
    }
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
	       "locked":locked && locked * ":",
	       "counter":counter,
             ]) );
  }


  // Throws strings.
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
    if( sizeof( data ) > 5) {
      if (data[5]) locked = (stringp(data[5])?data[5]:sname)/":";
    }
    if( sizeof( data ) > 6 )
      counter = data[6];
    else
      counter = sname;
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
        throw(sprintf("Failed to instance %s (%s)\n", sname,what));
      if (mod->module_is_disabled)
	return 0;
      if(!mod->register_module)
        throw(sprintf("The module %s (%s) has no register_module function\n",
                      sname, what ));
      update_with( mod, what );
      destruct( mod );
      return 1;
    };
    if (q)
      if( stringp( q ) )
	report_debug( q );
      else
	report_debug(describe_backtrace(q));
    return 0;
  }


  protected constant nomods = (< "pike-modules", "CVS", ".svn", ".git" >);

  protected void rec_find_module_files (string what, string dir,
					multiset(string) files)
  {
    if (r_file_stat(combine_path(dir, ".nomodules")) ||
	r_file_stat(combine_path(dir, ".no_modules")))
      return;
    array dirlist = r_get_dir( dir );
    if (!dirlist)
      return;

    foreach( dirlist, string file ) {
	Stdio.Stat s;
	string fpath = combine_path(dir, file);
        if( file[0] != '.' &&
	    (s=file_stat( fpath )) && s->isdir
	    && !nomods[file] ) {
	  rec_find_module_files (what, fpath, files);
	  continue;
	}

        if( strlen( file ) < 3 )
	  continue;
        if( (< '~','#' >)[file[-1]] )
          continue;

        if( strip_extention(file) == what )
        {
	  
	  if( (< "pike", "so" >)[ extension( file ) ] ||
	      ( (< "class", "jar" >)[extension(file)] && got_java()))
          {
	    //  Skip inner classes in Java
	    if (has_value(file, "$") && has_suffix(file, ".class"))
	      continue;
	    
            Stdio.File f = Stdio.File();
	    if( !f->open( fpath, "r" ) )
	      report_error ("Failed to open %s: %s\n",
			    fpath, strerror (f->errno()));
	    else if( (f->read( 4 ) != "#!NO" ) )
	      files[fpath] = 1;
	  }
        }
    }
  }

  int find_module( string sn )
  {
    foreach( roxenp()->query( "ModuleDirs" ), string dir ) {
      dir = roxen_path (dir);
      multiset(string) files = (<>);
      rec_find_module_files (sn, dir, files);
      if (sizeof (files)) {
	if (sizeof (files) > 1 &&
	    check_ambiguous_module (sn, indices (files)))
	  return 0;
	else
	  return init_module (Multiset.Iterator (files)->index());
      }
    }
  }

  int check (void|int force)
  {
    if( mapping data = module_cache->get( sname ) )
    {
      if( data->sname && data->sname != sname )
      {
        report_fatal( "Inconsistency in module cache. Ouch (%O != %O)\n",
		      data->sname, sname);
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
            name = decode_string( data->name );
            description = decode_string( data->description );
	    locked = data->locked && data->locked/":";
	    counter = data->counter || sname;
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

  int unlocked(object /*License.Key*/ key, Configuration|void conf)
  {
    // NOTE: The locked string is module:feature:mode.
    switch(sizeof(locked)) {
    case 0:
      break;
    case 1:
      if (!key->is_module_unlocked(locked[0]))
	return 0;
      break;
    default:
    case 3:
      if (!sizeof(locked[1])) {
	if (!key->is_module_unlocked(locked[0], locked[2]))
	  return 0;
	break;
      }
      // FALL_THROUGH
    case 2:
      int val;	// Note: Use of zero_type() to promote old licenses.
      if (!(val = key->get_module_feature(@locked)) && !zero_type(val))
	return 0;
      break;
    }
    if (!conf) return 1;
    int|string cnt = key->get_module_feature(counter, "instances");
    if (!cnt || cnt == "*") return 1;
    return conf->counters[counter] < cnt;
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
protected void rec_find_all_modules( string dir,
				     mapping(string:string) modules )
{
    Stdio.Stat s;
    if (r_file_stat(combine_path(dir, ".nomodules")) ||
	r_file_stat(combine_path(dir, ".no_modules")))
      return;
    array(string) dirlist = (r_get_dir( dir ) || ({ }) ) - ({"CVS"});

    foreach( dirlist, string file ) {
        if( file[0] == '.' ) continue;
        if( file[-1] == '~' ) continue;
	string fpath = combine_path(dir, file);
	if( (< "so", "pike">)[ extension( file ) ] ||
	    (<"class", "jar">)[extension (file)] && got_java())
        {
	  //  Skip inner classes in Java
	  if (has_value(file, "$") && has_suffix(file, ".class"))
	    continue;
	  
	  Stdio.File f = Stdio.File();
	  if (!f->open( fpath, "r" ))
	    report_warning ("Failed to open %s: %s\n",
			    fpath, strerror (f->errno()));
	  else if( (f->read( 4 ) != "#!NO" ) )
	    modules[fpath] = strip_extention (file);
	}
	else if( (s = file_stat( fpath )) &&
		 s->isdir &&
		 (file != "pike-modules") &&
		 (file != "CVS") )
	  rec_find_all_modules( fpath, modules );
    }
}

array(ModuleInfo) all_modules_cache;
array(string) all_pike_module_cache;

void clear_all_modules_cache()
{
  all_modules_cache = 0;
  all_pike_module_cache = 0;
  master()->clear_compilation_failures();
  foreach( values( modules ), RoxenModule o )
    if( !o || !o->check() )
      m_delete( modules, search( modules, o ) );
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
    module_cache = roxenp()->ConfigIFCache( "modules" ); 
  }

  array(string) possible = ({});

  foreach( roxenp()->query( "ModuleDirs" ), string dir ) {
    dir = roxen_path (dir);
    mapping(string:string) module_files = ([]);
    rec_find_all_modules( dir, module_files );

    array(string) module_names = Array.uniq (values (module_files));
    if (sizeof (module_names) < sizeof (module_files)) {
      mapping(string:array(string)) inv = ([]);
      foreach (module_files; string file; string name)
	inv[name] += ({file});
      foreach (inv; string name; array(string) files)
	if (sizeof (files) > 1 && check_ambiguous_module (name, files))
	  m_delete (inv, name);
      module_names = indices (inv);
    }

    possible |= module_names;
  }

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
    all_pike_module_cache += recurse( roxen_path (dir) );
  return all_pike_module_cache;
}

// List of modules that have been renamed
protected constant module_aliases = ([
  "whitespace_sucker":"whitespace_remover",
]);

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
