// This is a roxen module. Copyright © 1999 - 2000, Roxen IS.
//
// A filesystem for the roxen administration interface.
#include <module.h>
#include <stat.h>
#include <roxen.h>

inherit "module";
inherit "roxenlib";

//<locale-token project="roxen_config">LOCALE</locale-token>
USE_DEFERRED_LOCALE;
#define LOCALE(X,Y)	_DEF_LOCALE("roxen_config",X,Y)

constant module_type = MODULE_LOCATION;
constant module_name = "Configuration Filesystem";
constant module_doc = "This filesystem serves the administration interface";
constant module_unique = 1;
constant cvs_version = "$Id: config_filesystem.pike,v 1.46 2000/08/21 12:31:35 per Exp $";

constant path = "config_interface/";
string encoding = "iso-8859-1";         // charset for pages
object charset_decoder;

string template_for( string f, object id )
{
  string current_dir = query_location()+dirname(f+"foo")+"/";
  array cd = current_dir / "/";
  int i = sizeof(cd);
  while( i-- )
    if( id->conf->stat_file( cd[..i]*"/"+"/template", id ) )
      return cd[..i]*"/"+"/template";
}

// Try finding the locale-specific file first.
// Returns ({ realfile, statinfo }).
array(string|array) low_stat_file(string locale, string f, object id)
{
  foreach( ({ "../local/"+path, path }), string path )
  {
    array ret;
    if (!f) 
    {
      ret = low_stat_file(locale, "", id);

      if (ret) return ret;
      // Support stuff like /template  =>  /standard/template
      f = locale;
      locale = "standard";
    }
    if (locale == "standard")
      locale = roxen.locale->get();
    string p;
    if( strlen( f ) )
      f = "/"+f;
    ret = file_stat(p = path+locale+f);
    if (!ret && (locale != "standard")) 
      ret = file_stat(p = path+"standard"+f);
    if( ret )
      return ({ p, ret });
  }
}

string real_file( mixed f, mixed id )
{
  while( strlen( f ) && (f[0] == '/' ))
    f = f[1..];

  if (f == "") return path;

  string locale;
  string rest;

  sscanf(f, "%[^/]/%s", locale, rest);

  array(string|array) stat_info = low_stat_file(locale, rest, id);
  return stat_info && stat_info[0];
}

array stat_file( string f, object id )
{
  while( strlen( f ) && (f[0] == '/' ))
    f = f[1..];

  if (f == "") return file_stat(path);

  string locale;
  string rest;

  sscanf(f, "%[^/]/%s", locale, rest);

  array(string|array) ret = low_stat_file(locale, rest, id);
  return ret && ret[1];
}

constant base ="<use file='%s' /><tmpl title='%s'>%s</tmpl>";

mixed find_dir( string f, object id )
{
  while( strlen( f ) && (f[0] == '/' ))
    f = f[1..];
  
  if (f == "") {
#if constant(Locale.list_languages)
    return Locale.list_languages("roxen_config");
#else
    return RoxenLocale.list_languages("roxen_config");
#endif
  }

  string locale;
  string rest;

  sscanf(f, "%[^/]/%s", locale, rest);

  multiset languages;
#if constant(Locale.list_languages)
    languages=(multiset)Locale.list_languages("roxen_config");
#else
    languages=(multiset)RoxenLocale.list_languages("roxen_config");
#endif

  if (rest || languages[locale]) {
    return get_dir(path + "standard/" + (rest || ""));
  }
  return get_dir(path + "standard/" + locale);
}

mixed find_file( string f, object id )
{
  id->set_output_charset( encoding );

  id->since = 0;
  if( !id->misc->request_charset_decoded )
  {
    // We only need to decode f (and id->not_query)  here,
    // since there is no variables (if there were, the
    // request would have been automatically decoded).
    id->misc->request_charset_decoded = 1;

    if( charset_decoder )
    {
      void decode_variable( string v )
      {
        id->variables[v] = charset_decoder->clear()->
                         feed(id->variables[v])->drain();
      };
      f = charset_decoder->clear()->feed( f )->drain();
      id->not_query = charset_decoder->clear()->feed( id->not_query )->drain();
      map( (indices)id->variables, decode_variable );
    }
    else
    {
      void decode_variable( string v )
      {
        id->variables[v] = utf8_to_string( id->variables[v] );
      };
      f = utf8_to_string( f );
      id->not_query = utf8_to_string( id->not_query );
      map( (indices)id->variables, decode_variable );
    }
  }

  if( !id->misc->config_user )
    return http_auth_required( "Roxen configuration" );
  if( (f == "") && !id->misc->pathinfo )
    return http_redirect(fix_relative( "/standard/", id ), id );

  while( strlen( f ) && (f[0] == '/' ))
    f = f[1..];

  string locale;
  string rest;

  sscanf(f, "%[^/]/%s", locale, rest);

  id->misc->cf_locale = locale;

#ifdef __NT__
  if(strlen(rest) && rest[-1]=='/') 
    rest = rest[..strlen(rest)-2];
#endif
  array(string|array) stat_info = low_stat_file( locale, rest, id );
  if( !stat_info ) // No such luck...
    return 0;
  [string realfile, array stat] = stat_info;
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
  id->realfile = realfile;


  mixed retval = Stdio.File( realfile, "r" );

  if( id->variables["content-type"] )
    return http_file_answer( retval, id->variables["content-type"] );

  // add template to all rxml/html pages...
  string type = id->conf->type_from_filename( id->not_query );

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

     if(tmpl)
       data = sprintf(base,tmpl,title,data);

     if( !id->misc->stat )
       id->misc->stat = allocate(10);
     id->misc->stat[ ST_MTIME ] = time(1);
     if(!id->misc->defines)
       id->misc->defines = ([]);
     id->misc->defines[" _stat"] = id->misc->stat;
     retval = http_rxml_answer( data, id );
     NOCACHE();
     retval->stat = 0;
     retval->len = strlen( retval->data );
     retval->expires = time(1);
     if( locale != "standard" ) 
       roxen.set_locale( "standard" );
  }

  foreach( glob( "cf_goto_*", indices( id->variables ) - ({ 0 }) ), string q )
    if( sscanf( q, "cf_goto_%s.x", q ) )
    {
      while( id->misc->orig ) id = id->misc->orig;
      q = fix_relative( q, id );
      return http_redirect( q, id );
    }
  return retval;
}

void start(int n, Configuration cfg)
{
  encoding = query( "encoding" );
  if( cfg )
  {
    charset_decoder = 0;
    cfg->add_modules(({
      "config_tags", "config_userdb",   "contenttypes",    "indexfiles",
      "gbutton",     "wiretap",         "graphic_text",    "pathinfo",
      "pikescript",  "translation_mod", "rxmlparse",        "rxmltags",
      "tablist",     "update"
    }));
    catch 
    {
      charset_decoder = Locale.Charset.decoder( encoding );
    };
  }
}

void create()
{
  defvar("encoding", "UTF-8", LOCALE(262,"Character encoding"), TYPE_STRING,
	 LOCALE(263,"Send pages to client in this character encoding."));
  defvar( "location", "/", LOCALE(264,"Mountpoint"), TYPE_LOCATION,
          LOCALE(265,"Usually / is a good idea") );
}
