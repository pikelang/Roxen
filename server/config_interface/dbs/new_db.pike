#include <config_interface.h>
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">_</locale-token>
#define _(X,Y)	_STR_LOCALE("roxen_config",X,Y)

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
<cf-title>"+_(439,"Create a new database")+#"</cf-title>
[ERROR]

<dl class='config-var no-border narrow'>
  <dt class='name'>"+_(376,"Name")+#"</dt>
  <dd class='value'><input name='name' value='&form.name;' size='60'/></dd>
  <dd class='doc'>"+_(442,#"The name of the database. To make it easy on your
                           users, please use all lowercase characters, and
                           avoid 'odd' characters.")+#"</dd>
</dl>

<dl class='config-var no-border narrow'>
  <dt class='name'>"+_(419,"Type")+#"</dt>
  <dd class='value'>
    <default variable=form.type><select name=type>
      <option value='internal'>  "+_(440,"Internal")+#"  </option>
      <option value='external'>  "+_(441,"External")+#"  </option>
    </select></default>
  </dd>
  <dd class='doc'>"+_(443, #"The database type. <i>Internal</i> means that it
                            is created in the local Roxen MySQL server, or some
                            other MySQL server specified in the URL setting of
                            the chosen group. The permissions of the database
                            are manged by Roxen. <i>External</i> means that the
                            database resides in another server, which can be
                            another MySQL instance or something else.")+#"</dd>
</dl>


<dl class='config-var no-border narrow'>
  <dt class='name'>"+_(444,"URL")+#"</dt>
  <dd class='value'><input name='url' size='60' value='&form.url;'/></dd>
  <dd class='doc'>"+_(446,#"The URL to the database. It is only used for
                           <i>external</i> databases.")+#"</dd>
</dl>


<dl class='config-var no-border narrow'>
  <dt class='name'>"+_(503,"Group")+#"</dt>
  <dd class='value'>
    <default variable='form.group'><select name=group> "+
      group_selector()+#"
    </select></default>
  </dd>
  <dd class='doc'>"+_(447,#"The group to put the database in. For
                           <i>internal</i> databases, the URL setting in the
                           group also specifies which MySQL server the database
                           is created in.")+#"</dd>
</dl>

<dl class='config-var no-border narrow'>
  <dt class='name'>"+_(448,"Comment")+#"</dt>
  <dd class='value'><textarea name='comment' cols='50' rows='10'>&form.comment;</textarea></dd>
</dl>
";

  if( id->variables["ok.x"]  )
  {
    if( id->variables->type=="external" )
    {
      if( !strlen(id->variables->url) )
        error= "<div class='notify error'>"
	  +_(406,"Please specify an URL to define an external database")+
               "</div>";
      else if( mixed err = catch( Sql.Sql( id->variables->url ) ) )
        error = sprintf("<div class='notify error'>"+
                        _(407,"It is not possible to connect to %s.")+
			"<br /> (%s)"
                        "</div>",
                        id->variables->url,
			describe_error(err));
    }
    if( !strlen( error ) )
      switch( id->variables->name )
      {
       case "":
         error =  "<div class='notify error'>"+
	   _(408,"Please specify a name for the database")+
	   "</div>";
         break;
       case "mysql": case "roxen":
       case "local":
         error = sprintf("<div class='notify error'>"+
                         _(409,"%s is an internal database, used by Roxen. "
			   "Please select another name.")+
                         "</div>", id->variables->name );
         break;
       default:
	 if( Roxen.is_mysql_keyword( id->variables->name ) )
	   error = sprintf("<div class='notify error'>"+
			   _(410,"%s is a MySQL keyword, used by MySQL. "
			     "Please select another name.")+
			   "</div>", id->variables->name );
	 else
	 {
	   if( mixed err = catch {
	     really_do_create( id );
	     RXML.user_set_var( "var.go-on", "<redirect to='/dbs/'/>" );
	     return "";
	   } )
	     error = ("<div class='notify error'>"+
		      describe_error(err)+"</div>");
	 }
      }
  }
  return replace( form, "[ERROR]", error );
}
