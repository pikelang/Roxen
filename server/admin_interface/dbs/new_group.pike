#include <admin_interface.h>
#include <config.h>

string c_name( string c, RequestID id )
{
  if( c == "automatic" )
    return Roxen.short_name( id->variables->lname );
  return c;
}

void really_do_create( RequestID id  )
{
  while( sizeof(id->variables->url) && id->variables->url[-1] == '/' )
    id->variables->url = id->variables->url[..sizeof(id->variables->url)-2];
  DBManager.create_group( c_name(id->variables->name,id),
			     id->variables->lname,
			     id->variables->comment,
			     (sizeof(id->variables->url)?
			     "mysql://"+id->variables->url+"/" : 
			     ""));
}


mapping|string parse( RequestID id )
{
  int find_dbs;
  RXML.user_set_var( "var.go-on",  "<cf-ok/>" );

  if( !id->variables->name )
    id->variables->name = "automatic";
  
  string error="",form =
#"
<gtext scale=0.6>Create a new database group</gtext><br />
The groups are used mainly to group the databases in the
Administration interface, but also to indicate the default MySQL server
internal databases will be created in.

<p> If a group has a URL set, it will be used to select the database
server in which the database will be created, please note that this
server must be a MySQL server, nothing else will work.
<br /><p>
<font size='+1'><b>ERROR</b></font>
<table>
  <tr>
    <td><b>ID:</b></td> <td><input name='name' value='&form.name;' size='20'/></td>
    <td><b>Name:</b></td> <td><input name='lname' value='&form.lname;' size='30'/></td>
  </tr>
  <tr>
  <td valign='top' colspan='2'>
    <i>The identifier of the group. This is used internally in ChiliMoon,
       and must be unique.If you leave it as automatic, a ID will be selected
       automatically.</i>
   </td>
   <td valign='top' colspan='2' width='100%'>

        <i>The name of the database group. This is what is
	   shown in the administration interface</i>
   </td>
 </tr>
  <tr>
     <td><nbsp><b>URL:</b></nbsp></td>
      <td colspan='3'>mysql://<input name='url' size='30' value='&form.url;'/></td>
      </tr>
      <tr><td valign='top' colspan='4'><i>
        This URL is only used when </i>Internal<i> databases is
	created in this group, and it specified which MySQL server
	the datbase should be created in. As an example, if you want all
	databases created in the group to end up in the MySQL running
	on the host </i>wyrm<i>, using the account with the username </i>foo<i> and
	password </i>bar<i>, set this URL to </i>foo:bar@wyrm<i>
      </td></tr>
  <tr><td valign='top'><nbsp><b>Comment:</b></nbsp></td>
      <td colspan='3'><textarea name='comment' cols='50' rows='10'>&form.comment;</textarea></td></tr>

</table>";

  if( id->variables["ok.x"]  )
  {
    if( sizeof(id->variables->url) )
    {
      if(catch(Sql.Sql( "mysql://"+id->variables->url+"/mysql" ) ))
	error = sprintf( "<font color='&usr.warncolor;'>"
			 "Cannot connect to %s"
			 "</font>", "mysql://"+id->variables->url );
      else
	find_dbs = 1;
    }
    if(!sizeof(error))
      if (!sizeof(id->variables->lname))
	error="<font color='&usr.warncolor;'>"
	  "Please give a name for the group.</font>";
    if(!sizeof(error))
      if( DBManager.get_group( c_name(id->variables->name,id) ) )
	error=sprintf("<font color='&usr.warncolor;'>"
		      "A database group named %s already exists"
 		      "</font>", id->variables->name );
    if( !sizeof( error ) )
      if( Roxen.is_mysql_keyword( id->variables->name ) )
	error = sprintf("<font color='&usr.warncolor;'>"
			"%s is a MySQL keyword, used by MySQL."
			"Please select another name"
			"</font>", id->variables->name );
      else
      {
	really_do_create( id );
	if( find_dbs )
	  RXML.user_set_var( "var.go-on",
			     sprintf("<redirect to='import_dbs.pike?group=%s'/>",
				     Roxen.http_encode_string(c_name(id->variables->name,id))));
	else
	  RXML.user_set_var( "var.go-on", "<redirect to=''/>" );
	return "";
      }
  }
  return replace( form, "ERROR", error );
}
