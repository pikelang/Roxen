#include <config_interface.h>
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">_</locale-token>
#define _(X,Y)	_STR_LOCALE("roxen_config",X,Y)


void save_edit()
{
  
}

string parse( RequestID id )
{
  mapping c;
  string res =
    "<use file='/template'/><tmpl>"
    "<topmenu base='../' selected='dbs'/>"
    "<content><cv-split><subtablist width='100%'><st-tabs>"
    "<insert file='subtabs.pike'/></st-tabs><st-page>"
    "<input type=hidden name='sort' value='&form.sort:http;' />\n"
    "<input type=hidden name='db' value='&form.db:http;' />\n";

  c = DBManager.get_group( id->variables->group );

  
  res += "<blockquote><br />"+c->comment+"<table>";

  res += "<tr><td><b>Name:</b></td><td> <input size=50 value='"+
    Roxen.html_encode_string(c->lname)+"' /></td></tr>";
  
  res += "<tr><td><b>URL:</b> </td><td> <input size=50 value='"+
    Roxen.html_encode_string(c->pattern)+"' /></td></tr>";
  

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
