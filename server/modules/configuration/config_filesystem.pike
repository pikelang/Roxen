// A filesystem for the roxen configuration interface.
#include <module.h>
#include <stat.h>
#include <roxen.h>

inherit "modules/filesystems/filesystem.pike";

constant module_type = MODULE_LOCATION;
constant module_name = "Configration Filesystem";
constant module_doc = "This filesystem serves the configuration interface";
constant module_unique = 1;

static object charset_encoder, charset_decoder;

string template_for( string f, object id )
{
  string current_dir = query_location()+dirname(f+"foo")+"/";
  array cd = current_dir / "/";
  int i = sizeof(cd);
  while( i-- )
    if( id->conf->stat_file( cd[..i]*"/"+"/template", id ) )
      return cd[..i]*"/"+"/template";
}

static string revert_browser_encoding( string s )
{
  return charset_decoder?
    charset_decoder->clear( )->feed( s )->drain( ) :
    utf8_to_string( s );
}

mixed stat_file( string f, object id )
{
  mixed ret;
  f = decode_id_from_browser_encoding( f, id );
  ret = ::stat_file( f, id );
  if( !ret )
  {
    sscanf( f, "%*[^/]/%s", f );
    f = "standard/"+f;
    ret = ::stat_file( f, id );
  }
  return ret;
}

constant base ="<use file='%s' /><tmpl title='%s'>%s</tmpl>";

int count = time();
string idi_netscape( string what )
{
  return "/("+(count++)+")"+what;
}

mixed find_dir( string f, object id )
{
  f = decode_id_from_browser_encoding( f, id );
  return ::find_dir( f, id );
}

string decode_id_from_browser_encoding( string f, object id )
{
  if( !id->misc->path_decoded )
  {
    id->misc->path_decoded = 1;
    f = revert_browser_encoding( f );
    id->not_query = revert_browser_encoding( id->not_query );
    mapping new_variables = ([]);
    foreach( indices(id->variables), string q )
      new_variables[ revert_browser_encoding( q ) ] = 
               revert_browser_encoding( id->variables[q] );
    id->variables = new_variables;
    multiset new_prestate = (<>);
    foreach( indices( id->prestate ), string q )
      new_prestate[revert_browser_encoding( q ) ]=1;
    id->prestate = new_prestate;
  }
  return f;
}


mixed find_file( string f, object id )
{
  string locale;

  if( !id->misc->config_user )
    return http_auth_required( "Roxen configuration" );

  f = decode_id_from_browser_encoding( f, id );

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
     if(charset_encoder) {
       retval->data = charset_encoder->clear()->feed( retval->data )->drain();
       retval->extra_heads["Content-type"]
	 = "text/html; charset="+QUERY(encoding);
     } else {
       retval->data = string_to_utf8( retval->data );
       retval->extra_heads["Content-type"]
	 = "text/html; charset=utf-8";
     }
     if( locale != "standard" )
       roxen.set_locale( "standard" );
  }

  foreach( glob( "goto_*", indices( id->variables )  ), string q )
    if( sscanf( q, "goto_%s.x", q ) )
    {
      if( charset_encoder )
        q = charset_encoder->clear()->feed( q )->drain();
      else
        q = string_to_utf8( q );
      return http_redirect( fix_relative( q, id ), id );
    }
  return retval;
}

void start()
{
  ::start();
  charset_encoder = charset_decoder = 0;
  catch {
    charset_encoder = Locale.Charset.encoder(QUERY(encoding), "?");
    charset_decoder = Locale.Charset.decoder(QUERY(encoding));
  };
}

void create()
{
  ::create();

  defvar("encoding", "UTF-8", "Character encoding", TYPE_STRING,
	 "Send pages to client in this character encoding.");
}
