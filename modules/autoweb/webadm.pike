/*
 * $Id: webadm.pike,v 1.4 1998/07/26 21:37:45 wellhard Exp $
 *
 * AutoWeb administration interface
 *
 * Johan Schön, Marcus Wellhardh 1998-07-23
 */

constant cvs_version = "$Id: webadm.pike,v 1.4 1998/07/26 21:37:45 wellhard Exp $";

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


string update_template(string tag_name, mapping args, object id)
{
  object db = id->conf->call_provider("sql","sql_object",id);
  string templatesdir = combine_path(roxen->filename(this)+
				     "/", "../../../")+"templates/";
  string destfile = query("sites_location")+
		    (string)id->variables->customer_id+
		    "/templates/default.tmpl";
  array template_info =
    db->query("select * from "
	      "template_vars,customers_preferences,template_vars_opts where "
	      "customers_preferences.customer_id='"+
	      id->variables->customer_id+"' and " 
	      "template_vars.name='template_name' and "
	      "customers_preferences.variable_id=template_vars.id and "
	      "customers_preferences.value=template_vars_opts.name");
  if(!sizeof(template_info))
    return "<b>no such customer '"+id->variables->customer_id+"'</b>";
      
  string s = Stdio.read_bytes(templatesdir+template_info[0]->value);
  if(!sizeof(s))
    return "<b>Can not open file '"+
      templatesdir+template_info[0]->value+"', or it is empty</b>";
  
  array variables =
    db->query("select * from customers_preferences,template_vars where "
	      "customers_preferences.customer_id='"+
	      id->variables->customer_id+"' and "
	      "customers_preferences.variable_id=template_vars.id");
  
  foreach(variables, mapping variable) {
    s = replace(s, "$$"+variable->name+"$$", variable->value);
  }
  
  object template_file = Stdio.File();
  if(!template_file->open(destfile, "wct"))
    return "<b>Can not open file: '"+destfile+"'</b>";
  template_file->write(s);
  template_file->close();
  return "<b>Template updated</b>";
}


mapping query_tag_callers()
{
  return ([ "autosite-webadm-update" : tag_update,
            "autosite-webadm-customername" : customer_name,
	    "autosite-webadm-update-template" : update_template
  ]);
}


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


int validate_customer(object id)
{
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
    if(user == query("admin_user"))
      if(stringp(query("admin_pass")) && crypt(key, query("admin_pass"))) 
	return "admin";
  };
  return 0;
}


mixed find_file(string f, object id)
{
  string tab,sub;
  mixed content="";
  mapping state;
  
  int t1, t2, t3;
  
  // User validation
  if(!credentials)
    update_customer_cache(id);

  // User validation
#if 1
  if(!validate_customer(id)&&!validate_admin(id))
    return (["type":"text/html",
	     "error":401,
	     "extra_heads":
	     ([ "WWW-Authenticate":
		"basic realm=\"AutoWeb Admin\""]),
	     "data":"<title>Access Denied</title>"
	     "<h2 align=center>Access forbidden</h2>\n"
    ]);
#endif
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
  defvar("sites_location", "/webadm/", "Sites directory", TYPE_DIR,
	 "This is the physical location of the root directory for all"
         " the IP-less sites.");
  defvar("admin_user", "www", "Administrator login" ,TYPE_STRING,
 	 "This user name grants full access to all customers in"
	 "AutoWeb.");
  defvar("admin_pass", "www", "Administrator password" ,TYPE_PASSWORD,
	 "This password grants full access to all customers in"
	 "AutoWeb.");
}
