/*
 * $Id: webadm.pike,v 1.23 1998/08/27 20:29:55 wellhard Exp $
 *
 * AutoWeb administration interface
 *
 * Johan Schön, Marcus Wellhardh 1998-07-23
 */

constant cvs_version = "$Id: webadm.pike,v 1.23 1998/08/27 20:29:55 wellhard Exp $";

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
	     "",0,0 });
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
  array query_result = 
    db->query("select * from customers_schemes_vars,template_vars where "
	      "customers_schemes_vars.scheme_id='"+scheme_id+"' and "
	      "customers_schemes_vars.variable_id=template_vars.id and "
	      "template_vars.name='"+variable+"'");
  //werror("%O\n", query_result);
  if(!sizeof(query_result)) {
    werror("No such scheme '%s' or variable '%s' is undefined.\n",
	   scheme_id, variable);
    return 0;
  }
  return query_result[0]->value;
}

string tag_include(string tag, mapping args, string base)
{
  if(args->file) {
    args->file-= "../";
    string s = Stdio.read_bytes(base+args->file);
    if(s) return s;
    else werror("Can not open file "+base+args->file);
  }
  return "";
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
    db->query("select * from customers_schemes_vars,template_vars where "
	      "customers_schemes_vars.scheme_id='"+scheme_id+"' and "
	      "customers_schemes_vars.variable_id=template_vars.id");

  // Replace placeholders with customer spesific preferences  
  foreach(variables, mapping variable) {
    string from = "$$"+variable->name+"$$";
    string to = variable->value;
    if(variable->type == "font")
      to = replace(to, " ", "_");
    template = replace(template, from, to);
    //    werror("Replace from '"+from+"' to '"+to+"'\n");
  }

  // Insert files (eg navigation template)
  template=
    parse_html(template, ([ "include": tag_include ]), ([ ]), templatesdir);

  // Replace placeholders with customer spesific preferences  
  foreach(variables, mapping variable) {
    string from = "$$"+variable->name+"$$";
    string to = variable->value;
    if(variable->type == "font")
      to = replace(to, " ", "_");
    template = replace(template, from, to);
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

string container_as_color(string tag_name, mapping args, string contents,
			  object id)
{
  int r, g, b;
  array a;
  a = parse_color(contents);
  if(!a) {
    werror("'"+contents+"' is not a valid color.\n");
    return "";
  }
  r=a[0]; g=a[1]; b=a[2];
  if(args->diffrent) {
    if(((r+g+b)/3)>128) {
      r--; g--; b--;
      if(r<0) r=0;
      if(g<0) g=0;
      if(b<0) b=0;
    } else{
      r++; g++; b++;
      if(r>255) r=255;
      if(g>255) g=255;
      if(b>255) b=255;
    }
  }
  if(args->var) {
    id->variables[args->var]=sprintf("#%2x%2x%2x", r, g, b);
    return "";
  }
  return sprintf("#%2x%2x%2x", r, g, b);
}

mapping query_tag_callers()
{
  return ([ "autosite-webadm-update" : tag_update,
            "autosite-webadm-customername" : customer_name,
	    "autosite-webadm-update-template" : update_template,
	    "as-meta" : tag_as_meta
  ]);
}

mapping query_container_callers()
{
  return ([ "as-color" : container_as_color
  ]);
}

// Tablist

string make_tablist(array(object) tabs, object current, object id)
{
  string res_tabs = "";
  foreach(tabs, object tab)
  {
    mapping args = ([]);
    args->href = combine_path(query("location"), tab->tab)+"/";
    if(current==tab)
    {
      args->selected = "selected";
      args->href += "?_reset=";
    }
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
#if 1
  if(!validate_admin(id)&&!validate_customer(id))
    return (["type":"text/html",
	     "error":401,
	     "extra_heads":
	     ([ "WWW-Authenticate":
		"basic realm=\"AutoWeb Admin\""]),
	     "data":"<title>Access Denied</title>"
	     "<h2 align=center>Access forbidden</h2>\n"
    ]);
#else
  id->misc->customer_id = "1";
  id->variables->customer_id = "1";
#endif

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


