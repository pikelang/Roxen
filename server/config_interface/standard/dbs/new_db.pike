void really_do_create( RequestID id  )
{
  DBManager.create_db( id->variables->name,
                       id->variables->url,
                       id->variables->type == "internal" );
}

string parse(RequestID id )
{
  RXML.user_set_var( "var.go-on",  "<cf-ok/>" );
  string error="",form =
#"
<gtext scale=0.6>Create a new database</gtext><br />
ERROR
<table>
  <tr>
    <td><b>Name:</b></td> <td><input name='name' value='&form.name;'/></td>
    <td><b>Type:</b></td> <td width='100%'>
     <default variable=form.type><select name=type>
       <option value='internal'>  Internal  </option>
       <option value='external'>  External  </option>
     </select></default>
    </td>
  </tr>
  <tr>
  <td valign=top colspan='2'>
    <i>The name of the database. To make it easy on your users,
       use all lowercaps characters, and avoid 'odd' characters
     </i>
   </td>
   <td valign=top colspan='2' width='100%'>

        <i>The database type. Internal means that it will be created
           in the roxen mysql database, and the permissions of the
           database will be automatically manged by roxen. External
           means that the database resides in another database.</i>
   </td>
 </tr>
  <tr>
     <td><nbsp><b>URL:</b></nbsp></td>
      <td colspan='3'><input name='url' size=50 value='&form.url;'/></td>
      </tr>
      <tr><td colspan='4'><i>
      This URL is only used for </i>External<i> databases, it is
      totally ignored for databases defined internally in Roxen</i>
      </td></tr>
 </table>
";

  if( id->variables["ok.x"]  )
  {
    if( id->variables->type=="external" )
    {
      if( !strlen(id->variables->url) )
        error= "<font color='&usr.warncolor;'>"
               "Please specify an URL to define an external database"
               "</font>";
      else if( catch( Sql.sql( id->variables->url ) ) )
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
       case "mysql":
       case "roxen":
       case "cache":
         error = sprintf("<font color='&usr.warncolor;'>"
                         "%s is an internal database, used by roxen."
                         "Please select another name"
                         "</font>", id->variables->name );
         break;
       default:
         really_do_create( id );
         RXML.user_set_var( "var.go-on", "<redirect to='dbs.html'/>" );
         return "";
      }
  }
  return replace( form, "ERROR", error );
}
