#include <admin_interface.h>
#include <config.h>

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

  if( id->variables->action == "delete" )
  {
    mixed tmp = delete_group( id->variables->group, id );
    if( stringp( tmp ) )
      return res+tmp+"\n</st-page></content></tmpl>";
    if( tmp )
      return tmp;
  }


  if( id->variables->lname )
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

  res += "<tr><td><b>Name:</b></td><td> <input size=50 name=lname value='"+
    Roxen.html_encode_string(c->lname)+"' /></td></tr>";
  
  res += "<tr><td><b>URL:</b> </td><td> "
    "mysql://<input size=42 name=pattern value='"+
    Roxen.html_encode_string(trim_sl((c->pattern/"://")[-1]))+
    "' /></td></tr>";
  
  res += "<tr><td valign=top><b>Comment:</b></td><td valign=top> <textarea cols='50' rows=4 name=comment>"+
    Roxen.html_encode_string(c->comment)+"</textarea></td></tr>";


  res += "<tr><td></td><td align=right><cf-save /></td></tr>";
  res += "</table>";

  res += sprintf("<font size=+1><b>Databases in the group %s</b></font><br />", c->lname );

  array groups = DBManager.group_dbs( id->variables->group );
  res += "<dl>\n";
  if( sizeof(groups) )
    foreach( groups, string d )
    {
      res += "<dt><b><a href=browser.pike?db="+d+">"+d+"</a></b>";
      if( string cm = DBManager.module_table_info( d, "" )->comment )
	res += "<dd>"+cm+"</dd>";
      res += "</dt>\n";
    }
  else
    res += "(none)";
  res += "</dl>\n";

  string button;
  if ( sizeof(DBManager.group_dbs(id->variables->group)) )
    button = "<gbutton textcolor='#BEC2CB'>Delete group</gbutton>";
  else
    button = sprintf("<a href='%s?group=%s&action=%s'><gbutton>"
		     "Delete group</gbutton></a>",
		     id->not_query, id->variables->group, "delete");
  res += "<br />"+button;

  return res + "\n</blockquote></st-page></content></tmpl>";
}


mixed delete_group( string group, RequestID id )
{
  if( sizeof(DBManager.group_dbs( group )) )
    return "You can not delete this group because it is not empty.";
  string msg = "Are you sure you want to delete the group %s?";
  VERIFY(msg);

  DBManager.delete_group( group );
  return Roxen.http_redirect( "/dbs/", id );
}
