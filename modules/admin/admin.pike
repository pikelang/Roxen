/*
 * $Id: admin.pike,v 1.2 1998/07/13 07:08:28 js Exp $
 *
 * AutoAdmin, administration interface
 *
 * Johan Schön 1998-07-08
 */

constant cvs_version = "$Id: admin.pike,v 1.2 1998/07/13 07:08:28 js Exp $";

#include <module.h>
#include <roxen.h>

inherit "module";
inherit "roxenlib";

#define BODY  "<body bgcolor="+colorscheme->bgcolor+\
	      " text="+colorscheme->text+\
	      " link="+colorscheme->link+\
	      " vlink="+colorscheme->vlink+\
	      " alink="+colorscheme->alink+">"

mapping colorscheme= (["bgcolor":"white", "text":"black",
		       "link":"darkblue", "vlink":"darkblue",
		       "alink":"lightgreen",
		       "topbgcolor":"#dddddd", "toptext":"black"]);

string tabsdir,imgsdir,handlerdir,actionsdir;
mapping tabs,actions;
array tablist,actionlist;

string make_tablist(array(object) tabs, object current, string customer, object id)
{
  string res_tabs="";
  foreach(tabs, object tab)
  {
    mapping args = ([]);
    args->bgcolor=colorscheme->bgcolor;
    args->href = combine_path(query("location"),customer,tab->tab)+"/";
    if(current==tab)
    {
      args->selected = "selected";
      args->href += "?_reset=";
    }
    res_tabs += make_container( "tab", args, replace(tab->title,"_"," "));
  }
  return "\n\n<!-- Tab list -->\n"+
    make_container("config_tablist",([]), res_tabs)+"\n\n";
}

string status_row(string tab, object id)
{
   return
     "<table cellpadding=0 cellspacing=0 border=0 width='100%'>"
     "<tr><td valign=bottom align=left>"
     "<a href=http://www.roxen.com/>"
     "<img border=0 alt=\"Roxen\" src=/internal-roxen-roxen-icon-gray></a>"
     "</td><td>&nbsp;</td><td width='100%' height=39>"
     "<table cellpadding=0 cellspacing=0 width='100%' border=0>"
     "<tr width='100%'><td width=100% align=right valigh=center height=28>"
     "<b><font size=+1>AutoSite Administration Interface</font></b>"
     "</td></tr><tr width='100%'>"
     "<td bgcolor='#003366' align=right height=12 width='100%'>"
     "<font color=white size=-2>Roxen AutoSite&nbsp;&nbsp;</td>"
     "</tr></table></td>"
     "</tr></table><br>\n";
}


string validate_user(object id)
{
  string user = ((id->realauth||"*:*")/":")[0];
  string key = ((id->realauth||"*:*")/":")[1];
  catch {
    if(user == query("admin"))
      if(stringp(query("adminpass")) && crypt(key, query("adminpass"))) 
	return "admin";
  };
  return 0;
}


mixed find_file(string f, object id)
{
  string res = "";
  string customer="0",tab,sub;
  mixed content="";
  mapping state;

  int t1,t2,t3;

  // User validation
  string user = validate_user(id);
  if(!user)
    return (["type":"text/html",
		   "error":401,
		   "extra_heads":
		     ([ "WWW-Authenticate":
		        "basic realm=\"AutoSite Admin\""]),
		   "data":"<title>Access Denied</title>"
		   "<h2 align=center>Access forbidden</h2>"
    ]);
  
 sscanf(f, "%s/%s/%s", customer, tab, sub);
 id->variables->customer=customer;
 res =
   "<title>AutoSite Administration Interface</title>"+BODY+status_row(tab,id)+
   make_tablist(actionlist,actions[tab],customer,id)+
   "<sqloutput query=\"select name from customers where id='"+
   (int)customer+"'\"><b>Customer: #name#</b></sqloutput>";

 if(actions[tab])
   content = actions[tab]->show(sub,id,f);
 else
   if((int)customer)
   {
     if(!tab)
       tab=tablist[0]->tab,sub="";
     content = tabs[tab]->show(sub,id,f);
     res+="<hr noshade size=2><p>"+make_tablist(tablist,tabs[tab],customer,id);
   }

 if(mappingp(content))
       return content;
 res += "<p>" + content + "</body>";
 
  return http_string_answer(parse_rxml(res, id)) |
  ([ "extra_heads":
     (["Expires": http_date( 0 ), "Last-Modified": http_date( time(1) ) ])
  ]);
}

array register_module()
{
   return ({ MODULE_LOCATION, "AutoSite Administration Interface",
	     "",0,0 });
}

void start(int q, object conf)
{
   tabsdir=(combine_path(roxen->filename(this)+"/","../")+"tabs/");
   actionsdir=(combine_path(roxen->filename(this)+"/","../")+"actions/");
   tabs=mkmapping(
     get_dir(tabsdir)-({".","..",".no_modules","CVS"}),
     Array.map(get_dir(tabsdir)-({".","..",".no_modules","CVS"}),
	       lambda(string s,string d,string l) 
	       {
		 return .Tab.tab(d+s,s,this_object());
	       },tabsdir,query("location")));
   actions=mkmapping(
     get_dir(actionsdir)-({".","..",".no_modules","CVS"}),
     Array.map(get_dir(actionsdir)-({".","..",".no_modules","CVS"}),
	       lambda(string s,string d,string l) 
	       {
		 werror(s+"\n");
		 return .Tab.tab(d+s,s,this_object());
	       },actionsdir,query("location")));
   actionlist=values(actions);
   tablist=values(tabs);
   sort(indices(tabs),tablist);
   sort(indices(actions),actionlist);
   
   if(conf)
     module_dependencies(conf,
			 ({ "configtablist",
			    "htmlparse" }));
}

void create()
{
  defvar("location", "/admin/", "Mountpoint", TYPE_LOCATION);
  defvar("admin", roxen->query("ConfigurationUser"),
	 "Admin user name", TYPE_STRING,
	 "This user name grants full access to the configuration "
	 "part of AutoSite Admin.");
  defvar("adminpass", roxen->query("ConfigurationPassword"),
	 "Admin password", TYPE_PASSWORD,
	 "This password grants full access to the configuration "
	 "part of AutoSite Admin.");
}
