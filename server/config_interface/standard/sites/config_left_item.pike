string dotdot( RequestID id, int x )
{
  string dotodots = (sizeof( id->misc->path_info/"/" )-x)>0?((({ "../" })*(sizeof( id->misc->path_info/"/" )-x))*""):"./";

  while( id->misc->orig ) id = id->misc->orig;
  return combine_path( id->not_query+id->misc->path_info, dotodots );
}


#define DOTDOT( X ) dotdot( id, X )

string selected_item( string q, roxen.Configuration c, RequestID id )
{
  string subsel;
  string pre = ("<item selected "
                "title='"+(id->misc->variables->name-"'") +
                "' href='"+DOTDOT(2)+(q-"'")+"/'>");

  sscanf( id->misc->path_info, "/"+q+"/%[^/]", subsel );
  foreach( ({ "modules", "settings", }), string q )
  {
    if( subsel == q )
    {
      pre += ("<item selected title='<cf-locale get="+q+">' "
              " href='"+DOTDOT(3)+q+"/'>");
      
      pre += "</item>";
    } else
      pre += ("<item title='<cf-locale get="+q+">' "
              " href='"+DOTDOT(3)+q+"/'></item>");
  }
  pre += "</item>";
  return pre;
}

string parse( RequestID id )
{
  string site;
  sscanf( id->misc->path_info, "/%[^/]/", site );
  if(site == id->misc->variables->sname ) 
    return selected_item( site, roxen.find_configuration( site ), id );
  return "<item title='"+(id->misc->variables->name-"'")+"' href='"+
         DOTDOT( 2 )+(id->misc->variables->sname-"'")+"/'></item>";
}
