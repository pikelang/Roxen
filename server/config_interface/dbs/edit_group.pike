#include <config_interface.h>
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">_</locale-token>
#define _(X,Y)	_STR_LOCALE("roxen_config",X,Y)

string parse( RequestID id )
{
  mapping c;
  string res =
    "<use file='/template'/><tmpl>"
    "<topmenu base='../' selected='dbs'/>"
    "<content><cv-split><subtablist width='100%'><st-tabs>"
    "<insert file='subtabs.pike'/></st-tabs><st-page>"
    "<input type=hidden name=group value='&form.group;'/>";

  if( id->variables->lname )
    DBManager.create_group( id->variables->group,
			    id->variables->lname,
			    id->variables->comment,
			    id->variables->pattern );

  c = DBManager.get_group( id->variables->group );


  
  
  res += "<blockquote><br /><h2>"+c->lname+"</h2>"
    ""+c->comment+"<table>";

  res += "<tr><td><b>Name:</b></td><td> <input size=50 name=lname value='"+
    Roxen.html_encode_string(c->lname)+"' /></td></tr>";
  
  res += "<tr><td><b>URL:</b> </td><td> <input size=50 name=pattern value='"+
    Roxen.html_encode_string(c->pattern)+"' /></td></tr>";
  
  res += "<tr><td valign=top><b>Comment:</b></td><td valign=top> <textarea cols='50' rows=4 name=comment>"+
    Roxen.html_encode_string(c->comment)+"</textarea></td></tr>";


  res += "<tr><td></td><td align=right><cf-save /></td></tr>";
  res += "</table>";

  res += sprintf("<font size=+1><b>"+_(434,"Databases in the group %s")+
		 "</b></font><br />", c->lname );

  res += "<dl>";
  foreach( DBManager.group_dbs( id->variables->group ), string d )
  {
    res += "<dt><b><a href=browser.pike?db="+d+">"+d+"</a></b>";
    if( string cm = DBManager.module_table_info( d, "" )->comment )
      res += "<dd>"+cm+"</dd>";
  }

  return res + "\n</blockquote></st-page></content></tmpl>";
}
