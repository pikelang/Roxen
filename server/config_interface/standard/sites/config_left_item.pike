inherit "roxenlib";

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
                "title='"+(c->name-"'") +
                "' href='"+DOTDOT(2)+(q-"'")+"/'>");

  sscanf( id->misc->path_info, "/"+q+"/%[^/]", subsel );
  foreach( ({ "modules", "settings", }), string q )
  {
    if( subsel == q )
    {
      pre += ("<item selected title='<cf-locale get="+q+">' "
              " href='"+DOTDOT(3)+q+"/'>");

      string url = id->not_query + id->misc->path_info;
      id->variables->_config = cfg;
      id->variables->_url = url;

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
         string qurl = url, sel_module="";
         array variables = ({});
         foreach( values(roxen->find_configuration(cfg)->otomod), string q )
         {
           object mi = roxen->find_module((q/"#")[0]);
           variables += 
           ({
             ([
               "sname":replace(q, "#", "!"),
               "name":mi->get_name()+((int)reverse(q)?" # "+ (q/"#")[1]:""),
               "doc":mi->get_description(),
             ]),
           });
         }
         sort( variables->name, variables );
         if( sscanf( id->misc->path_info, 
                     "/"+cfg+"/"+subsel+"/%[^/]", 
                     id->variables->module ) && strlen(id->variables->module) )
         {
           qurl += "../";
           sel_module = replace( #string "module_variables.html", 
                                   ({"¤_url¤","¤_config¤", "¤module¤" }), 
           ({ url, cfg, (string)id->variables->module }) );
         }

         foreach( variables, mapping data )
         {
           if( data->sname == id->variables->module )
             pre += ("\n<item href=\""+qurl+data->sname+
                     "/\" title=\""+data->name+"\" selected>"+sel_module+
                     "</item>\n");
           else 
             pre += ("\n<item href=\""+qurl+data->sname+
                     "/\" title=\""+data->name+"\"></item>\n");
         }
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
  if( !id->misc->path_info ) id->misc->path_info = "";
  sscanf( id->misc->path_info, "/%[^/]/", site );
  return selected_item( site, roxen.find_configuration( site ), id );
  return "";
}
