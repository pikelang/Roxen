string dotdot( RequestID id, int x )
{
  string dotodots = (sizeof( id->misc->path_info/"/" )-x)>0?((({ "../" })*(sizeof( id->misc->path_info/"/" )-x))*""):"./";

  while( id->misc->orig ) id = id->misc->orig;
  return combine_path( id->not_query+id->misc->path_info, dotodots );
}


#define DOTDOT( X ) dotdot( id, X )

string selected_item( string q, roxen.Configuration c, RequestID id )
{
  while ( id->misc->orig ) 
    id = id->misc->orig;

  string subsel;
  string cfg = q;
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

      string url = id->not_query + id->misc->path_info;

      switch( q )
      {
       case "settings":
         pre += #"
  <item href=\""+url+#"?section=section\" title=\"Misc\"
    <if not variable=section> selected </if>
    <if variable=\"section is section\"> selected </if>
  ></item>

  <configif-output source=config-variables-sections configuration=\""+
cfg+#"\"><item href=\""+url+#"?section=#section#\"
         title=\"#section:quote=dtag#\"
    <if variable=\"section is #section#\">selected</if>></item>
  </configif-output>
";
         break;
       case "modules":
         break;
      }
      pre += "\n</item>";
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
  werror(" left item \n");
  mixed q =
  catch {
  if( !id->misc->path_info )
    id->misc->path_info = "";
  sscanf( id->misc->path_info, "/%[^/]/", site );
  if(id->misc->variables  && (site == id->misc->variables->sname ) )
    return selected_item( site, roxen.find_configuration( site ), id );
  return "<item title='"+(id->misc->variables->name-"'")+"' href='"+
         DOTDOT( 2 )+(id->misc->variables->sname-"'")+"/'></item>";
  };
  werror( describe_backtrace( q ) );
  return "";
}
