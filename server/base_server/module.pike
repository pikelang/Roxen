// This file is part of Roxen WebServer.
// Copyright © 1996 - 2001, Roxen IS.
// $Id: module.pike,v 1.145 2003/08/26 16:17:00 grubba Exp $

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
           "<b>CVS Version: </b>"+
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
  TRACE_ENTER("find_dir_stat(): \""+f+"\"", 0);

  array(string) files = find_dir(f, id);
  mapping(string:Stat) res = ([]);

  foreach(files || ({}), string fname) {
    TRACE_ENTER("stat()'ing "+ f + "/" + fname, 0);
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

//! Returns a multiset with the names of all supported properties.
//!
//! @note
//!   Only properties that should be listed by @tt{<DAV:allprop/>@}
//!   are returned.
//!
//! @note
//!   The following properties are required to keep
//!   @tt{Microsoft Data Access Internet Publishing Provider DAV 1.1@}
//!   as supplied with @tt{Microsoft Windows 2000@} happy:
//!   @string
//!     @value "DAV:creationdate"
//!	  RFC2518 13.1
//!     @value "DAV:displayname"
//!	  RFC2518 13.2
//!     @value "DAV:getcontentlanguage"
//!	  RFC2518 13.3
//!     @value "DAV:getcontentlength"
//!	  RFC2518 13.4
//!     @value "DAV:getcontenttype"
//!	  RFC2518 13.5
//!     @value "DAV:getlastmodified"
//!	  RFC2518 13.7
//!     @value "DAV:resourcetype"
//!	  RFC2518 13.9
//!
//!     @value "DAV:defaultdocument"
//!	  @tt{draft-hopmann-collection-props-00@} 1.3
//!
//!	  Specifies the default document for a collection.
//!
//!	  This property contains an URL that identifies the default
//!	  document for a collection. This is intended for collection
//!	  owners to be able to set a default document, for example
//!	  @tt{index.html@} or @tt{default.html@}. If this property
//!	  is absent, other means must be found to determine the default
//!	  document.
//!
//!	  If this property is present, but null, the collection does
//!	  not have a default document and the collection member listing
//!	  should be used (or nothing).
//!
//!	  Note: The server implementation does not need to store this
//!	  property in the normal property store (the property could well
//!	  be live).
//!     @value "DAV:ishidden"
//!	  @tt{draft-hopmann-collection-props-00@} 1.7
//!
//!	  Specifies whether or not a resource is hidden. 
//!
//!	  This property identifies whether or not a resource is hidden.
//!	  It contains either the values @tt{"1"@} or @tt{"0"@}. This 
//!	  can be considered a hint to the client UI: under normal 
//!	  conditions, for non-expert users, hidden files should not be
//!	  exposed to users. The server may omit the hidden resource from
//!	  some presentational listings, otherwise the client is responsible
//!	  for removing hidden resources when displaying to the user. If
//!	  this property is absent, the collection is not hidden. Since this 
//!	  property provides no actual form of protection to the resources,
//!	  this MUST NOT be used as a form of access control and should
//!	  only be used for presentation purposes. 
//!     @value "DAV:isstructureddocument"
//!	  @tt{draft-hopmann-collection-props-00@} 1.7
//!
//!	  Specifies whether the resource is a structured document.
//!
//!	  A structured document is a collection (@tt{DAV:iscollection@}
//!	  should also be true), so @tt{COPY@}, @tt{MOVE@} and @tt{DELETE@}
//!	  work as for a collection. The structured document may behave at 
//!	  times like a document. For example, clients may wish to display
//!	  the resource as a document rather than as a collection. This
//!	  contains either @tt{"1"@} (true) or @tt{"0"@}. If this property
//!	  is absent, the collection is not a structured document.
//!
//!	  This property can also be considered a hint for the client UI:
//!	  if the value of @tt{"DAV:isstructureddocument"@} is @tt{"1"@},
//!	  then the client UI may display this to the user as if it were
//!	  single document. This can be very useful when the default
//!	  document of a collection is an HTML page with a bunch of images
//!	  which are the other resources in the collection: only the default
//!	  document is intended to be viewed as a document, so the entire 
//!	  structure can appear as one document.
//!
//!	  A Structured document may contain collections. A structured
//!	  document must have a default document (if the
//!	  @tt{"DAV:defaultdocument"@} property is absent, the default
//!	  document is assumed by the client to be @tt{index.html@}). 
//!
//!     @value "DAV:iscollection"
//!	  @tt{draft-ietf-dasl-protocol-00@} 5.18
//!
//!	  The @tt{DAV:iscollection@} XML element is a synthetic property
//!	  whose value is defined only in the context of a query. The
//!	  property is TRUE (the literal string @tt{"1"@}) of a resource
//!	  if and only if a @tt{PROPFIND@} of the @tt{DAV:resourcetype@}
//!	  property for that resource would contain the @tt{DAV:collection@}
//!	  XML element. The property is FALSE (the literal string @tt{"0"@})
//!	  otherwise. 
//!	  
//!	  Rationale: This property is provided in lieu of defining generic
//!	  structure queries, which would suffice for this and for many more
//!	  powerful queries, but seems inappropriate to standardize at this
//!	  time.
//!
//!     @value "DAV:isreadonly"
//!	  Microsoft specific.
//!
//!	  The @tt{isreadonly@} field specifies whether an item can be
//!	  modified or deleted. If this field is TRUE, the item cannot
//!	  be modified or deleted.
//!     @value "DAV:isroot"
//!	  Microsoft specific.
//!
//!	  The @tt{DAV:isroot@} field specifies whether an item is a
//!	  root folder.
//!     @value "DAV:lastaccessed"
//!	  Microsoft specific.
//!
//!	  The @tt{DAV:lastaccessed@} field specifies the date and time
//!	  when an item was last accessed. This field is read-only.
//!     @value "DAV:href"
//!	  Microsoft specific.
//!
//!	  Read-only. The @b{absolute URL@} of an item.
//!     @value "DAV:contentclass"
//!	  Microsoft specific.
//!
//!	  The item's content class.
//!     @value "DAV:parentname"
//!	  Microsoft specific.
//!
//!	  The @tt{DAV:parentname@} field specifies the name of the folder
//!	  that contains an item.
//!     @value "DAV:name"
//!	  Microsoft specific.
//!
//!	  Unknown definition.
//!   @endstring
multiset(string) query_all_properties(string path, RequestID id)
{
  Stat st = stat_file(path, id);
  if (!st) return (<>);
  multiset(string) res = (<
    "DAV:creationdate",		// RFC2518 13.1
    "DAV:displayname",		// RFC2518 13.2
    "DAV:getcontentlanguage",	// RFC2518 13.3
    "DAV:getlastmodified",	// RFC2518 13.7
    "DAV:resourcetype",		// RFC2518 13.9

    "DAV:iscollection",		// draft-ietf-dasl-protocol-00 5.18

    "DAV:ishidden",		// draft-hopmann-collection-props-00 1.6

    "DAV:isreadonly",		// MS uses this.
    "DAV:lastaccessed",		// MS uses this.
    "DAV:href",			// MS uses this.
    "DAV:contentclass",		// MS uses this.
    "DAV:parentname",		// MS uses this.
    "DAV:name",			// MS uses this.
  >);
  if (st->isreg) {
    res += (<
      "DAV:getcontentlength",	// RFC2518 13.4
      "DAV:getcontenttype",	// RFC2518 13.5
      "http://apache.org/dav/props/executable",
    >);
  } else if (st->isdir) {
    res += (<
      "DAV:defaultdocument",	  // draft-hopmann-collection-props-00 1.3
      "DAV:isstructureddocument", // draft-hopmann-collection-props-00 1.7
      "DAV:isroot",		  // MS uses this.
    >);
  }
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
  Stat st = stat_file(path, id);
  if (!st) return Roxen.http_low_answer(404, "No such file or directory.");
  switch(prop_name) {
  case "DAV:displayname":	// RFC2518 13.2
    return combine_path(query_location(), path);
  case "DAV:getcontentlength":	// RFC2518 13.4
    if (st->isreg) {
      return (string)st->size;
    }
    break;
  case "DAV:getcontenttype":	// RFC2518 13.5
    if (st->isreg) {
      return id->conf->
	type_from_filename(path, 0,
			   lower_case(Roxen.extension(path, id)));
    }
    break;
  case "DAV:getlastmodified":	// RFC2518 13.7
    return Roxen.iso8601_date_time(st->mtime);
  case "DAV:resourcetype":	// RFC2518 13.9
    if (st->isdir) {
      return ({
	Parser.XML.Tree.ElementNode("DAV:collection", ([])),	// 12.2
      });
    }
    return "";
  case "http://apache.org/dav/props/executable":
    // http://www.webdav.org/mod_dav/:
    //
    // Name:		executable
    // Namespace:	http://apache.org/dav/props/
    // Purpose:		Describes the executable status of the resource. 
    // Value:		"T" | "F"    (case is significant)
    // Description:	This property is defined by mod_dav's default
    //			repository, the "filesystem" repository. It
    //			corresponds to the "executable" permission flag
    //			in most filesystems.
    //
    //			This property is not defined on collections.
    if (st->isreg) {
      if (st->mode & 0111) return "T";
      return "F";
    }
    break;

    // The following are properties in the DAV namespace
    // that Microsoft has stolen.
  case "DAV:isreadonly":	// draft-ietf-dasl-protocol-00
    if (!(st->mode & 0222)) {
      return "1";
    }
    return "0";
  case "DAV:iscollection":	// draft-ietf-dasl-protocol-00 5.18
  case "DAV:isfolder":		// draft-hopmann-collection-props-00 1.5
    if (st->isdir) {
      return "1";
    }
    return "0";
  case "DAV:ishidden":		// draft-hopmann-collection-props-00 1.6
    return "0";
  case "DAV:isroot":		// ?
    if (path == "/") return "1";
    return "0";
  default:
    break;
  }
  report_debug("query_property(): Unimplemented property:%O\n", prop_name);
#if 1
  // RFC 2518 8.1:
  //   A request to retrieve the value of a property which does not
  //   exist is an error and MUST be noted, if the response uses a
  //   multistatus XML element, with a response XML element which
  //   contains a 404 (Not Found) status value.
  return Roxen.http_low_answer(404, "No such property.");
#else /* !1 */
  return Roxen.http_low_answer(200, "OK");
#endif /* 1 */
}

//! Attempt to set property @[prop_name] for @[path] to @[value].
//!
//! @param value
//!   Value to set the node to.
//!   The case of an array of a single text node is special cased,
//!   and is sent as a @expr{string@}.
//!
//! @returns
//!   Returns a result mapping. May return @expr{0@} (zero) on success.
//!
//! @note
//!   Actual changing of the property should be done first
//!   when @[patch_property_commit()] is called, or unrolled
//!   when @[patch_property_unroll()] is called.
//!
//! @note
//!   Overloaded variants should only set live properties;
//!   setting of dead properties should be done throuh
//!   overloading of @[set_dead_property()].
mapping(string:mixed) set_property(string path, string prop_name,
				   string|array(Parser.XML.Tree.Node) value,
				   RequestID id)
{
  switch(prop_name) {
  case "http://apache.org/dav/props/executable":
    // FIXME: Could probably be implemented R/W.
    // FALL_THROUGH
  case "DAV:displayname":	// 13.2
  case "DAV:getcontentlength":	// 13.4
  case "DAV:getcontenttype":	// 13.5
  case "DAV:getlastmodified":	// 13.7
    return Roxen.http_low_answer(409,
				 "Attempt to set read-only property.");    
  }
  return set_dead_property(path, prop_name, value, id);
}

//! Attempt to set dead property @[prop_name] for @[path] to @[value].
//!
//! @returns
//!   Returns a result mapping. May return @expr{0@} (zero) on success.
//!
//! @note
//!   Actual changing of the property should be done first
//!   when @[patch_property_commit()] is called, or unrolled
//!   when @[patch_property_unroll()] is called.
//!
//! @note
//!   This function is called as a fallback by @[set_property()]
//!   if all else fails.
//!
//! @note
//!   The default implementation currently does not support setting
//!   of dead properties, and will return an error code.
mapping(string:mixed) set_dead_property(string path, string prop_name,
					array(Parser.XML.Tree.Node) value,
					RequestID id)
{
  return Roxen.http_low_answer(405,
			       "Setting of dead properties is not supported.");
}

//! Attempt to remove the property @[prop_name] for @[path].
//!
//! @note
//!   Actual removal of the property should be done first
//!   when @[patch_property_commit()] is called, or unrolled
//!   when @[patch_property_unroll()] is called.
//!
//! @returns
//!   Returns a result mapping. May return @expr{0@} (zero) on success.
//!
//! @note
//!   The default implementation does not support deletion.
mapping(string:mixed) remove_property(string path, string prop_name,
				      RequestID id)
{
  switch(prop_name) {
  case "http://apache.org/dav/props/executable":
  case "DAV:displayname":	// 13.2
  case "DAV:getcontentlength":	// 13.4
  case "DAV:getcontenttype":	// 13.5
  case "DAV:getlastmodified":	// 13.7
    return Roxen.http_low_answer(409,
				 "Attempt to remove a read-only property.");
  }
  // RFC 2518 12.13.1:
  //   Specifying the removal of a property that does not exist
  //   is not an error.
  return 0;
}

//! Default implementation of some RFC 2518 properties.
//!
//! @param path
//!   @[query_location()]-relative path.
//! @param mode
//!   Query-mode. Currently one of
//!   @string mode
//!     @value "DAV:propname"
//!       Query after names of supported properties.
//!     @value "DAV:allprop"
//!       Query after all properties and their values.
//!     @value "DAV:prop"
//!       Query after properties specified by @[filt] and
//!       their values.
//!   @endstring
//! @param result
//!   Result object.
//! @param id
//!   Id of the current request.
//! @param filt
//!   Optional multiset of requested properties. If this parameter
//!   is @expr{0@} (zero) then all available properties are requested.
//!
//! @note
//!   id->not_query() does not necessarily contain the same value as @[path].
void find_properties(string path, string mode, MultiStatus result,
		     RequestID id, multiset(string)|void filt)
{
  Stat st = stat_file(path, id);
  if (!st) return;

  switch(mode) {
  case "DAV:propname":
    foreach(indices(query_all_properties(path, id)), string prop_name) {
      result->add_property(path, prop_name, "");
    }
    return;
  case "DAV:allprop":
    if (filt) {
      // Used in http://sapportals.com/xmlns/cm/webdavinclude case.
      // (draft-reschke-webdav-allprop-include-04).
      filt |= query_all_properties(path, id);
    } else {
      filt = query_all_properties(path, id);
    }
    // FALL_THROUGH
  case "DAV:prop":
    foreach(indices(filt), string prop_name) {
      result->add_property(path, prop_name,
			   query_property(path, prop_name, id));
    }
    return;
  }
  // FIXME: Unsupported DAV operation.
  return;
}

void recurse_find_properties(string path, string mode, int depth,
			     MultiStatus result,
			     RequestID id, multiset(string)|void filt)
{
  Stat st = stat_file(path, id);
  if (!st) return;

  find_properties(path, mode, result, id, filt);
  if ((depth <= 0) || !st->isdir) return;
  depth--;
  foreach(find_dir(path, id), string filename) {
    recurse_find_properties(combine_path(path, filename), mode, depth,
			    result, id, filt);
  }
}

// RFC 2518 8.2
//   Instructions MUST either all be executed or none executed.
//   Thus if any error occurs during procesing all executed
//   instructions MUST be undone and a proper error result
//   returned.

//! Signal start of patching of properties for @[path].
void patch_property_start(string path, RequestID id)
{
}

//! Patching of the properties for @[path] failed.
//! Restore the state to what it was when @[patch_property_start()]
//! was called.
void patch_property_unroll(string path, RequestID id)
{
}

//! Patching of the properties for @[path] succeeded.
void patch_property_commit(string path, RequestID id)
{
}

void patch_properties(string path, array(PatchPropertyCommand) instructions,
		      MultiStatus result, RequestID id)
{
  patch_property_start(path, id);

  array(mapping(string:mixed)) results;

  mixed err = catch {
    results = instructions->execute(path, this_object(), id);
  };
  if (err) {
    report_debug("patch_properties() failed:\n"
		 "%s\n",
		 describe_backtrace(err));
    mapping(string:mixed) answer =
      Roxen.http_low_answer(500, "Internal Server Error.");
    foreach(instructions, PatchPropertyCommand instr) {
      result->add_property(path, instr->property_name, answer);
    }
    patch_property_unroll(path, id);
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
	Roxen.http_low_answer(424, "Failed dependency.");
      for(i = 0; i < sizeof(results); i++) {
	if (!results[i] || results[i]->error < 300) {
	  result->add_property(path, instructions[i]->property_name,
			       answer);
	} else {
	  result->add_property(path, instructions[i]->property_name,
			       results[i]);
	}
      }
      patch_property_unroll(path, id);
    } else {
      int i;
      for(i = 0; i < sizeof(results); i++) {
	result->add_property(path, instructions[i]->property_name,
			     results[i]);
      }
      patch_property_commit(path, id);
    }
  }
}

void recurse_patch_properties(string path, int depth,
			      array(PatchPropertyCommand) instructions,
			      MultiStatus result, RequestID id)
{
  Stat st = stat_file(path, id);

  patch_properties(path, instructions, result, id);
  if (!st || (depth <= 0) || !st->isdir) return;
  depth--;
  foreach(find_dir(path, id), string filename) {
    recurse_patch_properties(combine_path(path, filename), depth,
			     instructions, result, id);
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
				void|array(string)|string defenition,
				string|void comment,
				int|void flag )
//! @decl string get_my_table( string name, array(string) types )
//! @decl string get_my_table( string name, string defenition )
//! @decl string get_my_table( string defenition )
//! @decl string get_my_table( array(string) defenition )
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
//! In the second form, the whole table defenition is instead sent as
//! a string. The cases where the name is not included (the third and
//! fourth form) is equivalent to the first two cases with the name ""
//!
//! If the table does not exist in the datbase, it is created.
//!
//! @note
//!   This function may not be called from create
//
// If it exists, but it's defenition is different, the table will be
// altered with a ALTER TABLE call to conform to the defenition. This
// might not work if the database the table resides in is not a MySQL
// database (normally it is, but it's possible, using @[set_my_db],
// to change this).
{
  string oname;
  int ddc;
  if( !defenition )
  {
    defenition = name;
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
  if( arrayp( defenition ) )
    defenition *= ", ";
  
  if( catch(sql->query( "SELECT * FROM "+res+" LIMIT 1" )) )
  {
    ddc++;
    mixed error =
      catch
      {
	get_my_sql()->query( "CREATE TABLE "+res+" ("+defenition+")" );
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
//   // Update defenition if it has changed.
//   mixed error = 
//     catch
//     {
//       get_my_sql()->query( "ALTER TABLE "+res+" ("+defenition+")" );
//     };
//   if( error )
//   {
//     if( strlen( name ) )
//       name = " for "+name;
//     report_notice( "Failed to update table defenition"+name+": "+
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
