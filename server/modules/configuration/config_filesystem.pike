// A filesystem for the roxen configuration interface.
#include <module.h>
#include <stat.h>

inherit "modules/filesystems/filesystem.pike";

constant module_type = MODULE_LOCATION;
constant module_name = "Configration Filesystem";
constant module_doc = "This filesystem serves the configuration interface";
constant module_unique = 1;


string template_for( string f, object id )
{
  string current_dir = query_location()+dirname(f+"foo")+"/";
  array cd = current_dir / "/";
  int i = sizeof(cd);
  while( i-- )
    if( id->conf->stat_file( cd[..i]*"/"+"/template", id ) )
      return cd[..i]*"/"+"/template";
}

mixed stat_file( string f, object id )
{
  f = utf8_to_string( f );
  return ::stat_file( f, id );
}

constant base ="<use file='%s' /><tmpl title='%s'>%s</tmpl>";

int count = time();
string idi_netscape( string what )
{
  return "/("+(count++)+")"+what;
}

mixed find_dir( string f, object id )
{
  f = utf8_to_string( f );
  return ::find_dir( f, id );
}

mixed find_file( string f, object id )
{
  string locale;

  id->misc->more_mode = 1;

  f = utf8_to_string( f );

  if( (f == "") && !id->misc->pathinfo )
    return http_redirect(fix_relative( "/standard/", id ), id );

  while( strlen( f ) && (f[0] == '/' ))
    f = f[1..];
  
  if( sscanf( f, "%[^/]/%s", locale, f ) != 2 )
    locale = f;

  mixed retval = ::find_file( locale+"/"+f, id );

  if( retval == 0 )
    retval = ::find_file( "standard/"+f, id );
  
  if( intp( retval ) || mappingp( retval ) )
    return retval;

  if( id->variables["content-type"] )
    return http_file_answer( retval, id->variables["content-type"] );

  // add template to all rxml/html pages...
  string type = id->conf->type_from_filename( id->not_query );

  switch( type )
  {
   case "text/html":
   case "text/rxml":
     string data =  retval->read(), title="", pre;
     string title = "";
     if( 3 == sscanf( data, "%s<title>%s</title>%s", pre, title, data ) )
       data = pre+data;

     string tmpl = (template_for(locale+"/"+f,id) ||
                    template_for("standard/"+f,id));

     data = sprintf(base,tmpl,title,data);

     if( locale != "standard" )    roxen.set_locale( locale );
     if( !id->misc->stat )
       id->misc->stat = allocate(10);
     id->misc->stat[ ST_MTIME ] = time();
     if(!id->misc->defines)
       id->misc->defines = ([]);
     id->misc->defines[" _stat"] = id->misc->stat;
     retval = http_rxml_answer( data, id );
     retval->data = string_to_utf8( retval->data );
     retval->extra_heads["Content-type"]
       = "text/html; charset=utf-8";

     if( locale != "standard" )
       roxen.set_locale( "standard" );
  }

  foreach( glob( "goto_*", indices( id->variables )  ), string q )
    if( sscanf( q, "goto_%s.x", q ) )
      return http_redirect( fix_relative( q, id ), id );

  return retval;
}
