/*
 * $Id: webadm.pike,v 1.31 1998/09/29 16:20:56 wellhard Exp $
 *
 * AutoWeb administration interface
 *
 * Johan Schön, Marcus Wellhardh 1998-07-23
 */

constant cvs_version = "$Id: webadm.pike,v 1.31 1998/09/29 16:20:56 wellhard Exp $";

#include <module.h>
#include <roxen.h>

inherit "module";
inherit "roxenlib";
import .AutoWeb;

string tabsdir, templatesdir;
mapping tabs;
array tablist;

array register_module()
{
   return ({ MODULE_LOCATION|MODULE_PARSER, "AutoWeb Administration Interface",
	     "",0,1 });
}


mapping credentials;

void update_customer_cache(object id)
{
  object db = id->conf->call_provider("sql","sql_object",id);
  array a = db->query("select id,user_id,password from customers");
  mapping new_credentials = ([]);
  if(!catch {
    Array.map(a, lambda(mapping entry, mapping m)
		 {
		   m[entry->id]=({ entry->user_id, entry->password });
		 }, new_credentials);
  })
    credentials = new_credentials;
}


string tag_update(string tag_name, mapping args, object id)
{
  update_customer_cache(id);
  return "AutoWeb authorization data reloaded.";
}


string customer_name(string tag_name, mapping args, object id)
{
  object db = id->conf->call_provider("sql","sql_object",id);
  string query = ("select name from customers "
		  "where id='"+id->misc->customer_id+"'");
  array result = db->query(query);
  string customer_name = "Unknown";
  if(result&&sizeof(result))
    customer_name = result[0]->name;
  return
    cache_lookup("autoweb_customer_name",id->misc->customer_id)||
    cache_set("autoweb_customer_name",id->misc->customer_id,
	      customer_name);
}

string|int get_variable_value(object db, string scheme_id, string variable)
{
  // Function to get the value for a given scheme_id and a variable name.
  // Supports default values.
  array query_result = 
    db->query("SELECT cv.value AS value"
              "  FROM customers_schemes_vars cv, template_vars tv "
	      "  WHERE cv.scheme_id='"+scheme_id+"' "
	      "    AND cv.variable_name = tv.name "
	      "    AND tv.name = '"+variable+"'");
  
  if(sizeof(query_result)) 
    return query_result[0]->value;
  
  query_result =
    db->query("SELECT default_value AS value "
	      "  FROM template_vars "
	      "  WHERE name = '"+variable+"'");
  
  if(!sizeof(query_result)) {
    werror("Variable '%s' is undefined.\n", variable);
    return 0;
  }
  return query_result[0]->value;
}

string tag_include(string tag, mapping args, string base, mapping flags)
{
  args->file -= "../";
  if(sizeof(args->file)) {
    string s = Stdio.read_bytes(base+args->file);
    args -= (["file":1]);
    if(s) {
      flags->include = 1;
      foreach(indices(args), string var) {
	s = replace(s, "&"+var+";", args[var]);
      }
      return s;
    }
    else werror("Can not open file (include tag)"+base+args->file);
  }
  return "";
}

string mean_color(string c1, string c2)
{
  array a_c1 = parse_color(c1);
  array a_c2 = parse_color(c2);
  if(!a_c1||!a_c2)
    return c1;
  return sprintf("#%02x%02x%02x",
		 @((array)Image->colortable(0,0,0, a_c1, a_c2, 3))[1]);
}

string update_template(string tag_name, mapping args, object id)
{
  object db = id->conf->call_provider("sql","sql_object",id);
  string templatesdir = combine_path(roxen->filename(this)+
				     "/", "../../../")+"templates/";
  string destfile = query("searchpath")+
		    (string)id->variables->customer_id+
		    "/templates/default.tmpl";

  array scheme =
    db->query ("select * from customers where "
	       "id='"+id->variables->customer_id+"'");
  string scheme_id = 0;
  if(sizeof(scheme))
    scheme_id = scheme[0]->template_scheme_id;
  
  // Template
  string template_filename =
    get_variable_value(db, scheme_id, "template_name");
  if(!template_filename)
    return "";
  
  string template = Stdio.read_bytes(templatesdir+template_filename);
  if(!stringp(template)) {
    werror("Can not open file '%s'\n",
	   templatesdir+template_filename);
    return "";
  }
  
  // Fetch variables from database
  array variables =
    db->query("SELECT name "
	      "  FROM template_vars");
  
  mapping vars=([]);
  foreach(variables, mapping variable)
    vars[variable->name] = get_variable_value(db, scheme_id, variable->name);

  if(vars["bg_image"]&&sizeof(vars["bg_image"])) {
    vars["bg_image_color_2"] = vars["bg_color"];
    vars["bg_color"] = mean_color(vars->bg_color,
				  vars->bg_image_color);
  }

  if(vars["text_bg_image"]&&sizeof(vars["text_bg_image"])) {
    vars["text_bg_image_color_2"] = vars["text_bg_color"];
    vars["text_bg_color"] = mean_color(vars->text_bg_color,
				       vars->text_bg_image_color);
  }
  
  mapping flags = ([ "include":1 ]);
  while(flags->include) {
    // Replace placeholders with customer spesific preferences  
    foreach(indices(vars), string variable) {
      string from = "$$"+variable+"$$";
      string to = vars[variable];
      //      if(variable->type == "font")
      //	to = replace(to, " ", "_");
      template = replace(template, from, to);
    }
    // Insert files (eg navigation template)
    flags->include = 0;
    template =
      parse_html(template, ([ "include": tag_include ]), ([ ]),
		 templatesdir, flags);
  }
  
  // Save new template
  object template_file = Stdio.File();
  if(!template_file->open(destfile, "wct")) {
    werror("<b>Can not open file: '%s'", destfile);
    return "";
  }
  template_file->write(template);
  template_file->close();
  return "";
}

string tag_as_get_variable(string tag, mapping args, object id)
{
  // Tag to get the value for a given scheme_id and a variable name.
  // Supports default values.
  object db = id->conf->call_provider("sql","sql_object",id);
  if(args->scheme_id && args->variable) {
    string value;
    value = get_variable_value(db, args->scheme_id, args->variable);
    return value||"";
  } 
} 

string tag_as_meta(string tag_name, mapping args, object id)
{
  if(!args->var)
    return "";

  mapping md = MetaData(id, id->not_query)->get();
  if(!md)
    return "";

  string value = md[args->var];
  if(!value)
    return "";

  return value;
}

mapping query_tag_callers()
{
  return ([ "autosite-webadm-update" : tag_update,
            "autosite-webadm-customername" : customer_name,
	    "autosite-webadm-update-template" : update_template,
	    "as-meta" : tag_as_meta,
	    "as-get-variable" : tag_as_get_variable
  ]);
}

// Tablist

string make_tablist(array(object) tabs, object current, object id)
{
  string res_tabs = "";
  foreach(tabs, object tab) {
    mapping args = ([]);
    args->href = combine_path(query("location"), tab->tab)+"/";
    if(current==tab) {
      args->selected = "selected";
      args->href += "?_reset=";
    }
    if(tab->visible(id))
      res_tabs += make_container( "tab", args, replace(tab->title, "_"," "));
  }
  return "\n\n<!-- Tab list -->\n"+
    make_container("config_tablist", ([]), res_tabs)+"\n\n";
}

// Validation

int validate_customer(object id)
{
  // werror("Validating user customer: %O, %O\n",
  //	 id->misc->customer_id,
  //	 credentials[id->misc->customer_id]);
  catch {
    return equal(credentials[id->misc->customer_id],
		 ((id->realauth||"*:*")/":"));
  };
  return 0;
}


string validate_admin(object id)
{
  string user = ((id->realauth||"*:*")/":")[0];
  string key = ((id->realauth||"*:*")/":")[1];
  //  werror("Validating admin customer: %O, %O, %O, %O, %O\n",
  //	 id->misc->customer_id, user, key,
  //	 query("admin_user"), query("admin_pass"));
  catch {
    if((id->misc->customer_id) &&
       (user == query("admin_user")) &&
       (crypt(key, query("admin_pass"))))
      return "admin";
  };
  return 0;
}


mixed find_file(string f, object id)
{
  //werror("find_file: %O",id->variables);
  string tab,sub;
  mixed content="";
  mapping state;
  
  int t1, t2, t3;
  
  // User validation
  if(!credentials)
    update_customer_cache(id);

  id->misc->wa = this_object();
  id->misc->icons =
    .AutoWeb.Icons(combine_path(__FILE__+"/", "../img"),
		   "/webadmimg");
  // User validation
  if(!validate_admin(id)&&!validate_customer(id))
    return (["type":"text/html",
	     "error":401,
	     "extra_heads":
	     ([ "WWW-Authenticate":
		"basic realm=\"AutoWeb Admin\""]),
	     "data":"<title>Access Denied</title>"
	     "<h2 align=center>Access forbidden</h2>\n"
    ]);

  // State
  if (id->variables->_reset)
    id->misc->state = state = reset_state( id );
  else			      
    id->misc->state = state = state_for( id );   
  // no #($/!)!"#"#&! copy_value here.
  // ->state _has_ to be writable! /Wellhardh

  // Template
  if(sscanf(f, "templates/%s", string template)>0) {
    template -= "../";
    return http_string_answer(Stdio.read_bytes(templatesdir + template));
  }

  sscanf(f, "%s/%s", tab, sub);
  string tabnum = 0, tabname = "";
  if(tab) {
    sscanf(tab, "%d:%s", tabnum, tabname);
    id->variables->activetab = tabname;
  }
  string res = "<template base=/"+(query("location")-"/")+">\n";

  res += "<tablist>"+make_tablist(tablist, tabs[tab], id)+"</tablist>";
  if (!tabs[tab])
    content= "You've reached a non-existing tab '"
	     "<tt>"+tab+"</tt> somehow. Select another tab.\n";
  else
    content = tabs[tab]->show(sub, id, f);
  
  if(mappingp(content))
    return content;
  res += content+"\n</template>";
  
  return http_string_answer(parse_rxml(res, id)) |
    ([ "extra_heads":
       (["Expires": http_date( 0 ), "Last-Modified": http_date( time(1) ) ])
    ]);
}


void start(int q, object conf)
{
  templatesdir = combine_path(roxen->filename(this)+"/", "../")+"templates/";
  tabsdir = combine_path(roxen->filename(this)+"/", "../")+"tabs/";
  tabs = mkmapping(get_dir(tabsdir)-({".", "..", ".no_modules", "CVS"}),
		   Array.map(get_dir(tabsdir)-
			     ({".", "..", ".no_modules", "CVS"}),
			     lambda(string s, string d, string l) 
			     {
			       return .Tab.tab(d+s, s, this_object());
			     }, tabsdir, query("location")));
  tablist = values(tabs);
  sort(indices(tabs), tablist);
  
  if(conf)
    module_dependencies(conf,
			({ "configtablist",
			   "htmlparse" }));
}


void create()
{
  defvar("location", "/webadm/", "Mountpoint", TYPE_LOCATION);
  defvar("searchpath", "/home/autosite/", "Sites directory", TYPE_DIR,
	 "This is the physical location of the root directory for all"
         " the IP-less sites.");
  defvar("admin_user", "www", "Administrator login" ,TYPE_STRING,
 	 "This user name grants full access to all customers in"
	 "AutoWeb.");
  defvar("admin_pass", "www", "Administrator password" ,TYPE_PASSWORD,
	 "This password grants full access to all customers in"
	 "AutoWeb.");
  add_module_path(combine_path(__FILE__,"../"));
}

// State

mapping saved_state = ([ ]);

mapping init_state( string u )
{
  return saved_state[u] = ([ ]);
}

mapping reset_state( object id )
{
  string u;
  if(!(id->auth && id->auth[0])) u = id->remote_addr;
  else u = id->auth[1];
  
  if (!saved_state[u])
    return init_state( u );
  return init_state( u );
}

mapping state_for(object id)
{
  string u;
  if(!(id->auth && id->auth[0])) u = id->remote_addr;
  else u = id->auth[1];

  if(!saved_state[u])
    return init_state( u );
  return saved_state[u];
}


