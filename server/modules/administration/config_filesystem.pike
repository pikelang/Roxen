// This is a roxen module. Copyright © 1999 - 2001, Roxen IS.
//
// A filesystem for the roxen administration interface.
// NGSERVER: Rename to admin_filesystem.pike
#include <module.h>
#include <stat.h>
#include <admin_interface.h>

inherit "module";

constant module_type = MODULE_LOCATION;
constant module_name = "Administration Interface Filesystem";
constant module_doc  = "This filesystem serves the administration interface";

constant module_unique = 1;
constant cvs_version =
  "$Id: config_filesystem.pike,v 1.125 2004/06/04 08:33:15 _cvs_stephen Exp $";

constant path = "admin_interface/";

object charset_decoder;
Sql.Sql docs;

// NOTE: If we ever want to support more than one template, this
// optimization has to be removed, or at least changed to index on the
// directory of f.
string ctmpl; 
string template_for( string f, object id )
{
  if( ctmpl ) return ctmpl;
  string current_dir = query_location()+dirname(f+"foo")+"/";
  array cd = current_dir / "/";
  int i = sizeof(cd);
  while( i-- )
    if( id->conf->stat_file( cd[..i]*"/"+"/template", id ) )
      return ctmpl = (cd[..i]*"/"+"/template");
}

// Returns ({ realfile, statinfo }).
mapping stat_cache = ([]);
array(string|Stat) low_stat_file(string f, object id)
{
  if( stat_cache[ f ] )
    return stat_cache[ f ];
#ifdef __NT__
  string of = f;
  while(sizeof(f) && f[-1]=='/') 
    f = f[..sizeof(f)-2];
#else
#define of f
#endif

  foreach( ({ "../local/"+path, path }), string path )
  {
    Stat ret;
    string p;
    ret = file_stat( p = path+f );
    if( ret )
        return stat_cache[of] = ({ p, ret });
  }
#ifndef __NT__
#undef of
#endif
}

string real_file( mixed f, mixed id )
{
//   while( sizeof( f ) && (f[0] == '/' ))
//     f = f[1..];

  if (f == "")
    return path;
  if( docs && sscanf( f, "docs/%s", f ) )
    return 0;
  array(string|array) stat_info = low_stat_file(f, id);
  return stat_info && stat_info[0];
}

mapping get_docfile( string f )
{
  array q;
  if( f=="" || f[-1] == '/' )
    return get_docfile( f+"index.html" )||get_docfile( f+"index.xml" );

  if( sizeof(q = docs->query( "SELECT * FROM docs WHERE name=%s",
                              "/"+f )) )
    return q[0];
}



array(int)|Stat stat_file( string f, object id )
{
  if (f == "")
    return file_stat(path);

  if( docs && sscanf( f, "docs/%s", f ) )
    if( mapping rf = get_docfile( f ) )
      return ({ 0555, sizeof(rf->contents), time(), 0, 0, 0, 0 });

  array(string|Stat) ret = low_stat_file(f, id);
  return ret && ret[1];
}

constant base ="<use file='%s'/><tmpl title='%s'>%s</tmpl>";

mixed find_dir( string f, object id )
{
  return get_dir(path + f );
}

mapping logged_in = ([]);
int last_cache_clear_time;
mixed find_file( string f, RequestID id )
{
  int is_docs;
  User user;
  string locale = "standard";
  string encoding;

  if( (time(1) - last_cache_clear_time) > 4 )
  {
    last_cache_clear_time = time(1);
    stat_cache = ([]);
  }

  if( !id->misc->internal_get )
  {
    string host;
//     if( array h = gethostbyaddr( id->remoteaddr ) )
//       host = h[0];
//     else
      host = id->remoteaddr;

    // Patch it in. This is needed for the image-cache authentication handling.
    id->conf->set_userdb_module_cache( ({ core.admin_userdb_module }) );

    if( user = id->conf->authenticate( id, core.admin_userdb_module ) )
    {
      if( !id->misc->cf_theme )
	id->misc->cf_theme = ([]);
      id->misc->cf_theme["user-uid"] = user->name();
      id->misc->cf_theme["user-name"] = user->real_name();
      id->misc->remote_config_host = host;
      id->misc->config_user = user->ruser;
      if( (time(1) - logged_in[ user->name()+host ]) > 1800 )
	report_notice("Administrator logged on as %s from %s.\n",
		      user->name(), host+" ("+id->remoteaddr+")" );
      logged_in[ user->name()+host ] = time(1);
      core.adminrequest_get_context( user->name(), host, id );
    }
    else
    {
      report_notice("Login attempt from %s\n",host);
      return id->conf
	->authenticate_throw( id, "ChiliMoon Administration Interface",
			      core.admin_userdb_module );
    }

    encoding = config_setting( "charset" );
    if( encoding != "utf-8" &&
	encoding != "iso-8859-1")
      catch {
	charset_decoder=Locale.Charset.decoder( encoding );
      };
    else
      charset_decoder = 0;
    id->since = 0;
    catch 
    {
      if( !id->misc->request_charset_decoded && encoding != "iso-8859-1" )
      {
        id->misc->request_charset_decoded = 1;

        if( charset_decoder )
        {
          f = charset_decoder->clear()->feed( f )->drain();
          id->not_query =
	    charset_decoder->clear()->feed( id->not_query )->drain();
          map( indices(id->real_variables),
	       lambda ( string v )
	       {
		 id->real_variables[v] =
		   map( id->real_variables[v],
			lambda ( mixed what ) {
			  return charset_decoder->clear()->feed(what)->drain();
			} );
	       });
        }
        else
        {
          f = utf8_to_string( f );
          id->not_query = utf8_to_string( id->not_query );
          map( indices(id->real_variables),
	       lambda ( string v )
	       {
		 id->real_variables[v]=map( id->real_variables[v], utf8_to_string );
	       } );
        }
      }
    };
  }

  string type="";
  mixed retval;
  catch( locale = (id->misc->language || config_setting( "locale" )) ); 
  
  if( !id->misc->internal_get )
  {
    id->misc->cf_locale = locale;
    if(!id->misc->defines)
      id->misc->defines = ([]);
    id->misc->defines->theme_language = locale;
    id->misc->defines->language = locale;
    // add template to all rxml/html pages...
    if(id->not_query[-1] == '/' )
      type = "text/html";
    else
      type = id->conf->type_from_filename( id->not_query );

    if( locale != "standard" ) 
      core.set_locale( locale );

    if (glob("text*", type))
      id->set_output_charset( encoding );
  }

  if( docs && (sscanf( f, "docs/%s", f ) ) || (f=="docs"))
  {
    if( f == "docs" )
      return Roxen.http_redirect( id->not_query+"/", id );
    if( mapping m = get_docfile( f ) )
    {
      is_docs = 1;
      string data = m->contents;
      m = 0;
      if( type == "text/html" )
      {
        string title;
        sscanf( data, "%*s<title>%s</title>", title );
        sscanf( data, "%*s<br clear=\"all\">%s", data );
        sscanf( data, "%s</body>", data );
        retval = "<topmenu selected='docs' base='"+query_location()+"'/>"
	  "<define container='dox'>"
	  "<if variable='usr.doc-content-box = ?*'>"
	  "<subtablist><st-page>"
	  "<contents/>"
	  "</st-page></subtablist>"
	  "</if>"
	  "<else>"
	  "<contents/>"
	  "</else>"
	  "</define>"
	  "<content>"
	  "<dox>"
	  "<div class='doc'>"
	  +data+
	  "</div>"
	  "</dox>"
	  "</content>";
        if( title )
          retval="<title>: Docs "+Roxen.html_encode_string(title)+"</title>" +
                           retval;
      } else
        retval = data;
    }
  }
  else
  {
    array(string|array) stat_info = low_stat_file( f, id );
    if( !stat_info ) // No such luck...
      return 0;

    [string realfile, array stat] = stat_info;
    switch( stat[ ST_SIZE ] )
    {
     case -1:  case -3: case -4:
       return 0; /* Not suitable (device or no file) */
     case -2: /* directory */
       return -1;
    }
    id->realfile = realfile;
    retval = Stdio.File( realfile, "r" );
    if( id->misc->internal_get )
      return retval;
  }

#ifdef DEBUG
  if( id->variables["content-type"] )
    return Roxen.http_file_answer( retval, id->variables["content-type"] );
#endif
  
  if( !retval )
    return 0;

  if( type  == "text/html" )
  {
    string data, title, pre;
    title = " "+Roxen.http_decode_string((id->raw_url/"?")[0]);

    if( stringp( retval ) )
      data = retval;
    else 
      data = retval->read();

    if( 3 == sscanf( data, "%s<title>%s</title>%s", pre, title, data ) )
      data = pre+data;

    string tmpl = template_for(f,id);

    if(tmpl)
      data = sprintf(base,tmpl,title,data);

    if( !id->misc->stat )
      id->misc->stat = allocate(10);

    id->misc->stat[ ST_MTIME ] = time(1);
    if(!id->misc->defines)
      id->misc->defines = ([]);
    id->misc->defines[" _stat"] = id->misc->stat;
     
    mixed error;
    error = catch( retval = Roxen.http_rxml_answer( data, id ) );
    if( locale != "standard" )
      core.set_locale( "standard" );
    if( error )
      throw( error );
    
    if(!is_docs)
    {
      NOCACHE();
      retval->expires = time(1);
    }
    retval->stat = 0;
    retval->len = sizeof( retval->data );

    if( id->method != "GET" && id->real_variables->__redirect )
    {
      while( id->misc->orig )
	id = id->misc->orig;
      string url = Roxen.http_decode_string(id->raw_url);
      if( id->misc->request_charset_decoded )
	if( charset_decoder )
	  url = charset_decoder()->clear()->feed( url )->drain();
	else
	  url = utf8_to_string( url );
      url+="?rv="+random(471187)->digits(32);
      if( id->real_variables->section )
	url += "&section="+id->real_variables->section[0];
      retval = Roxen.http_redirect( url, id );
    }
  } else {
    // Most likely cacheable for quite a while.
    id->misc->cacheable = 100000;	// 2 days, 4:46:40
  }
  if( stringp( retval ) )
    retval = Roxen.http_string_answer( retval, type );
  return retval;
}

void start(int n, Configuration cfg)
{
  if( cfg )
  {
    if (cfg->query ("compat_level") != core.__chilimoon_version__)
      // The admin interface always runs with the current compatibility level.
      cfg->set ("compat_level", core.__chilimoon_version__);

    mixed err;
    array(mapping(string:string)) old_version;
    int ver;
    if( !(docs = DBManager.get( "docs", cfg ) ) ||
	(err = catch( old_version = DBManager.get( "docs", cfg )
		      ->query("SELECT contents FROM docs where name='_version'") )) ||
	((!sizeof(old_version) || old_version[0]->contents!=roxen_version()) &&
	 (ver=1)) )
    {
      if( !err && DBManager.get( "docs" ) && !ver )
	report_warning( "The database 'docs' exists, but this server can "
			"not read from it.\n"
			"Documentation will be unavailable.\n" );
      else if( file_stat( "data/docs.frm" ) )
      {
	if( !err && ver )
	{
	  report_notice("Removing old 'docs' database.\n");
	  DBManager.drop_db("docs");
	}

	// Restore from "backup".
	if( !err )
	{
	  report_notice("Creating the 'docs' database.\n");
	  DBManager.create_db( "docs", 0, 1 );
	  DBManager.is_module_db( this_module(), "docs", "All documentation");
	  foreach( core->configurations, Configuration c )
	    DBManager.set_permission( "docs", c, DBManager.READ );
	}
	DBManager.restore( "docs", getcwd()+"/data/", "docs", ({ "docs" }) );
	DBManager.set_permission( "docs", cfg, DBManager.WRITE );
	DBManager.get( "docs", cfg )->
	  query("REPLACE docs set name='_version', contents='"+roxen_version()+"'");
	DBManager.set_permission( "docs", cfg, DBManager.READ );
	docs = DBManager.get( "docs", cfg );
      }
      else
      {
	report_warning( "There is no documentation available\n");
	docs = 0;
      }
    }
    string am = query( "auth_method" );

    foreach( ({ "auth_httpbasic", "auth_httpcookie" }), string s )
    {
      if( am != s )
      {
	m_delete( cfg->enabled_modules, s+"#0" );
	if( cfg->find_module( s+"#0" ) )
	  cfg->disable_module( s+"#0" );
      }
      else
	cfg->enable_module( s+"#0" );
    }
#ifndef AVERAGE_PROFILING
    m_delete( cfg->enabled_modules, "avg_profiling#0" );
    if( cfg->find_module( "avg_profiling#0" ) )
      cfg->disable_module( "avg_profiling#0" );
#endif
    cfg->add_modules(({
      "config_tags", "contenttypes",    "indexfiles",
      "gbutton",     "graphic_text",    "pathinfo",        "javascript_support",
      "pikescript",  "rxmlparse",       "rxmltags",	   "usertags",
      "tablist",     "cimg",	        "development",	   "roxenwebserver",
#ifdef AVERAGE_PROFILING
      "avg_profiling",
#endif
    }));

    RoxenModule m;
    if( m = cfg->find_module( "pikescript#0" ) )
    {
#ifndef DEBUG
      m->set( "autoreload", 0 );
      m->set( "explicitreload", 0 );
#else
      m->set( "autoreload", 1 );
      m->set( "explicitreload", 1 );
#endif
#if constant(__builtin.security)
      m->set( "trusted", 1 );
#endif
      m->save(); // also forces call to start
    }
#ifdef DEBUG
    else 
      report_warning( "Failed to enable the pikescript module" );
#endif
  }
  call_out( zap_old_modules, 0 );
}

// NGSERVER: Compatibility. Remove.
void zap_old_modules()
{
  if( my_configuration()->find_module("awizard#0") )
    my_configuration()->disable_module( "awizard#0" );
  if( my_configuration()->find_module("config_userdb#0") )
    my_configuration()->disable_module( "config_userdb#0" );
}


void create()
{
  defvar( "location", "/", "Mountpoint", TYPE_LOCATION,
          "Usually / is a good idea" );

  defvar( "auth_method", "auth_httpbasic",
	  "Authentication method",
	  TYPE_STRING_LIST,
	  "The method to use to authenticate administration interface users.",
	  ([
	    "auth_httpbasic":"HTTP Basic passwords",
	    "auth_httpcookie":"HTTP Cookies",
	  ]) );

  core.add_permission( "View Settings", "View Settings");
  core.add_permission( "Edit Global Variables", "Edit Global Variables");
  core.add_permission( "Tasks", "Tasks");
  core.add_permission( "Restart", "Restart");
  core.add_permission( "Shutdown", "Shutdown");
  core.add_permission( "Create Site", "Create Sites");
  core.add_permission( "Add Module", "Add Modules");
}
