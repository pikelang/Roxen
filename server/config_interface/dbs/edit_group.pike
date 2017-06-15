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
       "<submit-gbutton2 name='yes' type='ok'>"+_(0,"Yes")+"</submit-gbutton2></td>\n"\
       "<td align=right><link-gbutton type='delete' href='"+Roxen.html_encode_string(id->not_query)+\
      "?group="+\
       Roxen.html_encode_string(id->variables->group)+"&amp;&usr.set-wiz-id;'>"+\
       _(0,"No")+" </link-gbutton></td>\n</table>\n");			\
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

  constant encstr = Roxen.html_encode_string;

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

  if (!c) {
    return res + sprintf(
      "<div class='notify error'>The database group <code>%s</code> doesn't"
      " exist!</div>", id->variables->group) +
      "</st-page></content></tmpl>";
  }


  res += "<cf-title>"+c->lname+"</cf-title>"
    "<p class='no-margin-top'>"+c->comment+"</p>";

  res +=
    "<dl class='config-var no-border narrow'>"
      "<dt class='name'>Name:</dt>"
      "<dd class='value'>" +
      (view_mode ? encstr(c->lname) :
        "<input size=50 name=lname value='"+encstr(c->lname)+"' />")+
      "</dd>"
    "</dl>";

  res +=
    "<dl class='config-var no-border narrow'>"
      "<dt class='name'>URL:</dt>"
      "<dd class='value'>" +
      (view_mode ?
        encstr(trim_sl((c->pattern/"://")[-1])) :
        "<input size=50 name=pattern value='"+
                encstr(trim_sl((c->pattern/"://")[-1]))+"'"
        " placeholder='mysql:// added automatically'/>"
      )+"</dd>"
    "</dl>";

  res +=
    "<dl class='config-var no-border narrow'>"
      "<dt class='name'>Comment:</dt>"
      "<dd class='value'>" +
      (view_mode ?
        encstr(c->comment) :
        "<textarea cols='50' rows=4 name=comment>"+encstr(c->comment)+
        "</textarea>"
      )+"</dd>"
    "</dl>";

  res += (view_mode ? "" : "<cf-save/>");


  res += "<hr class='margin-top'>";

  res += sprintf("<h3>"+_(434,"Databases in the group %s")+"</h3>", c->lname );

  array groups = DBManager.group_dbs( id->variables->group );
  res += "<dl>\n";
  if( sizeof(groups) )
    foreach( groups, string d )
    {
      res += "<dt><b>"+
	(view_mode ? "" : "<a href='browser.pike?db="+d+"&amp;&usr.set-wiz-id;'>")+d+
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
      button = sprintf("<disabled-button type='delete'>%s</disabled-button>",
		       _(352, "Delete group"));
    else
      button = sprintf("<link-gbutton href='%s?group=%s&amp;action=%s&amp;&usr.set-wiz-id;'>%s</link-gbutton>",
		       id->not_query, id->variables->group, "delete",
		       _(352, "Delete group"));
    res += "<hr>"+button;
  }

  return res + "</st-page></content></tmpl>";
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
