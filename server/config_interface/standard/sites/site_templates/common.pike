constant modules = ({});

//array(string) initial_variables;
// This overrides all the VAR_INITIAL flags in the added modules if
// it's defined. The strings are on the form:
//	<module name>#<copy>/<variable name>

string verify_url( string port )
{
  if( (int)port ) port = "http://*:"+port+"/";

  string protocol, host, path;

  if(sscanf( port, "%[^:]://%[^/]%s", protocol, host, path ) != 3)
    ;
  else if( path == "" )
    port += "/";

  if( protocol != lower_case( protocol ) )
    port = lower_case( protocol )+"://"+host+path;

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
  return "<b>URL</b>: <input size=50 name=url value='http://*:80/'>"
         "<br />"
         "<submit-gbutton> &locale.ok; </submit-gbutton>";
}
