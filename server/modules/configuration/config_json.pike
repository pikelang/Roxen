#include <module.h>

inherit "module";

#define LOCALE(X,Y)	_DEF_LOCALE("roxen_config",X,Y)
LocaleString module_name = LOCALE (0, "REST API");
LocaleString module_doc = LOCALE (0, #"
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

<p>Examples:
<ul>
<li>GET /rest/variables/ - list global variables</li>
<li>GET /rest/configurations/ - list configurations</li>
<li>GET /rest/configurations/CMS/ - get configuration \"CMS\" (currently not supported)</li>
<li>GET /rest/configurations/CMS/?envelope=1 - get configuration \"CMS\" in envelope. Provides a list of available subresources, such as \"modules\".
<li>GET /rest/configurations/CMS/modules/ - list enabled modules in the configuration \"CMS\".</li>
<li>GET /rest/configurations/CMS/modules/ - list enabled modules in the configuration \"CMS\".</li>
<li>GET /rest/configurations/CMS/modules/yui/variables/mountpoint - get the value of the variable \"mountpoint\" in the \"yui\" module.</li>
<li>PUT /rest/variables/abs_timeout - change the value of the \"abs_timeout\" global variable. The data body of the PUT request should be the JSON encoded value to set.</li>
<li>POST /rest/configurations/CMS/modules/yui/ - add an instance of the YUI module to the configuration \"CMS\".</li>
<li>DELETE /rest/configurations/CMS/modules/yui!0/ - remove instance #0 of the YUI module in the configuration \"CMS\".</li>
<li>PUT /rest/configurations/CMS/modules/yui!0/actions/Reload - Reload the YUI module.</li>
<li>PUT /rest/configurations/CMS/modules/insite_editor!0/actions/Clear Persistent Cache - call action button \"Clear Persistent Cache \" in the Insite Editor module.</li>
</ul>
</p>
");

constant module_type = MODULE_LOCATION;

protected void create()
{
  defvar("location", "/rest/", LOCALE(0,"Mountpoint"), TYPE_LOCATION,
          LOCALE(0, "Where the REST API is mounted."));
}

//! Base resource class. Inherit and override applicable methods.
class RESTResource
{
  array subresources = ({});
  protected mapping(string:RESTResource) sub_resource_map = ([]);

  protected array(mixed) list (mixed parent, RequestID id);
  protected mixed lookup_obj (string name, mixed parent, RequestID id);
  protected mixed post_obj (string name, mixed value, mixed parent,
			    RequestID id);
  protected void delete_obj (string name, mixed parent, RequestID id);
  protected mixed get_obj (mixed obj, RequestID id);
  protected mixed put_obj (mixed obj, mixed value, mixed parent, RequestID id);

  mixed handle_resource (array(string) path, RequestID id, mixed client_data,
			 int(0..1) envelope, mixed parent)
  {
    if (!sizeof (path))
      return list (parent, id);

    string resource_name = path[0];
    mixed obj;
    string method = id->method;

    if (method == "GET" || method == "PUT" || sizeof (path) > 1) {
      if (functionp (lookup_obj)) {
	obj = lookup_obj (resource_name, parent, id);
	if (!obj)
	  error ("Resource \"%s\" not found.\n", resource_name);
      } else {
	error ("Method \"%s\" not available here.\n", method);
      }
    }

    if (sizeof (path) > 1) {
      if (RESTResource r = sub_resource_map[path[1]]) {
	return r->handle_resource (path[2..], id, client_data, envelope,
				   obj);
      } else {
	error ("Resource \"%s\" not found.\n", path[1]);
      }
      error ("Never reached.\n");
    }

    if (method == "POST") {
      if (functionp (post_obj)) {
	obj = post_obj (resource_name, client_data, parent, id);
      } else {
	error ("Method \"%s\" not available here.\n", method);
      }
    } else if (method == "DELETE") {
      if (functionp (delete_obj)) {
	delete_obj (resource_name, parent, id);
      } else {
	error ("Method \"%s\" not available here.\n", method);
      }
    }

    mixed value_res;
    int got_value;
    int method_handled = 0;
    switch (method) {
    case "GET":
      if (functionp (get_obj)) {
	value_res = get_obj (obj, id);
	got_value = 1;
      } else if (!envelope) {
	error ("Method \"%s\" not available here.\n", method);
      }
      break;
    case "POST":
      if (functionp (get_obj)) {
	value_res = get_obj (obj, id);
	got_value = 1;
      }
      break;
    case "PUT":
      if (functionp (put_obj)) {
	value_res = put_obj (obj, client_data, parent, id);
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

    return value_res;
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

  protected array(string|int) list (mixed parent, RequestID id)
  {
    return indices (parent->query());
  }

  protected mixed lookup_obj (string name, mixed parent, RequestID id)
  {
    Variable.Variable var = parent->getvar (name);
    if (!var)
      error ("No such variable \"%s\".\n", name);
    return var;
  }

  protected mixed get_obj (mixed obj, RequestID id)
  {
    return obj->query();
  }

  protected mixed put_obj (mixed obj, mixed value, mixed parent, RequestID id)
  {
    string err;
    mixed mangled_value;
    [err, mangled_value] = obj->verify_set (value);
    if (err) {
      error (err);
    } else {
      if (obj->low_set (mangled_value))
	parent->save();
      return mangled_value;
    }
  }
}

class RESTModuleActions
{
  inherit RESTResource;
  constant name = "actions";

  protected array(string) list (mixed parent, RequestID id)
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

  protected mixed lookup_obj (string name, mixed parent, RequestID id)
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

  protected mixed put_obj (mixed obj, mixed value, mixed parent, RequestID id)
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

  protected array(string) list (mixed parent, RequestID id)
  {
    return map (indices (parent->enabled_modules), encode_mod_name);
  }

  protected mixed post_obj (string name, mixed value, mixed parent,
			    RequestID id)
  {
    string module_name = decode_mod_name (name);
    ModuleInfo mod_info = roxen.find_module (module_name, 1);

    if (!mod_info)
      error ("No such module %s.\n", module_name);

    return parent->enable_module (module_name, UNDEFINED, mod_info);
  }

  protected void delete_obj (string name, mixed parent, RequestID id)
  {
    string module_name = decode_mod_name (name);
    if (!parent->disable_module (module_name))
      error ("No such module %s.\n", module_name);
  }

  protected mixed lookup_obj (string name, mixed parent, RequestID id)
  {
    string module_name = decode_mod_name (name);
    RoxenModule module = parent->find_module (module_name);
    if (!module)
      error ("No such module \"%s\".\n", name);
    return module;
  }
}

class RESTConfigurations
{
  inherit RESTResource;
  constant name = "configurations";
  array subresources = ({ RESTModules() });

  protected array(string) list (mixed parent, RequestID id)
  {
    return roxen.configurations->name;
  }

  protected mixed lookup_obj (string name, RequestID id)
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
  id->conf->authenticate (id, roxen.config_userdb_module);
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
