// Protocol support for RFC 2518
//
// $Id: webdav.pike,v 1.1 2003/09/17 10:53:20 grubba Exp $
//
// 2003-09-17 Henrik Grubbström

inherit "module";

#include <module.h>
#include <request_trace.h>

constant cvs_version = "$Id: webdav.pike,v 1.1 2003/09/17 10:53:20 grubba Exp $";
constant thread_safe = 1;
constant module_name = "DAV: Protocol support";
constant module_type = MODULE_FIRST;
constant module_doc  = "Adds support for various HTTP extensions defined "
  "in <a href='http://rfc.roxen.com/2518'>RFC 2518 (WEBDAV)</a>, such as "
  "<b>PROPFIND</b> and <b>PROPPATCH</b>.";

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
		"Allow":"CHMOD,DELETE,GET,HEAD,MKCOL,MKDIR,MOVE,"
		"MV,PING,POST,PROPFIND,PROPPATCH,PUT,OPTIONS",
		"Public":"CHMOD,DELETE,GET,HEAD,MKCOL,MKDIR,MOVE,"
		"MV,PING,POST,PROPFIND,PROPPATCH,PUT,OPTIONS",
		"Accept-Ranges":"bytes",
		"DAV":"1",
	      ]),
    ]);
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
  string property_name;
  static string|array(Parser.XML.Tree.Node) value;
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

  mapping(string:mixed) execute(string path, RoxenModule module, RequestID id)
  {
    return module->set_property(path, property_name, value, id);
  }
}

//! Implements PROPPATCH <DAV:remove/>.
class PatchPropertyRemoveCmd
{
  string property_name;
  static void create(string prop_name)
  {
    property_name = prop_name;
  }

  mapping(string:mixed) execute(string path, RoxenModule module, RequestID id)
  {
    return module->remove_property(path, property_name, id);
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
  if (!(<"PROPFIND", "PROPPATCH">)[id->method]) {
    TRACE_LEAVE("Not implemented.");
    return Roxen.http_low_answer(501, "Not implemented.");
  }
  int depth = ([ "0":0, "1":1, "infinity":0x7fffffff, 0:0x7fffffff ])
    [id->request_headers->depth &&
     String.trim_whites(id->request_headers->depth)];
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
  function(string,int,RoxenModule,MultiStatus,RequestID,mixed ...:void)
    recur_func;
  array(mixed) extras = ({});

  switch(id->method) {
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
	  recur_func = lambda(string path, int d, RoxenModule module,
			      MultiStatus stat, RequestID id) {
			 module->recurse_find_properties(path, "DAV:propname", d,
							 stat, id);
		       };
	  break;
	case "DAV:allprop":
	  if (recur_func)
	    return Roxen.http_low_answer(400, "Bad DAV request (23.3.2.1).");
	  recur_func = lambda(string path, int d, RoxenModule module,
			      MultiStatus stat, RequestID id,
			      multiset(string)|void filt) {
			 module->recurse_find_properties(path, "DAV:allprop", d,
							 stat, id, filt);
		       };
	  break;
	case "DAV:prop":
	  if (recur_func)
	    return Roxen.http_low_answer(400, "Bad DAV request (23.3.2.1).");
	  recur_func = lambda(string path, int d, RoxenModule module,
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
      recur_func = lambda(string path, int d, RoxenModule module,
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
    recur_func = lambda(string path, int d, RoxenModule module,
			MultiStatus stat, RequestID id,
			array(PatchPropertyCommand) instructions) {
		   module->recurse_patch_properties(path, d, instructions,
						    stat, id);
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
  MultiStatus result =
    MultiStatus()->prefix(sprintf("%s://%s%s%s",
				  id->port_obj->prot_name,
				  id->misc->host || id->port_obj->ip ||
				  gethostname(),
				  (id->port_obj->port == id->port_obj->port)?
				  "":(":"+(string)id->port_obj->port),
				  id->port_obj->path||""));
  string href = id->not_query;
  string href_prefix = combine_path(href, "./");
  foreach(conf->location_modules(), [string loc, function fun]) {
    int d = depth;
    string path;
    TRACE_ENTER(sprintf("Trying module mounted at %O...", loc),
		function_object(fun));
    if (has_prefix(href, loc)) {
      // href = loc + path.
      path = href[sizeof(loc)..];
    } else if (d && has_prefix(loc, href_prefix) &&
	       ((d -= sizeof(loc[sizeof(href_prefix)..]/"/")) >= 0)) {
      // loc = href_path + ...
      // && recursion.
      path = "";
    } else {
      TRACE_LEAVE("Miss");
      continue;
    }
#ifdef MODULE_LEVEL_SECURITY
    int|mapping security_ret;
    if(security_ret = conf->check_security(fun, id)) {
      if (mappingp(security_ret)) {
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
    recur_func(path, d, c, result->prefix(loc), id, @extras);
    TRACE_LEAVE("Done.");
    TRACE_LEAVE("Done.");
  }
  TRACE_LEAVE("DAV request done.");
  return result->http_answer();
}

