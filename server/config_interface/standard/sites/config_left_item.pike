inherit "roxenlib";

string dotdot( RequestID id, int n )
{
  while( id->misc->orig ) id = id->misc->orig;

  int depth = sizeof( (id->not_query+(id->misc->path_info||"") )/"/" )-n;

  depth -= 3;
  string dotodots = depth>0?(({ "../" })*depth)*"":"./";

  return combine_path( id->not_query+id->misc->path_info, dotodots );
}


#define DOTDOT( X ) dotdot( id, X )

string selected_item( string q, roxen.Configuration c, RequestID id, string module )
{
  while ( id->misc->orig )
    id = id->misc->orig;

  string subsel = "";
  string cfg = q;

  sscanf( id->misc->path_info, "/"+q+"/%[^/]", subsel );

  string pre = ("<gbutton frame-image=&usr.left-buttonframe; href='/"+id->misc->cf_locale+"/sites' "
                "width=150 bgcolor=&usr.left-buttonbg; icon_src=&usr.selected-indicator; "
                "align_icon=left preparse>&locale.sites;</gbutton><br>"
                "<gbutton frame-image=&usr.left-buttonframe; width=150 "+(subsel == ""?"bgcolor=&usr.left-selbuttonbg;":
			      "bgcolor=&usr.left-buttonbg; href='"+id->not_query+"/"+replace(c->name, " ", "%20" )+"/' ")+
                " icon_src=&usr.selected-indicator; align_icon=left>"+
                c->query_name()+"</gbutton><br><br>");

  array sub = ({ "settings", "modules" });
//   if( subsel == "modules" )
//     sub = reverse(sub);

  foreach( sub, string q )
  {
    if( subsel == q )
    {
      pre += ("<gbutton frame-image=&usr.left-buttonframe; icon_src=&usr.selected-indicator; align_icon=left "
              "width=150 preparse bgcolor=&usr.left-selbuttonbg; href='"+DOTDOT(3)+q+"/'>"
              "&locale."+q+";</gbutton><br>");

      string url = id->not_query + id->misc->path_info;
      id->variables->_config = cfg;
      id->variables->_url = url;

      switch( q )
      {
       case "settings":
         break;

       case "modules":
	 string tmp="";
	 sscanf(id->not_query, "%ssite.html", tmp);
         string qurl = url;
         if( search( qurl, "!" ) != -1 )
           qurl += "../";
         array variables = ({});
         object c = roxen->find_configuration(cfg);
         if( !c->inited )
           c->enable_all_modules();
         foreach( indices(c->modules), string q )
         {
           object mi = roxen->find_module( q );
           foreach( sort(indices(c->modules[q]->copies)), int i )
           {
             variables +=
             ({
               ([
                 "sname":q+"!"+i,
                 "name":mi->get_name()+(i?" # "+i:""),
                 "doc":mi->get_description(),
               ]),
             });
           }
         }
         sort( variables->name, variables );

         foreach( variables, mapping data )
         {
           if( data->sname != module )
             pre += ("\n<img src=\"/internal-roxen-unit\" width=12 height=12>"
		     "<a href=\""+qurl+data->sname+
                     "/\">"+replace(data->name, " ", "&nbsp;")+"</a><br>\n");
           else
             pre += ("\n<img src=\"&usr.selected-indicator;\" width=12 height=12>"
		     "<b>" + replace(data->name, " ", "&nbsp;") + "</b><br>\n");
         }
	 pre+=sprintf("<br><gbutton frame-image=&usr.left-buttonframe; width=150 bgcolor=&usr.left-buttonbg; preparse href='"+tmp+
		      "add_module.pike?config=%s'> "
		      "&locale.add_module; </gbutton>",
		      http_encode_string( c->name ) )+
              sprintf("<br><gbutton frame-image=&usr.left-buttonframe; width=150 bgcolor=&usr.left-buttonbg; preparse href='"+tmp+
		   "drop_module.pike?config=%s'> "
		   "&locale.drop_module; </gbutton><br>",
		   http_encode_string( c->name ));


         break;
      }
      pre += "\n";
    } else
      pre += ("<gbutton frame-image=&usr.left-buttonframe; preparse bgcolor=&usr.left-buttonbg; "
              " width=150 href='"+DOTDOT(3)+q+"/'>"
              "&locale."+q+";</gbutton><br>");
  }
  pre += "</item>";
  return pre;
}

string parse( RequestID id )
{
  string site;
  if( !id->misc->path_info ) id->misc->path_info = "";
  sscanf( id->misc->path_info, "/%[^/]/", site );
  array(string) path = ((id->misc->path_info||"")/"/")-({""});

  return selected_item( site, roxen.find_configuration( site ), id,
 			(sizeof(path)>=3)?path[2]:"");
}
