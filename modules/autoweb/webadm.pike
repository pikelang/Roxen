/*
 * $Id: webadm.pike,v 1.14 1998/08/04 19:11:07 wellhard Exp $
 *
 * AutoWeb administration interface
 *
 * Johan Schön, Marcus Wellhardh 1998-07-23
 */

constant cvs_version = "$Id: webadm.pike,v 1.14 1998/08/04 19:11:07 wellhard Exp $";

#include <module.h>
#include <roxen.h>

inherit "module";
inherit "roxenlib";

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
  return "<sqloutput query="
    "\"select name from customers where id='"+id->misc->customer_id+"'\">"+
    "#name#<sqloutput>";
}


string insert_navigation(string tag, mapping args, string navigation)
{
  return navigation;
}


string|int get_variable_value(object db, string customer_id, string variable)
{
  array query_result = 
    db->query("select template_vars_opts.value from "
	      "template_vars,customers_preferences,template_vars_opts where "
	      "customers_preferences.customer_id='"+customer_id+"' and " 
	      "template_vars.name='"+variable+"' and "
	      "customers_preferences.variable_id=template_vars.id and "
	      "customers_preferences.value=template_vars_opts.name");
  //werror("%O\n", query_result);
  if(!sizeof(query_result)) {
    werror("No such customer '%s' or variable '%s' is undefined.\n",
	   customer_id, variable);
    return 0;
  }
  return query_result[0]->value;
}

string update_template(string tag_name, mapping args, object id)
{
  object db = id->conf->call_provider("sql","sql_object",id);
  string templatesdir = combine_path(roxen->filename(this)+
				     "/", "../../../")+"templates/";
  string destfile = query("searchpath")+
		    (string)id->variables->customer_id+
		    "/templates/default.tmpl";
  // Template
  string template_filename =
    get_variable_value(db, id->variables->customer_id, "template_name");
  if(!template_filename)
    return "";
  
  string template = Stdio.read_bytes(templatesdir+template_filename);
  if(!stringp(template)) {
    werror("Can not open file '%s', or it is empty\n",
	   templatesdir+template_filename);
    return "";
  }
  
  // Navigation
  string navigation_filename =
    get_variable_value(db, id->variables->customer_id, "nav_name");
  if(!navigation_filename)
    return "";
  
  string navigation = Stdio.read_bytes(templatesdir+navigation_filename);
  if(!stringp(navigation)) {
    werror("Can not open file '%s', or it is empty\n",
	   templatesdir+navigation_filename);
    return "";
  }
  // Insert navigation template
  template =
    parse_html(template, ([ "insertnavigation": insert_navigation ]), ([ ]),
	       navigation);

  // Fetch variables from database
  array variables =
    db->query("select * from customers_preferences,template_vars where "
	      "customers_preferences.customer_id='"+
	      id->variables->customer_id+"' and "
	      "customers_preferences.variable_id=template_vars.id");
  
  // Replace placeholders with customer spesific preferences  
  foreach(variables, mapping variable) {
    string from = "$$"+variable->name+"$$";
    string to = variable->value;
    if(variable->type == "select") {
      array options =
	db->query("Select * from template_vars_opts where "
		  "name='"+variable->value+"'");
      if(sizeof(options))
	to = options[0]->value;
    }
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
  return "<b>Template updated</b>";
}

string tag_as_meta(string tag_name, mapping args, object id)
{
  if(!args->var)
    return "";

  mapping md = get_md(id, id->not_query);
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
	    "as-meta" : tag_as_meta
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
  // werror("Validating customer: %O", id->misc->customer_id);
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
  catch {
    if((id->misc->customer_id) &&
       (user == query("admin_user")) &&
       (key == query("admin_pass")))
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

  id->misc->wa=this_object();

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
  string res = "<template base=/"+(query("location")-"/")+">\n"+
	       "<tmpl_body>";

  res += make_tablist(tablist, tabs[tab], id);
  if (!tabs[tab])
    content= "You've reached a non-existing tab '"
	     "<tt>"+tab+"</tt> somehow. Select another tab.\n";
  else
    content = tabs[tab]->show(sub, id, f);
  
  if(mappingp(content))
    return content;
  res += "<br>"+content+"</tmpl_body>\n</template>";
  
  return http_string_answer(parse_rxml(res, id)) |
    ([ "extra_heads":
       (["Expires": http_date( 0 ), "Last-Modified": http_date( time(1) ) ])
    ]);
}


void start(int q, object conf)
{
  init_content_types();
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


// Wizard functions

string real_path(object id, string filename)
{
  filename = replace(filename, "../", "");
  return query("searchpath")+id->misc->customer_id+
    (sizeof(filename)?(filename[0]=='/'?filename:"/"+filename):"/");
}

string read_file(object id, string f)
{
  return Stdio.read_bytes(real_path(id, f));
}

int save_file(object id, string f, string s)
{
  werror("Saving file '%s' in %s\n", f, real_path(id, f));
  object file = Stdio.File(real_path(id, f), "cwt");
  if(!objectp(file)) {
    werror("Can not save file %s", f);
    return 0;
  }
  file->write(s);
  file->close;
  return 1;
}


// Metadata functions

string container_md(string tag, mapping args, string contents, mapping md)
{
  if(args->variable)
    md[args->variable] = contents;
}

int save_md_file(object id, string f, mapping md)
{
  object file = Stdio.File(real_path(id, f+".md"), "cwt");
  if(!file)
    return 0;
  
  string s = "";
  foreach(sort(indices(md)), string variable)
    s += "<md variable=\""+variable+"\">"+md[variable]+"</md>\n";
  file->write(s);
  return 1;
}

mapping get_md(object id, string f)
{
  mapping md_default =  ([ "content_type":"autosite/unknown",
			   "title":"Unknown",
			   "template":"default.tmpl",
			   "keywords":"",
			   "description":""]);

  string file_name = real_path(id, f+".md");
  string s = Stdio.read_bytes(file_name);
  if(!s) {
    werror("File %s does not exist.\n", file_name);
    return md_default;
  }
  mapping md = ([]);
  parse_html(s, ([ ]), ([ "md":container_md ]), md);
  return ([ "content_type": md_default->content_type ]) + md;
}

// Content type functions

mapping content_types;
mapping name_to_type;

void init_content_types()
{
  mapping default_content_types =
  ([ "text/html" :
     ([ "name" : "HTML",
	"handler" : "html",
	"downloadp" : 1,
	"parsep" : 1,
	"extensions" : (< "html", "htm" >),
	"img" : "internal-gopher-text" ]),
     
     "text/plain" :
     ([ "name" : "Raw text",
	"handler" : "text",
	"downloadp" : 1,
	"extensions" : (< "txt" >),
	"img" : "internal-gopher-text" ]),
     
     "image/gif" :
     ([ "name" : "GIF Image",
	"handler" : "image",
	"downloadp" : 1,
	"extensions" : (< "gif" >),
	"img" : "internal-gopher-image" ]),
     
     "image/jpeg" :
     ([ "name" : "JPEG Image",
	"handler" : "image",
	"downloadp" : 1,
	"extensions" : (< "jpg", "jpeg" >),
	"img" : "internal-gopher-image" ]),
     
     "autosite/unknown" :
     ([ "name" : "Unknown",
	"handler" : "default",
	"downloadp" : 1,
	"extensions" : (< >),
	"img" : "internal-gopher-unknown" ]),
     
     "autosite/menu" :
     ([ "name" : "Menu",
	"handler" : "menu",
	"downloadp" : 0,
	"extensions" : (< "menu" >),
	"internalp" : 1,
	"img" : "internal-gopher-unknown" ]),
     
     "autosite/template" :
     ([ "name" : "Template",
	"handler" : "template",
	"downloadp" : 1,
	"extensions" : (< "tmpl" >),
	"internalp" : 1,
	"img" : "internal-gopher-unknown" ]),
     
  ]);
  
  content_types = default_content_types;
  name_to_type = ([ ]);
  foreach (indices( content_types ), string ct)
    name_to_type[ content_types[ ct ]->name ] = ct;
}

string get_content_type_from_extension( string filename )
{
  string extension = (filename / ".")[-1];

  foreach (indices( content_types ), string i)
    if (content_types[i]->extensions[ extension ])
      return i;
  if (sizeof( filename / "." ) >= 2)
  {
    extension = (filename / ".")[-2];
      
    foreach (indices( content_types ), string i)
      if (content_types[i]->extensions[ extension ])
	return i;
  }
  return "application/octet-stream";
}

string container_title(string tag, mapping args, string contents, mapping md)
{
  if(tag="title")
    md["title"] = contents;
}

mapping get_md_from_html(string f, string html)
{
  mapping md = ([]);
  md->content_type = get_content_type_from_extension(f);
  if(md->content_type == "text/html")
    parse_html(html, ([ ]), ([ "title":container_title ]), md);
  return md;
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


// Misc

string html_safe_encode(string s)
{
  return replace(s, ({ "<", ">" }), ({ "&lt;", "&gt;" }));
}
