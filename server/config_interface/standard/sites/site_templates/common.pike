constant modules = ({});

mixed parse( RequestID id )
{
  id->misc->modules_to_add = modules;
  if( id->variables->url )
  {
    id->misc->new_configuration->set( "URLs", ({ id->variables->url }) );
    return "<done/>";
  }
  return "<b>URL</b>: <input size=50 name=url value='http://*:80/'>"
         "<br />"
         "<submit-gbutton> &locale.ok; </submit-gbutton>";
}
