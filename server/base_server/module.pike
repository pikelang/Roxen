// This file is part of Roxen WebServer.
// Copyright © 1996 - 2001, Roxen IS.
// $Id: module.pike,v 1.167 2004/04/28 17:54:55 mast Exp $

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

  static void create (string path, RequestID id, Stat stat)
  {
    ::create (path, id);
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
PropertySet|mapping(string:mixed) query_properties(string path, RequestID id)
{
  SIMPLE_TRACE_ENTER (this, "Querying properties on %O", path);
  Stat st = stat_file(path, id);

  if (!st) {
    SIMPLE_TRACE_LEAVE ("No such file or dir");
    return 0;
  }

  PropertySet res = DefaultPropertySet(path, id, st);
  SIMPLE_TRACE_LEAVE ("");
  return res;
}

//! Returns the value of the specified property, or an error code
//! mapping.
//!
//! @note
//!   Returning a string is shorthand for returning an array
//!   with a single text node.
string|array(Parser.XML.Tree.Node)|mapping(string:mixed)
  query_property(string path, string prop_name, RequestID id)
{
  mapping(string:mixed)|PropertySet properties = query_properties(path, id);
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
			     int depth, MultiStatus result,
			     RequestID id,
			     multiset(string)|void filt)
{
  SIMPLE_TRACE_ENTER (this, "%s for %O, depth %d",
		      mode == "DAV:propname" ? "Listing property names" :
		      mode == "DAV:allprop" ? "Retrieving all properties" :
		      mode == "DAV:prop" ? "Retrieving specific properties" :
		      "Finding properties with mode " + mode,
		      path, depth);
  mapping(string:mixed)|PropertySet properties = query_properties(path, id);

  if (!properties) {
    SIMPLE_TRACE_LEAVE ("No such file or dir");
    return;
  }

  {
    mapping(string:mixed) ret = mappingp (properties) ?
      properties : properties->find_properties(mode, result, filt);

    if (ret) {
      result->add_response(path, XMLStatusNode(ret->error, ret->rettext));
      if (ret->rettext) {
	Parser.XML.Tree.ElementNode descr =
	  Parser.XML.Tree.ElementNode ("DAV:responsedescription", ([]));
	descr->add_child (Parser.XML.Tree.TextNode (ret->rettext));
	result->add_response (path, descr);
      }
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
      recurse_find_properties(combine_path(path, filename), mode, depth,
			      result, id, filt);
    }
  }

  SIMPLE_TRACE_LEAVE ("");
  return;
}

mapping(string:mixed) patch_properties(string path,
				       array(PatchPropertyCommand) instructions,
				       MultiStatus result, RequestID id)
{
  SIMPLE_TRACE_ENTER (this, "Patching properties for %O", path);
  mapping(string:mixed)|PropertySet properties = query_properties(path, id);

  if (!properties) {
    SIMPLE_TRACE_LEAVE ("No such file or dir");
    return 0;
  }
  if (mappingp (properties)) {
    SIMPLE_TRACE_LEAVE ("Got error %d from query_properties: %O",
			properties->error, properties->rettext);
    return properties;
  }

  mapping(string:mixed) errcode = properties->start();

  if (errcode) {
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
	  result->add_property(path, instructions[i]->property_name,
			       answer);
	} else {
	  result->add_property(path, instructions[i]->property_name,
			       results[i]);
	}
      }
      properties->unroll();
    } else {
      int i;
      for(i = 0; i < sizeof(results); i++) {
	result->add_property(path, instructions[i]->property_name,
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
				    string|array(Parser.XML.Tree.Node) value,
				    RequestID id)
{
  mapping(string:mixed)|PropertySet properties = query_properties(path, id);
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
  mapping(string:mixed)|PropertySet properties = query_properties(path, id);
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

#if 0
//! Mapping from canonical path to a mapping from username to
//! the locks that apply to the path.
//!
//! The @expr{0@} username is the anonymous user.
static mapping(string:mapping(string:DAVLock)) file_locks = ([]);

//! Mapping from canonical path prefix to a set of locks that apply
//! recursively to all files under that prefix.
//!
//! The @expr{0@} username is the anonymous user.
static mapping(string:mapping(string:DAVLock)) prefix_locks = ([]);

//! Find all locks that apply to @[path].
//!
//! @param path
//!   Canonical path. Always ends with a @expr{"/"@}.
//!
//! @param recursive
//!   If @expr{1@} also return all locks under @[path].
//!
//! @returns
//!   Returns a multiset containing all applicable locks in
//!   this location module, or @expr{0@} (zero) if there are none.
multiset(DAVLock) find_all_locks(string path,
				 int(0..1) recursive,
				 RequestID id)
{
  // Common case.
  if (!sizeof(file_locks) && !sizeof(prefix_locks)) return 0;

  multiset(DAVLock) locks = (<>);
  if (file_locks[path]) {
    locks = (< @values(file_locks[path]) >);
  }
  foreach(prefix_locks;
	  string prefix; mapping(string:DAVLock) sub_locks) {
    if (has_prefix(path, prefix)) {
      locks |= (< @values(sub_locks) >);
      break;
    }
  }
  if (recursive) {
    foreach(file_locks|prefix_locks;
	    string prefix; mapping(string:DAVLock) sub_locks) {
      if (has_prefix(prefix, path)) {
	locks |= (< @values(sub_locks) >);
      }
    }
  }
  return sizeof(locks) && locks;
}

//! Find if there is a lock that applies to @[path]
//! for the specified user.
//!
//! @param path
//!   Canonical path. Always ends with a @expr{"/"@}.
//!
//! @param recursive
//!   If @expr{1@} also return all locks under @[path].
//!
//! @param user
//!   Username, usually @expr{id->misc->authenticated_user->name()@}.
//!
//! @returns
//!   @mixed
//!     @type DAVLock
//!       Returns the lock if it is owned by the user.
//!     @type int(-1..1)
//!       @int
//!         @value -1
//!           Returns @expr{-1@} if there's an exclusive lock.
//!         @value 0
//!           Returns @expr{0@} if no locks apply.
//!         @value 1
//!           Returns @expr{1@} if there are shared lock(s).
//!       @endint
//!   @endmixed
DAVLock|int(-1..1) find_user_lock(string path, string user, RequestID id)
{
  // Common case.
  if (!sizeof(file_locks) && !sizeof(prefix_locks)) return 0;

  int(0..1) shared;
  mapping(string:DAVLock) locks;
  if (locks = file_locks[path]) {
    if (locks[user]) return locks[user];
    foreach(locks; string user; DAVLock lock) {
      if (lock->lockscope == "DAV:exclusive") return -1;
      shared = 1;
      break;
    }
  }
  foreach(prefix_locks; string prefix; locks) {
    if (has_prefix(path, prefix)) {
      if (locks[user]) return locks[user];
      foreach(locks; string user; DAVLock lock) {
	if (lock->lockscope == "DAV:exclusive") return -1;
	shared = 1;
	break;
      }
    }
  }
  return shared;
}

//! Find all locks that apply to @[path] recursively
//! for the specified user.
//!
//! @param path
//!   Canonical path. Always ends with a @expr{"/"@}.
//!
//! @param user
//!   Username, usually @expr{id->misc->authenticated_user->name()@}.
//!
//! @returns
//!   Returns a multiset containing all applicable locks in
//!   this location module, or @expr{0@} (zero) if there are none.
multiset(DAVLock)|int(-1..1) recur_find_user_locks(string path,
						   string user,
						   RequestID id)
{
  // Common case.
  if (!sizeof(file_locks) && !sizeof(prefix_locks)) return 0;

  int(-1..1)|DAVLock lock = find_user_lock(path, user, id);

  if (lock == -1) return -1;

  int(0..1) shared;
  multiset(DAVLock) ret = (<>);

  if (intp(lock)) shared = lock;
  else {
    ret[lock] = 1;
    if (lock->recursive) return ret;
  }

  // We want to know if there are any locks with @[path] as prefix
  // that apply to us.

  mapping(string:DAVLock) locks;
  if (locks = file_locks[path]) {
    if (locks[user]) ret[locks[user]] = 1;
    foreach(locks; string user; DAVLock lock) {
      if (lock->lockscope == "DAV:exclusive") return -1;
      shared = 1;
      break;
    }
  }
  foreach(prefix_locks; string prefix; locks) {
    if (has_prefix(prefix, path)) {
      if (locks[user]) ret[locks[user]] = 1;
      foreach(locks; string user; DAVLock lock) {
	if (lock->lockscope == "DAV:exclusive") return -1;
	shared = 1;
	break;
      }
    }
  }
  return sizeof(ret)?ret:shared;
}

//! Register @[lock] on the path @[path].
//!
//! This function is typically called from @[lock_file].
//!
//! @param path
//!   Canonical path that the lock applies to.
//!
//! @param lock
//!   The lock to register.
//!
//! @param user
//!   User t
void register_lock(string path, DAVLock lock, string user)
{
  if (lock->recursive) {
    if (prefix_locks[path]) {
      prefix_locks[path][user] = lock;
    } else {
      prefix_locks[path] = ([ user:lock ]);
    }
  } else {
    if (file_locks[path]) {
      file_locks[path][user] = lock;
    } else {
      file_locks[path] = ([ user:lock ]);
    }
  }
}

DAVLock|mapping(string:mixed) lock_file(string path,
					string locktype,
					string lockscope,
					string locktoken,
					int(0..1) recursive,
					string user,
					RequestID id)
{
  return 0;
}
#endif

mapping(string:mixed)|int(-1..0)|Stdio.File find_file(string path,
						      RequestID id);

//! Delete the file specified by @[path].
//!
//! @note
//!   Should return a 204 status on success.
//!
//! @note
//!   The default implementation falls back to @[find_file()].
mapping(string:mixed) delete_file(string path, RequestID id)
{
  // Fall back to find_file().
  RequestID tmp_id = id->close_me();
  tmp_id->not_query = query_location() + path;
  tmp_id->method = "DELELE";
  // FIXME: Logging?
  return find_file(path, id) || Roxen.http_status(404);
}

int(0..1) recurse_delete_files(string path, MultiStatus stat, RequestID id)
{
  Stat st = stat_file(path, id);
  if (!st) return 0;
  if (st->isdir) {
    // RFC 2518 8.6.2
    //   The DELETE operation on a collection MUST act as if a
    //   "Depth: infinity" header was used on it.
    int(0..1) fail;
    foreach(find_dir(path, id) || ({}), string fname) {
      fail |= recurse_delete_files(path+"/"+fname, stat, id);
    }
    // RFC 2518 8.6.2
    //   424 (Failed Dependancy) errors SHOULD NOT be in the
    //   207 (Multi-Status).
    if (fail) return fail;
  }
  mapping ret = delete_file(path, id);
  if (ret->code != 204) {
    // RFC 2518 8.6.2
    //   Additionally 204 (No Content) errors SHOULD NOT be returned
    //   in the 207 (Multi-Status). The reason for this prohibition
    //   is that 204 (No COntent) is the default success code.
    stat->add_response(path, XMLStatusNode(ret->code));
  }
  return ret->code >= 300;
}

mapping copy_file(string path, string dest, int(-1..1) behavior, RequestID id)
{
  werror("copy_file(%O, %O, %O, %O)\n",
	 path, dest, behavior, id);
  return Roxen.http_status (Protocols.HTTP.HTTP_NOT_IMPL);
}

void recurse_copy_files(string path, int depth, string dest_prefix,
			string dest_suffix,
			mapping(string:int(-1..1)) behavior,
			MultiStatus result, RequestID id)
{
  Stat st = stat_file(path, id);
  if (!st) return;
  if (!dest_prefix) {
    Standards.URI dest_uri = Standards.URI(result->href_prefix);
    Configuration c = roxen->find_configuration_for_url(dest_uri, id->conf);
    // FIXME: Mounting server on subpath.
    if (!c ||
	!has_prefix(dest_uri->path||"/", query_location())) {
      // Destination is not local to this module.
      // FIXME: Not supported yet.
      result->add_response(dest_suffix, XMLStatusNode(502));
      return;
    }
    dest_prefix = (dest_uri->path||"/")[sizeof(query_location())..];
    Stat dest_st;
    if (!(dest_st = stat_file(combine_path(dest_prefix, ".."), id)) ||
	!(dest_st->isdir)) {
      result->add_response("", XMLStatusNode(409));
      return;
    }
    if (combine_path(dest_prefix, dest_suffix, ".") ==
	combine_path(path, ".")) {
      result->add_response(dest_suffix, XMLStatusNode(403, "Source and destination are the same."));
      return;
    }
  }
  werror("recurse_copy_files(%O, %O, %O, %O, %O, %O, %O)\n",
	 path, depth, dest_prefix, dest_suffix, behavior, result, id);
  mapping res = copy_file(path, dest_prefix + dest_suffix,
			  behavior[dest_prefix + dest_suffix]||behavior[0],
			  id);
  result->add_response(dest_suffix, XMLStatusNode(res->error, res->data));
  if (res->error >= 300) {
    // RFC 2518 8.8.3 and 8.8.8 (error minimization).
    return;
  }
  if ((depth <= 0) || !st->isdir) return;
  depth--;
  foreach(find_dir(path, id), string filename) {
    recurse_copy_files(combine_path(path, filename), depth,
		       dest_prefix, combine_path(dest_suffix, filename),
		       behavior, result, id);
  }
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
