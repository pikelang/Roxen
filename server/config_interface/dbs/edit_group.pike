#include <config_interface.h>
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">_</locale-token>
#define _(X,Y)	_STR_LOCALE("roxen_config",X,Y)

#define VERIFY(X) do {						\
  if( !id->variables["yes.x"] )					\
  {								\
    return							\
      ("<table><tr><td colspan='2'>\n"+				\
       sprintf((string)(X), group)+				\
       "</td><tr><td><input type=hidden name=action value='&form.action;' />"\
       "<submit-gbutton2 name='yes'>"+_(0,"Yes")+"</submit-gbutton2></td>\n"\
       "<td align=right><a href="+Roxen.html_encode_string(id->not_query)+\
      "?group="+\
       Roxen.html_encode_string(id->variables->group)+"><gbutton> "+\
       _(0,"No")+" </gbutton></a></td>\n</table>\n");			\
  }									\
} while(0)

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

  if( id->variables->action == "delete" && !view_mode)
  {
    mixed tmp = delete_group( id->variables->group, id );
    if( stringp( tmp ) )
      return res+tmp+"\n</st-page></content></tmpl>";
    if( tmp )
      return tmp;
  }


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

  array groups = DBManager.group_dbs( id->variables->group );
  res += "<dl>\n";
  if( sizeof(groups) )
    foreach( groups, string d )
    {
      res += "<dt><b>"+
	(view_mode ? "" : "<a href=browser.pike?db="+d+">")+d+
	(view_mode ? "" : "</a>")+
	"</b>";
      if( string cm = DBManager.module_table_info( d, "" )->comment )
	res += "<dd>"+cm+"</dd>";
      res += "</dt>\n";
    }
  else
    res += _(312,"(none)");
  res += "</dl>\n";

  if (!view_mode)
  {
    string button;
    if ( sizeof(DBManager.group_dbs(id->variables->group)) )
      button = sprintf("<gbutton textcolor='#BEC2CB'>%s</gbutton>",
		       _(352, "Delete group"));
    else
      button = sprintf("<a href='%s?group=%s&action=%s'><gbutton>%s</gbutton></a>",
		       id->not_query, id->variables->group, "delete",
		       _(352, "Delete group"));
    res += "<br />"+button;
  }

  return res + "\n</blockquote></st-page></content></tmpl>";
}


mixed delete_group( string group, RequestID id )
{
  if( sizeof(DBManager.group_dbs( group )) )
    return (string)_(353, "You can not delete this group because it is not empty.");
  string msg = (string)_(354, "Are you sure you want to delete the group %s?");
  VERIFY(msg);

  DBManager.delete_group( group );
  return Roxen.http_redirect( "/dbs/", id );
}
