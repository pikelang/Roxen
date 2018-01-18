#include <module.h>
#include <config_interface.h>

inherit "module";

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y) _DEF_LOCALE("roxen_config",X,Y)

LocaleString module_name = LOCALE(1122, "REST API");
LocaleString module_doc = LOCALE(1123, #"
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

protected string encode_mod_name (string s)
{
  return replace (s, "#", "!");
}

protected string decode_mod_name (string s)
{
  return replace (s, "!", "#");
}

Configuration get_configuration(string name) {
  Configuration conf = roxen.get_configuration (name);
  if (conf && !conf->inited)
    conf->enable_all_modules();
  return conf;
}

string module_endpoint(RoxenModule mod) {
  return query("location") +
         "v2/configurations/" +
         Roxen.http_encode_url(mod->my_configuration()->name) +
         "/modules/" +
         encode_mod_name(mod->module_local_id());
}

mapping get_configuration_module_variable(mapping(string:string) params) {
  mapping res = ([ ]);

  if(params->variable && !params->configuration) {
    // global variable
    Variable.Variable var = roxen->getvar ( params->variable );
    if (!var) {
      res["error"] = RouterResponse(Protocols.HTTP.HTTP_NOT_FOUND,
                                    ([ "error": "Variable not found." ]) );
    } else {
      res["variable"] = var;
    }
    return res;
  }

  if(params->configuration) {
    object conf = get_configuration(params->configuration);
    if(!conf) {
      res["error"] = RouterResponse(Protocols.HTTP.HTTP_NOT_FOUND,
                                    ([ "error": "Configuration not found." ]) );
      return res;
    }
    res->configuration = conf;
    if(params->module) {
      // module variable
      string module_name = decode_mod_name (params->module);
      RoxenModule module = conf->find_module (module_name);
      if (!module || module->not_a_module) {
        res["error"] = RouterResponse(Protocols.HTTP.HTTP_NOT_FOUND,
                                      ([ "error": "Module not found." ]) );
        return res;
      }
      res->module = module;
      if(params->variable) {
        Variable.Variable var = module->getvar ( params->variable );
        if (!var) {
          res["error"] = RouterResponse(Protocols.HTTP.HTTP_NOT_FOUND,
                                        ([ "error": "Variable not found." ]) );
          return res;

        }
        res->variable = var;

      }
    } else {
      // configuration variable
      if(params->variable) {
        Variable.Variable var = conf->getvar ( params->variable );
        if (!var) {
          res["error"] = RouterResponse(Protocols.HTTP.HTTP_NOT_FOUND,
                                        ([ "error": "Variable not found." ]) );
          return res;

        }
        res->variable = var;

      }
    }
  }

  return res;
}

typedef function(string, mapping(string:string), mixed, RequestID : RouterResponse) RouterCallback;

class Route(PathMatcher matcher, RouterCallback callback) {}

class RouterResponse(int status_code, void|mixed data) {
  void|string location;

  string _sprintf() { return sprintf("RouterResponse(%O,%O)", status_code,data);}
}

class PathMatcher {
  // matches simple path patterns like /foo/:param1/bar/:param2
  // lot's of improvement potiential
  // see https://www.npmjs.com/package/path-to-regexp
  string pattern;
  Regexp.PCRE regexp;
  array regexp_params = ({ });

  mapping|void match(string path, RequestID id) {
    if(!regexp) {
      if( path == pattern || path == pattern + "/")
        return ([ ]);
    } else {
      if(array(string) parts = regexp->split(path)) {
        mapping(string:string) res = ([]);
        for (int i; i < sizeof(regexp_params); i++) {
          res[regexp_params[i]] = parts[i];
        }
        return res;
      }
    }
    return;
  }

  void create (string _pattern) {
   array pattern_parts = ((_pattern/"/") - ({ "" }));
   if(has_value(_pattern, ":")) {
     string re_string = "^";
     array new_parts = ({ });
     foreach(pattern_parts, string part) {
        if(has_prefix(part, ":")) {
          new_parts += ({ "([^/]+)" });
          regexp_params += ({ part[1..] });
        } else {
          new_parts += ({ part });
        }
     }
     re_string += new_parts * "/" + "/?$";
     regexp = Regexp.PCRE(re_string);
   } else {
     pattern = pattern_parts * "/";
   }
  }

}

class Router {
  mapping(string: array(Route) ) method_callbacks = ([
    "GET": ({}),
    "POST": ({}),
    "PUT": ({}),
    "PATCH": ({}),
    "DELETE": ({})
   ]);

  private void add_route(string method, PathMatcher matcher, RouterCallback callback) {
     method_callbacks[method] += ({ Route(matcher, callback) });
  }

#define MAKE_ROUTER_FUNCTION(NAME, METHOD)		\
  void NAME(string pattern, RouterCallback callback) {	\
    add_route(METHOD, PathMatcher(pattern), callback);	\
  }

  MAKE_ROUTER_FUNCTION(get, "GET")
  MAKE_ROUTER_FUNCTION(post, "POST")
  MAKE_ROUTER_FUNCTION(put, "PUT")
  MAKE_ROUTER_FUNCTION(patch, "PATCH")
  MAKE_ROUTER_FUNCTION(delete, "DELETE")

  void|RouterResponse handle_request(string path, RequestID id) {
    string method = id->method;
    string method_override = id->request_headers["x-http-method-override"];
    if(method == "POST" && (<"PUT","PATCH","DELETE">)[method_override])
      method = method_override;

    //FIXME: content-type: return HTTP_BAD etc
    mixed client_data;
    if ((<"PUT","PATCH","POST">)[method] && sizeof (id->data)) {
        client_data = Standards.JSON.decode (id->data);
    }

    foreach (method_callbacks[method] || ({ }), Route route ) {
       if(mapping res = route->matcher->match(path, id)) {
          return route->callback(method, res, client_data, id);
       }
    }

    return;
  }
}

Router router = Router();

mapping list_dbs() {
  mapping(string:mapping(string:int)) q = DBManager.get_permission_map();
  mapping dbs = ([ ]);

  foreach( sort(indices(q)), string db ) {
    if(db == "roxen" || db == "mysql")
      continue;
    string db_group = DBManager.db_group(db);
    string db_url = DBManager.db_url( db );
    dbs[db] = ([ "name":db, "group":db_group,"url":db_url, "permissions":q[db] ]);
  }

  return dbs;
}

mapping filter_db_data(mapping db) {
  mapping res = ([
          "group": db->group,
          "url": db->url || "",
          "permissions": map(db->permissions,
                             lambda(mixed perm) {
                               if(perm == DBManager.WRITE)
                                 return "write";
                               if(perm == DBManager.READ)
                                 return "read";
                               return "none";
                             })
          ]);
  return res;
}

mapping get_databases(string group) {
  mapping dbs = list_dbs();
  if(group != "_all") {
    dbs = filter(dbs, lambda(mapping db) { return db.group == group;});
  }
  return dbs;
}


RouterResponse handle_patch_database_permissions(string method, mapping(string:string) params, mixed data, RequestID id) {
  mapping dbs = get_databases(params->group);
  mapping db = dbs[params->database];

  if(!db)
    return RouterResponse(Protocols.HTTP.HTTP_NOT_FOUND);

  if(!mappingp(data))
    return RouterResponse(Protocols.HTTP.HTTP_BAD);

  array(array) todos = ({ });
  mapping perm_string_to_perm = ([ "none": DBManager.NONE,
                                   "write": DBManager.WRITE,
                                   "read": DBManager.READ
                                ]);


  foreach (data; string key; mixed value) {
    Configuration conf = roxen.find_configuration(key);
    if(!conf)
      return RouterResponse(Protocols.HTTP.HTTP_BAD, ([ "error":sprintf("Unknown configuration %O.", key) ]));
    if( !(<"none","read","write">)[value] )
      return RouterResponse(Protocols.HTTP.HTTP_BAD, ([ "error":sprintf("Unknown permission %O.", value) ]));
    todos += ({  ({ conf, perm_string_to_perm[value] }) });
  }


  foreach (todos, array todo) {
    // set_permission could fail if db is missing
    // but it's highly inlikely since we just checked
    DBManager.set_permission(params->database, todo[0],todo[1]);
  }

  return RouterResponse(Protocols.HTTP.HTTP_NO_CONTENT);
}

RouterResponse handle_patch_database(string method, mapping(string:string) params, mixed data, RequestID id) {
  if(!data || !mappingp(data))
    return RouterResponse(Protocols.HTTP.HTTP_BAD);

  mapping dbs = get_databases(params->group);
  mapping db;
  if(!(db = dbs[params->database]))
    return RouterResponse(Protocols.HTTP.HTTP_NOT_FOUND);

  mapping valid_data = ([ "url": stringp ]);

  foreach (data; string key; mixed value) {
    function validator = valid_data[key];
    if(!validator || !validator(value))
      return RouterResponse(Protocols.HTTP.HTTP_BAD, ([ "error": sprintf("Bad data %O\n",key) ]));
  }

  if(data->url) {
    if(db->url == "" && data->url != "") {
      return RouterResponse(Protocols.HTTP.HTTP_BAD, ([ "error": sprintf("Can't set url on internal db.\n") ]));
    }
    DBManager.set_url(params->database, data->url, 0);
  }
  //FIXME: patch "group" to move to groups

  //FIXME: how to handle atomicity for PATCH?

  return handle_get_database("GET", params, 0 , id);
}

RouterResponse handle_get_database(string method, mapping(string:string) params,mixed data, RequestID id) {
  mapping dbs = get_databases(params->group);
  mapping res = dbs[params->database];
  if(res)
    return RouterResponse(Protocols.HTTP.HTTP_OK, filter_db_data(res) );
  return RouterResponse(Protocols.HTTP.HTTP_NOT_FOUND);
}

RouterResponse handle_post_databases(string method, mapping(string:string) params, mixed data, RequestID id) {
  string url;
  string name;
  if(mappingp(data)) {
    if(data->name && stringp(data->name) && sizeof(data->name))
      name = data->name;
    if(data->url && stringp(data->url) && sizeof(data->url))
      url = data->url;
  }

  if(!name) {
   return RouterResponse(Protocols.HTTP.HTTP_BAD, ([ "error":"name missing."]) );
  }

  if(DBManager.get(name)) {
    return RouterResponse(Protocols.HTTP.HTTP_CONFLICT, ([ "error":"The database already exists"]));
  }

  DBManager.create_db( name,
                       url,
                       url ? 0 : 1,
                       params->group );

  RouterResponse get_resp = handle_get_database("GET", (["group":params->group, "database":name]),0,id);
  if(get_resp->status_code / 100 != 2) {
    // probably very unlikely to happen
    return RouterResponse(Protocols.HTTP.HTTP_NOT_FOUND);
  }
  RouterResponse res = RouterResponse(Protocols.HTTP.HTTP_CREATED, get_resp->data );
  res->location = query("location") +
                  "v2/databasegroups/" +
                  Roxen.http_encode_url(params->group) +
                  "/databases/" +
                  Roxen.http_encode_url(name);
  return res;
}

RouterResponse handle_get_databases(string method, mapping(string:string) params,mixed data, RequestID id) {
  mapping res = get_databases(params->group);
  res = map(res, filter_db_data);
  return RouterResponse(Protocols.HTTP.HTTP_OK, res );
}

RouterResponse handle_post_databasegroups(string method, mapping(string:string) params, mixed data, RequestID id) {
  string name;
  string comment;
  string long_name;
  if(mappingp(data)) {
    if(data->name && stringp(data->name) && sizeof(data->name))
      name = data->name;
    if(data->comment && stringp(data->comment) && sizeof(data->comment))
      comment = data->comment;
    if(data->long_name && stringp(data->long_name) && sizeof(data->long_name))
      long_name = data->long_name;
  }

  if(!name) {
   return RouterResponse(Protocols.HTTP.HTTP_BAD, ([ "error":"name missing."]) );
  }

  if(DBManager.get_group( name ))
    return RouterResponse(Protocols.HTTP.HTTP_CONFLICT, (["error":"Group already exists."]) );

  // create group has int declared as return typ, but returns void
  // also updates definition if the group already exists :/
  DBManager.create_group( name, long_name || name, comment || "", "");

  RouterResponse get_resp = handle_get_databasegroup("GET", (["group":name]),0,id);
  if(get_resp->status_code / 100 != 2) {
     // probably very unlikely to happen
     return RouterResponse(Protocols.HTTP.HTTP_NOT_FOUND);
  }
  RouterResponse res = RouterResponse(Protocols.HTTP.HTTP_CREATED, get_resp->data );
  res->location = query("location") +
                  "v2/databasegroups/" +
                  Roxen.http_encode_url(name);
  return res;
}



RouterResponse handle_get_databasegroup(string method, mapping(string:string) params, mixed data, RequestID id) {
  mapping result_data = ([ ]);
  if(params->group != "_all") {
    mapping group_data = DBManager.get_group( params->group );
    if(!group_data)
      return RouterResponse(Protocols.HTTP.HTTP_NOT_FOUND);
    result_data->long_name = group_data->lname;
    result_data->comment = group_data->comment;
  }
  mapping dbs = get_databases(params->group);
  result_data->databases = map(dbs, filter_db_data);
  return RouterResponse(Protocols.HTTP.HTTP_OK, result_data );
}

RouterResponse handle_get_databasegroups(string method, mapping(string:string) params,mixed data, RequestID id) {
  return RouterResponse(Protocols.HTTP.HTTP_OK, DBManager.list_groups() + ({ "_all" }) );
}

mixed get_variable_value(Variable.Variable variable, Configuration configuration) {
  mixed res = variable->query();
  if (objectp (res)) {
    // ModuleChoice. Return module identifier.
    res = configuration->otomod[res];
  }
  return res;
}

RouterResponse handle_get_variable(string method, mapping(string:string) params,mixed data, RequestID id) {
  mapping stuff = get_configuration_module_variable(params);
  if(stuff->error)
    return stuff->error;
  mixed res = get_variable_value(stuff->variable, stuff->configuration);
  return RouterResponse(Protocols.HTTP.HTTP_OK, res );
}

RouterResponse handle_put_variable(string method, mapping(string:string) params,mixed data, RequestID id) {
  mapping stuff = get_configuration_module_variable(params);
  if(stuff->error)
    return stuff->error;
  string err;
  mixed mangled_value;
  [err, mangled_value] = stuff->variable->verify_set (data);
  if (err) {
    return RouterResponse(Protocols.HTTP.HTTP_BAD, ([ "error": err ]) );
  }

  if (stuff->variable->set (mangled_value))
    (stuff->module || stuff->configuration || roxen)->save();
  return RouterResponse(Protocols.HTTP.HTTP_OK, mangled_value );
}

RouterResponse handle_put_action(string method, mapping(string:string) params, mixed data, RequestID id) {
  mapping stuff = get_configuration_module_variable(params);
  if(stuff->error)
    return stuff->error;

  if (params->action == "Reload") {
    roxenloader.LowErrorContainer ec = roxenloader.LowErrorContainer();
    RoxenModule new_module;
    Configuration conf = stuff->module->my_configuration();
    string mod_id = stuff->module->module_local_id();
    string mod_id_2 = replace (mod_id, "#", "!");

    roxenloader.push_compile_error_handler (ec);
    new_module = conf->reload_module(mod_id);
    roxenloader.pop_compile_error_handler();

    if (sizeof (ec->get())) {
      report_debug (ec->get());
      return RouterResponse(Protocols.HTTP.HTTP_INTERNAL_ERR, (["error": ec->get()]) );
    }
    return RouterResponse(Protocols.HTTP.HTTP_NO_CONTENT);
 } else if (function qab = stuff->module->query_action_buttons) {
    mapping(string:function|array(function|string)) buttons = qab (id);
    function action;
    foreach(indices(buttons), string title) {
      // Is this typecast really needed? The return value of
      // query_action_buttons is defined as mapping(string:...)
      // after all... (Code copied from site_content.pike.)
      if (params->action == (string)title) {
        function|array(function|string) _action = buttons[title];
        if (arrayp(_action))
          action = _action[0];
        else
          action = _action;
        break;
      }
    }
    if(action) {
      action();
      return RouterResponse(Protocols.HTTP.HTTP_NO_CONTENT);
    }
  }

 return RouterResponse(Protocols.HTTP.HTTP_NOT_FOUND, ([ "error":"No such action.\n" ]) );
}

protected void create()
{
  defvar("location", "/rest/", LOCALE(264,"Mountpoint"), TYPE_LOCATION,
          LOCALE(1124, "Where the REST API is mounted."));
  roxen.add_permission (perm_name, LOCALE(1122, "REST API"));


  router->patch("v2/databasegroups/:group/databases/:database/permissions", handle_patch_database_permissions);
  router->get("v2/databasegroups/:group/databases/:database/permissions", lambda(string method,  mapping(string:string) params,mixed data, RequestID id) {
     RouterResponse res = handle_get_database("GET",params,data,id);
     if(res->status_code == Protocols.HTTP.HTTP_OK) {
       return RouterResponse(Protocols.HTTP.HTTP_OK, res->data->permissions);
     }
     return res;
  });
  router->patch("v2/databasegroups/:group/databases/:database", handle_patch_database);
  router->delete("v2/databasegroups/:group/databases/:database", lambda(string method,  mapping(string:string) params,mixed data, RequestID id) {
    //FIXME: should we also check if the user is adressing the correct group here?
    if(!DBManager.get(params->database))
      return RouterResponse(Protocols.HTTP.HTTP_NOT_FOUND);
    DBManager.drop_db(params->database);
    return RouterResponse(Protocols.HTTP.HTTP_NO_CONTENT);
  });
  router->get("v2/databasegroups/:group/databases/:database", handle_get_database);
  router->get("v2/databasegroups/:group/databases", handle_get_databases);

  router->post("v2/databasegroups/:group/databases/", handle_post_databases);

  //FIXME
  //router->patch("v2/databasegroups/:group", handle_patch_databasegroup);
  router->delete("v2/databasegroups/:group", lambda(string method, mapping(string:string) params,mixed data, RequestID id) {
    if(!DBManager.get_group( params->group ))
      return RouterResponse(Protocols.HTTP.HTTP_NOT_FOUND);

   if( !DBManager.delete_group( params->group )) // probably fails because it has databases
     return RouterResponse(Protocols.HTTP.HTTP_CONFLICT);

   return RouterResponse(Protocols.HTTP.HTTP_NO_CONTENT);
  });
  router->get("v2/databasegroups/:group", handle_get_databasegroup);

  router->post("v2/databasegroups", handle_post_databasegroups);
  router->get("v2/databasegroups", handle_get_databasegroups);

  router->get("v2/configurations/:configuration/modules/:module/actions",lambda(string method,  mapping(string:string) params,mixed data, RequestID id) {
    mapping stuff = get_configuration_module_variable(params);
    if(stuff->error)
      return stuff->error;
    mapping(string:function|array(function|string)) mod_buttons =
       stuff->module->query_action_buttons && stuff->module->query_action_buttons(id) || ({ });
    return RouterResponse(Protocols.HTTP.HTTP_OK,  ({ "Reload" }) + sort(indices(mod_buttons)) );
  });

  router->put("v2/configurations/:configuration/modules/:module/actions/:action", handle_put_action);

  router->put("v2/configurations/:configuration/modules/:module/variables/:variable", handle_put_variable);
  router->get("v2/configurations/:configuration/modules/:module/variables/:variable", handle_get_variable);

  router->get("v2/configurations/:configuration/modules/:module/variables",
	      lambda(string method, mapping(string:string) params,
		     mixed ignored_data, RequestID ignored_id) {
    mapping stuff = get_configuration_module_variable(params);
    if(stuff->error)
      return stuff->error;
    return RouterResponse(Protocols.HTTP.HTTP_OK,
                          map(stuff->module->query(),get_variable_value, stuff->configuration) );
  });

  router->post("v2/configurations/:configuration/modules/:new_module",
	       lambda(string method, mapping(string:string) params,
		      mixed ignored_data, RequestID ignored_id) {
    mapping stuff = get_configuration_module_variable(params);
    if(stuff->error)
      return stuff->error;
    string module_name = decode_mod_name (params->new_module);
    ModuleInfo mod_info = roxen.find_module (module_name, 1);
    RoxenModule mod;
    if (!mod_info || !(mod = stuff->configuration->enable_module (module_name, UNDEFINED, mod_info))) {
       //FIXME: other return code?
      return RouterResponse(Protocols.HTTP.HTTP_BAD, ([ "error":sprintf("No such module %s.\n", module_name)]) );
    }
    RouterResponse res = RouterResponse(Protocols.HTTP.HTTP_OK );
    res->location = module_endpoint( mod );
    //FIXME: add module data to response
    return res;
  });

  router->delete("v2/configurations/:configuration/modules/:module",
		 lambda(string method, mapping(string:string) params,
			mixed ignored_data, RequestID ignored_id) {
    mapping stuff = get_configuration_module_variable(params);
    if(stuff->error)
      return stuff->error;
    if (!stuff->configuration->disable_module(decode_mod_name(params->module))) {
      return RouterResponse(Protocols.HTTP.HTTP_NOT_FOUND, ([ "error":"No such module.\n" ]) );
    }
    RouterResponse res = RouterResponse(Protocols.HTTP.HTTP_NO_CONTENT );
    return res;
  });

  router->put("v2/configurations/:configuration/variables/:variable", handle_put_variable);
  router->get("v2/configurations/:configuration/variables/:variable", handle_get_variable);

  router->get("v2/configurations/:configuration/variables",
	      lambda(string method, mapping(string:string) params,
		     mixed ignored_data, RequestID ignored_id) {
    mapping stuff = get_configuration_module_variable(params);
    if(stuff->error)
      return stuff->error;
    return RouterResponse(Protocols.HTTP.HTTP_OK,
                          map(stuff->configuration->query(),get_variable_value, stuff->configuration) );
  });

  router->get("v2/configurations/:configuration/modules",
	      lambda(string method, mapping(string:string) params,
		     mixed ignored_data, RequestID ignored_id) {
    mapping stuff = get_configuration_module_variable(params);
    if(stuff->error)
      return stuff->error;
    array mods = map (indices (stuff->configuration->enabled_modules), encode_mod_name);
    return RouterResponse(Protocols.HTTP.HTTP_OK, sort(mods) );
  });

  router->get("v2/configurations",lambda() {
    return RouterResponse(Protocols.HTTP.HTTP_OK, sort(roxen.configurations->name) );
  });

  router->put("v2/variables/:variable", handle_put_variable);
  router->get("v2/variables/:variable", handle_get_variable);

  router->get("v2/variables",lambda() {
    return RouterResponse(Protocols.HTTP.HTTP_OK,
                          map(roxen->query(),get_variable_value) );

  });

  router->get("v2",lambda() {
    return RouterResponse(Protocols.HTTP.HTTP_OK,({ "variables", "configurations", "databasegroups" }));
  });
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

  if (mixed err = catch {
    if(void|RouterResponse router_response = router->handle_request(f, id)) {
      mapping(string:mixed) res =
        Roxen.http_low_answer (router_response->status_code, router_response->data ?
                         Standards.JSON.encode (router_response->data, jsonflags) + "\n" : "");
      id->set_output_charset ("utf-8");
      res->type = "application/json";
      if(router_response->location)
        id->set_response_header ("Location",  (string)Standards.URI(router_response->location, id->url_base()));
      return res;
    }
  }) {
    string errstr = describe_error (err);
#ifdef MODULE_DEBUG
    report_error (describe_backtrace (err));
#endif
    mapping(string:mixed) res =
      Roxen.http_low_answer (Protocols.HTTP.HTTP_BAD,
                             Standards.JSON.encode ((["error": errstr]), jsonflags) + "\n");
    id->set_output_charset ("utf-8");
    res->type = "application/json";
    return res;
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
