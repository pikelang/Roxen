/*
 * $Id: webadm.pike,v 1.1 1998/07/23 04:38:56 js Exp $
 *
 * AutoWeb administration interface
 *
 * Johan Schön 1998-07-08
 */

constant cvs_version = "$Id: webadm.pike,v 1.1 1998/07/23 04:38:56 js Exp $";

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



array register_module()
{
   return ({ MODULE_LOCATION|MODULE_PARSER, "AutoWeb Administration Interface",
	     "",0,0 });
}



mapping credentials;

void update_customer_cache(object id)
{
  object db=id->conf->call_provider("sql","sql_object",id);
  array a=db->query("select id,user_id,password from customers");
  mapping new_credentials=([]);
  if(!catch {
    Array.map(a,lambda(mapping entry, mapping m)
		{
		  m[entry->id]=({ entry->user_id, entry->password });
		},new_credentials);
  })
    credentials=new_credentials;

}

int validate_customer(object id)
{
  catch {
    return equal(credentials[id->misc->customer_id],
		 ((id->realauth||"*:*")/":"));
  };
  return 0;
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

mapping query_tag_callers()
{
  return ([ "autosite-webadm-update" : tag_update,
            "autosite-webadm-customername" : customer_name]);
}

string make_tablist(array(object) tabs, object current, object id)
{
  string res_tabs="";
  foreach(tabs, object tab)
  {
    mapping args = ([]);
    args->bgcolor=colorscheme->bgcolor;
    args->href = combine_path(query("location"),tab->tab)+"/";
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
  string tab,sub;
  mixed content="";
  mapping state;

  int t1,t2,t3;

  // User validation
  if(!credentials)
    update_customer_cache(id);
  // User validation
  if(!validate_customer(id))
    return (["type":"text/html",
	     "error":401,
	     "extra_heads":
	     ([ "WWW-Authenticate":
		"basic realm=\"AutoWeb Admin\""]),
	     "data":"<title>Access Denied</title>"
	     "<h2 align=center>Access forbidden</h2>\n"
    ]);

  
 sscanf(f, "%s/%s", tab, sub);
 string res = "<title>AutoSite Administration Interface</title>"+BODY+status_row(tab,id);
 res+=make_tablist(tablist,tabs[tab],id);
 if (!tabs[tab])
     content=
	"You've reached a non-existing tab '"
	"<tt>"+tab+"</tt> somehow. Select another tab.\n";
 else
     content = tabs[tab]->show(sub,id,f);

 if(mappingp(content))
       return content;
 res += "<p>" + content + "</body>";
 
  return http_string_answer(parse_rxml(res, id)) |
  ([ "extra_heads":
     (["Expires": http_date( 0 ), "Last-Modified": http_date( time(1) ) ])
  ]);
}


void start(int q, object conf)
{
   tabsdir=(combine_path(roxen->filename(this)+"/","../")+"tabs/");
   tabs=mkmapping(
     get_dir(tabsdir)-({".","..",".no_modules","CVS"}),
     Array.map(get_dir(tabsdir)-({".","..",".no_modules","CVS"}),
	       lambda(string s,string d,string l) 
	       {
		 return .Tab.tab(d+s,s,this_object());
	       },tabsdir,query("location")));
   tablist=values(tabs);
   sort(indices(tabs),tablist);
   
   if(conf)
     module_dependencies(conf,
			 ({ "configtablist",
			    "htmlparse" }));
}

void create()
{
  defvar("location", "/webadm/", "Mountpoint", TYPE_LOCATION);
}
