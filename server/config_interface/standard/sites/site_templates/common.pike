constant modules = ({});

//array(string) initial_variables;
// This overrides all the VAR_INITIAL flags in the added modules if
// it's defined. The strings are on the form:
//	<module name>#<copy>/<variable name>

string verify_url( string port )
{
  if( (int)port ) 
    port = "http://*:"+port+"/";

  string protocol, host, path;

  if(sscanf( port, "%[^:]://%[^/]%s", protocol, host, path ) != 3)
    ;
  else
  {
    int pno;
    if( sscanf( host, "%s:%d", host, pno ) == 2)
    {
      if( pno != roxen->protocols[ lower_case( protocol ) ]->default_port )
        host = host+":"+pno;
    }
    if( !strlen(path) )
      path = "/";
    port = lower_case( protocol )+"://"+host+path;
  }
  return port;
}

mixed parse( RequestID id )
{
  id->misc->modules_to_add = modules;
  if (this_object()->initial_variables)
    id->misc->module_initial_vars = this_object()->initial_variables;
  if( id->variables->url )
  {
    id->misc->new_configuration->set( "URLs",
			              ({verify_url(id->variables->url) }) );
    id->misc->new_configuration->set( "MyWorldLocation", Roxen.get_world( ({ id->variables->url }) ) || "" );
    return "<done/>";
  }
  return "<b>URL</b>: <input size=50 name=url value='http://*/'>"
         "<br />"
         "<submit-gbutton> &locale.ok; </submit-gbutton>";
}
