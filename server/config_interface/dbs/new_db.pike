#include <config_interface.h>
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">_</locale-token>
#define _(X,Y)	_STR_LOCALE("roxen_config",X,Y)

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
<gtext scale=0.6>"+_(0,"Create a new database")+#"</gtext><br />
ERROR
<table>
  <tr>
    <td><b>"+_(0,"Name")+#":</b></td> <td><input name='name' value='&form.name;'/></td>
    <td><b>"+_(0,"Type")+#":</b></td> <td width='100%'>
     <default variable=form.type><select name=type>
       <option value='internal'>  "+_(0,"Internal")+#"  </option>
       <option value='external'>  "+_(0,"External")+#"  </option>
     </select></default>
    </td>
  </tr>
  <tr>
  <td valign=top colspan='2'>
    <i>"+_(0,"The name of the database. To make it easy on your users, "
	   "use all lowercaps characters, and avoid 'odd' characters ")+#"
     </i>
   </td>
   <td valign=top colspan='2' width='100%'>

        <i>"+_(0,"The database type. Internal means that it will be created"
	       " in the roxen mysql database, and the permissions of the"
	       " database will be automatically manged by roxen. External"
	       " means that the database resides in another database.")+#"</i>
   </td>
 </tr>
  <tr>
     <td><nbsp><b>"+_(0,"URL")+#":</b></nbsp></td>
      <td colspan='3'><input name='url' size=50 value='&form.url;'/></td>
      </tr>
      <tr><td colspan='4'><i>
      "+_(0,"This URL is only used for </i>External<i> databases, it is "
	  "totally ignored for databases defined internally in Roxen")+"</i>"
      "</td></tr>"
    "</table>";

  if( id->variables["ok.x"]  )
  {
    if( id->variables->type=="external" )
    {
      if( !strlen(id->variables->url) )
        error= "<font color='&usr.warncolor;'>"
	  +_(0,"Please specify an URL to define an external database")+
               "</font>";
      else if( catch( Sql.Sql( id->variables->url ) ) )
        error = sprintf("<font color='&usr.warncolor;'>"+
                        _(0,"It is not possible to connect to %s")+
                        "</font>",
                        id->variables->url );
    }
    if( !strlen( error ) )
      switch( id->variables->name )
      {
       case "":
         error =  "<font color='&usr.warncolor;'>"+
	   _(0,"Please specify a name for the database")+
	   "</font>";
         break;
       case "mysql":
       case "roxen":
       case "local":
       case "shared":
         error = sprintf("<font color='&usr.warncolor;'>"+
                         _(0,"%s is an internal database, used by roxen."
			   "Please select another name")+
                         "</font>", id->variables->name );
         break;
       default:
	 if( Roxen.is_mysql_keyword( id->variables->name ) )
	   error = sprintf("<font color='&usr.warncolor;'>"+
			   _(0,"%s is a mysql keyword, used by mysql."
			     "Please select another name")+
			   "</font>", id->variables->name );
	 else
	 {
	   really_do_create( id );
	   RXML.user_set_var( "var.go-on", "<redirect to=''/>" );
	 }
         return "";
      }
  }
  return replace( form, "ERROR", error );
}
