#define translate( X ) _translate( (X), id )

string _translate( mixed what, RequestID id )
{
  if( mappingp( what ) )
    if( what[ id->misc->cf_locale ] )
      return what[ id->misc->cf_locale ];
    else
      return what->standard;
  return what;
}

string find_module_doc( string cn, string mn, RequestID id )
{
  Configuration c = roxen.find_configuration( cn );

  if(!c)
    return "";

  RoxenModule m = c->find_module( replace(mn,"!","#") );

  if(!m)
    return "";

  return replace( "<b>"
                  + translate(m->register_module()[1]) + "</b><br /><p>"
                  + translate(m->info()||"") + "</p><p>"
                  + translate(m->status()||"") +"</p><p>"
                  + translate(m->file_name_and_stuff())+"</p>",
                  ({ "/image/", }), ({ "/internal-roxen-" }));
}

string parse( RequstID id )
{
  array q = id->misc->path_info / "/";
  if( sizeof( q ) >= 5 )
    return find_module_doc( q[1], q[3], id );
} 
