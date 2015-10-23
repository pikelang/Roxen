//! Contains methods for querying and setting of properties for a
//! resource.
//!
//! This default implementation takes care of the most important RFC
//! 2518 properties for ordinary files and directories in read-only
//! mode.
//!
//! Objects of this class are usually created through
//! @[RoxenModule.query_property_set].

#include <roxen.h>

#ifdef DAV_DEBUG
#define DAV_WERROR(X...)	werror(X)
#else /* !DAV_DEBUG */
#define DAV_WERROR(X...)
#endif /* DAV_DEBUG */

//! Filesystem-relative path for which these properties apply.
string path;

//! Absolute path for which these properties apply.
string abs_path;

//! The current request.
RequestID id;

//! Create a new property set.
//!
//! Usually called via @[RoxenModule.query_propery_set].
protected void create(string path, string abs_path, RequestID id)
{
  global::path = path;
  global::abs_path = abs_path;
  global::id = id;

  ASSERT_IF_DEBUG(has_prefix(abs_path, "/") && has_suffix(abs_path, path));
}

//! @decl protected void destroy();
//!
//! Destruction callback.
//!
//! Note that this function must unroll any uncommitted
//! property changes.

//! Return an @[Stdio.Stat] object for the resource. Its main use is
//! to tell collections (i.e. directories) from non-collections.
Stat get_stat();

//! Called by the default @[query_property] implementation to get the
//! response headers a GET or HEAD request on @[path] would yield.
//! It's used to fill in the properties that should reflect various
//! response headers.
mapping(string:string) get_response_headers();

// Simulate an import of useful stuff from Parser.XML.Tree.
protected constant SimpleNode = Parser.XML.Tree.SimpleNode;
protected constant SimpleElementNode = Parser.XML.Tree.SimpleElementNode;

private constant all_properties_common = (<
  "DAV:getcontentlength",
  "DAV:getcontenttype",
  "DAV:displayname",
  "DAV:resourcetype",
  "DAV:supportedlock",
  "DAV:iscollection",
  "DAV:isfolder",
  "DAV:lockdiscovery",
  "DAV:supportedlock",
>);

private constant all_properties_file = all_properties_common + (<
  "http://apache.org/dav/props/executable",
>);

private constant all_properties_dir = all_properties_common;

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
//!
//!   @string
//!     @value "DAV:creationdate"
//!	  RFC2518 13.1
//!
//!     @value "DAV:displayname"
//!	  RFC2518 13.2
//!
//!     @value "DAV:getcontentlanguage"
//!	  RFC2518 13.3
//!
//!     @value "DAV:getcontentlength"
//!	  RFC2518 13.4
//!
//!     @value "DAV:getcontenttype"
//!	  RFC2518 13.5
//!
//!     @value "DAV:getetag"
//!	  RFC2518 13.6
//!
//!     @value "DAV:getlastmodified"
//!	  RFC2518 13.7
//!
//!     @value "DAV:lockdiscovery"
//!       RFC2518 13.8
//!
//!     @value "DAV:resourcetype"
//!	  RFC2518 13.9
//!
//!     @value "DAV:supportedlock"
//!	  RFC2518 13.11
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
//!
//!     @value "DAV:ishidden"
//!	  @tt{draft-hopmann-collection-props-00@} 1.6
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
//!
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
//!
//!     @value "DAV:isroot"
//!	  Microsoft specific.
//!
//!	  The @tt{DAV:isroot@} field specifies whether an item is a
//!	  root folder.
//!
//!     @value "DAV:lastaccessed"
//!	  Microsoft specific.
//!
//!	  The @tt{DAV:lastaccessed@} field specifies the date and time
//!	  when an item was last accessed. This field is read-only.
//!
//!     @value "DAV:href"
//!	  Microsoft specific.
//!
//!	  Read-only. The @b{absolute URL@} of an item.
//!
//!     @value "DAV:contentclass"
//!	  Microsoft specific.
//!
//!	  The item's content class.
//!
//!     @value "DAV:parentname"
//!	  Microsoft specific.
//!
//!	  The @tt{DAV:parentname@} field specifies the name of the folder
//!	  that contains an item.
//!
//!     @value "DAV:name"
//!	  Microsoft specific.
//!
//!	  Unknown definition.
//!   @endstring
//!
//!   Also, the MS DAV client requires a type argument to be able to
//!   parse date/time fields correctly, even when they are formatted
//!   according to the standard. @[XMLPropStatNode.add_property] has
//!   special cases for this for @tt{DAV:creationdate@} and
//!   @tt{DAV:getlastmodified@}.
multiset(string) query_all_properties()
{
  Stat st = get_stat();
  if (st) {
    multiset(string) props =
      (get_stat()->isreg ? all_properties_file : all_properties_dir) + (<>);

    // This isn't necessary for the Content-Length and Content-Type
    // headers since RequestID.make_response_headers always sets those.
    mapping(string:string) hdrs = get_response_headers();
    if (hdrs["Content-Language"]) props["DAV:getcontentlanguage"] = 1;
    if (hdrs->ETag)               props["DAV:getetag"] = 1;
    if (hdrs["Last-Modified"])    props["DAV:getlastmodified"] = 1;
    return props;
  }
  // Null resource.
  return all_properties_common + (<>);
}

//! Returns the value of the specified property, or an error code
//! mapping.
//!
//! The default implementation takes care of the most important RFC
//! 2518 properties.
//!
//! @note
//!   Returning a string is shorthand for returning an array
//!   with a single text node.
string|array(SimpleNode)|mapping(string:mixed)
  query_property(string prop_name)
{
  switch(prop_name) {
#if 0
    // We don't really have any idea of the creation time in a unix
    // style file system.
  case "DAV:creationdate":	// RFC2518 13.1
    Stdio.Stat stat = get_stat();
    if (stat) {
      int t = stat->ctime;
      if (t > stat->atime) t = stat->atime;
      if (t > stat->mtime) t = stat->mtime;
      return Roxen.iso8601_date_time(t);	// MS kludge.
    }
    break;
#endif

  case "DAV:displayname":	// RFC2518 13.2
    if ((path == "") || (path == "/")) return "/";
    if (path[-1] == '/') return basename(path[..sizeof(path)-2]);
    return basename(path);

  case "DAV:getcontentlanguage":// RFC2518 13.3
    return get_response_headers()["Content-Language"];

  case "DAV:getcontentlength":	// RFC2518 13.4
    return get_response_headers()["Content-Length"];

  case "DAV:getcontenttype":	// RFC2518 13.5
    return get_response_headers()["Content-Type"];

  case "DAV:getetag":		// RFC2518 13.6
    return get_response_headers()->ETag;

  case "DAV:getlastmodified":	// RFC2518 13.7
    return get_response_headers()["Last-Modified"];

  case "DAV:lockdiscovery":	// RFC2518 13.8
    return indices(id->conf->find_locks(abs_path, 0, 0, id))->get_xml();

  case "DAV:resourcetype":	// RFC2518 13.9
    if ((get_stat()||([]))->isdir) {
      return ({
	SimpleElementNode("DAV:collection", ([])),	// 12.2
      });
    }
    return 0;

  case "DAV:supportedlock":	// RFC2518 13.11
    {
      return ({
	SimpleElementNode("DAV:lockentry", ([]))->
	add_child(SimpleElementNode("DAV:lockscope", ([]))->
		  add_child(SimpleElementNode("DAV:exclusive", ([]))))->
	add_child(SimpleElementNode("DAV:locktype", ([]))->
		  add_child(SimpleElementNode("DAV:write", ([])))),

	SimpleElementNode("DAV:lockentry", ([]))->
	add_child(SimpleElementNode("DAV:lockscope", ([]))->
		  add_child(SimpleElementNode("DAV:shared", ([]))))->
	add_child(SimpleElementNode("DAV:locktype", ([]))->
		  add_child(SimpleElementNode("DAV:write", ([])))),
      });
    }
  case "http://apache.org/dav/props/executable":
    // http://www.webdav.org/mod_dav/:
    //
    // Name:		executable
    // Namespace:	http://apache.org/dav/props/
    // Purpose:	Describes the executable status of the resource. 
    // Value:		"T" | "F"    (case is significant)
    // Description:	This property is defined by mod_dav's default
    //		repository, the "filesystem" repository. It
    //		corresponds to the "executable" permission flag
    //		in most filesystems.
    //
    //		This property is not defined on collections.
    Stdio.Stat stat = get_stat();
    if (stat && stat->isreg) {
      if (stat->mode & 0111) return "T";
      return "F";
    }
    break;

#if 0
    // Need more interaction with directory listing modules to handle
    // this.
  case "DAV:defaultdocument":	// draft-hopmann-collection-props-00 1.3
    return "";

    // Absence means not hidden.
  case "DAV:ishidden":	// draft-hopmann-collection-props-00 1.6
    return "0";

    // Absence means not a structured document.
  case "DAV:isstructureddocument": // draft-hopmann-collection-props-00 1.7
    return "0";
#endif

  case "DAV:iscollection":	// draft-ietf-dasl-protocol-00 5.18
  case "DAV:isfolder":	// draft-hopmann-collection-props-00 1.5
    if ((get_stat()||([]))->isdir) {
      return "1";
    }
    return "0";

#if 0
    // The following are properties in the DAV namespace
    // that Microsoft has stolen.
  case "DAV:isreadonly":	// MS
    if (!((get_stat()||(["mode":0222]))->mode & 0222)) {
      return "1";
    }
    return "0";
  case "DAV:isroot":		// MS
    if (path == "") return "1";
    return "0";
  case "DAV:lastaccessed":	// MS
    return Roxen.iso8601_date_time((get_stat()||([]))->atime);
  case "DAV:href":		// MS
    return id->url_base() + abs_path[1..];
  case "DAV:contentclass":	// MS
    return "";
  case "DAV:parentname":	// MS
    return "";
  case "DAV:name":		// MS
    return abs_path;
#endif /* 0 */

  default:
    break;
  }

  DAV_WERROR("query_property(): Unimplemented property:%O\n", prop_name);
  // RFC 2518 8.1:
  //   A request to retrieve the value of a property which does not
  //   exist is an error and MUST be noted, if the response uses a
  //   multistatus XML element, with a response XML element which
  //   contains a 404 (Not Found) status value.
  return Roxen.http_status (Protocols.HTTP.HTTP_NOT_FOUND,
			    "No such property.");
}

// RFC 2518 8.2
//   Instructions MUST either all be executed or none executed.
//   Thus if any error occurs during procesing all executed
//   instructions MUST be undone and a proper error result
//   returned.

//! Signal start of patching of properties for @[path].
//!
//! At end of patching one of @[commit()] or @[unroll()]
//! will be called.
//!
//! @returns
//!   @mixed
//!     @type zero
//!	  Ok, patching will commence.
//!     @type mapping
//!       Return code. No patching will be performed.
//!   @endmixed
//!
//! @seealso
//!   @[set_property()], @[set_dead_property()], @[remove_property()]
mapping(string:mixed) start()
{
  return 0;
}

//! Patching of the properties for @[path] failed.
//! Restore the state to what it was when @[start()]
//! was called.
void unroll()
{
}

//! Patching of the properties for @[path] succeeded.
void commit()
{
}

//! Attempt to set property @[prop_name] to @[value].
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
//!   when @[commit()] is called, or unrolled
//!   when @[unroll()] is called.
//!
//! @note
//!   Overloaded variants should only set the live properties they can
//!   handle and call the inherited implementation for all others.
//!   Setting of dead properties should be done through overloading of
//!   @[set_dead_property()]. This way, the live properties handled on
//!   any level in the inherit hierachy take precedence over dead
//!   properties.
//!
//! @note
//!   RFC 2518: Live property - A property whose semantics and syntax
//!   are enforced by the server. For example, the live
//!   @tt{"getcontentlength"@} property has its value, the length of the
//!   entity returned by a GET request, automatically calculated by
//!   the server.
mapping(string:mixed) set_property(string prop_name,
				   string|array(SimpleNode) value)
{
  switch(prop_name) {
  case "http://apache.org/dav/props/executable":
    // FIXME: Could probably be implemented R/W.
    // FALL_THROUGH
  case "DAV:displayname":		// 13.2
  case "DAV:getcontentlength":	// 13.4
  case "DAV:getcontenttype":		// 13.5
  case "DAV:getlastmodified":		// 13.7
    return Roxen.http_status (Protocols.HTTP.HTTP_CONFLICT,
			      "Attempt to set read-only property.");
  }
  return set_dead_property(prop_name, value);
}

//! Attempt to set dead property @[prop_name] to @[value].
//!
//! @returns
//!   Returns a result mapping. May return @expr{0@} (zero) on success.
//!
//! @note
//!   Actual changing of the property should be done first
//!   when @[commit()] is called, or unrolled
//!   when @[unroll()] is called.
//!
//! @note
//!   This function is called as a fallback by @[set_property()]
//!   if all else fails.
//!
//! @note
//!   The default implementation currently does not support setting
//!   of dead properties, and will return an error code.
//!
//! @note
//!    RFC 2518: Dead Property - A property whose semantics and syntax
//!    are not enforced by the server. The server only records the
//!    value of a dead property; the client is responsible for
//!    maintaining the consistency of the syntax and semantics of a
//!    dead property.
mapping(string:mixed) set_dead_property(string prop_name,
					string|array(SimpleNode) value)
{
  return Roxen.http_status (Protocols.HTTP.HTTP_METHOD_INVALID,
			    "Setting of dead properties is not supported.");
}

//! Attempt to remove the property @[prop_name].
//!
//! @note
//!   Actual removal of the property should be done first
//!   when @[commit()] is called, or unrolled
//!   when @[unroll()] is called.
//!
//! @returns
//!   Returns a result mapping. May return @expr{0@} (zero) on success.
//!
//! @note
//!   The default implementation does not support deletion.
mapping(string:mixed) remove_property(string prop_name)
{
  switch(prop_name) {
  case "http://apache.org/dav/props/executable":
  case "DAV:displayname":	// 13.2
  case "DAV:getcontentlength":	// 13.4
  case "DAV:getcontenttype":	// 13.5
  case "DAV:getlastmodified":	// 13.7
    return Roxen.http_status (Protocols.HTTP.HTTP_CONFLICT,
			      "Attempt to remove a read-only property.");
  }
  // RFC 2518 12.13.1:
  //   Specifying the removal of a property that does not exist
  //   is not an error.
  return 0;
}

//! RFC 2518 PROPFIND implementation for a single resource (i.e. not
//! recursive).
//!
//! @param mode
//!   Query mode. Currently one of
//!   @string mode
//!     @value "DAV:propname"
//!       Query names of supported properties.
//!     @value "DAV:allprop"
//!       Query all properties and their values.
//!     @value "DAV:prop"
//!       Query properties specified by @[filt] and their values.
//!   @endstring
//! @param result
//!   @[MultiStatus.Prefixed] object to collect the results. It has
//!   the path to the file system as implicit prefix.
//! @param filt
//!   Optional multiset of requested properties. If this parameter
//!   is @expr{0@} (zero) then all available properties are requested.
mapping(string:mixed) find_properties(string mode,
				      MultiStatus.Prefixed result,
				      multiset(string)|void filt)
{
  switch(mode) {
  case "DAV:propname":
    filt = query_all_properties();
    foreach(filt; string prop_name;) {
      result->add_property(path, prop_name, "");
    }
    break;
  case "DAV:allprop":
    if (filt) {
      // Used in http://sapportals.com/xmlns/cm/webdavinclude case.
      // (draft-reschke-webdav-allprop-include-04).
      filt |= query_all_properties();
    } else {
      filt = query_all_properties();
    }
    // FALL_THROUGH
  case "DAV:prop":
    foreach(filt; string prop_name;) {
      result->add_property(path, prop_name,
			   query_property(prop_name));
    }
    break;
  default:
    // FIXME: Unsupported DAV operation.
    return 0;
  }

  if (filt["http://apache.org/dav/props/executable"])
    // Not really necessary.
    result->add_namespace ("http://apache.org/dav/props/");
  return 0;
}
