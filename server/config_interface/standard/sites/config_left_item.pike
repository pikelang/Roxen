#include <config_interface.h>
#include <roxen.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

string dotdot( RequestID id, int n )
{
  while( id->misc->orig ) id = id->misc->orig;

  int depth = sizeof( (id->not_query+(id->misc->path_info||"") )/"/" )-n;

  depth -= 3;
  string dotodots = depth>0?(({ "../" })*depth)*"":"./";

  return combine_path( id->not_query+id->misc->path_info, dotodots );
}


#define DOTDOT( X ) dotdot( id, X )

string selected_item( string q, roxen.Configuration c, RequestID id, 
                      string module )
{
  while ( id->misc->orig )
    id = id->misc->orig;

  string subsel = "";
  string cfg = q;

  sscanf( id->misc->path_info, "/"+q+"/%[^/]", subsel );

  string pre = 
         ("<gbutton frame-image='&usr.left-buttonframe;' href='/"+id->misc->cf_locale+"/sites/' "
          "width='150' bgcolor='&usr.left-buttonbg;' icon_src='&usr.selected-indicator;' "
          "align_icon='left' preparse=''>"+LOCALE(213, "Sites")+"</gbutton><br />"
          "<gbutton frame-image='&usr.left-buttonframe;' width='150' "+
          (subsel == "" ?
           "bgcolor='&usr.left-selbuttonbg;'" : "bgcolor='&usr.left-buttonbg;'") +
          " href='"+id->not_query+"/"+replace(c->name, " ", "%20" )+"/' "
          " icon_src='&usr.selected-indicator;' align_icon='left'>"+
          c->query_name()+"</gbutton><br><br>");

  array sub = ({ ({ "settings", LOCALE(256, "Settings") }),
 		 ({ "",  LOCALE(257, "Modules") }),
              });
//   if( subsel == "modules" )
//     sub = reverse(sub);

  string noendslash( string what )
  {
    while( strlen( what ) && what[ -1 ] == '/' )
      what = what[..strlen(what)-2];
    return what;
  };

  foreach( sub, array q )
  {
    if( subsel == q[0]  || (q[0] == "" && (search(subsel,"!")!=-1)))
    {
      pre += ("<gbutton frame-image='&usr.left-buttonframe;' "
              "icon_src='&usr.selected-indicator;' align_icon='left' "
              "width='150' preparse='' bgcolor='&usr.left-selbuttonbg;'"
              " href='"+(noendslash(DOTDOT(3)+q[0]))+"/'>"
              +q[1]+"</gbutton><br />\n");

      string url = id->not_query + id->misc->path_info;
      id->variables->_config = cfg;
      id->variables->_url = url;

      switch( q[0] )
      {
       case "settings":
         break;

       default:
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

	 pre += "<table cellspacing=0 cellpadding=0>\n";

         foreach( variables, mapping data )
         {
           if( data->sname != module )
             pre += ("\n<tr><td valign=top><img src=\"&usr.item-indicator;\" width=12 height=12></td>"
		     "<td><a href=\""+qurl+data->sname+
                     "/\">"+Roxen.html_encode_string(data->name)+"</a></td></tr>\n");
           else
             pre += ("\n<tr><td valign=top><img src=\"&usr.selected-indicator;\" width=12 height=12></td>"
		     "<td><b>" + Roxen.html_encode_string(data->name) + "</b></td></tr>\n");
         }

	 pre += "</table>\n";

         if( config_perm( "Add Module" ) )
         {
           pre+=sprintf("<br />\n<gbutton frame-image='&usr.left-buttonframe;' "
                        "width='150' bgcolor='&usr.left-buttonbg;' preparse='' "
                        "href='"+tmp+
                        "add_module.pike?config=%s'> "
                        +LOCALE(258, "Add module")+" </gbutton>",
                        Roxen.http_encode_string( c->name ) )+
                             sprintf("<br />\n<gbutton frame-image='&usr.left"
                                     "-buttonframe;' width='150' bgcolor='&usr."
                                     "left-buttonbg;' preparse='' href='"+tmp+
                                     "drop_module.pike?config=%s'> "
                                     +LOCALE(259, "Drop module")+
                                     " </gbutton><br />\n",
                                     Roxen.http_encode_string( c->name ));
         }

         break;
      }
      pre += "\n";
    } else
      pre += ("<gbutton frame-image='&usr.left-buttonframe;' preparse='' "
              "bgcolor='&usr.left-buttonbg;' width='150' "
              "href='"+noendslash(DOTDOT(3)+q[0])+"/'>"
              +q[1]+"</gbutton><br />");
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
 			(sizeof(path)>=2)?path[1]:"");
}
