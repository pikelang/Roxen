// Protocol support for RFC 2518
//
// $Id: webdav.pike,v 1.5 2004/03/01 19:38:15 grubba Exp $
//
// 2003-09-17 Henrik Grubbström

inherit "module";

#include <module.h>
#include <request_trace.h>

constant cvs_version = "$Id: webdav.pike,v 1.5 2004/03/01 19:38:15 grubba Exp $";
constant thread_safe = 1;
constant module_name = "DAV: Protocol support";
constant module_type = MODULE_FIRST;
constant module_doc  = "Adds support for various HTTP extensions defined "
  "in <a href='http://rfc.roxen.com/2518'>RFC 2518 (WEBDAV)</a>, such as "
  "<b>PROPFIND</b> and <b>PROPPATCH</b>.";

#ifdef DAV_DEBUG
#define DAV_WERROR(X...)	werror(X)
#else /* !DAV_DEBUG */
#define DAV_WERROR(X...)
#endif /* DAV_DEBUG */

Configuration conf;

void start(int q, Configuration c)
{
  conf = c;
}

mapping|int(-1..0) first_try(RequestID id)
{
  switch(id->method) {
  case "OPTIONS":
    return ([ "type":"text/html",
	      "data":"",
	      "extra_heads":([
		"Allow":"CHMOD,COPY,DELETE,GET,HEAD,MKCOL,MKDIR,MOVE,"
		"MV,PING,POST,PROPFIND,PROPPATCH,PUT,OPTIONS",
		"Public":"CHMOD,COPY,DELETE,GET,HEAD,MKCOL,MKDIR,MOVE,"
		"MV,PING,POST,PROPFIND,PROPPATCH,PUT,OPTIONS",
		"Accept-Ranges":"bytes",
		"DAV":"1",
	      ]),
    ]);
  case "COPY":
  case "PROPFIND":
  case "PROPPATCH":
    // These need to be special cased, since they are recursive.
    return handle_webdav(id);
  }
  return 0;
}

//! Implements PROPPATCH <DAV:set/>.
class PatchPropertySetCmd
{
  constant command="DAV:set";
  string property_name;
  string|array(Parser.XML.Tree.Node) value;
  static void create(Parser.XML.Tree.Node prop_node)
  {
    property_name = prop_node->get_full_name();
    value = prop_node->get_children();

    if ((sizeof(value) == 1) &&
	(value[0]->get_node_type() == Parser.XML.Tree.XML_TEXT)) {
      // Special case for a single text node.
      value = value[0]->get_text();
    }
  }

  mapping(string:mixed) execute(string path, RoxenModule module,
				RequestID id, mixed context)
  {
    return module->set_property(path, property_name, value, id, context);
  }
}

//! Implements PROPPATCH <DAV:remove/>.
class PatchPropertyRemoveCmd(string property_name)
{
  constant command="DAV:remove";
  mapping(string:mixed) execute(string path, RoxenModule module,
				RequestID id, mixed context)
  {
    return module->remove_property(path, property_name, id, context);
  }
}

//! Handle WEBDAV requests.
mapping|int(-1..0) handle_webdav(RequestID id)
{
  Parser.XML.Tree.Node xml_data;
  TRACE_ENTER("Handle WEBDAV request...", 0);
  if (catch { xml_data = id->get_xml_data(); }) {
    // RFC 2518 8:
    //   If a server receives ill-formed XML in a request it MUST reject
    //   the entire request with a 400 (Bad Request).
    TRACE_LEAVE("Malformed XML.");
    return Roxen.http_low_answer(400, "Malformed XML data.");
  }
  if (!(<"COPY", "PROPFIND", "PROPPATCH">)[id->method]) {
    TRACE_LEAVE("Not implemented.");
    return Roxen.http_low_answer(501, "Not implemented.");
  }

  // RFC 2518 9.2:
  //   The Depth header is only supported if a method's definition
  //   explicitly provides for such support.
  int depth;
  if ((<"PROPFIND", "COPY", "MOVE", "DELETE", "LOCK">)[id->method]) {
    depth = ([ "0":0, "1":1, "infinity":0x7fffffff, 0:0x7fffffff ])
      [id->request_headers->depth &&
       String.trim_whites(id->request_headers->depth)];
  } else if (id->request_headers->depth) {
    // Depth header not supported in this case.
  }
  if (zero_type(depth)) {
    TRACE_LEAVE(sprintf("Bad depth header: %O.",
			id->request_headers->depth));
    return Roxen.http_low_answer(400, "Unsupported depth.");
  }

  // Function to call for matching location modules.
  //
  // Arguments:
  //   string path
  //   int d
  //   RoxenModule module
  //   RequestID id
  //   mixed ... extras
  function(string,string,int,RoxenModule,MultiStatus,RequestID,mixed ...:void)
    recur_func;
  array(mixed) extras = ({});

  switch(id->method) {
  case "COPY":
    if (!id->request_headers->destination) {
      return Roxen.http_low_answer(400, "COPY: Missing destination header.");
    }
    // Check that destination is on this virtual server.
    Standards.URI dest_uri;
    if (catch {
	dest_uri = Standards.URI(id->request_headers->destination);
      }) {
      return Roxen.http_low_answer(400,
				   sprintf("COPY: Bad destination header:%O.",
					   id->request_headers->destination));
    }
    if ((dest_uri->scheme != id->port_obj->prot_name) ||
	!(<id->misc->host, id->port_obj->ip, gethostname()>)[dest_uri->host] ||
	dest_uri->port != id->port_obj->port) {
      return Roxen.http_low_answer(400,
				   sprintf("COPY: Bad destination:%O != %s://%s:%d/.",
					   id->request_headers->destination,
					   id->port_obj->prot_name,
					   id->port_obj->ip,
					   id->port_obj->port));
    }
    extras = ({ dest_uri->path });
    if (xml_data) {
      // Mapping from href to behavior.
      // @int
      //   @value -1
      //     omit
      //   @value 0
      //     default
      //     If default also check the entry for href @tt{0@} (zero).
      //   @value 1
      //     keepalive
      // @endint
      mapping(string:int(-1..1)) propertybehavior = ([]);
      Parser.XML.Tree.Node prop_behav_node =
	xml_data->get_first_element("DAV:propertybehavior", 1);
      if (!prop_behav_node) {
	return Roxen.http_low_answer(400, "Missing DAV:propertybehavior.");
      }
      /* Valid children of <DAV:propertybehavior> are
       *   <DAV:keepalive>	(12.12.1)
       * or
       *   <DAV:omit>		(12.12.2)
       */
      foreach(prop_behav_node->get_children(), Parser.XML.Tree.Node n) {
	switch(n->get_full_name()) {
	case "DAV:omit":
	  if (propertybehavior[0] > 0) {
	    return Roxen.http_low_answer(400, "Conflicting DAV:propertybehavior.");
	  }
	  propertybehavior[0] = -1;
	  break;
	case "DAV:keepalive":
	  foreach(n->get_children(), Parser.XML.Tree.Node href) {
	    if (href->get_full_name == "DAV:href") {
	      propertybehavior[href->value_of_node()] = 1;
	    } else if (href->mNodeType == Parser.XML.Tree.XML_TEXT) {
	      if (href->get_text() != "*"){
		return Roxen.http_low_answer(400, "Syntax error in DAV:keepalive.");
	      }
	      if (propertybehavior[0] < 0) {
		return Roxen.http_low_answer(400, "Conflicting DAV:propertybehavior.");
	      }
	      propertybehavior[0] = 1;
	    }
	  }
	  break;
	}
      }
      if (sizeof(propertybehavior)) {
	extras += ({ propertybehavior });
      }
    }
    
    recur_func = lambda(string path, string dest, int d, RoxenModule module,
			MultiStatus stat, RequestID id,
			mapping(string:int(-1..1))|void behavior) {
		   module->recurse_copy_files(path, d, 0, "",
					      behavior||([]),
					      stat, id);
		 };
    break;
  case "PROPFIND":	// Get meta data.
    if (xml_data) {
      Parser.XML.Tree.Node propfind =
	xml_data->get_first_element("DAV:propfind", 1);
      if (!propfind) {
	return Roxen.http_low_answer(400, "Missing DAV:propfind.");
      }
      /* Valid children of <DAV:propfind> are
       *   <DAV:propname />
       * or
       *   <DAV:allprop />
       * or
       *   <DAV:prop>{propertylist}*</DAV:prop>
       */
      foreach(propfind->get_children(), Parser.XML.Tree.Node prop) {
	switch(prop->get_full_name()) {
	case "DAV:propname":
	  if (recur_func)
	    return Roxen.http_low_answer(400, "Bad DAV request (23.3.2.1).");
	  recur_func = lambda(string path, string ignored, int d,
			      RoxenModule module,
			      MultiStatus stat, RequestID id) {
			 module->recurse_find_properties(path, "DAV:propname", d,
							 stat, id);
		       };
	  break;
	case "DAV:allprop":
	  if (recur_func)
	    return Roxen.http_low_answer(400, "Bad DAV request (23.3.2.1).");
	  recur_func = lambda(string path, string ignored, int d,
			      RoxenModule module,
			      MultiStatus stat, RequestID id,
			      multiset(string)|void filt) {
			 module->recurse_find_properties(path, "DAV:allprop", d,
							 stat, id, filt);
		       };
	  break;
	case "DAV:prop":
	  if (recur_func)
	    return Roxen.http_low_answer(400, "Bad DAV request (23.3.2.1).");
	  recur_func = lambda(string path, string ignored, int d,
			      RoxenModule module,
			      MultiStatus stat, RequestID id,
			      multiset(string) filt) {
			 module->recurse_find_properties(path, "DAV:prop", d,
							 stat, id, filt);
		       };
	  // FALL_THROUGH
	case "http://sapportals.com/xmlns/cm/webdavinclude":
	  // Support for draft-reschke-webdav-allprop-include-04
	  // FIXME: Should we check that
	  //        http://sapportals.com/xmlns/cm/webdavinclude only
	  //        occurrs in the DAV:allprop case? 
	  multiset(string) props =
	    (multiset(string))(prop->get_children()->get_full_name() -
			       ({ "" }));
	  if (sizeof(extras)) {
	    extras[0] |= props;
	  } else {
	    extras = ({ props });
	  }
	  break;
	default:
	  break;
	}
      }
    } else {
      // RFC 2518 8.1:
      //   A client may choose not to submit a request body. An empty
      //   PROPFIND request body MUST be treated as a request for the
      //   names and values of all properties.
      recur_func = lambda(string path, string ignored, int d,
			  RoxenModule module,
			  MultiStatus stat, RequestID id) {
		     module->recurse_find_properties(path, "DAV:allprop", d,
						     stat, id);
		   };
    }
    break;
  case "PROPPATCH":	// Set/delete meta data.
    Parser.XML.Tree.Node propupdate =
      xml_data->get_first_element("DAV:propertyupdate", 1);
    if (!propupdate) {
      return Roxen.http_low_answer(400, "Missing DAV:propertyupdate.");
    }
    /* Valid children of <DAV:propertyupdate> are any combinations of
     *   <DAV:set><DAV:prop>{propertylist}*</DAV:prop></DAV:set>
     * and
     *   <DAV:remove><DAV:prop>{propertylist}*</DAV:prop></DAV:remove>
     *
     * RFC 2518 8.2:
     *   Instruction processing MUST occur in the order instructions
     *   are received (i.e., from top to bottom).
     */
    array(PatchPropertyCommand) instructions = ({});
    foreach(propupdate->get_children(), Parser.XML.Tree.Node cmd) {
      switch(cmd->get_full_name()) {
      case "DAV:set":
      case "DAV:remove":
	Parser.XML.Tree.Node prop =
	  cmd->get_first_element("DAV:prop", 1);
	if (!prop) {
	  TRACE_LEAVE("Bad DAV request.");
	  return Roxen.http_low_answer(400, "Bad DAV request (no properties specified).");
	}
	if (cmd->get_full_name() == "DAV:set") {
	  instructions += map(prop->get_children(), PatchPropertySetCmd);
	} else {
	  // FIXME: Should we verify that the properties are empty?
	  instructions += map(prop->get_children()->get_full_name(),
			      PatchPropertyRemoveCmd);
	}
	break;
      default:
	// FIXME: Should we complain here?
	break;
      }
    }
    if (!sizeof(instructions)) {
      TRACE_LEAVE("Bad DAV request.");
      return Roxen.http_low_answer(400, "Bad DAV request (23.3.2.2).");
    }
    recur_func = lambda(string path, string ignored, int d, RoxenModule module,
			MultiStatus stat, RequestID id,
			array(PatchPropertyCommand) instructions) {
		   // NOTE: RFC 2518 does not support depth header
		   //       with PROPPATCH, thus no recursion wrapper.
		   module->patch_properties(path, instructions, stat, id);
		 };
    extras = ({ instructions });
    break;
  default:
    break;
  }
  if (!recur_func) {
    TRACE_LEAVE("Bad DAV request.");
    return Roxen.http_low_answer(400, "Bad DAV request (23.3.2.2).");
  }
  // FIXME: Security, DoS, etc...
  MultiStatus result = MultiStatus();
  if (id->method != "COPY") {
    result = result->prefix(sprintf("%s://%s%s%s",
				    id->port_obj->prot_name,
				    id->misc->host || id->port_obj->ip ||
				    gethostname(),
				    (id->port_obj->port == id->port_obj->port)?
				    "":(":"+(string)id->port_obj->port),
				    id->port_obj->path||""));
  } else {
    result = result->prefix(id->request_headers->destination);
  }
  string href = id->not_query;
  string href_prefix = combine_path(href, "./");
  foreach(conf->location_modules(), [string loc, function fun]) {
    int d = depth;
    string path;	// Module location relative path.
    string dest = "";	// Destination header relative path.
    TRACE_ENTER(sprintf("Trying module mounted at %O...", loc),
		function_object(fun));
    if (has_prefix(href, loc) || (loc == href+"/")) {
      // href = loc + path.
      path = href[sizeof(loc)..];
    } else if (d && has_prefix(loc, href_prefix) &&
	       ((d -= sizeof((dest = loc[sizeof(href_prefix)..])/"/")) >= 0)) {
      // loc = href_path + ...
      // && recursion.
      path = "";
      if (!sizeof(dest) || (dest[0] != '/')) {
	dest = "/" + dest;
      }
    } else {
      TRACE_LEAVE("Miss");
      continue;
    }
#ifdef MODULE_LEVEL_SECURITY
    int|mapping security_ret;
    if(security_ret = conf->check_security(fun, id)) {
      if (mappingp(security_ret)) {
	// FIXME: What if we've already added some stuff in result?
	TRACE_LEAVE("Security check return.");
	TRACE_LEAVE("Need authentication.");
	return security_ret;
      } else {
	TRACE_LEAVE("Not allowed.");
	continue;
      }
    }
#endif
    RoxenModule c = function_object(fun);
    TRACE_ENTER("Performing the work...", c);
    recur_func(path, dest, d, c,
	       id->method=="COPY"?result->prefix(dest):result->prefix(loc),
	       id, @extras);
    TRACE_LEAVE("Done.");
    TRACE_LEAVE("Done.");
  }
  TRACE_LEAVE("DAV request done.");
  return result->http_answer();
}

