// This file is part of Roxen WebServer.
// Copyright © 1996 - 2001, Roxen IS.
// $Id: module.pike,v 1.197 2004/05/12 12:06:44 mast Exp $

#include <module_constants.h>
#include <module.h>
#include <request_trace.h>

constant __pragma_save_parent__ = 1;

inherit "basic_defvar";
mapping(string:array(int)) error_log=([]);

constant is_module = 1;
// constant module_type = MODULE_ZERO;
// constant module_name    = "Unnamed module";
// constant module_doc     = "Undocumented";
constant module_unique  = 1;


private Configuration _my_configuration;
private string _module_local_identifier;
private string _module_identifier =
  lambda() {
    mixed init_info = roxen->bootstrap_info->get();
    if (arrayp (init_info)) {
      [_my_configuration, _module_local_identifier] = init_info;
      return _my_configuration->name + "/" + _module_local_identifier;
    }
  }();
static mapping _api_functions = ([]);

string|array(string) module_creator;
string module_url;
RXML.TagSet module_tag_set;

/* These functions exists in here because otherwise the messages in
 * the event log does not always end up in the correct
 * module/configuration.  And the reason for that is that if the
 * messages are logged from subclasses in the module, the DWIM in
 * roxenlib.pike cannot see that they are logged from a module. This
 * solution is not really all that beautiful, but it works. :-)
 */
void report_fatal( mixed ... args )  { predef::report_fatal( @args );  }
void report_error( mixed ... args )  { predef::report_error( @args );  }
void report_notice( mixed ... args ) { predef::report_notice( @args ); }
void report_debug( mixed ... args )  { predef::report_debug( @args );  }


string module_identifier()
//! Returns a string that uniquely identifies this module instance
//! within the server. The identifier is the same as
//! @[Roxen.get_module] and @[Roxen.get_modname] handles.
{
#if 1
  return _module_identifier;
#else
  if (!_module_identifier) {
    string|mapping name = this_object()->register_module()[1];
    if (mappingp (name)) name = name->standard;
    string cname = sprintf ("%O", my_configuration());
    if (sscanf (cname, "Configuration(%s", cname) == 1 &&
	sizeof (cname) && cname[-1] == ')')
      cname = cname[..sizeof (cname) - 2];
    _module_identifier = sprintf ("%s,%s",
				  name||this_object()->module_name, cname);
  }
  return _module_identifier;
#endif
}

string module_local_id()
//! Returns a string that uniquely identifies this module instance
//! within the configuration. The returned string is the same as the
//! part after the first '/' in the one returned from
//! @[module_identifier].
{
  return _module_local_identifier;
}

RoxenModule this_module()
{
  return this_object(); // To be used from subclasses.
}

string _sprintf()
{
  return sprintf ("RoxenModule(%s)", _module_identifier || "?");
}

array register_module()
{
  return ({
    this_object()->module_type,
    this_object()->module_name,
    this_object()->module_doc,
    0,
    module_unique,
    this_object()->module_locked,
  });
}

string fix_cvs(string from)
{
  from = replace(from, ({ "$", "Id: "," Exp $" }), ({"","",""}));
  sscanf(from, "%*s,v %s", from);
  return replace(from,"/","-");
}

int module_dependencies(Configuration configuration,
                        array (string) modules,
                        int|void now)
//! If your module depends on other modules present in the server,
//! calling <pi>module_dependencies()</pi>, supplying an array of
//! module identifiers. A module identifier is either the filename
//! minus extension, or a string on the form that Roxen.get_modname
//! returns. In the latter case, the <config name> and <copy> parts
//! are ignored.
{
  modules = map (modules,
		 lambda (string modname) {
		   sscanf ((modname / "/")[-1], "%[^#]", modname);
		   return modname;
		 });
  Configuration conf = configuration || my_configuration();
  if (!conf)
    report_warning ("Configuration not resolved; module(s) %s that %s "
		    "depend on weren't added.", String.implode_nicely (modules),
		    module_identifier());
  else
    conf->add_modules( modules, now );
  return 1;
}

string file_name_and_stuff()
{
  return ("<b>Loaded from:</b> "+(roxen->filename(this_object()))+"<br>"+
	  (this_object()->cvs_version?
           "<b>CVS Version:</b> "+
           fix_cvs(this_object()->cvs_version)+"\n":""));
}


Configuration my_configuration()
//! Returns the Configuration object of the virtual server the module
//! belongs to.
{
  return _my_configuration;
}

nomask void set_configuration(Configuration c)
{
  if(_my_configuration && _my_configuration != c)
    error("set_configuration() called twice.\n");
  _my_configuration = c;
}

void set_module_creator(string|array(string) c)
//! Set the name and optionally email address of the author of the
//! module. Names on the format "author name <author_email>" will
//! end up as links on the module's information page in the admin
//! interface. In the case of multiple authors, an array of such
//! strings can be passed.
{
  module_creator = c;
}

void set_module_url(string to)
//! A common way of referring to a location where you maintain
//! information about your module or similar. The URL will turn up
//! on the module's information page in the admin interface,
//! referred to as the module's home page.
{
  module_url = to;
}

void free_some_sockets_please(){}

void start(void|int num, void|Configuration conf) {}

string status() {}

string info(Configuration conf)
{
 return (this_object()->register_module()[2]);
}

string sname( )
{
  return my_configuration()->otomod[ this_object() ];
}

ModuleInfo my_moduleinfo( )
//! Returns the associated @[ModuleInfo] object
{
  string f = sname();
  if( f ) return roxen.find_module( (f/"#")[0] );
}

void save_me()
{
  my_configuration()->save_one( this_object() );
  my_configuration()->module_changed( my_moduleinfo(), this_object() );
}

void save()      { save_me(); }
string comment() { return ""; }

string query_internal_location()
//! Returns the internal mountpoint, where <ref>find_internal()</ref>
//! is mounted.
{
  if(!_my_configuration)
    error("Please do not call this function from create()!\n");
  return _my_configuration->query_internal_location(this_object());
}

string query_absolute_internal_location(RequestID id)
//! Returns the internal mountpoint as an absolute path.
{
  return (id->misc->site_prefix_path || "") + query_internal_location();
}

string query_location()
//! Returns the mountpoint as an absolute path. The default
//! implementation uses the "location" configuration variable in the
//! module.
{
  string s;
  catch{s = query("location");};
  return s;
}

array(string) location_urls()
//! Returns an array of all locations where the module is mounted.
{
  string loc = query_location();
  if (!loc) return ({});
  if(!_my_configuration)
    error("Please do not call this function from create()!\n");
  array(string) urls = copy_value(_my_configuration->query("URLs"));
  string hostname;
  if (string world_url = _my_configuration->query ("MyWorldLocation"))
    sscanf (world_url, "%*s://%s%*[:/]", hostname);
  if (!hostname) hostname = gethostname();
  for (int i = 0; i < sizeof (urls); i++)
  {
    urls[i] = (urls[i]/"#")[0];
    if (sizeof (urls[i]/"*") == 2)
      urls[i] = replace(urls[i], "*", hostname);
  }
  return map (urls, `+, loc[1..]);
}

/* By default, provide nothing. */
string query_provides() { return 0; }


function(RequestID:int|mapping) query_seclevels()
{
  if(catch(query("_seclevels")) || (query("_seclevels") == 0))
    return 0;
  return roxen.compile_security_pattern(query("_seclevels"),this_object());
}

void set_status_for_path (string path, RequestID id, int status_code,
			  string|void message, mixed... args)
//! Register a status to be included in the response that applies only
//! for the given path. This is used for recursive operations that can
//! yield different results for different encountered files or
//! directories.
//!
//! The status is stored in the @[MultiStatus] object returned by
//! @[id->get_multi_status]. The server will use it to make a 207
//! Multi-Status response iff the module returns an empty mapping as
//! response.
//!
//! @param path
//!   Path below the filesystem location to which the status applies.
//!
//! @param status_code
//!   The HTTP status code.
//!
//! @param message
//!   If given, it's a message to include in the response. The
//!   message may contain line feeds ('\n') and ISO-8859-1
//!   characters in the ranges 32..126 and 128..255. Line feeds are
//!   converted to spaces if the response format doesn't allow them.
//!
//! @param args
//!   If there are more arguments after @[message] then @[message]
//!   is taken as an @[sprintf] style format string which is used to
//!   format @[args].
//!
//! @note
//! This function is just a wrapper for @[id->set_status_for_path]
//! that corrects for the filesystem location.
//!
//! @seealso
//! @[RequestID.set_status_for_path], @[Roxen.http_status]
{
  if (sizeof (args)) message = sprintf (message, @args);
  id->set_status_for_path (query_location() + path, status_code, message);
}

Stat stat_file(string f, RequestID id){}
array(string) find_dir(string f, RequestID id){}
mapping(string:Stat) find_dir_stat(string f, RequestID id)
{
  SIMPLE_TRACE_ENTER(this, "find_dir_stat(): %O", f);

  array(string) files = find_dir(f, id);
  mapping(string:Stat) res = ([]);

  foreach(files || ({}), string fname) {
    SIMPLE_TRACE_ENTER(this, "stat()'ing %O", f + "/" + fname);
    Stat st = stat_file(replace(f + "/" + fname, "//", "/"), id);
    if (st) {
      res[fname] = st;
      TRACE_LEAVE("OK");
    } else {
      TRACE_LEAVE("No stat info");
    }
  }

  TRACE_LEAVE("");
  return(res);
}

class DefaultPropertySet
{
  inherit PropertySet;

  static Stat stat;

  static void create (string path, string abs_path, RequestID id, Stat stat)
  {
    ::create (path, abs_path, id);
    this_program::stat = stat;
  }

  Stat get_stat() {return stat;}

  static mapping(string:string) response_headers;

  mapping(string:string) get_response_headers()
  {
    if (!response_headers) {
      // Old kludge inherited from configuration.try_get_file.
      if (!id->misc->common)
	id->misc->common = ([]);

      RequestID sub_id = id->clone_me();
      sub_id->misc->common = id->misc->common;

      sub_id->not_query = query_location() + path;
      sub_id->raw_url = replace (id->raw_url, id->not_query, sub_id->not_query);
      sub_id->method = "HEAD";

      mapping(string:mixed)|int(-1..0)|object res = find_file (path, sub_id);
      if (res == -1) res = ([]);
      else if (objectp (res)) {
	string ext;
	if(stringp(sub_id->extension)) {
	  sub_id->not_query += sub_id->extension;
	  ext = lower_case(Roxen.extension(sub_id->not_query, sub_id));
	}
	array(string) tmp=sub_id->conf->type_from_filename(sub_id->not_query, 1, ext);
	if(tmp)
	  res = ([ "file":res, "type":tmp[0], "encoding":tmp[1] ]);
	else
	  res = (["file": res]);
      }
      response_headers = sub_id->make_response_headers (res);
      destruct (sub_id);
    }

    return response_headers;
  }
}

//! Return the set of properties for @[path].
//!
//! @returns
//!   Returns @tt{0@} (zero) if @[path] does not exist.
//!
//!   Returns an error mapping if there's some other error accessing
//!   the properties.
//!
//!   Otherwise returns a @[PropertySet] object.
PropertySet|mapping(string:mixed) query_property_set(string path, RequestID id)
{
  SIMPLE_TRACE_ENTER (this, "Querying properties on %O", path);
  Stat st = stat_file(path, id);

  if (!st) {
    SIMPLE_TRACE_LEAVE ("No such file or dir");
    return 0;
  }

  PropertySet res = DefaultPropertySet(path, query_location()+path, id, st);
  SIMPLE_TRACE_LEAVE ("");
  return res;
}

//! Returns the value of the specified property, or an error code
//! mapping.
//!
//! @note
//!   Returning a string is shorthand for returning an array
//!   with a single text node.
string|array(Parser.XML.Tree.SimpleNode)|mapping(string:mixed)
  query_property(string path, string prop_name, RequestID id)
{
  mapping(string:mixed)|PropertySet properties = query_property_set(path, id);
  if (!properties) {
    return Roxen.http_status(Protocols.HTTP.HTTP_NOT_FOUND,
			     "No such file or directory.");
  }
  if (mappingp (properties))
    return properties;
  return properties->query_property(prop_name) ||
    Roxen.http_status(Protocols.HTTP.HTTP_NOT_FOUND, "No such property.");
}

//! RFC 2518 PROPFIND implementation with recursion according to
//! @[depth]. See @[find_properties] for details.
void recurse_find_properties(string path, string mode,
			     int depth, RequestID id,
			     multiset(string)|void filt)
{
  MultiStatus.Prefixed result =
    id->get_multi_status()->prefix (id->url_base() + query_location()[1..]);

  void recurse (string path, int depth) {
    SIMPLE_TRACE_ENTER (this, "%s for %O, depth %d",
			mode == "DAV:propname" ? "Listing property names" :
			mode == "DAV:allprop" ? "Retrieving all properties" :
			mode == "DAV:prop" ? "Retrieving specific properties" :
			"Finding properties with mode " + mode,
			path, depth);
    mapping(string:mixed)|PropertySet properties = query_property_set(path, id);

    if (!properties) {
      SIMPLE_TRACE_LEAVE ("No such file or dir");
      return;
    }

    {
      mapping(string:mixed) ret = mappingp (properties) ?
	properties : properties->find_properties(mode, result, filt);

      if (ret) {
	result->add_status (path, ret->error, ret->rettext);
	SIMPLE_TRACE_LEAVE ("Got status %d: %O", ret->error, ret->rettext);
	return;
      }
    }

    if (properties->get_stat()->isdir) {
      if (depth <= 0) {
	SIMPLE_TRACE_LEAVE ("Not recursing due to depth limit");
	return;
      }
      depth--;
      foreach(find_dir(path, id) || ({}), string filename) {
	recurse(combine_path_unix(path, filename), depth);
      }
    }

    SIMPLE_TRACE_LEAVE ("");
  };

  recurse (path, depth);
}

mapping(string:mixed) patch_properties(string path,
				       array(PatchPropertyCommand) instructions,
				       RequestID id)
{
  SIMPLE_TRACE_ENTER (this, "Patching properties for %O", path);
  mapping(string:mixed)|PropertySet properties = query_property_set(path, id);

  if (!properties) {
    SIMPLE_TRACE_LEAVE ("No such file or dir");
    return 0;
  }
  if (mappingp (properties)) {
    SIMPLE_TRACE_LEAVE ("Got error %d from query_property_set: %O",
			properties->error, properties->rettext);
    return properties;
  }

  mapping(string:mixed) errcode;

  if (errcode = write_access(path, 0, id)) {
    SIMPLE_TRACE_LEAVE("Patching denied by write_access().");
    return errcode;
  }

  if (errcode = properties->start()) {
    SIMPLE_TRACE_LEAVE ("Got error %d from PropertySet.start: %O",
			errcode->error, errcode->rettext);
    return errcode;
  }

  array(mapping(string:mixed)) results;

  mixed err = catch {
      results = instructions->execute(properties);
    };
  if (err) {
    properties->unroll();
    throw (err);
  } else {
    MultiStatus.Prefixed result =
      id->get_multi_status()->prefix (id->url_base() + query_location()[1..] + path);
    int any_failed;
    foreach(results, mapping(string:mixed) answer) {
      if (any_failed = (answer && (answer->error >= 300))) {
	break;
      }
    }
    if (any_failed) {
      // Unroll and fail any succeeded items.
      int i;
      mapping(string:mixed) answer =
	Roxen.http_status (Protocols.HTTP.DAV_FAILED_DEP, "Failed dependency.");
      for(i = 0; i < sizeof(results); i++) {
	if (!results[i] || results[i]->error < 300) {
	  result->add_property("", instructions[i]->property_name,
			       answer);
	} else {
	  result->add_property("", instructions[i]->property_name,
			       results[i]);
	}
      }
      properties->unroll();
    } else {
      int i;
      for(i = 0; i < sizeof(results); i++) {
	result->add_property("", instructions[i]->property_name,
			     results[i]);
      }
      properties->commit();
    }
  }

  SIMPLE_TRACE_LEAVE ("");
  return 0;
}

//! Convenience variant of @[patch_properties()] that sets a single
//! property.
//!
//! @returns
//!   Returns a mapping on any error, zero otherwise.
mapping(string:mixed) set_property (string path, string prop_name,
				    string|array(Parser.XML.Tree.SimpleNode) value,
				    RequestID id)
{
  mapping(string:mixed)|PropertySet properties = query_property_set(path, id);
  if (!properties) return Roxen.http_status(Protocols.HTTP.HTTP_NOT_FOUND,
					    "File not found.");
  if (mappingp (properties)) return properties;

  mapping(string:mixed) result = properties->start();
  if (result) return result;

  result = properties->set_property(prop_name, value);
  if (result && result->error >= 300) {
    properties->unroll();
    return result;
  }

  properties->commit();
  return 0;
}

//! Convenience variant of @[patch_properties()] that removes a single
//! property.
//!
//! @returns
//!   Returns a mapping on any error, zero otherwise.
mapping(string:mixed) remove_property (string path, string prop_name,
				       RequestID id)
{
  mapping(string:mixed)|PropertySet properties = query_property_set(path, id);
  if (!properties) return Roxen.http_status(Protocols.HTTP.HTTP_NOT_FOUND,
					    "File not found.");
  if (mappingp (properties)) return properties;

  mapping(string:mixed) result = properties->start();
  if (result) return result;

  result = properties->remove_property(prop_name);
  if (result && result->error >= 300) {
    properties->unroll();
    return result;
  }

  properties->commit();
  return 0;
}

string resource_id (string path, RequestID id)
//! Return a string that within the filesystem uniquely identifies the
//! resource on @[path] in the given request. This is commonly @[path]
//! itself but can be extended with e.g. language, user or some form
//! variable if the path is mapped to different files according to
//! those fields.
//!
//! The important criteria here is that every unique returned string
//! corresponds to a resource that can be changed independently of
//! every other. Thus e.g. dynamic pages that evaluate to different
//! results depending on variables or cookies etc should _not_ be
//! mapped to more than one string by this function. It also means
//! that if files are stored in a filesystem which is case insensitive
//! then this function should normalize case differences.
//!
//! This function is used e.g by the default lock implementation to
//! convert paths to resources that can be locked independently of
//! each other. There's also a notion of recursive locks there, which
//! means that a recursive lock on a certain resource identifier also
//! locks every resource whose identifier it is a prefix of. Therefore
//! it's typically necessary to ensure that every identifier ends with
//! "/" so that a recursive lock on e.g. "doc/foo" doesn't lock
//! "doc/foobar".
//!
//! @param path
//! The requested path below the filesystem location. It has been
//! normalized with @[VFS.normalize_path].
{
  return has_suffix (path, "/") ? path : path + "/";
}

string|int authenticated_user_id (string path, RequestID id)
//! Return a value that uniquely identifies the user that the given
//! request is authenticated as.
//!
//! This function is e.g. used by the default lock implementation to
//! tell different users holding locks apart.
//!
//! @param path
//! The requested path below the filesystem location. It has been
//! normalized with @[VFS.normalize_path].
{
  // Leave this to the standard auth system by default.
  User uid = my_configuration()->authenticate (id);
  return uid && uid->name();
}

// Mapping from resource id to a mapping from user id to the lock
// that apply to the resource.
//
// Only used internally by the default lock implementation.
static mapping(string:mapping(mixed:DAVLock)) file_locks = ([]);

// Mapping from resource id to a mapping from user id to the lock
// that apply recursively to the resource and all other resources
// it's a prefix of.
//
// Only used internally by the default lock implementation.
static mapping(string:mapping(mixed:DAVLock)) prefix_locks = ([]);

#define LOOP_OVER_BOTH(PATH, LOCKS, CODE)				\
  do {									\
    foreach (file_locks; PATH; LOCKS) {CODE;}				\
    foreach (prefix_locks; PATH; LOCKS) {CODE;}				\
  } while (0)

//! Find some or all locks that apply to @[path].
//!
//! @param path
//!   Normalized path below the filesystem location.
//!
//! @param recursive
//!   If @expr{1@} also return locks anywhere below @[path].
//!
//! @param exclude_shared
//!   If @expr{1@} do not return shared locks that are held by users
//!   other than the one the request is authenticated as. (This is
//!   appropriate to get the list of locks that would conflict if the
//!   current user were to make a shared lock.)
//!
//! @returns
//!   Returns a multiset containing all applicable locks in
//!   this location module, or @expr{0@} (zero) if there are none.
//!
//! @note
//! @[DAVLock] objects may be created if the filesystem has some
//! persistent storage of them. The default implementation does not
//! store locks persistently.
//!
//! @note
//! The default implementation only handles the @expr{"DAV:write"@}
//! lock type.
multiset(DAVLock) find_locks(string path,
			     int(0..1) recursive,
			     int(0..1) exclude_shared,
			     RequestID id)
{
  // Common case.
  if (!sizeof(file_locks) && !sizeof(prefix_locks)) return 0;

  TRACE_ENTER(sprintf("find_locks(%O, %O, %O, X)",
		      path, recursive, exclude_shared), this);

  path = resource_id (path, id);

  multiset(DAVLock) locks = (<>);
  function(mapping(mixed:DAVLock):void) add_locks;

  if (exclude_shared) {
    mixed auth_user = authenticated_user_id (path, id);
    add_locks = lambda (mapping(mixed:DAVLock) sub_locks) {
		  foreach (sub_locks; string user; DAVLock lock)
		    if (user == auth_user ||
			lock->lockscope == "DAV:exclusive")
		      locks[lock] = 1;
		};
  }
  else
    add_locks = lambda (mapping(mixed:DAVLock) sub_locks) {
		  locks |= mkmultiset (values (sub_locks));
		};

  if (file_locks[path]) {
    add_locks (file_locks[path]);
  }

  foreach(prefix_locks;
	  string prefix; mapping(mixed:DAVLock) sub_locks) {
    if (has_prefix(path, prefix)) {
      add_locks (sub_locks);
      break;
    }
  }

  if (recursive) {
    LOOP_OVER_BOTH (string prefix, mapping(mixed:DAVLock) sub_locks, {
	if (has_prefix(prefix, path)) {
	  add_locks (sub_locks);
	}
      });
  }

  add_locks = 0;

  TRACE_LEAVE(sprintf("Done, found %d locks.", sizeof(locks)));

  return sizeof(locks) && locks;
}

//! Check if there are one or more locks that apply to @[path] for the
//! user the request is authenticated as.
//!
//! @param path
//!   Normalized path below the filesystem location.
//!
//! @param recursive
//!   If @expr{1@} also check recursively under @[path] for locks.
//!
//! @returns
//!   The valid return values are:
//!   @mixed
//!     @type DAVLock
//!       The lock owned by the authenticated user that apply to
//!       @[path]. (It doesn't matter if the @expr{recursive@} flag in
//!       the lock doesn't match the @[recursive] argument.)
//!     @type LockFlag
//!       @int
//!         @value LOCK_NONE (0)
//!           No locks apply.
//!         @value LOCK_SHARED_BELOW (2)
//!           There are only one or more shared locks held by other
//!           users somewhere below @[path] (but not on @[path]
//!           itself). Only returned if @[recursive] is set.
//!         @value LOCK_SHARED_AT (3)
//!           There are only one or more shared locks held by other
//!           users on @[path].
//!         @value LOCK_OWN_BELOW (4)
//!           The authenticated user has locks under @[path] (but not
//!           on @[path] itself) and there are no exclusive locks held
//!           by other users. Only returned if @[recursive] is set.
//!         @value LOCK_EXCL_BELOW (6)
//!           There are one or more exclusive locks held by other
//!           users somewhere below @[path] (but not on @[path]
//!           itself). Only returned if @[recursive] is set.
//!         @value LOCK_EXCL_AT (7)
//!           There are one or more exclusive locks held by other
//!           users on @[path].
//!       @endint
//!       Note that the lowest bit is set for all flags that apply to
//!       @[path] itself.
//!   @endmixed
//!
//! @note
//! @[DAVLock] objects may be created if the filesystem has some
//! persistent storage of them. The default implementation does not
//! store locks persistently.
//!
//! @note
//! The default implementation only handles the @expr{"DAV:write"@}
//! lock type.
DAVLock|LockFlag check_locks(string path,
			     int(0..1) recursive,
			     RequestID id)
{
  // Common case.
  if (!sizeof(file_locks) && !sizeof(prefix_locks)) return 0;

  TRACE_ENTER(sprintf("check_locks(%O, %d, X)", path, recursive), this);

  path = resource_id (path, id);

  mixed auth_user = authenticated_user_id (path, id);

  if (DAVLock lock =
      file_locks[path] && file_locks[path][auth_user] ||
      prefix_locks[path] && prefix_locks[path][auth_user]) {
    TRACE_LEAVE(sprintf("Found lock %O.", lock->locktoken));
    return lock;
  }

  LockFlag shared;

  if (mapping(mixed:DAVLock) locks = file_locks[path]) {
    foreach(locks;; DAVLock lock) {
      if (lock->lockscope == "DAV:exclusive") {
	TRACE_LEAVE(sprintf("Found other user's exclusive lock %O.",
			    lock->locktoken));
	return LOCK_EXCL_AT;
      }
      shared = LOCK_SHARED_AT;
      break;
    }
  }

  foreach(prefix_locks;
	  string prefix; mapping(mixed:DAVLock) locks) {
    if (has_prefix(path, prefix)) {
      if (DAVLock lock = locks[auth_user]) return lock;
      if (!shared)
	// If we've found a shared lock then we won't find an
	// exclusive one anywhere else.
	foreach(locks;; DAVLock lock) {
	  if (lock->lockscope == "DAV:exclusive") {
	    TRACE_LEAVE(sprintf("Found other user's exclusive lock %O.",
				lock->locktoken));
	    return LOCK_EXCL_AT;
	  }
	  shared = LOCK_SHARED_AT;
	  break;
	}
    }
  }

  if (!recursive) {
    TRACE_LEAVE(sprintf("Returning %O.", shared));
    return shared;
  }

  int(0..1) locked_by_auth_user;

  // We want to know if there are any locks with @[path] as prefix
  // that apply to us.
  LOOP_OVER_BOTH (string prefix, mapping(mixed:DAVLock) locks, {
      if (has_prefix(prefix, path)) {
	if (locks[auth_user])
	  locked_by_auth_user = 1;
	else
	  foreach(locks;; DAVLock lock) {
	    if (lock->lockscope == "DAV:exclusive") {
	      TRACE_LEAVE(sprintf("Found other user's exclusive lock %O.",
				  lock->locktoken));
	      return LOCK_EXCL_BELOW;
	    }
	    if (!shared) shared = LOCK_SHARED_BELOW;
	    break;
	  }
      }
    });

  TRACE_LEAVE(sprintf("Returning %O.", locked_by_auth_user ? LOCK_OWN_BELOW : shared));
  return locked_by_auth_user ? LOCK_OWN_BELOW : shared;
}

//! Register @[lock] on the path @[path] under the assumption that
//! there is no other lock already that conflicts with this one, i.e.
//! that @code{check_locks(path,lock->recursive,id)@} would return
//! @expr{LOCK_NONE@} if @expr{lock->lockscope@} is
//! @expr{"DAV:exclusive"@}, or @expr{< LOCK_OWN_BELOW@} if
//! @expr{lock->lockscope@} is @expr{"DAV:shared"@}.
//!
//! This function is only provided as a helper to call from
//! @[lock_file] if the default lock implementation is to be used.
//!
//! @param path
//!   Normalized path below the filesystem location that the lock
//!   applies to.
//!
//! @param lock
//!   The lock to register.
//!
//! @note
//! The default implementation only handles the @expr{"DAV:write"@}
//! lock type. It uses @[resource_id] to map paths to unique resources
//! and @[authenticated_user_id] to tell users apart.
static void register_lock(string path, DAVLock lock, RequestID id)
{
  TRACE_ENTER(sprintf("register_lock(%O, lock(%O), X).", path, lock->locktoken),
	      this);
  ASSERT_IF_DEBUG (lock->locktype == "DAV:write");
  path = resource_id (path, id);
  mixed auth_user = authenticated_user_id (path, id);
  if (lock->recursive) {
    if (prefix_locks[path]) {
      prefix_locks[path][auth_user] = lock;
    } else {
      prefix_locks[path] = ([ auth_user:lock ]);
    }
  } else {
    if (file_locks[path]) {
      file_locks[path][auth_user] = lock;
    } else {
      file_locks[path] = ([ auth_user:lock ]);
    }
  }
  TRACE_LEAVE("Ok.");
}

//! Register @[lock] on the path @[path] under the assumption that
//! there is no other lock already that conflicts with this one, i.e.
//! that @code{check_locks(path,lock->recursive,id)@} would return
//! @expr{LOCK_NONE@} if @expr{lock->lockscope@} is
//! @expr{"DAV:exclusive"@}, or @expr{<= LOCK_SHARED_AT@} if
//! @expr{lock->lockscope@} is @expr{"DAV:shared"@}.
//!
//! The implementation must at least support the @expr{"DAV:write"@}
//! lock type (RFC 2518, section 7). Briefly: An exclusive lock on a
//! file prohibits other users from changing its content. An exclusive
//! lock on a directory (aka collection) prohibits other users from
//! adding or removing files or directories in it. An exclusive lock
//! on a file or directory prohibits other users from setting or
//! deleting any of its properties. A shared lock prohibits users
//! without locks to do any of this, and it prohibits other users from
//! obtaining an exclusive lock. A resource that doesn't exist can be
//! locked, provided the directory it would be in exists (relaxed in
//! RFC 2518Bis (working draft)).
//!
//! It's up to @[find_file] et al to actually check that the necessary
//! locks are held. It can preferably use @[write_access] for that,
//! which has a default implementation for checking
//! @expr{"DAV:write"@} locks.
//!
//! @param path
//!   Normalized path below the filesystem location that the lock
//!   applies to.
//!
//! @param lock
//!   The lock to register.
//!
//! @returns
//!   Returns @expr{0@} if the lock is successfully installed or if
//!   locking isn't used. Returns a status mapping if an error
//!   occurred.
mapping(string:mixed) lock_file(string path,
				DAVLock lock,
				RequestID id)
{
  return 0;
}

//! Remove @[lock] that currently is locking the resource at @[path].
//!
//! @param path
//!   Normalized path below the filesystem location that the lock
//!   applies to.
//!
//! @param lock
//!   The lock to unregister. (It must not be changed or destructed.)
//!
//! @returns
//!   Returns a status mapping on any error, zero otherwise.
mapping(string:mixed) unlock_file (string path,
				   DAVLock lock,
				   RequestID id)
{
  if (!sizeof (file_locks) && !sizeof (prefix_locks))
    return 0;			// Lock system not in use.
  TRACE_ENTER(sprintf("unlock_file(%O, lock(%O), X).", path, lock->locktoken),
	      this);
  mixed auth_user = authenticated_user_id (path, id);
  path = resource_id (path, id);
  DAVLock removed_lock;
  if (lock->recursive) {
    removed_lock = m_delete(prefix_locks[path], auth_user);
    if (!sizeof (prefix_locks[path])) m_delete (prefix_locks, path);
  }
  else if (file_locks[path]) {
    removed_lock = m_delete (file_locks[path], auth_user);
    if (!sizeof (file_locks[path])) m_delete (file_locks, path);
  }
  ASSERT_IF_DEBUG (lock /*%O*/ == removed_lock /*%O*/, lock, removed_lock);
  TRACE_LEAVE("Ok.");
  return 0;
}

//! Check if we may perform a write access to @[path].
//!
//! The default implementation checks if the current locks match the
//! if-header.
//!
//! Usually called from @[find_file()], @[delete_file()] or similar.
//!
//! @note
//!   Does not support checking against etags yet.
//!
//! @param path
//!   Path below the filesystem location that the lock applies to.
//!
//! @param recursive
//!   If @expr{1@} also check write access recursively under @[path].
//!
//! @returns
//!   Returns @expr{0@} (zero) on success, a status mapping on
//!   failure, or @expr{1@} if @[recursive] is set and write access is
//!   allowed on this level but maybe not somewhere below. The caller
//!   should in the last case do the operation on this level if
//!   possible and then handle each member in the directory
//!   recursively with @[write_access] etc.
mapping(string:mixed)|int(0..1) write_access(string relative_path,
					     int(0..1) recursive,
					     RequestID id)
{
  SIMPLE_TRACE_ENTER(this, "write_access(%O, %O, X)",
		     relative_path, recursive);

  int/*LockFlag*/|DAVLock lock = check_locks(relative_path, recursive, id);

  int(0..1) got_sublocks;
  if (lock && intp(lock)) {
    if (lock & 1) {
      TRACE_LEAVE("Locked by other user.");
      return Roxen.http_status(Protocols.HTTP.DAV_LOCKED);
    }
    else if (recursive)
      // This is set for LOCK_OWN_BELOW too since it might be
      // necessary to come back here and check the If header for
      // those locks.
      got_sublocks = 1;
  }

  string path = relative_path;
  if (!has_suffix (path, "/")) path += "/"; // get_if_data always adds a "/".
  path = query_location() + path; // No need for fancy combine_path stuff here.

  mapping(string:array(array(array(string)))) if_data = id->get_if_data();
  array(array(array(string))) condition;
  if (!if_data || !sizeof(condition = if_data[path] || if_data[0])) {
    if (lock) {
      TRACE_LEAVE("Locked, no if header.");
      return Roxen.http_status(Protocols.HTTP.DAV_LOCKED);
    }
    SIMPLE_TRACE_LEAVE("No lock and no if header - ok%s.",
		       got_sublocks ? " (this level only)" : "");
    return got_sublocks;	// No condition and no lock -- Ok.
  }

  string|int(-1..0) etag;

  mapping(string:mixed) res =
    lock && Roxen.http_status(Protocols.HTTP.DAV_LOCKED);
 next_condition:
  foreach(condition, array(array(string)) sub_cond) {
    SIMPLE_TRACE_ENTER(this,
		       "Trying condition ( %{%s:%O %})...", sub_cond);
    int negate;
    DAVLock locked = lock;
    foreach(sub_cond, array(string) token) {
      switch(token[0]) {
      case "not":
	negate = !negate;
	break;
      case "etag":
	if (!etag) {
	  // Get the etag for this resource (if any).
	  // FIXME: We only support straight strings as etag properties.
	  if (!stringp(etag = query_property(relative_path,
					     "DAV:getetag", id))) {
	    etag = -1;
	  }
	}
	if (etag != token[1]) {
	  // No etag available for this resource, or mismatch.
	  if (!negate) {
	    TRACE_LEAVE("Etag mismatch.");
	    continue next_condition;
	  }
	} else if (negate) {
	  // Etag match with negated expression.
	  TRACE_LEAVE("Matched negated etag.");
	  continue next_condition;
	}
	negate = 0;
	break;
      case "key":
	// The user has specified a key, so don't fail with DAV_LOCKED.
	if (res && res->error == Protocols.HTTP.DAV_LOCKED) {
	  res = 0;
	}
	if (negate) {
	  if (lock && lock->locktoken == token[1]) {
	    TRACE_LEAVE("Matched negated lock.");
	    continue next_condition;	// Fail.
	  }
	} else if (!lock || lock->locktoken != token[1]) {
	  // Lock mismatch.
	  TRACE_LEAVE("Lock mismatch.");
	  continue next_condition;	// Fail.
	} else {
	  locked = 0;
	}
	negate = 0;
	break;
      }
    }
    if (!locked) {
      TRACE_LEAVE("Found match.");
      SIMPLE_TRACE_LEAVE("Ok%s.",
			 got_sublocks ? " (this level only)" : "");
      return got_sublocks;	// Found matching sub-condition.
    }
    SIMPLE_TRACE_LEAVE("Conditional ok, but still locked (locktoken: %O).",
		       lock->locktoken);
  }

  TRACE_LEAVE("Failed.");
  return res || Roxen.http_status(Protocols.HTTP.HTTP_PRECOND_FAILED);
}

mapping(string:mixed)|int(-1..0)|Stdio.File find_file(string path,
						      RequestID id);

//! Delete the file specified by @[path].
//!
//! It's unspecified if it works recursively or not, but if it does
//! then it has to check DAV locks through @[write_access]
//! recursively.
//!
//! @returns
//!   Returns a 204 status on success, 0 if the file doesn't exist, or
//!   an appropriate status mapping for any other error.
//!
//! @note
//!   The default implementation falls back to @[find_file()].
mapping(string:mixed) delete_file(string path, RequestID id)
{
  // Fall back to find_file().
  RequestID tmp_id = id->clone_me();
  tmp_id->not_query = query_location() + path;
  tmp_id->method = "DELETE";
  // FIXME: Logging?
  return find_file(path, tmp_id) ||
    Roxen.http_status(tmp_id->misc->error_code || 404);
}

//! Delete @[path] recursively.
//! @returns
//!   Returns @expr{0@} (zero) on file not found.
//!   Returns @[Roxen.http_status(204)] on success.
//!   Returns other result mappings on failure.
mapping(string:mixed) recurse_delete_files(string path,
					   RequestID id,
					   void|MultiStatus.Prefixed stat)
{
  SIMPLE_TRACE_ENTER (this, "Deleting %O recursively", path);
  if (!stat)
    id->get_multi_status()->prefix (id->url_base() + query_location()[1..]);

  Stat st = stat_file(path, id);
  if (!st) {
    SIMPLE_TRACE_LEAVE ("No such file or directory");
    return 0;
  }

  mapping(string:mixed) recurse (string path, Stat st)
  {
    // Note: Already got an extra TRACE_ENTER level on entry here.

    if (st->isdir) {
      // RFC 2518 8.6.2
      //   The DELETE operation on a collection MUST act as if a
      //   "Depth: infinity" header was used on it.
      int fail;
      if (!has_suffix(path, "/")) path += "/";
      foreach(find_dir(path, id) || ({}), string fname) {
	fname = path + fname;
	if (Stat sub_stat = stat_file (fname, id)) {
	  SIMPLE_TRACE_ENTER (this, "Deleting %O recursively", fname);
	  mapping(string:mixed) sub_res = recurse(fname, sub_stat);
	  // RFC 2518 8.6.2
	  //   424 (Failed Dependancy) errors SHOULD NOT be in the
	  //   207 (Multi-Status).
	  //
	  //   Additionally 204 (No Content) errors SHOULD NOT be returned
	  //   in the 207 (Multi-Status). The reason for this prohibition
	  //   is that 204 (No Content) is the default success code.
	  if (sub_res && sub_res->error != 204 && sub_res->error != 424) {
	    stat->add_status(fname, sub_res->error, sub_res->rettext);
	    if (sub_res->error >= 300) fail = 1;
	  }
	}
      }
      if (fail) {
	SIMPLE_TRACE_LEAVE ("Partial failure");
	return Roxen.http_status(424);
      }
    }

    SIMPLE_TRACE_LEAVE ("");
    return 0;
  };

  return recurse(path, st) || delete_file(path, id) || Roxen.http_status(204);
}

mapping(string:mixed) make_collection(string path, RequestID id)
{
  // Fall back to find_file().
  RequestID tmp_id = id->clone_me();
  tmp_id->not_query = query_location() + path;
  tmp_id->method = "MKCOL";
  // FIXME: Logging?
  return find_file(path, tmp_id);
}

mapping(string:mixed) copy_properties(string source, string destination,
				      PropertyBehavior behavior, RequestID id)
{
  SIMPLE_TRACE_ENTER(this, "copy_properties(%O, %O, %O, %O)",
		     source, destination, behavior, id);
  PropertySet source_properties = query_property_set(source, id);
  PropertySet destination_properties = query_property_set(destination, id);

  multiset(string) property_set = source_properties->query_all_properties();
  mapping(string:mixed) res;
  foreach(property_set; string property_name;) {
    SIMPLE_TRACE_ENTER(this, "Copying the property %O.", property_name);
    string|array(Parser.XML.Tree.SimpleNode)|mapping(string:mixed) source_val =
      source_properties->query_property(property_name);
    if (mappingp(source_val)) {
      TRACE_LEAVE("Reading of property failed. Skipped.");
      continue;
    }
    string|array(Parser.XML.Tree.SimpleNode)|mapping(string:mixed) dest_val =
      destination_properties->query_property(property_name);
    if (dest_val == source_val) {
      TRACE_LEAVE("Destination already has the correct value.");
      continue;
    }
    mapping(string:mixed) subres =
      destination_properties->set_property(property_name, source_val);
    if (behavior == PROPERTY_OMIT) {
      TRACE_LEAVE("Omit verify.");
      continue;
    }
    if ((behavior == PROPERTY_ALIVE) && (subres->error < 300)) {
      // FIXME: Check that if the property was live in source,
      //        it is still live in destination.
      // This is likely already so, since we're in the same module.
    }
    if ((subres->error < 300) ||
	(subres->error == Protocols.HTTP.HTTP_CONFLICT)) {
      // Ok, or read-only property.
      TRACE_LEAVE("Copy ok or read-only property.");
      continue;
    }
    if (!subres) {
      // Copy failed, but attempt to copy the rest.
      res = Roxen.http_status(Protocols.HTTP.HTTP_PRECOND_FAILED);
    }
    TRACE_LEAVE("Copy failed.");
  }
  TRACE_LEAVE(res?"Failed.":"Ok.");
  return res;
}

//! Used by the default @[recurse_copy_files] to copy a collection
//! (aka directory).
static mapping(string:mixed) copy_collection(string source,
					     string destination,
					     PropertyBehavior behavior,
					     Overwrite overwrite,
					     MultiStatus.Prefixed result,
					     RequestID id)
{
  SIMPLE_TRACE_ENTER(this, "copy_collection(%O, %O, %O, %O, %O, %O).",
		     source, destination, behavior, overwrite, result, id);
  Stat st = stat_file(destination, id);
  if (st) {
    // Destination exists. Check the overwrite header.
    switch(overwrite) {
    case DO_OVERWRITE:
      // RFC 2518 8.8.4
      //   If a resource exists at the destination, and the Overwrite
      //   header is "T" then prior to performing the copy the server
      //   MUST perform a DELETE with "Depth: infinity" on the
      //   destination resource.
      TRACE_ENTER("Destination exists and overwrite is on.", this);
      mapping(string:mixed) res = recurse_delete_files(destination, id, result);
      if (res && (res->error >= 300)) {
	// Failed to delete something.
	TRACE_LEAVE("Deletion failed.");
	TRACE_LEAVE("Copy collection failed.");
	return Roxen.http_status(Protocols.HTTP.HTTP_PRECOND_FAILED);
      }
      TRACE_LEAVE("Deletion ok.");
      break;
    case NEVER_OVERWRITE:
      TRACE_LEAVE("Destination already exists.");
      return Roxen.http_status(Protocols.HTTP.HTTP_PRECOND_FAILED);
    case MAYBE_OVERWRITE:
      // No overwrite header.
      // Be nice, and fail only if we don't already have a collection.
      if (st->isdir) {
	TRACE_LEAVE("Destination exists and is a directory.");
	return copy_properties(source, destination, behavior, id);
      }
      TRACE_LEAVE("Destination exists and is not a directory.");
      return Roxen.http_status(Protocols.HTTP.HTTP_PRECOND_FAILED);
    }
  }
  // Create the new collection.
  TRACE_LEAVE("Make a new collection.");
  mapping(string:mixed) res = make_collection(destination, id);
  if (res && res->error >= 300) return res;
  return copy_properties(source, destination, behavior, id) || res;
}

mapping(string:mixed) copy_file(string source, string destination,
				PropertyBehavior behavior,
				Overwrite overwrite, RequestID id)
{
  SIMPLE_TRACE_ENTER(this, "copy_file(%O, %O, %O, %O, %O)\n",
		     source, destination, behavior, overwrite, id);
  TRACE_LEAVE("Not implemented yet.");
  return Roxen.http_status (Protocols.HTTP.HTTP_NOT_IMPL);
}

mapping(string:mixed) recurse_copy_files(string source, string destination, int depth,
					 mapping(string:PropertyBehavior) behavior,
					 Overwrite overwrite, RequestID id)
{
  SIMPLE_TRACE_ENTER(this, "recurse_copy_files(%O, %O, %O, %O, %O)\n",
		     source, destination, depth, behavior, id);
  string src_tmp = has_suffix(source, "/")?source:(source+"/");
  string dst_tmp = has_suffix(destination, "/")?destination:(destination+"/");
  if ((src_tmp == dst_tmp) ||
      has_prefix(src_tmp, dst_tmp) ||
      has_prefix(dst_tmp, src_tmp)) {
    TRACE_LEAVE("Source and destination overlap.");
    return Roxen.http_status(403, "Source and destination overlap.");
  }

  string loc = query_location();
  MultiStatus.Prefixed result =
    id->get_multi_status()->prefix (id->url_base() + loc[1..]);

  mapping(string:mixed) recurse(string source, string destination, int depth) {
    // Note: Already got an extra TRACE_ENTER level on entry here.

    Stat st = stat_file(source, id);
    if (!st) {
      TRACE_LEAVE("Source not found.");
      return 0;	/* FIXME: 404? */
    }
    // FIXME: Check destination?
    if (st->isdir) {
      mapping(string:mixed) res =
	copy_collection(source, destination,
			behavior[loc+source] || behavior[0],
			overwrite, result, id);
      if (res && (res->error != 204) && (res->error != 201)) {
	if (res->error >= 300) {
	  // RFC 2518 8.8.3 and 8.8.8 (error minimization).
	  TRACE_LEAVE("Copy of collection failed.");
	  return res;
	}
	result->add_status(destination, res->error, res->rettext);
      }
      if (depth <= 0) {
	TRACE_LEAVE("Non-recursive copy of collection done.");
	return res;
      }
      depth--;
      foreach(find_dir(source, id), string filename) {
	string subsrc = combine_path_unix(source, filename);
	string subdst = combine_path_unix(destination, filename);
	SIMPLE_TRACE_ENTER(this, "Recursive copy from %O to %O, depth %O\n",
			   subsrc, subdst, depth);
	mapping(string:mixed) sub_res = recurse(subsrc, subdst, depth);
	if (sub_res && (sub_res->error != 204) && (sub_res->error != 201)) {
	  result->add_status(combine_path_unix(destination, filename),
			     sub_res->error, sub_res->rettext);
	}
      }
      TRACE_LEAVE("");
      return res;
    } else {
      TRACE_LEAVE("");
      return copy_file(source, destination,
		       behavior[query_location()+source] ||
		       behavior[0],
		       overwrite, id);
    }
  };

  return recurse (source, destination, depth);
}

string real_file(string f, RequestID id){}

void add_api_function( string name, function f, void|array(string) types)
{
  _api_functions[name] = ({ f, types });
}

mapping api_functions()
{
  return _api_functions;
}

#if ROXEN_COMPAT <= 1.4
mapping(string:function) query_tag_callers()
//! Compat
{
  mapping(string:function) m = ([]);
  foreach(glob("tag_*", indices( this_object())), string q)
    if(functionp( this_object()[q] ))
      m[replace(q[4..], "_", "-")] = this_object()[q];
  return m;
}

mapping(string:function) query_container_callers()
//! Compat
{
  mapping(string:function) m = ([]);
  foreach(glob("container_*", indices( this_object())), string q)
    if(functionp( this_object()[q] ))
      m[replace(q[10..], "_", "-")] = this_object()[q];
  return m;
}
#endif

mapping(string:array(int|function)) query_simpletag_callers()
{
  mapping(string:array(int|function)) m = ([]);
  foreach(glob("simpletag_*", indices(this_object())), string q)
    if(functionp(this_object()[q]))
      m[replace(q[10..],"_","-")] =
	({ intp (this_object()[q + "_flags"]) && this_object()[q + "_flags"],
	   this_object()[q] });
  return m;
}

mapping(string:array(int|function)) query_simple_pi_tag_callers()
{
  mapping(string:array(int|function)) m = ([]);
  foreach (glob ("simple_pi_tag_*", indices (this_object())), string q)
    if (functionp (this_object()[q]))
      m[replace (q[sizeof ("simple_pi_tag_")..], "_", "-")] =
	({(intp (this_object()[q + "_flags"]) && this_object()[q + "_flags"]) |
	  RXML.FLAG_PROC_INSTR, this_object()[q]});
  return m;
}

RXML.TagSet query_tag_set()
{
  if (!module_tag_set) {
    array(function|program|object) tags =
      filter (rows (this_object(),
		    glob ("Tag*", indices (this_object()))),
	      lambda(mixed x) { return functionp(x)||programp(x); });
    for (int i = 0; i < sizeof (tags); i++)
      if (programp (tags[i]))
	if (!tags[i]->is_RXML_Tag) tags[i] = 0;
	else tags[i] = tags[i]();
      else {
	tags[i] = tags[i]();
	// Bogosity: The check is really a little too late here..
	if (!tags[i]->is_RXML_Tag) tags[i] = 0;
      }
    tags -= ({0});
    module_tag_set =
      (this_object()->ModuleTagSet || RXML.TagSet) (this_object(), "", tags);
  }
  return module_tag_set;
}

mixed get_value_from_file(string path, string index, void|string pre)
{
  Stdio.File file=Stdio.File();
  if(!file->open(path,"r")) return 0;
  if(has_suffix(index, "()"))
    index = index[..sizeof(index) - 3];

  //  Pass path to original file so that include statements for local files
  //  work correctly.
  return compile_string((pre || "") + file->read(), path)[index];
}

static private mapping __my_tables = ([]);

array(mapping(string:mixed)) sql_query( string query, mixed ... args )
//! Do a SQL-query using @[get_my_sql], the table names in the query
//! should be written as &table; instead of table. As an example, if
//! the tables 'meta' and 'data' have been created with create_tables
//! or get_my_table, this query will work:
//!
//! SELECT &meta;.id AS id, &data;.data as DATA
//!        FROM &data;, &meta; WHERE &my.meta;.xsize=200
//!
{
  return get_my_sql()->query( replace( query, __my_tables ), @args );
}

object sql_big_query( string query, mixed ... args )
//! Identical to @[sql_query], but the @[Sql.sql()->big_query] method
//! will be used instead of the @[Sql.sql()->query] method.
{
  return get_my_sql()->big_query( replace( query, __my_tables ), @args );
}

array(mapping(string:mixed)) sql_query_ro( string query, mixed ... args )
//! Do a read-only SQL-query using @[get_my_sql], the table names in the query
//! should be written as &table; instead of table. As an example, if
//! the tables 'meta' and 'data' have been created with create_tables
//! or get_my_table, this query will work:
//!
//! SELECT &meta;.id AS id, &data;.data as DATA
//!        FROM &data;, &meta; WHERE &my.meta;.xsize=200
//!
{
  return get_my_sql(1)->query( replace( query, __my_tables ), @args );
}

object sql_big_query_ro( string query, mixed ... args )
//! Identical to @[sql_query_ro], but the @[Sql.sql()->big_query] method
//! will be used instead of the @[Sql.sql()->query] method.
{
  return get_my_sql(1)->big_query( replace( query, __my_tables ), @args );
}

static int create_sql_tables( mapping(string:array(string)) definitions,
			      string|void comment,
			      int|void no_unique_names )
//! Create multiple tables in one go. See @[get_my_table]
//! Returns the number of tables that were actually created.
{
  int ddc;
  if( !no_unique_names )
    foreach( indices( definitions ), string t )
      ddc+=get_my_table( t, definitions[t], comment, 1 );
  else
  {
    Sql.Sql sql = get_my_sql();
    foreach( indices( definitions ), string t )
    {
      if( !catch {
	sql->query("CREATE TABLE "+t+" ("+definitions[t]*","+")" );
      } )
	ddc++;
      DBManager.is_module_table( this_object(), my_db, t, comment );
    }
  }
  return ddc;
}

static string sql_table_exists( string name )
//! Return the real name of the table 'name' if it exists.
{
  if(strlen(name))
    name = "_"+name;
  
  string res = hash(_my_configuration->name)->digits(36)
    + "_" + replace(sname(),"#","_") + name;

  return catch(get_my_sql()->query( "SELECT * FROM "+res+" LIMIT 1" ))?0:res;
}


static string|int get_my_table( string|array(string) name,
				void|array(string)|string definition,
				string|void comment,
				int|void flag )
//! @decl string get_my_table( string name, array(string) types )
//! @decl string get_my_table( string name, string definition )
//! @decl string get_my_table( string definition )
//! @decl string get_my_table( array(string) definition )
//!
//! Returns the name of a table in the 'shared' database that is
//! unique for this module. It is possible to select another database
//! by using @[set_my_db] before calling this function.
//!
//! You can use @[create_sql_tables] instead of this function if you want
//! to create more than one table in one go.
//! 
//! If @[flag] is true, return 1 if a table was created, and 0 otherwise.
//! 
//! In the first form, @[name] is the (postfix of) the name of the
//! table, and @[types] is an array of definitions, as an example:
//!
//! 
//! @code{
//!   cache_table = get_my_table( "cache", ({
//!               "id INT UNSIGNED AUTO_INCREMENT",
//!               "data BLOB",
//!               }) );
//! @}
//!
//! In the second form, the whole table definition is instead sent as
//! a string. The cases where the name is not included (the third and
//! fourth form) is equivalent to the first two cases with the name ""
//!
//! If the table does not exist in the datbase, it is created.
//!
//! @note
//!   This function may not be called from create
//
// If it exists, but it's definition is different, the table will be
// altered with a ALTER TABLE call to conform to the definition. This
// might not work if the database the table resides in is not a MySQL
// database (normally it is, but it's possible, using @[set_my_db],
// to change this).
{
  string oname;
  int ddc;
  if( !definition )
  {
    definition = name;
    oname = name = "";
  }
  else if(strlen(name))
    name = "_"+(oname = name);

  Sql.Sql sql = get_my_sql();

  string res = hash(_my_configuration->name)->digits(36)
    + "_" + replace(sname(),"#","_") + name;

  if( !sql )
  {
    report_error("Failed to get SQL handle, permission denied for "+my_db+"\n");
    return 0;
  }
  if( arrayp( definition ) )
    definition *= ", ";
  
  if( catch(sql->query( "SELECT * FROM "+res+" LIMIT 1" )) )
  {
    ddc++;
    mixed error =
      catch
      {
	get_my_sql()->query( "CREATE TABLE "+res+" ("+definition+")" );
	DBManager.is_module_table( this_object(), my_db, res,
				   oname+"\0"+comment );
      };
    if( error )
    {
      if( strlen( name ) )
	name = " "+name;
      report_error( "Failed to create table"+name+": "+
		    describe_error( error ) );
      return 0;
    }
    if( flag )
    {
      __my_tables[ "&"+oname+";" ] = res;
      return ddc;
    }
    return __my_tables[ "&"+oname+";" ] = res;
  }
//   // Update definition if it has changed.
//   mixed error = 
//     catch
//     {
//       get_my_sql()->query( "ALTER TABLE "+res+" ("+definition+")" );
//     };
//   if( error )
//   {
//     if( strlen( name ) )
//       name = " for "+name;
//     report_notice( "Failed to update table definition"+name+": "+
// 		   describe_error( error ) );
//   }
  if( flag )
  {
    __my_tables[ "&"+oname+";" ] = res;
    return ddc;
  }
  return __my_tables[ "&"+oname+";" ] = res;
}

static string my_db = "local";

static void set_my_db( string to )
//! Select the database in which tables will be created with
//! get_my_table, and also the one that will be returned by
//! @[get_my_sql]
{
  my_db = to;
}

Sql.Sql get_my_sql( int|void read_only )
//! Return a SQL-object for the database set with @[set_my_db],
//! defaulting to the 'shared' database. If read_only is specified,
//! the database will be opened in read_only mode.
//! 
//! See also @[DBManager.get]
{
  return DBManager.cached_get( my_db, _my_configuration, read_only );
}
