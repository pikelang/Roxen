// A filesystem for the roxen configuration interface.
#include <module.h>
#include <stat.h>
#include <roxen.h>

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
  mixed ret;
  f = utf8_to_string( f );
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
  f = utf8_to_string( f );
  return ::find_dir( f, id );
}

object settings = roxen.ConfigIFCache( "settings" );

class ConfigurationSettings
{
  mapping variables = ([ ]);
  string name, host;

  mapping locs = ([]);
  void deflocaledoc( string locale, string variable, 
                     string name, string doc, mapping|void translate)
  {
    if(!locs[locale] )
      locs[locale] = master()->resolv("Locale")["Roxen"][locale]
                   ->register_module_doc;
    if(!locs[locale])
      report_debug("Invalid locale: "+locale+". Ignoring.\n");
    else
      locs[locale]( this_object(), variable, name, doc, translate );
  }

  void set( string what, mixed to  )
  {
    variables[ what ][ VAR_VALUE ] = to;
    remove_call_out( save );
    call_out( save, 0.1 );
  }

  void defvar( string v, mixed val, int type, mapping q, mapping d,
               array misc, mapping translate )
  {
    if( !variables[v] )
    {
      variables[v]                     = allocate( VAR_SIZE );
      variables[v][ VAR_VALUE ]        = val;
    }
    variables[v][ VAR_TYPE ]         = type & VAR_TYPE_MASK;
    variables[v][ VAR_DOC_STR ]      = d->english;
    variables[v][ VAR_NAME ]         = q->english;
    variables[v][ VAR_MISC ]         = misc;
    type &= (VAR_EXPERT | VAR_MORE);
    variables[v][ VAR_CONFIGURABLE ] = type?type:1;
    foreach( indices( q ), string l )
      deflocaledoc( l, v, q[l], d[l], (translate?translate[l]:0));
  }

  void query( string what )
  {
    if( variables[ what ] )
      return variables[what][VAR_VALUE];
  }
  
  void save()
  {
    werror("Saving settings for "+name+"\n");
    settings->set( name, variables );
  }

  void create( string _name )
  {
    name = _name;
    variables = settings->get( name ) || ([]);
    defvar( "docs", 1, TYPE_FLAG,
            ([
              "english":"Show documentation",
              "svenska":"Visa dokumentation",
            ]),
            ([
              "english":"Show the variable documentation.",
              "svenska":"Visa variabeldokumentationen.",
            ]),
            0,0 );

    defvar( "more_mode", 0, TYPE_FLAG,
            ([
              "english":"Show advanced configuration options",
              "svenska":"Visa avancerade val",
            ]), 
            ([ "english":"Show all possible configuration options, not only "
               "the ones that are most often changed.",
               "svenska":"Visa alla konfigureringsval, inte bara de som "
               "oftast ändras" ]),
            0, 0 );

    defvar( "devel_mode", 0, TYPE_FLAG,
            ([
              "english":"Show developer options and actions",
              "svenska":"Visa utvecklingsval och funktioner",
            ]),
            ([ 
              "english":"Show settings and actions that are not normaly "
              "useful for non-developer users. If you develop your own "
              "roxen modules, this option is for you",
              "svenska":"Visa inställningar och funktioner som normaly "
              "sätt inte är intressanta för icke-utvecklare. Om du utvecklar "
              "egna moduler så är det här valet för dig"
            ]), 0,0 );
  }
}

mapping settings_cache = ([ ]);

void get_context( string ident, string host, object id )
{
  if( settings_cache[ ident ] )
    id->misc->config_settings = settings_cache[ ident ];
  else
    id->misc->config_settings = settings_cache[ ident ] 
                              = ConfigurationSettings( ident );
  id->misc->config_settings->host = host;
}

mapping logged_in = ([]);
mixed find_file( string f, object id )
{
  string locale;
  string identifier = (id->auth && id->auth[1] ) ? id->auth[1] : "anonymous";
  string host;


  if( array h = gethostbyaddr( id->remoteaddr ) )
    host = h[0];
  else
    host = id->remoteaddr;

  
  if( (time() - logged_in[ identifier ]) > 3600 )
    report_notice(LOW_LOCALE->config_interface->
                  admin_logged_on( identifier,host+" ("+id->remoteaddr+")" ));

  logged_in[ identifier ] = time();
  get_context( identifier, host, id );
  
  id->misc->more_mode = 1;

  if( !id->misc->path_decoded )
    id->not_query = f = utf8_to_string( f );

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
