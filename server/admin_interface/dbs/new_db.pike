#include <admin_interface.h>
#include <config.h>

void really_do_create( RequestID id  )
{
  DBManager.create_db( id->variables->name,
                       id->variables->url,
                       id->variables->type == "internal",
		       id->variables->group );
  if( strlen( id->variables->comment ) )
    DBManager.is_module_db( 0, id->variables->name,
			    id->variables->comment-"\r" );
  foreach( roxen->configurations, Configuration c )
    DBManager.set_permission( id->variables->name, c, DBManager.READ );
  DBManager.set_permission( id->variables->name, id->conf, DBManager.WRITE );
}

string parse(RequestID id )
{
  RXML.user_set_var( "var.go-on",  "<cf-ok/>" );

  string group_selector()
  {
    array res = ({});
    string form = "";
    foreach( DBManager.list_groups(), string c )
      if( c != "internal" )
	res += ({ ({DBManager.get_group(c)->lname, c}) });
      else
	res = ({ ({DBManager.get_group(c)->lname, c}) })+res;
    foreach( res[0..0]+sort(res[1..]), array q )
      form += "   <option value='"+q[1]+"'>"+q[0]+"\n";
    return form;
  };

  string error="",form =
#"
<gtext scale=0.6>Create a new database</gtext><br />
ERROR
<table>
  <tr>
    <td><b>Name:</b></td> <td><input name='name' value='&form.name;' size=30/></td>
    <td><b>Type:</b></td> <td width='100%'>
     <default variable='form.type'><select name='type'>
       <option value='internal'>  Internal  </option>
       <option value='external'>  External  </option>
     </select></default>
    </td>
  </tr>
  <tr>
  <td valign='top' colspan='2'>
    <i>The name of the database. To make it easy on your users,
       use all lowercaps characters, and avoid 'odd' characters</i>
   </td>
   <td valign='top' colspan='2' width='100%'>

        <i>The database type. Internal means that it will be created
	   in the roxen mysql database, and the permissions of the
	   database will be automatically manged by roxen. External
	   means that the database resides in another database.</i>
   </td>
 </tr>
  <tr>
     <td><nbsp><b>URL:</b></nbsp></td>
      <td><input name='url' size='30' value='&form.url;'/></td>
       <td><b>Group:</b></td> <td width='100%'>
       <default variable='form.group'><select name='group'> "+
      group_selector()+#"
       </select></default>
      </td>

      </tr>
      <tr><td valign=top colspan='2'><i>
        This URL is only used for </i>External<i> databases, it is
	totally ignored for databases defined internally in Roxen</i>
      </td>
      <td valign=top colspan='2'><i>
        This group is used to group the databses. For internal databases,
        the group can also be used to select which MySQL server the
        database should be created in.</i>
      </td></tr>
 <tr><td valign='top'><nbsp><b>Comment:</b></nbsp></td>
      <td colspan='3'><textarea name='comment' cols='50' rows='10'>&form.comment;</textarea></td></tr>
</table>";

  if( id->variables["ok.x"]  )
  {
    if( id->variables->type=="external" )
    {
      if( !strlen(id->variables->url) )
        error= "<font color='&usr.warncolor;'>"
	  "Please specify an URL to define an external database</font>";
      else if( catch( Sql.Sql( id->variables->url ) ) )
        error = sprintf("<font color='&usr.warncolor;'>"
                        "It is not possible to connect to %s"
                        "</font>",
                        id->variables->url );
    }
    if( !strlen( error ) )
      switch( id->variables->name )
      {
       case "":
         error =  "<font color='&usr.warncolor;'>"
	   "Please specify a name for the database"
	   "</font>";
         break;
       case "mysql": case "roxen":
       case "local":
         error = sprintf("<font color='&usr.warncolor;'>"
                         "%s is an internal database, used by roxen."
			 "Please select another name"
                         "</font>", id->variables->name );
         break;
       default:
	 if( Roxen.is_mysql_keyword( id->variables->name ) )
	   error = sprintf("<font color='&usr.warncolor;'>"
			   "%s is a mysql keyword, used by mysql."
			   "Please select another name"
			   "</font>", id->variables->name );
	 else
	 {
	   if( mixed err = catch {
	     really_do_create( id );
	     RXML.user_set_var( "var.go-on", "<redirect to=''/>" );
	     return "";
	   } )
	     error = ("<font color='&usr.warncolor;'>"+
		      describe_error(err)+"</font>");
	 }
      }
  }
  return replace( form, "ERROR", error );
}
