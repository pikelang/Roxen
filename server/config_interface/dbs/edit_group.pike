#include <config_interface.h>
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">_</locale-token>
#define _(X,Y)	_STR_LOCALE("roxen_config",X,Y)

#define CU_AUTH id->misc->config_user->auth

string trim_sl( string x )
{
  while( strlen(x) && x[-1] == '/' )
    x = x[..strlen(x)-2];
  return x;
}

string parse( RequestID id )
{
  mapping c;
  string res =
    "<use file='/template'/><tmpl>"
    "<topmenu base='../' selected='dbs'/>"
    "<content><cv-split><subtablist width='100%'><st-tabs>"
    "<insert file='subtabs.pike'/></st-tabs><st-page>"
    "<input type=hidden name=group value='&form.group;'/>";

  int view_mode;
  if ( !(CU_AUTH( "Edit Global Variables" )) )
    view_mode = 1;

  if( id->variables->lname && !view_mode)
  {
    if( strlen(id->variables->pattern) )
      id->variables->pattern = "mysql://"+trim_sl(id->variables->pattern)+"/";
    DBManager.create_group( id->variables->group,
			    id->variables->lname,
			    id->variables->comment,
			    id->variables->pattern );
  }
  c = DBManager.get_group( id->variables->group );


  
  
  res += "<blockquote><br /><h2>"+c->lname+"</h2>"
    ""+c->comment+"<table>";

  res += "<tr><td><b>Name:</b></td><td> "+
    (view_mode ? Roxen.html_encode_string(c->lname) :
     "<input size=50 name=lname value='"+
     Roxen.html_encode_string(c->lname)+"' />")+
    "</td></tr>";
  
  res += "<tr><td><b>URL:</b> </td><td> "
    "mysql://"+
    (view_mode ? Roxen.html_encode_string(trim_sl((c->pattern/"://")[-1]))
     : "<input size=42 name=pattern value='"+
    Roxen.html_encode_string(trim_sl((c->pattern/"://")[-1]))+
    "' />")+"</td></tr>";
  
  res += "<tr><td valign=top><b>Comment:</b></td><td valign=top> "+
    (view_mode ? Roxen.html_encode_string(c->comment) :
     "<textarea cols='50' rows=4 name=comment>"+
     Roxen.html_encode_string(c->comment)+"</textarea>")+
    "</td></tr>";


  res += "<tr><td></td><td align=right>"
    +(view_mode ? "" : "<cf-save />")+
    "</td></tr>";
  res += "</table>";

  res += sprintf("<font size=+1><b>"+_(434,"Databases in the group %s")+
		 "</b></font><br />", c->lname );

  res += "<dl>";
  foreach( DBManager.group_dbs( id->variables->group ), string d )
  {
    res += "<dt><b>"+
      (view_mode ? "" : "<a href=browser.pike?db="+d+">")+d+
      (view_mode ? "" : "</a>")+
      "</b>";
    if( string cm = DBManager.module_table_info( d, "" )->comment )
      res += "<dd>"+cm+"</dd>";
  }

  return res + "\n</blockquote></st-page></content></tmpl>";
}
