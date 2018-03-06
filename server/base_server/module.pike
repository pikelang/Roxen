// This file is part of Roxen WebServer.
// Copyright © 1996 - 2009, Roxen IS.
// $Id$

#include <module_constants.h>
#include <module.h>
#include <request_trace.h>

constant __pragma_save_parent__ = 1;

// Tell Pike.count_memory this is global.
constant pike_cycle_depth = 0;

inherit "basic_defvar";
mapping(string:array(int)) error_log=([]);

constant is_module = 1;
// constant module_type = MODULE_ZERO;
// constant module_name    = "Unnamed module";
// constant module_doc     = "Undocumented";
constant module_unique  = 1;

//! If set to non-zero the module won't show up in the module listing
//! when adding modules.
constant module_deprecated = 0;

//! Specifies that the module is opaque when it comes WebDAV
//! requests. Normally, recursive WebDAV requests will iterate through
//! all matching location modules even after a successful result has
//! been returned by some module. With this flag set, iteration will
//! stop after the call to this module. Useful if the module wants to
//! handle all requests for the specified location itself with no
//! fallback to other modules.
constant webdav_opaque = 0;

private Configuration _my_configuration;
private string _module_local_identifier;
private string _module_identifier =
  lambda() {
    mixed init_info = roxen->bootstrap_info->get();
    if (arrayp (init_info)) {
      [_my_configuration, _module_local_identifier] = init_info;
      return _my_configuration->name + "/" + _module_local_identifier;
    }
#ifdef DEBUG
    else
      error ("Got invalid bootstrap info for module: %O\n", init_info);
#endif
  }();
protected mapping _api_functions = ([]);

class ModuleJSONLogger {
  inherit Logger.BaseJSONLogger;

  void create(object parent_config) {
    string name = combine_path_unix(parent_config->json_logger->logger_name,
				    module_local_id());
    ::create(name, UNDEFINED, parent_config->json_logger);
  }
}

// Module local JSON logger
private ModuleJSONLogger json_logger;

string|array(string) module_creator;
string module_url;
RXML.TagSet module_tag_set;

/* These functions exist in here because otherwise the messages in the
 * event log do not always end up in the correct module/configuration.
 * And the reason for that is that if the messages are logged from
 * subclasses in the module, the DWIM in roxenlib.pike cannot see that
 * they are logged from a module. This solution is not really all that
 * beautiful, but it works. :-)
 */
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
void report_warning_sparsely (sprintf_format fmt, sprintf_args ... args)
  {predef::report_warning_sparsely (fmt, @args);}
void report_error_sparsely (sprintf_format fmt, sprintf_args ... args)
  {predef::report_error_sparsely (fmt, @args);}

void log_event (string facility, string action, string resource,
		void|mapping(string:mixed) info)
//! Log an event. See @[Configuration.log_event] for details.
//!
//! @[facility] may be zero. The local module identifier as returned
//! by @[module_local_id] is used as facility in that case.
{
  _my_configuration->log_event (facility || _module_local_identifier,
				action, resource, info);
}

void json_log_trace(string|mapping log_msg) { json_log_with_level(log_msg, Logger.BaseJSONLogger.TRACE); }
void json_log_debug(string|mapping log_msg) { json_log_with_level(log_msg, Logger.BaseJSONLogger.DBG); }
void json_log_info (string|mapping log_msg) { json_log_with_level(log_msg, Logger.BaseJSONLogger.INFO); }
void json_log_warn (string|mapping log_msg) { json_log_with_level(log_msg, Logger.BaseJSONLogger.WARN); }
void json_log_error(string|mapping log_msg) { json_log_with_level(log_msg, Logger.BaseJSONLogger.ERROR); }
void json_log_fatal(string|mapping log_msg) { json_log_with_level(log_msg, Logger.BaseJSONLogger.FATAL); }

// Helper method to force a specific logging level
void json_log_with_level(string|mapping log_msg, int level) {
  if (stringp(log_msg)) {
    log_msg = ([
      "msg" : log_msg,
    ]);
  }
  log_msg->level = level;
  json_log(log_msg);
}

// Log a message more or less verbatim via the JSON logger infrastructure
void json_log(string|mapping log_msg) {
  if (stringp(log_msg)) {
    log_msg = ([
      "msg" : log_msg,
    ]);
  }

  if (json_logger && functionp(json_logger->log)) {
    json_logger->log(log_msg);
  }
}

string module_identifier()
//! Returns a string that uniquely identifies this module instance
//! within the server. The identifier is the same as
//! @[Roxen.get_module] and @[Roxen.get_modname] handles.
{
  return _module_identifier;
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

//! @ignore
DECLARE_OBJ_COUNT;
//! @endignore

string _sprintf()
{
  return sprintf ("RoxenModule(%s)" + OBJ_COUNT, _module_identifier || "?");
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
    this_object()->module_counter,
    this_object()->module_deprecated,
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
//! If your module depends on other modules, call this function to
//! ensure that those modules get loaded.
//!
//! @param configuration
//!   The configuration for the modules. Use zero for the same as this
//!   module.
//!
//! @param modules
//!   An array of module identifiers. A module identifier is either
//!   the name of the pike file minus extension, or a string on the
//!   form that @[Roxen.get_modname] returns. In the latter case, the
//!   @tt{<config name>@} and @tt{<copy>@} parts are ignored.
//!
//! @param now
//!   If this flag is nonzero then any modules that aren't already
//!   loaded get loaded (and started) right away, so that the code
//!   following the @[module_dependencies] call can start using them.
//!
//!   Otherwise the function only ensures that the modules exist in
//!   the configuration and they will be loaded sometime during the
//!   startup of it.
//!
//! @note
//! This function is only intended to be called from @[start].
//!
//! @note
//! The @[now] flag does not affect calls to
//! @[ready_to_receive_requests] in the listed modules. I.e. even if
//! you have declared a dependency on a module and have @[now] set,
//! you cannot assume its @[ready_to_receive_requests] function has
//! run (in fact, you can almost safely assume it hasn't). You can
//! however assume that its @[start] function has been called.
{
  modules = map (modules,
		 lambda (string modname) {
		   sscanf ((modname / "/")[-1], "%[^#]", modname);
		   return modname;
		 });
  Configuration conf = configuration || my_configuration();
  if (!conf)
    report_warning ("Configuration not resolved; module(s) %s that %O "
		    "depend on weren't added.\n", String.implode_nicely (modules),
		    module_identifier() ||
		    master()->describe_program(this_program) ||
		    "unknown module");
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

final void set_configuration(Configuration c)
{
  if(_my_configuration && _my_configuration != c)
    error("set_configuration() called twice.\n");
  _my_configuration = c;

  // if configuration changes, we should reinitialize our JSON logger too!
  json_logger = ModuleJSONLogger(_my_configuration);
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

// These functions have bodies to make module inheritance easier: An
// inheriting module can always assume that the module it inherits
// have these functions defined and properly proxy the calls to them.
// Thus an inherited module should be free to define them later on
// even if it didn't have them initially. (Modules need never proxy
// calls to the default implementations here.)
void start(int variable_save, Configuration conf, void|int newly_added) {}
void stop() {}
void ready_to_receive_requests (Configuration conf) {}

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
//! is mounted. It always ends with a '/'.
{
  if(!_my_configuration)
    error("Please do not call this function from create()!\n");
  return _my_configuration->query_internal_location(this_object());
}

string query_absolute_internal_location(RequestID id)
//! Returns the internal mountpoint as an absolute path. It always
//! ends with a '/'.
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
    if (sizeof(world_url)) {
      Standards.URI uri = Standards.URI(world_url);
      hostname = uri->host;
    }
  if (!hostname) hostname = gethostname();
  for (int i = 0; i < sizeof (urls); i++)
  {
    urls[i] = (urls[i]/"#")[0];
    if (sizeof (urls[i]/"*") == 2)
      urls[i] = replace(urls[i], "*", hostname);
  }
  return map (urls, `+, loc[1..]);
}

string location_url()
//! Returns an http or https url including the modules mountpoint. The
//! ip-number for the corresponding port will be added to the fragment
//! of the url. An http url will be prioritized over an https url.
{
  string short_array(array a)
  {
    return "({ " + (map(a, lambda(object o) {
			     return sprintf("%O", o);
			   })*", ") + " })";
  };
  string loc = query_location();
  if(!loc) return 0;
  if(!_my_configuration)
    error("Please do not call this function from create()!\n");
  string hostname;
  string world_url = _my_configuration->query("MyWorldLocation");
  if (world_url && sizeof(world_url)) {
    Standards.URI uri = Standards.URI(world_url);
    hostname = uri->host;
  }
  if(!hostname)
    hostname = gethostname();
#ifdef LOCATION_URL_DEBUG
  werror("  Hostname: %O\n", hostname);
#endif
  Standards.URI candidate_uri;
  array(string) urls =
    filter(_my_configuration->registered_urls, has_prefix, "http:") +
    filter(_my_configuration->registered_urls, has_prefix, "https:");
  foreach(urls, string url)
  {
#ifdef LOCATION_URL_DEBUG
    werror("  URL: %s\n", url);
#endif
    mapping url_info = roxen.urls[url];
    if(!url_info || !url_info->port || url_info->conf != _my_configuration)
      continue;
    Protocol p = url_info->port;
#ifdef LOCATION_URL_DEBUG
    werror("  Protocol: %s\n", p);
#endif
    Standards.URI uri = Standards.URI(url);
    string ip = p->ip || "127.0.0.1";
    if (ip == "::")
      ip = "::1";
    uri->fragment = "ip=" + ip;
    if(has_value(uri->host, "*") || has_value(uri->host, "?"))
      if(glob(uri->host, hostname))
	uri->host = hostname;
      else {
	if(!candidate_uri) {
	  candidate_uri = uri;
	  candidate_uri->host = hostname;
	}
	continue;
      }
    uri->path += loc[1..];
    return (string)uri;
  }
  if(candidate_uri) {
    report_warning("Warning: Could not find any suitable ports, continuing anyway. "
		   "Please make sure that your Primary Server URL matches "
		   "at least one port. Primary Server URL: %O, URLs: %s.\n",
		 world_url, short_array(urls));
    candidate_uri->path += loc[1..];
    return (string)candidate_uri;
  }
  return 0;
}

/* By default, provide nothing. */
multiset(string) query_provides() { return 0; }


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
//!   Path (below the filesystem location) to which the status applies.
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

  protected Stat stat;

  protected void create (string path, string abs_path, RequestID id, Stat stat)
  {
    ::create (path, abs_path, id);
    this_program::stat = stat;
  }

  Stat get_stat() {return stat;}

  protected mapping(string:string) response_headers;

  mapping(string:string) get_response_headers()
  {
    if (!response_headers) {
      // Old kludge inherited from configuration.try_get_file.
      if (!id->misc->common)
	id->misc->common = ([]);

      RequestID sub_id = id->clone_me();
      sub_id->misc->common = id->misc->common;

      sub_id->raw_url = sub_id->not_query = query_location() + path;
      if ((sub_id->raw_url != id->raw_url) && (id->raw_url != id->not_query)) {
	// sub_id->raw_url = replace (id->raw_url, id->not_query, sub_id->not_query);
	sub_id->raw_url = sub_id->not_query +
	  (({ "" }) + (id->raw_url/"?")[1..]) * "?";
      }
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
//!
//! @seealso
//!   @[query_property()]
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
//!
//! @seealso
//!   @[query_property_set()]
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
//! @[depth]. See @[PropertySet()->find_properties()] for details.
//!
//! @seealso
//!   @[query_property_set()]
mapping(string:mixed) recurse_find_properties(string path, string mode,
					      int depth, RequestID id,
					      multiset(string)|void filt)
{
  string prefix = map(query_location()[1..]/"/", Roxen.http_encode_url)*"/";
  MultiStatus.Prefixed result =
    id->get_multi_status()->prefix (id->url_base() + prefix);

  mapping(string:mixed) recurse (string path, int depth) {
    SIMPLE_TRACE_ENTER (this, "%s for %O, depth %d",
			mode == "DAV:propname" ? "Listing property names" :
			mode == "DAV:allprop" ? "Retrieving all properties" :
			mode == "DAV:prop" ? "Retrieving specific properties" :
			"Finding properties with mode " + mode,
			path, depth);
    mapping(string:mixed)|PropertySet properties = query_property_set(path, id);

    if (!properties) {
      SIMPLE_TRACE_LEAVE ("No such file or dir");
      return 0;
    }

    {
      mapping(string:mixed) ret = mappingp (properties) ?
	properties : properties->find_properties(mode, result, filt);

      if (ret) {
	SIMPLE_TRACE_LEAVE ("Got status %d: %O", ret->error, ret->rettext);
	return ret;
      }
    }

    if (properties->get_stat()->isdir) {
      if (depth <= 0) {
	SIMPLE_TRACE_LEAVE ("Not recursing due to depth limit");
	return ([]);
      }
      depth--;
      foreach(find_dir(path, id) || ({}), string filename) {
	filename = combine_path_unix(path, filename);
	if (mapping(string:mixed) sub_res = recurse(filename, depth))
	  if (sizeof (sub_res))
	    result->add_status (filename, sub_res->error, sub_res->rettext);
      }
    }

    SIMPLE_TRACE_LEAVE ("");
    return ([]);
  };

  return recurse (path, depth);
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
    string prefix = map((query_location()[1..] + path)/"/",
			Roxen.http_encode_url)*"/";
    MultiStatus.Prefixed result =
      id->get_multi_status()->prefix (id->url_base() + prefix);
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
	Roxen.http_status (Protocols.HTTP.DAV_FAILED_DEP);
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

string resource_id (string path, RequestID|int(0..0) id)
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
//!
//! @param id
//!   The request id may have the value @expr{0@} (zero) if called
//!   by @[Configuration()->expire_locks()].
{
  return has_suffix (path, "/") ? path : path + "/";
}

string|int authenticated_user_id (string path, RequestID id)
//! Return a value that uniquely identifies the user that the given
//! request is authenticated as.
//!
//! This function is e.g. used by the default lock implementation to
//! tell different users holding locks apart. WARNING: Due to some
//! design issues in the lock system, it's likely that it will change
//! to not use this function in the future.
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
protected mapping(string:mapping(mixed:DAVLock)) file_locks = ([]);

// Mapping from resource id to a mapping from user id to the lock
// that apply recursively to the resource and all other resources
// it's a prefix of.
//
// Only used internally by the default lock implementation.
protected mapping(string:mapping(mixed:DAVLock)) prefix_locks = ([]);

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
//!   If @expr{-1} return locks anywhere below @[path], but not
//!   any above @[path]. (This is appropriate to use to get the
//!   list of locks that need to be unlocked on DELETE.)
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
			     int(-1..1) recursive,
			     int(0..1) exclude_shared,
			     RequestID id)
{
  // Common case.
  if (!sizeof(file_locks) && !sizeof(prefix_locks)) return 0;

  TRACE_ENTER(sprintf("find_locks(%O, %O, %O, X)",
		      path, recursive, exclude_shared), this);

  string rsc = resource_id (path, id);

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

  if (file_locks[rsc]) {
    add_locks (file_locks[rsc]);
  }

  if (recursive >= 0) {
    foreach(prefix_locks;
	    string prefix; mapping(mixed:DAVLock) sub_locks) {
      if (has_prefix(rsc, prefix)) {
	add_locks (sub_locks);
	break;
      }
    }
  }

  if (recursive) {
    LOOP_OVER_BOTH (string prefix, mapping(mixed:DAVLock) sub_locks, {
	if (has_prefix(prefix, rsc)) {
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
//! WARNING: This function has some design issues and will very likely
//! get a different interface. Compatibility is NOT guaranteed.
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
//!         @value LOCK_NONE
//!           No locks apply. (0)
//!         @value LOCK_SHARED_BELOW
//!           There are only one or more shared locks held by other
//!           users somewhere below @[path] (but not on @[path]
//!           itself). Only returned if @[recursive] is set. (2)
//!         @value LOCK_SHARED_AT
//!           There are only one or more shared locks held by other
//!           users on @[path]. (3)
//!         @value LOCK_OWN_BELOW
//!           The authenticated user has locks under @[path] (but not
//!           on @[path] itself) and there are no exclusive locks held
//!           by other users. Only returned if @[recursive] is set. (4)
//!         @value LOCK_EXCL_BELOW
//!           There are one or more exclusive locks held by other
//!           users somewhere below @[path] (but not on @[path]
//!           itself). Only returned if @[recursive] is set. (6)
//!         @value LOCK_EXCL_AT
//!           There are one or more exclusive locks held by other
//!           users on @[path]. (7)
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
  TRACE_ENTER(sprintf("check_locks(%O, %d, X)", path, recursive), this);

  // Common case.
  if (!sizeof(file_locks) && !sizeof(prefix_locks)) {
    TRACE_LEAVE ("Got no locks");
    return 0;
  }

  mixed auth_user = authenticated_user_id (path, id);
  path = resource_id (path, id);

  if (DAVLock lock =
      file_locks[path] && file_locks[path][auth_user] ||
      prefix_locks[path] && prefix_locks[path][auth_user]) {
    TRACE_LEAVE(sprintf("Found own lock %O.", lock->locktoken));
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
      if (DAVLock lock = locks[auth_user]) {
	SIMPLE_TRACE_LEAVE ("Found own lock %O on %O.", lock->locktoken, prefix);
	return lock;
      }
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
    SIMPLE_TRACE_LEAVE("Returning %O.", shared);
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

  SIMPLE_TRACE_LEAVE("Returning %O.", locked_by_auth_user ? LOCK_OWN_BELOW : shared);
  return locked_by_auth_user ? LOCK_OWN_BELOW : shared;
}

//! Register @[lock] on the path @[path] under the assumption that
//! there is no other lock already that conflicts with this one, i.e.
//! that @expr{check_locks(path,lock->recursive,id)@} would return
//! @expr{LOCK_NONE@} if @expr{lock->lockscope@} is
//! @expr{"DAV:exclusive"@}, or @expr{< LOCK_OWN_BELOW@} if
//! @expr{lock->lockscope@} is @expr{"DAV:shared"@}.
//!
//! This function is only provided as a helper to call from
//! @[lock_file] if the default lock implementation is to be used.
//!
//! @param path
//!   Normalized path (below the filesystem location) that the lock
//!   applies to.
//!
//! @param lock
//!   The lock to register.
//!
//! @note
//! The default implementation only handles the @expr{"DAV:write"@}
//! lock type. It uses @[resource_id] to map paths to unique resources
//! and @[authenticated_user_id] to tell users apart.
protected void register_lock(string path, DAVLock lock, RequestID id)
{
  TRACE_ENTER(sprintf("register_lock(%O, lock(%O), X).", path, lock->locktoken),
	      this);
  ASSERT_IF_DEBUG (lock->locktype == "DAV:write");
  mixed auth_user = authenticated_user_id (path, id);
  path = resource_id (path, id);
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

//! Unregister @[lock] that currently is locking the resource at
//! @[path]. It's assumed that the lock is registered for exactly that
//! path.
//!
//! This function is only provided as a helper to call from
//! @[unlock_file] if the default lock implementation is to be used.
//!
//! @param path
//!   Normalized path (below the filesystem location) that the lock
//!   applies to.
//!
//! @param lock
//!   The lock to unregister. (It must not be changed or destructed.)
//!
//! @param id
//!   The request id may have the value @expr{0@} (zero) if called
//!   by @[Configuration()->expire_locks()].
protected void unregister_lock (string path, DAVLock lock,
				RequestID|int(0..0) id)
{
  TRACE_ENTER(sprintf("unregister_lock(%O, lock(%O), X).", path, lock->locktoken),
	      this);
  mixed auth_user = id && authenticated_user_id (path, id);
  path = resource_id (path, id);
  DAVLock removed_lock;
  if (lock->recursive) {
    if (id) {
      removed_lock = m_delete(prefix_locks[path], auth_user);
    } else {
      foreach(prefix_locks[path]||([]); mixed user; DAVLock l) {
	if (l == lock) {
	  removed_lock = m_delete(prefix_locks[path], user);
	}
      }
    }
    if (!sizeof (prefix_locks[path])) m_delete (prefix_locks, path);
  }
  else if (file_locks[path]) {
    if (id) {
      removed_lock = m_delete (file_locks[path], auth_user);
    } else {
      foreach(file_locks[path]||([]); mixed user; DAVLock l) {
	if (l == lock) {
	  removed_lock = m_delete(file_locks[path], user);
	}
      }
    }
    if (!sizeof (file_locks[path])) m_delete (file_locks, path);
  }
  // NB: The lock may have already been removed in the !id case.
  ASSERT_IF_DEBUG (!(id || removed_lock) ||
		   (lock /*%O*/ == removed_lock /*%O*/),
		   lock, removed_lock);
  TRACE_LEAVE("Ok.");
  return 0;
}

//! Register @[lock] on the path @[path] under the assumption that
//! there is no other lock already that conflicts with this one, i.e.
//! that @expr{check_locks(path,lock->recursive,id)@} would return
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
//! RFC 2518Bis (working draft)). The default implementation fulfills
//! these criteria.
//!
//! It's up to @[find_file] et al to actually check that the necessary
//! locks are held. It can preferably use @[write_access] for that,
//! which has a default implementation for checking
//! @expr{"DAV:write"@} locks.
//!
//! @param path
//!   Normalized path (below the filesystem location) that the lock
//!   applies to.
//!
//! @param lock
//!   The lock to register.
//!
//! @returns
//!   Returns @expr{0@} if the lock is successfully installed or if
//!   locking isn't used. Returns a status mapping if an error
//!   occurred.
//!
//! @note
//!   To use the default lock implementation, call @[register_lock]
//!   from this function.
mapping(string:mixed) lock_file(string path,
				DAVLock lock,
				RequestID id)
{
  return 0;
}

//! Remove @[lock] that currently is locking the resource at @[path].
//! It's assumed that the lock is registered for exactly that path.
//!
//! @param path
//!   Normalized path (below the filesystem location) that the lock
//!   applies to.
//!
//! @param lock
//!   The lock to unregister. (It must not be changed or destructed.)
//!
//! @param id
//!   @mixed
//!     @type RequestID
//!	  The request that attempted to unlock the lock. The function
//!	  should do the normal access checks before unlocking the lock
//!	  in this case.
//!
//!	@type int(0..0)
//!	  The lock is unlocked internally by the server (typically due
//!	  to a timeout) and should be carried out without any access
//!	  checks. The function must succeed and return zero in this
//!	  case.
//!   @endmixed
//!
//! @returns
//!   Returns a status mapping on any error, zero otherwise.
//!
//! @note
//!   To use the default lock implementation, call @[unregister_lock]
//!   from this function.
mapping(string:mixed) unlock_file (string path,
				   DAVLock lock,
				   RequestID|int(0..0) id);

//! Checks that the conditions specified by the WebDAV @expr{"If"@}
//! header are fulfilled on the given path (RFC 2518 9.4). This means
//! that locks are checked as necessary using @[check_locks].
//!
//! WARNING: This function has some design issues and will very likely
//! get a different interface. Compatibility is NOT guaranteed.
//!
//! @param path
//!   Path (below the filesystem location) that the lock applies to.
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
mapping(string:mixed)|int(0..1) check_if_header(string relative_path,
						int(0..1) recursive,
						RequestID id)
{
  SIMPLE_TRACE_ENTER(this, "Checking \"If\" header for %O",
		     relative_path);

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

  int(0..1) locked_fail = !!lock;
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
	locked_fail = 0;
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
    locked_fail = 1;
  }

  if (locked_fail) {
    TRACE_LEAVE("Failed (locked).");
  } else {
    TRACE_LEAVE("Precondition failed.");
  }
  return Roxen.http_status(locked_fail ?
			   Protocols.HTTP.DAV_LOCKED :
			   Protocols.HTTP.HTTP_PRECOND_FAILED);
}

//! Used by some default implementations to check if we may perform a
//! write access to @[path]. It should at least call
//! @[check_if_header] to check DAV locks. It takes the same arguments
//! and has the same return value as that function.
//!
//! WARNING: This function has some design issues and will very likely
//! get a different interface. Compatibility is NOT guaranteed.
//!
//! A filesystem module should typically put all needed write access
//! checks here and then use this from @[find_file()],
//! @[delete_file()] etc.
//!
//! @returns
//!   Returns @expr{0@} (zero) on success, a status mapping on
//!   failure, or @expr{1@} if @[recursive] is set and write access is
//!   allowed on this level but maybe not somewhere below. The caller
//!   should in the last case do the operation on this level if
//!   possible and then handle each member in the directory
//!   recursively with @[write_access] etc.
protected mapping(string:mixed)|int(0..1) write_access(string relative_path,
						       int(0..1) recursive,
						       RequestID id)
{
  return check_if_header (relative_path, recursive, id);
}

//!
protected variant mapping(string:mixed)|int(0..1) write_access(array(string) paths,
							       int(0..1) recursive,
							       RequestID id)
{
  mapping(string:mixed)|int(0..1) ret;
  int got_ok;
  foreach(paths, string path) {
    ret = write_access(path, recursive, id);
    if (!ret) {
      got_ok = 1;
      continue;
    }
    if (ret == 1) {
      continue;
    }
    if (ret->error == Protocols.HTTP.HTTP_PRECOND_FAILED) {
      continue;
    }
    return ret;
  }

  if (got_ok) {
    // The if headers are valid for at least one of the paths,
    // and none of the other paths are locked.
    return 0;
  }

  // HTTP_PRECOND_FAILED for all of the paths.
  return ret;
}

mapping(string:mixed)|int(-1..0)|Stdio.File find_file(string path,
						      RequestID id);

//! Used by the default @[recurse_delete_files] implementation to
//! delete a file or an empty directory.
//!
//! @returns
//!   Returns a 2xx series status mapping on success (typically 204 No
//!   Content). Returns 0 if the file doesn't exist. Returns an
//!   appropriate status mapping for any other error.
//!
//! @note
//!   The default implementation falls back to @[find_file()].
protected mapping(string:mixed) delete_file(string path, RequestID id)
{
  // Fall back to find_file().
  RequestID tmp_id = id->clone_me();
  tmp_id->not_query = query_location() + path;
  tmp_id->method = "DELETE";
  // FIXME: Logging?
  return find_file(path, tmp_id) ||
    tmp_id->misc->error_code && Roxen.http_status (tmp_id->misc->error_code);
}

//! Delete @[path] recursively.
//!
//! The default implementation handles the recursion and calls
//! @[delete_file] for each file and empty directory.
//!
//! @returns
//!   Returns a 2xx series status mapping on success (typically 204 No
//!   Content). Returns 0 if the file doesn't exist. Returns an
//!   appropriate status mapping for any other error. That includes an
//!   empty mapping in case some subparts couldn't be deleted, to
//!   signify a 207 Multi-Status response using the info in
//!   @[id->get_multi_status()].
mapping(string:mixed) recurse_delete_files(string path,
					   RequestID id,
					   void|MultiStatus.Prefixed stat)
{
  SIMPLE_TRACE_ENTER (this, "Deleting %O recursively", path);
  if (!stat)
    stat = id->get_multi_status()->prefix (id->url_base() +
					   query_location()[1..]);

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
	  SIMPLE_TRACE_ENTER (this, "Deleting %O", fname);
	  if (mapping(string:mixed) sub_res = recurse(fname, sub_stat)) {
	    // RFC 2518 8.6.2
	    //   Additionally 204 (No Content) errors SHOULD NOT be returned
	    //   in the 207 (Multi-Status). The reason for this prohibition
	    //   is that 204 (No Content) is the default success code.
	    if (sizeof (sub_res) && sub_res->error != 204) {
	      stat->add_status(fname, sub_res->error, sub_res->rettext);
	    }
	    if (!sizeof (sub_res) || sub_res->error >= 300) fail = 1;
	  }
	}
      }
      if (fail) {
	SIMPLE_TRACE_LEAVE ("Partial failure");
	return ([]);
      }
    }

    SIMPLE_TRACE_LEAVE ("");
    return delete_file (path, id);
  };

  return recurse(path, st) || Roxen.http_status(204);
}

//! Make a new collection (aka directory) at @[path].
//!
//! @returns
//!   Returns a 2xx series status on success (typically 201 Created).
//!   Returns @expr{0@} (zero) if there's no directory to create the
//!   new one in. Returns other result mappings on failure.
mapping(string:mixed) make_collection(string path, RequestID id)
{
  // Fall back to find_file().
  RequestID tmp_id = id->clone_me();
  tmp_id->not_query = query_location() + path;
  tmp_id->method = "MKCOL";
  // FIXME: Logging?
  return find_file(path, tmp_id);
}

//! Used by the default @[copy_collection] implementation to copy all
//! properties at @[source] to @[destination].
//!
//! @param source
//!   Source path below the filesystem location.
//!
//! @param destination
//!   Destination path below the filesystem location.
//!
//! @param behavior
//!   Specifies how to copy properties. See the @[PropertyBehavior]
//!   type for details.
//!
//! @returns
//!   @expr{0@} (zero) on success or an appropriate status mapping for
//!   any error.
protected mapping(string:mixed) copy_properties(
  string source, string destination, PropertyBehavior behavior, RequestID id)
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
    if (!behavior) {
      TRACE_LEAVE("Omit verify.");
      continue;
    }
    if ((intp(behavior) || behavior[property_name]) && (subres->error < 300)) {
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

//! Used by the default @[recurse_copy_files] and @[move_collection]
//! to copy a collection (aka directory) and its properties but not
//! its contents.
//!
//! @param source
//!   Source path below the filesystem location.
//!
//! @param destination
//!   Destination path below the filesystem location.
//!
//! @param behavior
//!   Specifies how to copy properties. See the @[PropertyBehavior]
//!   type for details.
//!
//! @param overwrite
//!   Specifies how to handle the situation if the destination already
//!   exists. See the @[Overwrite] type for details.
//!
//! @param result
//!   A @[MultiStatus.Prefixed] to collect status mappings if some
//!   subparts fail. It's prefixed with the URL to the filesystem
//!   location.
//!
//! @returns
//!   Returns a 2xx series status mapping on success (typically 201
//!   Created if the destination didn't exist before, or 204 No
//!   Content otherwise). Returns 0 if the source doesn't exist.
//!   Returns an appropriate status mapping for any other error. That
//!   includes an empty mapping in case there's a failure on some
//!   subpart or at the destination, to signify a 207 Multi-Status
//!   response using the info in @[id->get_multi_status()].
protected mapping(string:mixed) copy_collection(
  string source, string destination, PropertyBehavior behavior,
  Overwrite overwrite, MultiStatus.Prefixed result, RequestID id)
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
      if (res && (!sizeof (res) || res->error >= 300)) {
	// Failed to delete something.
	TRACE_LEAVE("Deletion failed.");
	TRACE_LEAVE("Copy collection failed.");
	// RFC 2518 9.6 says:
	//
	//   If a COPY or MOVE is not performed due to the value of
	//   the Overwrite header, the method MUST fail with a 412
	//   (Precondition Failed) status code.
	//
	// That can perhaps be interpreted as that we should return
	// 412 here. But otoh, in RFC 2518 8.8.5 COPY status codes:
	//
	//    412 (Precondition Failed) - /.../ the Overwrite header
	//    is "F" and the state of the destination resource is
	//    non-null.
	//
	// That clearly doesn't include this case. Also, common sense
	// says that the error from the failed delete is more useful
	// to the client.
#if 0
	return Roxen.http_status(Protocols.HTTP.HTTP_PRECOND_FAILED);
#else
	if (sizeof (res)) {
	  // RFC 2518 8.8.3:
	  //   If an error in executing the COPY method occurs with a
	  //   resource other than the resource identified in the
	  //   Request-URI then the response MUST be a 207
	  //   (Multi-Status).
	  //
	  // So if the failure was on the root destination resource we
	  // have to convert it to a multi-status.
	  result->add_status (destination, res->error, res->rettext);
	}
	return ([]);
#endif
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

//! Used by the default @[recurse_copy_files] to copy a single file
//! along with its properties.
//!
//! @param source
//!   Source path below the filesystem location.
//!
//! @param destination
//!   Destination path below the filesystem location.
//!
//! @param behavior
//!   Specifies how to copy properties. See the @[PropertyBehavior]
//!   type for details.
//!
//! @param overwrite
//!   Specifies how to handle the situation if the destination already
//!   exists. See the @[Overwrite] type for details.
//!
//! @returns
//!   Returns a 2xx series status mapping on success (typically 201
//!   Created if the destination didn't exist before, or 204 No
//!   Content otherwise). Returns 0 if the source doesn't exist.
//!   Returns an appropriate status mapping for any other error.
protected mapping(string:mixed) copy_file(string source, string destination,
					  PropertyBehavior behavior,
					  Overwrite overwrite, RequestID id)
{
  SIMPLE_TRACE_ENTER(this, "copy_file(%O, %O, %O, %O, %O)\n",
		     source, destination, behavior, overwrite, id);
  TRACE_LEAVE("Not implemented.");
  return Roxen.http_status (Protocols.HTTP.HTTP_NOT_IMPL);
}

//! Copy a resource recursively from @[source] to @[destination].
//!
//! @param source
//!   Source path below the filesystem location.
//!
//! @param destination
//!   Destination path below the filesystem location.
//!
//! @param behavior
//!   Specifies how to copy properties. See the @[PropertyBehavior]
//!   type for details.
//!
//! @param overwrite
//!   Specifies how to handle the situation if the destination already
//!   exists. See the @[Overwrite] type for details.
//!
//! @returns
//!   Returns a 2xx series status mapping on success (typically 201
//!   Created if the destination didn't exist before, or 204 No
//!   Content otherwise). Returns 0 if the source doesn't exist.
//!   Returns an appropriate status mapping for any other error. That
//!   includes an empty mapping in case there's a failure on some
//!   subpart or at the destination, to signify a 207 Multi-Status
//!   response using the info in @[id->get_multi_status()].
mapping(string:mixed) recurse_copy_files(string source, string destination,
					 PropertyBehavior behavior,
					 Overwrite overwrite, RequestID id)
{
  SIMPLE_TRACE_ENTER(this, "Recursive copy from %O to %O (%s)",
		     source, destination,
		     overwrite == DO_OVERWRITE ? "replace" :
		     overwrite == NEVER_OVERWRITE ? "no overwrite" :
		     "overlay");
  string src_tmp = has_suffix(source, "/")?source:(source+"/");
  string dst_tmp = has_suffix(destination, "/")?destination:(destination+"/");
  if ((src_tmp == dst_tmp) ||
      has_prefix(src_tmp, dst_tmp) ||
      has_prefix(dst_tmp, src_tmp)) {
    TRACE_LEAVE("Source and destination overlap.");
    return Roxen.http_status(403, "Source and destination overlap.");
  }

  string prefix = map(query_location()[1..]/"/", Roxen.http_encode_url)*"/";
  MultiStatus.Prefixed result =
    id->get_multi_status()->prefix (id->url_base() + prefix);

  mapping(string:mixed) recurse(string source, string destination) {
    // Note: Already got an extra TRACE_ENTER level on entry here.

    Stat st = stat_file(source, id);
    if (!st) {
      TRACE_LEAVE("Source not found.");
      return 0;
    }
    // FIXME: Check destination?
    if (st->isdir) {
      mapping(string:mixed) res =
	copy_collection(source, destination, behavior, overwrite, result, id);
      if (res && (!sizeof (res) || res->error >= 300)) {
	// RFC 2518 8.8.3 and 8.8.8 (error minimization).
	TRACE_LEAVE("Copy of collection failed.");
	return res;
      }
      foreach(find_dir(source, id), string filename) {
	string subsrc = combine_path_unix(source, filename);
	string subdst = combine_path_unix(destination, filename);
	SIMPLE_TRACE_ENTER(this, "Copy from %O to %O\n", subsrc, subdst);
	mapping(string:mixed) sub_res = recurse(subsrc, subdst);
	if (sub_res && !(<0, 201, 204>)[sub_res->error]) {
	  result->add_status(subdst, sub_res->error, sub_res->rettext);
	}
      }
      TRACE_LEAVE("");
      return res;
    } else {
      TRACE_LEAVE("");
      return copy_file(source, destination, behavior, overwrite, id);
    }
  };

  int start_ms_size = id->multi_status_size();
  mapping(string:mixed) res = recurse (source, destination);
  if (res && res->error != 204 && res->error != 201)
    return res;
  else if (id->multi_status_size() != start_ms_size)
    return ([]);
  else
    return res;
}

//! Used by the default @[recurse_move_files] to move a file (and not
//! a directory) from @[source] to @[destination].
//!
//! The default implementation tries to call @[find_file] with the
//! MOVE method. If that returns 501 Not Implemented then it copies
//! the file and deletes the source afterwards.
//!
//! @param source
//!   Source path below the filesystem location.
//!
//! @param destination
//!   Destination path below the filesystem location.
//!
//! @param behavior
//!   Specifies how to move properties. See the @[PropertyBehavior]
//!   type for details.
//!
//! @param overwrite
//!   Specifies how to handle the situation if the destination already
//!   exists. See the @[Overwrite] type for details.
//!
//! @returns
//!   Returns a 2xx series status mapping on success (typically 201
//!   Created if the destination didn't exist before, or 204 No
//!   Content otherwise). Returns 0 if the source doesn't exist.
//!   Returns an appropriate status mapping for any other error. That
//!   includes an empty mapping in case there's a failure on some
//!   subpart or at the destination, to signify a 207 Multi-Status
//!   response using the info in @[id->get_multi_status()].
protected mapping(string:mixed) move_file(string source, string destination,
					  PropertyBehavior behavior,
					  Overwrite overwrite, RequestID id)
{
  // Fall back to find_file().
  RequestID tmp_id = id->clone_me();
  tmp_id->not_query = query_location() + source;
  tmp_id->misc["new-uri"] = query_location() + destination;
  tmp_id->request_headers->destination =
    id->url_base() + query_location()[1..] + destination;
  tmp_id->method = "MOVE";
  mapping(string:mixed) res = find_file(source, tmp_id);
  if (!res || res->error != 501) return res;
  // Not implemented. Fall back to COPY + DELETE.
  res = copy_file(source, destination, behavior, overwrite, id);
  if (res && res->error >= 300) {
    // Copy failed.
    return res;
  }
  return delete_file(source, id);
}

//! Used by the default @[recurse_move_files] to move a collection
//! (aka directory) and all its content from @[source] to
//! @[destination].
//!
//! The default implementation tries to call @[find_file] with the
//! MOVE method. If that returns 501 Not Implemented then it copies
//! the collection, moves each directory entry recursively, and
//! deletes the source collection afterwards.
//!
//! @param source
//!   Source path below the filesystem location.
//!
//! @param destination
//!   Destination path below the filesystem location.
//!
//! @param behavior
//!   Specifies how to move properties. See the @[PropertyBehavior]
//!   type for details.
//!
//! @param overwrite
//!   Specifies how to handle the situation if the destination already
//!   exists. See the @[Overwrite] type for details.
//!
//! @returns
//!   Returns a 2xx series status mapping on success (typically 201
//!   Created if the destination didn't exist before, or 204 No
//!   Content otherwise). Returns 0 if the source doesn't exist.
//!   Returns an appropriate status mapping for any other error. That
//!   includes an empty mapping in case there's a failure on some
//!   subpart or at the destination, to signify a 207 Multi-Status
//!   response using the info in @[id->get_multi_status()].
//!
//! @note
//! The function must be prepared to recurse to check DAV locks
//! properly.
protected mapping(string:mixed) move_collection(
  string source, string destination, PropertyBehavior behavior,
  Overwrite overwrite, RequestID id)
{
  // Fall back to find_file().
  RequestID tmp_id = id->clone_me();
  tmp_id->not_query = query_location() + source;
  tmp_id->misc["new-uri"] = query_location() + destination;
  tmp_id->request_headers->destination =
    id->url_base() + query_location()[1..] + destination;
  tmp_id->method = "MOVE";
  mapping(string:mixed) res = find_file(source, tmp_id);
  if (!res || res->error != 501) return res;
  // Not implemented. Fall back to COPY + DELETE.
  string prefix = map(query_location()[1..]/"/", Roxen.http_encode_url)*"/";
  MultiStatus.Prefixed result =
    id->get_multi_status()->prefix (id->url_base() + prefix);
  res = copy_collection(source, destination, behavior, overwrite, result, id);
  if (res && (res->error >= 300 || !sizeof(res))) {
    // Copy failed.
    return res;
  }
  int fail;
  foreach(find_dir(source, id), string filename) {
    string subsrc = combine_path_unix(source, filename);
    string subdst = combine_path_unix(destination, filename);
    SIMPLE_TRACE_ENTER(this, "Recursive move from %O to %O\n",
		       subsrc, subdst);
    if (mapping(string:mixed) sub_res =
	recurse_move_files(subsrc, subdst, behavior, overwrite, id)) {
      if (!(<0, 201, 204>)[sub_res->error]) {
	result->add_status(subdst, sub_res->error, sub_res->rettext);
      }
      if (!sizeof (sub_res) || sub_res->error >= 300) {
	// Failed to move some content.
	fail = 1;
      }
    }
  }
  if (fail) return ([]);
  return delete_file(source, id);
}

//! Move a resource from @[source] to @[destination].
//!
//! @param source
//!   Source path below the filesystem location.
//!
//! @param destination
//!   Destination path below the filesystem location.
//!
//! @param behavior
//!   Specifies how to move properties. See the @[PropertyBehavior]
//!   type for details.
//!
//! @param overwrite
//!   Specifies how to handle the situation if the destination already
//!   exists. See the @[Overwrite] type for details.
//!
//! @returns
//!   Returns a 2xx series status mapping on success (typically 201
//!   Created if the destination didn't exist before, or 204 No
//!   Content otherwise). Returns 0 if the source doesn't exist.
//!   Returns an appropriate status mapping for any other error. That
//!   includes an empty mapping in case there's a failure on some
//!   subpart or at the destination, to signify a 207 Multi-Status
//!   response using the info in @[id->get_multi_status()].
mapping(string:mixed) recurse_move_files(string source, string destination,
					 PropertyBehavior behavior,
					 Overwrite overwrite, RequestID id)
{
  Stat st = stat_file(source, id);
  if (!st) return 0;

  if (st->isdir) {
    return move_collection(source, destination, behavior, overwrite, id);
  }
  return move_file(source, destination, behavior, overwrite, id);
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

#if constant(roxen.FSGarbWrapper)
//! Register a filesystem path for automatic garbage collection.
//!
//! @param path
//!   Path in the real filesystem to garbage collect.
//!
//! @param max_age
//!   Maximum allowed age in seconds for files.
//!
//! @param max_size
//!   Maximum total size in bytes for all files under the path.
//!   Zero to disable the limit.
//!
//! @param max_files
//!   Maximum number of files under the path.
//!   Zero to disable the limit.
//!
//! @returns
//!   Returns a roxen.FSGarbWrapper object. The garbage collector
//!   will be removed when this object is destructed (eg via
//!   refcount-garb).
roxen.FSGarbWrapper register_fsgarb(string path, int max_age,
				    int|void max_size, int|void max_files,
				    string|void quarantine)
{
  return roxen.register_fsgarb(module_identifier(), path, max_age,
			       max_size, max_files, quarantine);
}
#endif

private mapping __my_tables = ([]);

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
//! Identical to @[sql_query], but the @[Sql.Sql()->big_query] method
//! will be used instead of the @[Sql.Sql()->query] method.
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
//! Identical to @[sql_query_ro], but the @[Sql.Sql()->big_query] method
//! will be used instead of the @[Sql.Sql()->query] method.
{
  return get_my_sql(1)->big_query( replace( query, __my_tables ), @args );
}

protected int create_sql_tables( mapping(string:array(string)) definitions,
				 string|void comment, int|void no_unique_names )
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

protected string sql_table_exists( string name )
//! Return the real name of the table 'name' if it exists.
{
  if(strlen(name))
    name = "_"+name;

  string res = hash(_my_configuration->name)->digits(36)
    + "_" + replace(sname(), ({ "#","-" }), ({ "_","_" })) + name;

  return catch(get_my_sql()->query( "SELECT * FROM "+res+" LIMIT 1" ))?0:res;
}


protected string|int get_my_table( string|array(string) name,
				   void|array(string)|string definition,
				   string|void comment, int|void flag )
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
//! @code
//!   cache_table = get_my_table( "cache", ({
//!               "id INT UNSIGNED AUTO_INCREMENT",
//!               "data BLOB",
//!               }) );
//! @endcode
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
    + "_" + replace(sname(),({ "#","-" }), ({ "_","_" })) + name;

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

protected string my_db = "local";

protected void set_my_db( string to )
//! Select the database in which tables will be created with
//! get_my_table, and also the one that will be returned by
//! @[get_my_sql]
{
  my_db = to;
}

Sql.Sql get_my_sql( int|void read_only, void|string charset )
//! Return a SQL-object for the database set with @[set_my_db],
//! defaulting to the 'shared' database. If @[read_only] is specified,
//! the database will be opened in read_only mode. @[charset] may be
//! used to specify a charset for the connection if the database
//! supports it.
//!
//! See also @[DBManager.get]
{
  return DBManager.cached_get( my_db, _my_configuration, read_only, charset );
}

// Callback used by the DB browser, if defined, for custom formatting
// of database fields.
int|string format_db_browser_value (string db_name, string table_name,
				    string column_name, array(string) col_names,
				    array(string) col_types, array(string) row,
				    RequestID id);
