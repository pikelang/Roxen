string find_module_doc( string cn, string mn, RequestID id )
{
  Configuration c = core.find_configuration( cn );

  if(!c)
    return "";

  RoxenModule m = c->find_module( replace(mn,"!","#") );

  if(!m)
    return "";

  return "<b>"
         + m->register_module()[1] + "</b><br /><p>"
         + (m->info()||"") + "</p><p>"
         + (m->status()||"") +"</p><p>"
         + m->file_name_and_stuff() +"</p>");
}

string parse( RequstID id )
{
  array q = id->misc->path_info / "/";
  if( sizeof( q ) >= 5 )
    return find_module_doc( q[1], q[3], id );
} 
