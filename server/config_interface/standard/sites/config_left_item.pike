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

string selected_item( string q, roxen.Configuration c, RequestID id )
{
  while ( id->misc->orig )
    id = id->misc->orig;

  string subsel;
  string cfg = q;

  sscanf( id->misc->path_info, "/"+q+"/%[^/]", subsel );

  string pre = (("<a href='"+DOTDOT(1)+(q-"'")+"/")+"'><b><font size=+2>"+c->name+"</font></b></a><br>");

  array sub = ({ "modules", "settings", });
  if( subsel == "modules" )
    sub = reverse(sub);

  foreach( sub, string q )
  {
    if( subsel == q )
    {
      pre += ("&nbsp;<cf-locale get="+q+"><br>\n");
      string url = id->not_query + id->misc->path_info;
      id->variables->_config = cfg;
      id->variables->_url = url;

      switch( q )
      {
       case "settings":
         break;

       case "modules":
         string qurl = url;
         if( search( qurl, "!" ) != -1 )
           qurl += "../";
         array variables = ({});
         object c = roxen->find_configuration(cfg);
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
           if( data->sname == id->variables->module )
             pre += ("\n&nbsp;&nbsp;<a href=\""+qurl+data->sname+
                     "/\">"+replace(data->name, " ", "&nbsp;")+"</a><br>\n");
           else 
             pre += ("\n&nbsp;&nbsp;<a href=\""+qurl+data->sname+
                     "/\"><b>"+replace(data->name, " ", "&nbsp;")+"</b></a><br>\n");
         }
         break;
      }
      pre += "\n";
    } else
      pre += ("&nbsp;<a href='"+DOTDOT(3)+q+"/'><cf-locale get="+q+"></a><br>");
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
}
