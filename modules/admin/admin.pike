/*
 * $Id: admin.pike,v 1.1 1998/07/10 01:25:56 js Exp $
 *
 * AutoAdmin, administration interface
 *
 * Johan Schön 1998-07-08
 */

constant cvs_version = "$Id: admin.pike,v 1.1 1998/07/10 01:25:56 js Exp $";

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

string tabsdir,imgsdir,handlerdir;
mapping tabs;
array tablist;

string make_tablist(array(object) tabs, object current, object id)
{
  string res_tabs="";
  foreach(tabs, object tab)
  {
    mapping args = ([]);
    args->bgcolor=colorscheme->bgcolor;
    args->href = tab->loc;
    if(current==tab)
    {
      args->selected = "selected";
      args->href += "?_reset=";
    }
    res_tabs += make_container( "tab", args, tab->title );
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


mixed find_file(string f, object id)
{
  string res = "";
  string tab,sub;
  mixed content;
  mapping state;

  int t1,t2,t3;

  // do access control here

  if(sscanf(f, "%s/%s", tab, sub) != 2)
    return http_redirect(tablist[0]->loc);

  if(!tabs[tab])
    return http_string_answer("huh?","text/html");

  content = tabs[tab]->show(sub,id,f);

  if(mappingp(content))
     return content;

  res = 
    "<title>AutoAdmin: "+tabs[tab]->title+"</title>"+
    BODY
    + status_row( tab, id ) ;
  
  array a=({});
  foreach (tablist, object t)
    if (t->space)
    {
      res+=make_tablist(a,tabs[tab],id)+"\n<tt>&nbsp;</tt>\n";
      a=({});
    }
    else if (t->visible(id))
      a+=({t});
  res+= make_tablist(a,tabs[tab],id) + "<p>" + content;
  res+="</body>";

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
   tabs=mkmapping(
     get_dir(tabsdir)-({".","..",".no_modules","CVS"}),
     Array.map(get_dir(tabsdir)-({".","..",".no_modules","CVS"}),
	       lambda(string s,string d,string l) 
	       {
		 return .Tab.tab(d+s,l+s+"/",s,this_object());
	       },tabsdir,query("location")));
   tablist=values(tabs);
   sort(indices(tabs),tablist);
   
//    if(conf)
//      module_dependencies(conf,
// 			 ({ "configtablist",
// 			    "htmlparse" }));
}


void create()
{
  defvar("location", "/admin/", "Mountpoint", TYPE_LOCATION);
}
