#include <config_interface.h>
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">_</locale-token>
#define _(X,Y)	_STR_LOCALE("roxen_config",X,Y)

string c_name( string c, RequestID id )
{
  if( c == _(449,"automatic") )
    return Roxen.short_name( id->variables->lname );
  return c;
}

void really_do_create( RequestID id  )
{
  while( strlen(id->variables->url) && id->variables->url[-1] == '/' )
    id->variables->url = id->variables->url[..strlen(id->variables->url)-2];
  DBManager.create_group( c_name(id->variables->name,id),
			     id->variables->lname,
			     id->variables->comment,
			     (strlen(id->variables->url)?
			     "mysql://"+id->variables->url+"/" : 
			     ""));
}


mapping|string parse( RequestID id )
{
  int find_dbs;
  RXML.user_set_var( "var.go-on",  "<cf-ok/>" );

  if( !id->variables->name )
    id->variables->name = _(449,"automatic");
  
  string error="",form =
#"
<h3>"+_(450,"Create a new database group")+#"</h3>
"+_(451,#"<p>The groups are used mainly to group the databases in the
Administration interface, but also to indicate the default MySQL
server external databases will be created in.</p>

<p>If a group has a URL set, it will be used to select the database
server in which the database will be created. Please note that it
server must be a MySQL server.</p>")+#"<p>
<font size=+1><b>ERROR</b></font>
<table>
  <tr>
    <td><b>"+_(452,"ID")+#":</b></td> <td><input name='name' value='&form.name;' size=20/></td>
    <td><b>"+_(376,"Name")+#":</b></td> <td><input name='lname' value='&form.lname;' size=30/></td>
  </tr>
  <tr>
  <td valign=top colspan='2'>
    "+_(453,"The identifier of the group. This is used internally in Roxen,"
	   " and must be unique. "
	   "If you leave it as automatic, an identifier is selected "
	   "automatically.")+#"
   </td>
   <td valign=top colspan='2' width='100%'>
     "+_(454,"The name of the database group. This is what is"
	 " shown in the configuration interface.")+#"
   </td>
 </tr>
  <tr>
     <td><nbsp><b>"+_(444,"URL")+#":</b></nbsp></td>
      <td colspan=3>mysql://<input name='url' size=30 value='&form.url;'/></td>
      </tr>
      <tr><td valign=top colspan='4'>
      "+_(455, #"\
This URL is used for <i>internal</i> databases created in this group,
and it specifies which MySQL server they should be created in. As an
example, if you want all databases created in the group to end up in
the MySQL running on the host <i>wyrm</i>, using the account with
the username <i>foo</i> and password <i>bar</i>, set this URL to
<i>foo:bar@wyrm</i>.")+
    "</td></tr>"
#"<tr><td valign=top><nbsp><b>"+_(448,"Comment")+#":</b></nbsp></td>
      <td colspan=3><textarea name='comment' cols=50 rows=10>&form.comment;</textarea></td></tr>"

    "</table>";

  if( id->variables["ok.x"]  )
  {
    if( strlen(id->variables->url) )
    {
      id->variables->url = Stdio.append_path(id->variables->url, "/");
      if(catch(Sql.Sql( "mysql://"+id->variables->url ) ))
	error = sprintf( "<font color='&usr.warncolor;'>"+
			 _(456,"Cannot connect to %s")+
			 "</font>", "mysql://"+id->variables->url );
      else
	find_dbs = 1;
    }
    if(!strlen(error))
      if (!sizeof(id->variables->lname))
	error="<font color='&usr.warncolor;'>"+
	  _(355,"Please give a name for the group.")+
	  "</font>";
    if(!strlen(error))
      if( DBManager.get_group( c_name(id->variables->name,id) ) )
	error=sprintf("<font color='&usr.warncolor;'>"+
		      _(457,"A database group named %s already exists")+
 		      "</font>", id->variables->name );
    if( !strlen( error ) )
      if( Roxen.is_mysql_keyword( id->variables->name ) )
	error = sprintf("<font color='&usr.warncolor;'>"+
			_(410,"%s is a MySQL keyword, used by MySQL. "
			  "Please select another name.")+
			"</font>", id->variables->name );
      else
      {
	really_do_create( id );
	if( find_dbs )
	  RXML.user_set_var( "var.go-on",
			     sprintf("<redirect to='import_dbs.pike?group=%s'/>",
				     Roxen.http_encode_url(c_name(id->variables->name,id))));
	else
	  RXML.user_set_var( "var.go-on", "<redirect to='/dbs/'/>" );
	return "";
      }
  }
  return replace( form, "ERROR", error );
}
