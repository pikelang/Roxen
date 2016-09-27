#include <module.h>
#include <config_interface.h>

inherit "module";

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y) _DEF_LOCALE("roxen_config",X,Y)

LocaleString module_name = LOCALE(0, "REST API");
LocaleString module_doc = LOCALE(0, #"
<p>This module provides a REST API for parts of the Administration Interface.
</p>

<p>The API is JSON based - i.e. responses are JSON encoded and PUT/POST data is expected to be JSON encoded too.</p>

<p>In general, the following request methods are available:
<ul>
<li>GET: Query the current value of a resource.</li>
<li>PUT: Update the current value of a resource.</li>
<li>POST: Add a resource.</li>
<li>DELETE: Remove a resource.</li>
</ul>
</p>

<p>The \"X-Roxen-API\" header must be set in all API requests. This requirement acts as a minimum counter-measure against CSRF attacks.</p>

<p>The resource specifier \"_all\" can be used to map an operation over all resources (see examples below).</p>

<p>Examples:
<ul>
<li><pre>GET /rest/variables/</pre> - list global variables</li>
<li><pre>GET /rest/configurations/</pre> - list configurations</li>
<li><pre>GET /rest/configurations/CMS/</pre> - get configuration \"CMS\" (currently not supported)</li>
<li><pre>GET /rest/configurations/CMS/?envelope=1</pre> - get configuration \"CMS\" in envelope. Provides a list of available subresources, such as \"modules\".
<li><pre>GET /rest/configurations/CMS/modules/</pre> - list enabled modules in the configuration \"CMS\".</li>
<li><pre>GET /rest/configurations/CMS/modules/</pre> - list enabled modules in the configuration \"CMS\".</li>
<li><pre>GET /rest/configurations/CMS/modules/yui/variables/mountpoint</pre> - get the value of the variable \"mountpoint\" in the \"yui\" module.</li>
<li><pre>PUT /rest/variables/abs_timeout</pre> - change the value of the \"abs_timeout\" global variable. The data body of the PUT request should be the JSON encoded value to set.</li>
<li><pre>POST /rest/configurations/CMS/modules/yui/</pre> - add an instance of the YUI module to the configuration \"CMS\".</li>
<li><pre>DELETE /rest/configurations/CMS/modules/yui!0/</pre> - remove instance #0 of the YUI module in the configuration \"CMS\".</li>
<li><pre>PUT /rest/configurations/CMS/modules/yui!0/actions/Reload</pre> - Reload the YUI module.</li>
<li><pre>PUT /rest/configurations/CMS/modules/insite_editor!0/actions/Clear Persistent Cache</pre> - call action button \"Clear Persistent Cache \" in the Insite Editor module.</li>
<li><pre>PUT /rest/configurations/_all/modules/insite_editor!0/actions/Clear Persistent Cache</pre> - call action button \"Clear Persistent Cache \" in the Insite Editor module in all configurations.</li>
<li><pre>GET /rest/configurations/_all/modules/_all/variables/mountpoint</pre> - get the value of the \"mountpoint\" variable in all modules across all configurations.
</ul>
</p>

<p>cURL example:
<pre>curl -H \"X-Roxen-API: 1\" -u admin:password https://localhost.roxen.com:22202/rest/variables/</pre>
</p>
");

constant module_type = MODULE_LOCATION;
constant resource_all = 1;
constant perm_name = "REST API";

protected void create()
{
  defvar("location", "/rest/", LOCALE(0,"Mountpoint"), TYPE_LOCATION,
          LOCALE(0, "Where the REST API is mounted."));
  roxen.add_permission (perm_name, LOCALE(0, "REST API"));
}

typedef object RESTObj;
typedef mixed RESTValue;

//! Base resource class. Inherit and override applicable methods.
class RESTResource
{
  array subresources = ({});
  protected mapping(string:RESTResource) sub_resource_map = ([]);

  protected array(string|int) list (RESTObj parent, RequestID id);
  protected RESTObj lookup_resource (string name, RESTObj parent, RequestID id);
  protected RESTObj post_resource (string name, RESTObj parent, RequestID id);
  protected void delete_resource (string name, RESTObj parent, RequestID id);
  protected RESTValue get_obj (RESTObj obj, RESTObj parent, RequestID id);
  protected RESTValue put_obj (RESTObj obj, RESTObj parent, RequestID id,
			       void|RESTValue value);

  protected mapping(string:mixed)|array(mixed)
  apply_resource (function func,
		  int|string resource,
		  RESTObj parent,
		  RequestID id,
		  int(0..1) tolerant)
  {
    string method = id->method;
    if (functionp (func)) {
      array(string) resource_list =
	resource == resource_all ? list (parent, id) : ({ resource });

      mapping(string:RESTObj|mapping) res = mkmapping (resource_list,
			map (resource_list,
			     lambda (string resource)
			     {
			       RESTObj res;
			       if (mixed err = catch {
				   res = func (resource, parent, id);
				 }) {
				 if (tolerant)
				   return ([ "apply_error":
					     describe_error (err) ]);
				 throw (err);
			       }

			       return res;
			     }));
      return filter (res,
		     lambda (RESTObj obj)
		     { return !mappingp (obj) || !obj->apply_error; });
    } else {
      error ("Method \"%s\" not available here.\n", method);
    }
  }

  mapping(string:mixed)|array(mapping(string:mixed))|mixed
  handle_resource (array(string) path, RequestID id, mixed client_data,
		   int(0..1) envelope, RESTObj parent,
		   void|int(0..1) tolerant)
  {
    if (!sizeof (path))
      return list (parent, id) + ({ "_all" });

    int|string resource = path[0];
    if (resource == "_all")
      resource = resource_all;

    mapping(string:RESTObj) objs;
    string method = id->method;

    if (method == "GET" || method == "PUT" || sizeof (path) > 1) {
      if (functionp (lookup_resource))
	objs = apply_resource (lookup_resource, resource, parent, id,
			       (tolerant || resource == resource_all));
      else
	error ("Method \"%s\" not available here.\n", method);
    }

    if (sizeof (path) > 1) {
      if (RESTResource r = sub_resource_map[path[1]]) {
	mapping(string:RESTObj) res =
	  map (objs,
	       lambda (RESTObj obj)
	       {
		 mixed res = r->handle_resource (path[2..], id, client_data,
						 envelope, obj,
						 (tolerant ||
						  resource == resource_all));
		 if (zero_type (res))
		   ([ "apply_error": "No such resource." ]);

		 return res;
	       });
	res = filter (res,
		      lambda (RESTObj obj)
		      { return !mappingp (obj) || !obj->apply_error; });

	if (resource == resource_all)
	  return res;

	if (sizeof (res))
	  return values(res)[0];

	return ([ "apply_error": "No such resource." ]);
      } else {
	error ("Resource \"%s\" not found.\n", path[1]);
      }
      error ("Never reached.\n");
    }

    if (method == "POST") {
      if (functionp (post_resource)) {
	objs = apply_resource (post_resource, resource, parent, id, tolerant);
      } else {
	error ("Method \"%s\" not available here.\n", method);
      }
    } else if (method == "DELETE") {
      if (functionp (delete_resource)) {
	objs = apply_resource (delete_resource, resource, parent, id, tolerant);
      } else {
	error ("Method \"%s\" not available here.\n", method);
      }
    }

    mapping(string:RESTValue) value_res;
    int got_value;
    int method_handled = 0;
    switch (method) {
    case "GET":
      if (functionp (get_obj)) {
	value_res = map (objs, get_obj, parent, id);
	got_value = 1;
      } else if (!envelope) {
	error ("Method \"%s\" not available here.\n", method);
      }
      break;
    case "POST":
      if (functionp (get_obj)) {
	value_res = map (objs, get_obj, parent, id);
	got_value = 1;
      }
      break;
    case "PUT":
      if (functionp (put_obj)) {
	value_res = map (objs, put_obj, parent, id, client_data);
	got_value = 1;
	method_handled = 1;
      } else {
	error ("Method \"%s\" not available here.\n", method);
      }
      break;
    }

    if (envelope) {
      mapping(string:mixed) res = ([]);
      if (method == "GET")
	res["subresources"] = indices (sub_resource_map);

      if (got_value)
	res["value"] = value_res;
      return res;
    }

    if (got_value) {
      if (resource == resource_all)
	return value_res;

      if (sizeof (value_res))
	return values(value_res)[0];
    }

    return ([ "apply_error": "No such resource." ]);
  }

  protected void create()
  {
    sub_resource_map = mkmapping (subresources->name, subresources);
  }
}

class RESTVariables
{
  inherit RESTResource;
  constant name = "variables";

  protected array(string) list (RESTObj parent, RequestID id)
  {
    return indices (parent->query());
  }

  protected RESTObj lookup_resource (string name, RESTObj parent, RequestID id)
  {
    Variable.Variable var = parent->getvar (name);
    if (!var)
      error ("No such variable \"%s\".\n", name);
    return var;
  }

  protected RESTValue get_obj (RESTObj obj, RESTObj parent, RequestID id)
  {
    mixed res = obj->query();
    if (objectp (res)) {
      // ModuleChoice. Return module identifier.
      Configuration conf = parent->my_configuration();
      return conf->otomod[res];
    }

    return res;
  }

  protected RESTValue put_obj (RESTObj obj, RESTObj parent, RequestID id,
			       RESTValue value)
  {
    string err;
    mixed mangled_value;
    [err, mangled_value] = obj->verify_set (value);
    if (err) {
      error (err);
    } else {
      if (obj->set (mangled_value))
	parent->save();
      return mangled_value;
    }
  }
}

class RESTModuleActions
{
  inherit RESTResource;
  constant name = "actions";

  protected array(string) list (RESTObj parent, RequestID id)
  {
    array(string) res = ({ "Reload" });

    if (parent->query_action_buttons) {
      mapping(string:function|array(function|string)) mod_buttons =
	parent->query_action_buttons(id);
      array(string) titles = indices(mod_buttons);
      if (sizeof(titles)) {
	res += Array.sort (titles);
      }
    }

    return res;
  }

  protected RESTObj lookup_resource (string name, RESTObj parent, RequestID id)
  {
    if (name == "Reload") {
      return lambda()
	     {
	       roxenloader.LowErrorContainer ec =
		 roxenloader.LowErrorContainer();
	       RoxenModule new_module;
	       Configuration conf = parent->my_configuration();
	       string mod_id = parent->module_local_id();
	       string mod_id_2 = replace (mod_id, "#", "!");

	       roxenloader.push_compile_error_handler (ec);
	       new_module = conf->reload_module(mod_id);
	       roxenloader.pop_compile_error_handler();

	       if (sizeof (ec->get())) {
		 report_debug (ec->get());
		 error (ec->get());
	       }
	     };
    } else if (function qab = parent->query_action_buttons) {
      mapping(string:function|array(function|string)) buttons =
	qab (id);
      foreach(indices(buttons), string title) {
	// Is this typecast really needed? The return value of
	// query_action_buttons is defined as mapping(string:...)
	// after all... (Code copied from site_content.pike.)
	if ((string)name == (string)title) {
	  function|array(function|string) action = buttons[title];
	  if (arrayp(action))
	    return action[0];

	  return action;
	}
      }
    }

    return 0;
  }

  protected RESTValue put_obj (RESTObj obj, RESTObj parent, RequestID id,
			       void|RESTValue value)
  {
    if (obj) {
      obj (id);
      return 1;
    }
    return 0;
  }
}

class RESTModules
{
  inherit RESTResource;
  constant name = "modules";
  array subresources = ({ RESTVariables(), RESTModuleActions() });

  protected string encode_mod_name (string s)
  {
    return replace (s, "#", "!");
  }

  protected string decode_mod_name (string s)
  {
    return replace (s, "!", "#");
  }

  protected array(string) list (RESTObj parent, RequestID id)
  {
    return map (indices (parent->enabled_modules), encode_mod_name);
  }

  protected RESTObj post_resource (string name, RESTObj parent, RequestID id)
  {
    string module_name = decode_mod_name (name);
    ModuleInfo mod_info = roxen.find_module (module_name, 1);

    if (!mod_info)
      error ("No such module %s.\n", module_name);

    return parent->enable_module (module_name, UNDEFINED, mod_info);
  }

  protected void delete_resource (string name, RESTObj parent, RequestID id)
  {
    string module_name = decode_mod_name (name);
    if (!parent->disable_module (module_name))
      error ("No such module %s.\n", module_name);
  }

  protected RESTObj lookup_resource (string name, RESTObj parent, RequestID id)
  {
    string module_name = decode_mod_name (name);
    RoxenModule module = parent->find_module (module_name);
    if (!module || module->not_a_module) {
      error ("No such module \"%s\".\n", name);
    }
    return module;
  }
}

class RESTConfigurations
{
  inherit RESTResource;
  constant name = "configurations";
  array subresources = ({ RESTModules() });

  protected array(string) list (RESTObj parent, RequestID id)
  {
    return roxen.configurations->name;
  }

  protected RESTObj lookup_resource (string name, RequestID id)
  {
    Configuration conf = roxen.get_configuration (name);
    if (!conf)
      error ("No such configuration \"%s\".\n", name);
    if (!conf->inited)
      conf->enable_all_modules();
    return conf;
  }
}

array top_level_resources = ({ RESTConfigurations(), RESTVariables() });
mapping(string:object) top_level_map = mkmapping (top_level_resources->name,
						  top_level_resources);

constant jsonflags = Standards.JSON.HUMAN_READABLE;

mapping(string:mixed) find_file (string f, RequestID id)
{
  if (!id->conf->authenticate (id, roxen.config_userdb_module)) {
    return id->conf->authenticate_throw (id, "Roxen Administration Interface",
                                         roxen.config_userdb_module);
  }

  if (!config_perm(perm_name)) {
    string errstr = "REST API access not allowed.";
    return
      Roxen.http_low_answer (Protocols.HTTP.HTTP_FORBIDDEN,
                             Standards.JSON.encode (([ "error": errstr ])));
  }

  if (!id->request_headers["x-roxen-api"]) {
    string errstr = "The \"X-Roxen-API\" header must be set in API requests.";
    return
      Roxen.http_low_answer (Protocols.HTTP.HTTP_FORBIDDEN,
                             Standards.JSON.encode (([ "error": errstr ])));

  }

  array(string) segments = f / "/";

  mixed json_res;
  int got_result;

  if (!sizeof (f)) {
    if (id->method == "GET") {
      json_res = indices (top_level_map);
      got_result = 1;
    } else {
      string errstr = "Method %s not available here.\n";
      return
	Roxen.http_low_answer (Protocols.HTTP.HTTP_METHOD_INVALID,
			       Standards.JSON.encode (([ "error": errstr ])));
    }
  } else {
    if (mixed err = catch {
	if (RESTResource r = top_level_map[segments[0]]) {
	  mixed client_data;
	  if ((id->method == "PUT" || id->method == "POST") &&
	      sizeof (id->data)) {
	    client_data = Standards.JSON.decode (id->data);
	  }
	  int envelope = id->variables["envelope"] == "1";
	  json_res = r->handle_resource (segments[1..] - ({ "" }), id,
					 client_data, envelope, roxen);
	  got_result = 1;
	}
      }) {
#if 0
      report_error (describe_backtrace (err));
#endif
      string errstr = describe_error (err);
      mapping(string:mixed) res =
	Roxen.http_low_answer (Protocols.HTTP.HTTP_BAD,
			       Standards.JSON.encode ((["error": errstr]),
						      jsonflags) + "\n");
      id->set_output_charset ("utf-8");
      res->type = "application/json";
      return res;
    }
  }

  if (got_result) {
    mapping(string:mixed) res =
      Roxen.http_low_answer (Protocols.HTTP.HTTP_OK,
			     Standards.JSON.encode (json_res, jsonflags) +
			     "\n");
    id->set_output_charset ("utf-8");
    res->type = "application/json";
    return res;
  }

  return Roxen.http_low_answer (Protocols.HTTP.HTTP_NOT_FOUND,
				Standards.JSON.encode (
				  (["error": "Resource not found."]),
				  jsonflags) + "\n");
}
