// A filesystem for the roxen configuration interface.
#include <module.h>
#include <stat.h>
#include <roxen.h>

inherit "module";
inherit "roxenlib";

constant module_type = MODULE_LOCATION;
constant module_name = "Configuration Filesystem";
constant module_doc = "This filesystem serves the configuration interface";
constant module_unique = 1;
constant cvs_version = "$Id: config_filesystem.pike,v 1.21 2000/02/02 02:05:38 per Exp $";

constant path = "config_interface/";

object charset_encoder, charset_decoder;

string template_for( string f, object id )
{
  string current_dir = query_location()+dirname(f+"foo")+"/";
  array cd = current_dir / "/";
  int i = sizeof(cd);
  while( i-- )
    if( id->conf->stat_file( cd[..i]*"/"+"/template", id ) )
      return cd[..i]*"/"+"/template";
}

string real_file( mixed f, mixed id )
{
  if(stat_file( f, id ))
    return path + f;
}

mixed stat_file( string f, object id )
{
  mixed ret;
  ret = file_stat( path+f );
  if( !ret )
  {
    sscanf( f, "%*[^/]/%s", f );
    f = "standard/"+f;
    ret = file_stat( path+f );
  }
  return ret;
}

constant base ="<use file='%s' /><tmpl title='%s'>%s</tmpl>";

mixed find_dir( string f, object id )
{
  return get_dir( path+f );
}

mixed find_file( string f, object id )
{
  string locale;

  id->since = 0;
  if( !id->misc->request_charset_decoded )
  {
    // We only need to decode f (and id->not_query)  here,
    // since there is no variables (if there were, the
    // request would have been automatically decoded).
    id->misc->request_charset_decoded = 1;

    if( charset_decoder )
    {
      f = charset_decoder->clear()->feed( f )->drain();
      id->not_query = charset_decoder->clear()->feed( id->not_query )->drain();
    }
    else
    {
      f = utf8_to_string( f );
      id->not_query = utf8_to_string( id->not_query );
    }
  }

  if( !id->misc->config_user )
    return http_auth_required( "Roxen configuration" );

  if( (f == "") && !id->misc->pathinfo )
    return http_redirect(fix_relative( "/standard/", id ), id );

  while( strlen( f ) && (f[0] == '/' ))
    f = f[1..];

  sscanf( f, "%[^/]/%*s", locale );

  id->misc->cf_locale = locale;

  array stat = stat_file( f, id );
  if( !stat ) // No such luck...
    return 0;
  switch( stat[ ST_SIZE ] )
  {
   case -1:
   case -3:
   case -4:
     return 0; /* Not suitable (device or no file) */
   case -2: /* directory */
     return -1;
   default:
     if (f[-1] == '/')
       return 0;	/* Let the PATH_INFO module handle it */
  }
  id->realfile = path+replace(f,locale,"standard");

  mixed retval = Stdio.File( id->realfile, "r" );

  if( id->variables["content-type"] )
    return http_file_answer( retval, id->variables["content-type"] );

  // add template to all rxml/html pages...
  string type = id->conf->type_from_filename( id->not_query );

//   werror( f + " is " + type + "\n");

  if( locale != "standard" )
    roxen.set_locale( locale );

  switch( type )
  {
   case "text/html":
     string data =  retval->read(), title="", pre;
     string title = "";
     if( 3 == sscanf( data, "%s<title>%s</title>%s", pre, title, data ) )
       data = pre+data;

     string tmpl = (template_for(locale+"/"+f,id) ||
                    template_for("standard/"+f,id));

     data = sprintf(base,tmpl,title,data);

     if( !id->misc->stat )
       id->misc->stat = allocate(10);
     id->misc->stat[ ST_MTIME ] = time();
     if(!id->misc->defines)
       id->misc->defines = ([]);
     id->misc->defines[" _stat"] = id->misc->stat;
     retval = http_rxml_answer( data, id );
     if(charset_encoder)
     {
       retval->data = charset_encoder->clear()->feed( retval->data )->drain();
       retval->extra_heads["Content-type"]
	 = "text/html; charset="+QUERY(encoding);
     } else {
       retval->data = string_to_utf8( retval->data );
       retval->extra_heads["Content-type"]
	 = "text/html; charset=utf-8";
     }
     NOCACHE();
     retval->stat = 0;
     retval->len = strlen( retval->data );
     retval->expires = time();
     if( locale != "standard" )
       roxen.set_locale( "standard" );
  }

  foreach( glob( "cf_goto_*", indices( id->variables )  ), string q )
    if( sscanf( q, "cf_goto_%s.x", q ) )
    {
      while( id->misc->orig ) id = id->misc->orig;
      q = fix_relative( q, id );
      if( charset_encoder )
        q = charset_encoder->clear()->feed( q )->drain();
      else
        q = string_to_utf8( q );
      return http_redirect( q, id );
    }
  return retval;
}

void start(int n, object cfg)
{
  if( cfg )
  {
    charset_encoder = charset_decoder = 0;
    cfg->add_modules(({
      "awizard",      "config_tags", "config_userdb","contenttypes",
      "indexfiles",  "gbutton",     "wiretap",      "graphic_text",
      "obox",         "piketag",     "pathinfo",     "pikescript",
      "rxmlparse",    "rxmltags",    "tablist"
    }));
    catch {
      charset_encoder = Locale.Charset.encoder(QUERY(encoding), "?");
      charset_decoder = Locale.Charset.decoder(QUERY(encoding));
    };
  }
}

void create()
{
  defvar("encoding", "UTF-8", "Character encoding", TYPE_STRING,
	 "Send pages to client in this character encoding.");
  defvar( "location", "/", "Mountpoint", TYPE_LOCATION,
          "Usually / is a good idea" );
}
