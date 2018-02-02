// Protocol support for RFC 2518
//
// $Id$
//
// 2003-09-17 Henrik Grubbström

inherit "module";

#include <module.h>
#include <request_trace.h>

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_name = "WebDAV: Protocol support";
constant module_type = MODULE_FIRST;
constant module_doc  = "Adds support for various HTTP extensions defined "
  "in <a href='http://rfc.roxen.com/2518'>RFC 2518 (WEBDAV)</a>, such as "
  "<b>PROPFIND</b> and <b>PROPPATCH</b>.";

#ifdef DAV_DEBUG
#define DAV_WERROR(X...)	werror(X)
#else /* !DAV_DEBUG */
#define DAV_WERROR(X...)
#endif /* DAV_DEBUG */

// Stuff from base_server/configuration.pike:
#ifdef THREADS
#define LOCK(X) key=id->conf->_lock(X)
#define UNLOCK() do{key=0;}while(0)
#else
#define LOCK(X)
#define UNLOCK()
#endif


Configuration conf;

void create()
{
  defvar( "lock-timeout", 3600, "Default lock timeout", TYPE_INT,
	  "Number of seconds a WebDAV lock should by default be valid for. "
	  "Negative disables locking. Zero means that locks default to "
	  "being valid for infinite duration." );
  defvar( "max-lock-timeout", 86400, "Maximum lock timeout", TYPE_INT,
	  "Maximum number of seconds a WebDAV lock should be valid for. "
	  "Negative disables the timeout header. "
	  "Zero enables infinite locks. " );
}

void start(int q, Configuration c)
{
  conf = c;
}

mapping(string:mixed)|int(-1..0) first_try(RequestID id)
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
		"DAV":"1,2",
	      ]),
    ]);
  case "LOCK":
  case "UNLOCK":
  case "COPY":
  case "MOVE":
  case "DELETE":
  case "PROPFIND":
  case "PROPPATCH":
    // These need to be special cased, since they are recursive.
    return handle_webdav(id);
  }
  return 0;
}

protected constant SimpleNode = Parser.XML.Tree.SimpleNode;
protected constant SimpleRootNode = Parser.XML.Tree.SimpleRootNode;
protected constant SimpleHeaderNode = Parser.XML.Tree.SimpleHeaderNode;
protected constant SimpleElementNode = Parser.XML.Tree.SimpleElementNode;

//! Implements PROPPATCH <DAV:set/>.
class PatchPropertySetCmd
{
  constant command="DAV:set";
  string property_name;
  string|array(SimpleNode) value;
  protected void create(SimpleNode prop_node)
  {
    property_name = prop_node->get_full_name();
    value = prop_node->get_children();

    if ((sizeof(value) == 1) &&
	(value[0]->get_node_type() == Parser.XML.Tree.XML_TEXT)) {
      // Special case for a single text node.
      value = value[0]->get_text();
    }
  }

  mapping(string:mixed) execute(PropertySet context)
  {
#ifdef REQUEST_TRACE
    RequestID id = context->id;
    SIMPLE_TRACE_ENTER (0, "Setting property %O to %O", property_name, value);
#endif
    mapping(string:mixed) res = context->set_property(property_name, value);
#ifdef REQUEST_TRACE
    SIMPLE_TRACE_LEAVE (res ?
			sprintf ("Got status %d: %O", res->error, res->rettext) :
			"");
#endif
    return res;
  }
}

//! Implements PROPPATCH <DAV:remove/>.
class PatchPropertyRemoveCmd(string property_name)
{
  constant command="DAV:remove";

  mapping(string:mixed) execute(PropertySet context)
  {
#ifdef REQUEST_TRACE
    RequestID id = context->id;
    SIMPLE_TRACE_ENTER (0, "Removing property %O", property_name);
#endif
    mapping(string:mixed) res = context->remove_property(property_name);
#ifdef REQUEST_TRACE
    SIMPLE_TRACE_LEAVE (res ?
			sprintf ("Got status %d: %O", res->error, res->rettext) :
			"");
#endif
    return res;
  }
}

//! Handle WEBDAV requests.
mapping(string:mixed)|int(-1..0) handle_webdav(RequestID id)
{
  SimpleNode xml_data;
  SIMPLE_TRACE_ENTER(this, "Handle WEBDAV request %s...", id->method);
  if (catch { xml_data = id->get_xml_data(); }) {
    // RFC 2518 8:
    //   If a server receives ill-formed XML in a request it MUST reject
    //   the entire request with a 400 (Bad Request).
    TRACE_LEAVE("Malformed XML.");
    return Roxen.http_status(400, "Malformed XML data.");
  }
  if (!(< "LOCK", "UNLOCK", "COPY", "MOVE", "DELETE",
	  "PROPFIND", "PROPPATCH">)[id->method]) {
    TRACE_LEAVE("Not implemented.");
    return Roxen.http_status(501, "Not implemented.");
  }

  // RFC 2518 9.2:
  //   The Depth header is only supported if a method's definition
  //   explicitly provides for such support.
  int depth;
  if ((<"PROPFIND", "COPY", "MOVE", "DELETE", "LOCK">)[id->method]) {
    depth = ([ "0":0, "1":1, "infinity":0x7fffffff, 0:0x7fffffff ])
      [id->request_headers->depth &&
       String.trim_whites(id->request_headers->depth)];
    if (zero_type(depth)) {
      TRACE_LEAVE(sprintf("Bad depth header: %O.",
			  id->request_headers->depth));
      return Roxen.http_status(400, "Unsupported depth.");
    }
  } else if (id->request_headers->depth) {
    // Depth header not supported in this case.
  }

#ifdef URL_MODULES
  // Check URL modules (eg htaccess).
  // Ripped from base_server/configuration.pike.
  foreach(conf->url_modules(), function funp)
  {
    PROF_ENTER(Roxen.get_owning_module(funp)->module_name,"url module");
#ifdef THREADS
    Thread.MutexKey key;
#endif
    LOCK(funp);
    TRACE_ENTER("URL module", funp);
    mapping(string:mixed)|object tmp=funp( id, id->not_query );
    UNLOCK();
    PROF_LEAVE(Roxen.get_owning_module(funp)->module_name,"url module");

    if(mappingp(tmp))
    {
      TRACE_LEAVE("");
      TRACE_LEAVE("Returning data");
      return tmp;
    }
    if(objectp( tmp ))
    {
      mixed err;

      err = catch {
	  tmp = id->conf->low_get_file( tmp, 1 );
	};
      if(err) throw(err);
      TRACE_LEAVE("");
      TRACE_LEAVE("Returning data");
      return tmp;
    }
    TRACE_LEAVE("");
  }
#endif
  

  // Function to call for matching location modules.
  //
  // Arguments:
  //   string path
  //   int d
  //   RoxenModule module
  //   RequestID id
  //   mixed ... extras
  function(string,string,int,RoxenModule,RequestID,
	   mixed ...:mapping(string:mixed)) recur_func;
  array(mixed) extras = ({});

  mapping(string:mixed) empty_result;

  switch(id->method) {
  case "LOCK":
    DAVLock lock;
    if (!xml_data) {
      // Refresh.
      int/*LockFlag*/|DAVLock state =
	id->conf->check_locks(id->not_query, 0, id);
      if (intp(state)) {
	if (state) {
	  TRACE_LEAVE("LOCK: Refresh: locked by other user.");
	  return Roxen.http_status(423, "Locked by other user");
	} else {
	  TRACE_LEAVE("LOCK: Refresh: Lock not found.");
	  return Roxen.http_status(424, "Couldn't refresh missing lock.");
	}
      }
      id->conf->refresh_lock(lock = state);
    } else {
      // New lock.
      SimpleNode lock_info_node =
	xml_data->get_first_element("DAV:lockinfo", 1);
      if (!lock_info_node) {
	TRACE_LEAVE("LOCK: No DAV:lockinfo.");
	return Roxen.http_status(422, "Missing DAV:lockinfo.");
      }
      SimpleNode lock_scope_node =
	lock_info_node->get_first_element("DAV:lockscope", 1);
      if (!lock_scope_node) {
	TRACE_LEAVE("LOCK: No DAV:lockscope.");
	return Roxen.http_status(422, "Missing DAV:lockscope.");
      }
      string lockscope;
      if (lock_scope_node->get_first_element("DAV:exclusive", 1)) {
	lockscope = "DAV:exclusive";
      }
      if (lock_scope_node->get_first_element("DAV:shared", 1)) {
	if (lockscope) {
	  TRACE_LEAVE("LOCK: Both DAV:exclusive and DAV:shared.");
	  return Roxen.http_status(422, "Both DAV:exclusive and DAV:shared.");
	}
	lockscope = "DAV:shared";
      }
      if (!lockscope) {
	TRACE_LEAVE("LOCK: Both DAV:lockscope.");
	return Roxen.http_status(422, "Unsupported DAV:lockscope.");
      }
      SimpleNode lock_type_node =
	  lock_info_node->get_first_element("DAV:locktype", 1);
      if (!lock_type_node) {
	TRACE_LEAVE("LOCK: Both DAV:locktype.");
	return Roxen.http_status(422, "Missing DAV:locktype.");
      }
      if (!lock_type_node->get_first_element("DAV:write", 1)) {
	// We only support DAV:write locks.
	TRACE_LEAVE("LOCK: No DAV:write.");
	return Roxen.http_status(422, "Missing DAV:write.");
      }
      string locktype = "DAV:write";

      int expiry_delta = query("lock-timeout");	// Default timeout.
      if (expiry_delta < 0) {
	// Locks disabled.
	TRACE_LEAVE("LOCK: Locks disabled.");
	return Roxen.http_status(403, "Locking not allowed.");
      }
      if (id->request_headers->timeout) {
	// Parse the timeout header, and use the first valid timeout.
	foreach(MIME.tokenize(id->request_headers->timeout),
		string|int entry) {
	  if (intp(entry)) continue;	// ',' etc.
	  if (entry == "Infinite") {
	    if (!query("max-lock-timeout")) {
	      expiry_delta = 0;
	      break;
	    }
	  } else if (has_prefix(entry, "Second-")) {
	    int t;
	    if (sscanf(entry, "Second-%d", t) && (t > 0)) {
	      if (!query("max-lock-timeout") ||
		  (t < query("max-lock-timeout"))) {
		expiry_delta = t;
		break;
	      }
	    }
	  }
	}
      }

      array(SimpleNode) owner;
      if (SimpleNode owner_node = lock_info_node->get_first_element("DAV:owner", 1))
	owner = owner_node->get_children();

      // Parameters OK, try to create a lock.

      TRACE_ENTER(sprintf("LOCK: Creating a %s%s lock on %O.",
			  depth?"recursive ":"", lockscope, id->not_query),
		  this);
      mapping(string:mixed)|DAVLock new_lock =
	id->conf->lock_file(id->not_query,
			    depth != 0,
			    lockscope,
			    "DAV:write",
			    expiry_delta,
			    owner,
			    id);
      if (mappingp(new_lock)) {
	// Error
	// FIXME: Should probably generate a MultiStatus response.
	//        cf RFC 2518 8.10.10.
	TRACE_LEAVE("Failed.");
	TRACE_LEAVE("Returning failure code.");
	return new_lock;
      }
      TRACE_LEAVE("Ok.");
      lock = new_lock;
    }
    string xml = SimpleRootNode()->
      add_child(SimpleHeaderNode((["version":"1.0", "encoding":"utf-8"])))->
      add_child(SimpleElementNode("DAV:prop",
				  ([ "xmlns:DAV":"DAV:",
				     "xmlns:MS":
				     "urn:schemas-microsoft-com:datatypes"
				  ]))->
		add_child(SimpleElementNode("DAV:lockdiscovery", ([]))->
			  add_child(lock->get_xml())))->render_xml();
    TRACE_LEAVE("Returning XML.");
    return ([
      "error":200,
      "data":xml,
      "len":sizeof(xml),
      "type":"text/xml; charset=\"utf-8\"",
      "extra_heads":([ "Lock-Token":lock->locktoken ]),
    ]);
  case "UNLOCK":
    string locktoken;
    if (!(locktoken = id->request_headers["lock-token"])) {
      TRACE_LEAVE("UNLOCK: No lock-token.");
      return Roxen.http_status(400, "UNLOCK: Missing lock-token header.");
    }
    // The lock-token header is a Coded-URL.
    sscanf(locktoken, "<%s>", locktoken);
    if (!objectp(lock = id->conf->check_locks(id->not_query, 0, id))) {
      TRACE_LEAVE(sprintf("UNLOCK: Lock-token %O not found.", locktoken));
      return Roxen.http_status(403, "UNLOCK: Lock not found.");
    }
    if (lock->locktoken != locktoken) {
      SIMPLE_TRACE_LEAVE("UNLOCK: Locktoken mismatch: %O != %O.\n",
			 locktoken, lock->locktoken);
      return Roxen.http_status(423, "Invalid locktoken.");
    }
    mapping res = id->conf->unlock_file(id->not_query, lock, id);
    if (res) {
      TRACE_LEAVE(sprintf("UNLOCK: Unlocking of %O failed.", locktoken));
      return res;
    }
    TRACE_LEAVE(sprintf("UNLOCK: Unlocked %O successfully.", locktoken));
    return Roxen.http_status(204, "Ok.");

  case "COPY":
  case "MOVE":
    if (!id->request_headers->destination) {
      SIMPLE_TRACE_LEAVE("%s: No destination header.", id->method);
      return Roxen.http_status(400,
			       sprintf("%s: Missing destination header.",
				       id->method));
    }
    PropertyBehavior propertybehavior = (<>);	// default
    if (xml_data) {
      // Mapping from href to behavior.
      // @int
      //   @value -1
      //     omit
      //   @value 0
      //     default
      //     If default also check the entry for href @expr{0@} (zero).
      //   @value 1
      //     keepalive
      // @endint
      SimpleNode prop_behav_node =
	xml_data->get_first_element("DAV:propertybehavior", 1);
      if (!prop_behav_node) {
	SIMPLE_TRACE_LEAVE("%s: No DAV:propertybehavior.", id->method);
	return Roxen.http_status(400, "Missing DAV:propertybehavior.");
      }
      /* Valid children of <DAV:propertybehavior> are
       *   <DAV:keepalive>	(12.12.1)
       * or
       *   <DAV:omit>		(12.12.2)
       */
      foreach(prop_behav_node->get_children(), SimpleNode n) {
	switch(n->get_full_name()) {
	case "DAV:omit":
	  if (!multisetp(propertybehavior) || sizeof(propertybehavior)) {
	    return Roxen.http_status(400, "Conflicting DAV:propertybehavior.");
	  }
	  propertybehavior = 0;
	  break;
	case "DAV:keepalive":
	  if (!multisetp(propertybehavior) || sizeof(propertybehavior)) {
	    return Roxen.http_status(400, "Conflicting DAV:propertybehavior.");
	  }
	  foreach(n->get_children(), SimpleNode href) {
	    if (href->get_full_name == "DAV:href") {
	      if (!multisetp(propertybehavior)) {
		SIMPLE_TRACE_LEAVE("%s: Conflicting DAV:propertybehaviour.",
				   id->method);
		return Roxen.http_status(400,
					 "Conflicting DAV:propertybehavior.");
	      }
	      propertybehavior[href->value_of_node()] = 1;
	    } else if (href->mNodeType == Parser.XML.Tree.XML_TEXT) {
	      if (href->get_text() != "*"){
		SIMPLE_TRACE_LEAVE("%s: Syntax error in DAV:keepalive.",
				   id->method);
		return Roxen.http_status(400,
					 "Syntax error in DAV:keepalive.");
	      }
	      if (!multisetp(propertybehavior) || sizeof(propertybehavior)) {
		SIMPLE_TRACE_LEAVE("%s: Conflicting DAV:propertybehaviour.",
				   id->method);
		return Roxen.http_status(400,
					 "Conflicting DAV:propertybehavior.");
	      }
	      propertybehavior = 1;
	    }
	  }
	  break;
	}
      }
    }
    extras = ({ id->misc["new-uri"],
		propertybehavior,
		// RFC 2518 9.6: If the overwrite header is not
		// included in a COPY or MOVE request then the
		// resource [sic] MUST treat the request as if it has
		// an overwrite header of value "T".
		(!id->request_headers->overwrite ||
		 id->request_headers->overwrite=="T")?
		DO_OVERWRITE:NEVER_OVERWRITE,
    });

    recur_func = lambda(string source, string loc, int d, RoxenModule module,
			RequestID id, string destination,
			PropertyBehavior behavior,
			Overwrite overwrite) {
		   if (!has_prefix(destination, loc)) {
		     // FIXME: Destination in other filesystem.
		     return 0;
		   }
		   // Convert destination to module location relative.
		   destination = destination[sizeof(loc)..];
		   mapping(string:mixed) res =
		     ((id->method == "COPY")?
		      module->recurse_copy_files:
		      module->recurse_move_files)
		     (source, destination, behavior, overwrite, id);
		   if (res && ((res->error == 201) || (res->error == 204))) {
		     empty_result = res;
		     if (id->method == "MOVE") {
		       // RFC 4918 9.9:
		       // The MOVE operation on a non-collection resource is
		       // the logical equivalent of a copy (COPY), followed
		       // by consistency maintenance processing, followed by
		       // a delete of the source, where all three actions are
		       // performed in a single operation.

		       // The above seems to imply that RFC 4918 9.6 applies
		       // to MOVE. We thus need to destroy any locks rooted
		       // on the moved resource.
		       multiset(DAVLock) sub_locks =
			 module->find_locks(source, -1, 0, id);
		       foreach(sub_locks||(<>);DAVLock lock;) {
			 SIMPLE_TRACE_ENTER(module,
					    "MOVE: Unlocking %O...", lock);
			 mapping fail =
			   id->conf->unlock_file(lock->path, lock, id);
			 if (fail) {
			   TRACE_LEAVE("MOVE: Unlock failed.");
			 } else {
			   TRACE_LEAVE("MOVE: Unlock ok.");
			 }
		       }
		     }
		     return 0;
		   }
		   else if (!res && id->misc->error_code) {
		     empty_result = Roxen.http_status(id->misc->error_code);
		   }
		   return res;
		 };
    empty_result = Roxen.http_status(404);
    break;
  case "DELETE":
    recur_func = lambda(string path, string ignored, int d, RoxenModule module,
			RequestID id) {
		   mapping res = module->recurse_delete_files(path, id);
		   if (res && res->error < 300) {
		     // Succeed in deleting some file(s).
		     empty_result = res;

		     // RFC 4918 9.6:
		     // A server processing a successful DELETE request:
		     //
		     //    MUST destroy locks rooted on the deleted resource
		     multiset(DAVLock) sub_locks =
		       module->find_locks(path, -1, 0, id);
		     foreach(sub_locks||(<>);DAVLock lock;) {
		       SIMPLE_TRACE_ENTER(module,
					  "DELETE: Unlocking %O...", lock);
		       mapping fail =
			 id->conf->unlock_file(lock->path, lock, id);
		       if (fail) {
			 TRACE_LEAVE("DELETE: Unlock failed.");
		       } else {
			 TRACE_LEAVE("DELETE: Unlock ok.");
		       }
		     }
		     return 0;
		   }
		   return res;
		 };
    // The multi status will be empty if everything went well,
    // or if the file didn't exist.
    empty_result = Roxen.http_status(404);
    break;
  case "PROPFIND":	// Get meta data.
    if (xml_data) {
      SimpleNode propfind = xml_data->get_first_element("DAV:propfind", 1);
      if (!propfind) {
	TRACE_LEAVE("PROPFIND: No DAV:propfind.");
	return Roxen.http_status(400, "Missing DAV:propfind.");
      }
      /* Valid children of <DAV:propfind> are
       *   <DAV:propname />
       * or
       *   <DAV:allprop />
       * or
       *   <DAV:prop>{propertylist}*</DAV:prop>
       */
      foreach(propfind->get_children(), SimpleNode prop) {
	switch(prop->get_full_name()) {
	case "DAV:propname":
	  if (recur_func) {
	    TRACE_LEAVE("PROPFIND: Conflicting DAV:propfind.");
	    return Roxen.http_status(400, "Bad DAV request (23.3.2.1).");
	  }
	  recur_func = lambda(string path, string ignored, int d,
			      RoxenModule module, RequestID id) {
			 return module->recurse_find_properties(path,
								"DAV:propname",
								d, id);
		       };
	  break;
	case "DAV:allprop":
	  if (recur_func) {
	    TRACE_LEAVE("PROPFIND: Conflicting DAV:propfind.");
	    return Roxen.http_status(400, "Bad DAV request (23.3.2.1).");
	  }
	  recur_func = lambda(string path, string ignored, int d,
			      RoxenModule module, RequestID id,
			      multiset(string)|void filt) {
			 return module->recurse_find_properties(path,
								"DAV:allprop",
								d, id,
								filt);
		       };
	  break;
	case "DAV:prop":
	  if (recur_func) {
	    TRACE_LEAVE("PROPFIND: Conflicting DAV:propfind.");
	    return Roxen.http_status(400, "Bad DAV request (23.3.2.1).");
	  }
	  recur_func = lambda(string path, string ignored, int d,
			      RoxenModule module, RequestID id,
			      multiset(string) filt) {
			 return module->recurse_find_properties(path,
								"DAV:prop",
								d, id,
								filt);
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
			  RoxenModule module, RequestID id) {
		     return module->recurse_find_properties(path,
							    "DAV:allprop",
							    d, id);
		   };
    }
    break;
  case "PROPPATCH":	// Set/delete meta data.
    SimpleNode propupdate = xml_data->get_first_element("DAV:propertyupdate", 1);
    if (!propupdate) {
      TRACE_LEAVE("PROPPATCH: No DAV:propertyupdate.");
      return Roxen.http_status(400, "Missing DAV:propertyupdate.");
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
    foreach(propupdate->get_children(), SimpleNode cmd) {
      switch(cmd->get_full_name()) {
      case "DAV:set":
      case "DAV:remove":
	SimpleNode prop = cmd->get_first_element("DAV:prop", 1);
	if (!prop) {
	  TRACE_LEAVE("PROPPATCH: No DAV:prop.");
	  return Roxen.http_status(400, "Bad DAV request (no properties specified).");
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
      TRACE_LEAVE("PROPPATCH: No instructions.");
      return Roxen.http_status(400, "Bad DAV request (23.3.2.2).");
    }
    recur_func = lambda(string path, string ignored, int d, RoxenModule module,
			RequestID id,
			array(PatchPropertyCommand) instructions) {
		   // NOTE: RFC 2518 does not support depth header
		   //       with PROPPATCH, thus no recursion wrapper.
		   return module->patch_properties(path, instructions, id);
		 };
    extras = ({ instructions });
    break;
  default:
    break;
  }
  if (!recur_func) {
    TRACE_LEAVE("Bad DAV request.");
    return Roxen.http_status(400, "Bad DAV request (23.3.2.2).");
  }
  // FIXME: Security, DoS, etc...
  int start_ms_size = id->multi_status_size();
  string href = id->not_query;
  string href_prefix = combine_path(href, "./");
  RoxenModule opaque_module;
  foreach(conf->location_modules(), [string loc, function fun]) {
    int d = depth;
    string path;	// Module location relative path.
    SIMPLE_TRACE_ENTER(function_object(fun),
		       "Trying module mounted at %O...", loc);
    if (has_prefix(href, loc) || (loc == href+"/")) {
      // href = loc + path.
      path = href[sizeof(loc)..];
    } else if (d && has_prefix(loc, href_prefix) &&
	       ((d -= sizeof((loc[sizeof(href_prefix)..])/"/")) >= 0)) {
      // loc = href_prefix + ...
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
	// FIXME: What if we've already added some stuff in result?
	TRACE_LEAVE("Security check return.");
	TRACE_LEAVE("Need authentication.");
	recur_func = 0;		// Avoid garbage.
	return security_ret;
      } else {
	TRACE_LEAVE("Not allowed.");
	continue;
      }
    }
#endif
    RoxenModule c = function_object(fun);
    if (c->webdav_opaque) opaque_module = c;
    TRACE_ENTER("Performing the work...", c);
    ASSERT_IF_DEBUG (has_prefix (loc, "/"));
    mapping(string:mixed) ret = recur_func(path, loc, d, c, id, @extras);
    if (ret) {
      TRACE_LEAVE("Short circuit return.");
      TRACE_LEAVE("Done.");
      TRACE_LEAVE("DAV request done.");
      recur_func = 0;		// Avoid garbage.
      return ret;
    }
    TRACE_LEAVE("Done.");
    TRACE_LEAVE("Done.");
    if (opaque_module) break;
  }
  if (opaque_module)
    TRACE_LEAVE(sprintf("DAV request done (returned early after %O).",
			opaque_module));
  else
    TRACE_LEAVE("DAV request done.");

  recur_func = 0;		// Avoid garbage.
  if (id->multi_status_size() == start_ms_size) {
    return empty_result || Roxen.http_status(404);
  }
  return ([]);
}
