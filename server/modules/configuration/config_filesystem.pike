// This is a roxen module. Copyright © 1999 - 2000, Roxen IS.
//
// A filesystem for the roxen administration interface.
#include <module.h>
#include <stat.h>
#include <config_interface.h>
#include <roxen.h>

inherit "module";
inherit "roxenlib";

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("roxen_config",X,Y)

constant module_type = MODULE_LOCATION;
LocaleString module_name_locale = LOCALE(0,"Configuration Filesystem");
LocaleString module_doc_locale =
  LOCALE(0,"This filesystem serves the administration interface");
constant module_unique = 1;
constant cvs_version =
  "$Id: config_filesystem.pike,v 1.69 2001/01/19 16:41:51 per Exp $";

constant path = "config_interface/";

object charset_decoder;
Sql.Sql docs;

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
array(string|Stat) low_stat_file(string locale, string f, object id)
{
  foreach( ({ "../local/"+path, path }), string path )
  {
    Stat ret;
    if (!f) 
    {
      mixed r2 = low_stat_file(locale, "", id);

      if (r2) return r2;
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

  if( docs && rest && (sscanf( rest, "docs/%s", rest ) ))
    return 0;
  array(string|array) stat_info = low_stat_file(locale, rest, id);
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
  while( strlen( f ) && (f[0] == '/' ))
    f = f[1..];

  if (f == "") return file_stat(path);

  string locale;
  string rest;

  sscanf(f, "%[^/]/%s", locale, rest);

  if( docs && rest && (sscanf( rest, "docs/%s", rest ) ))
    if( mapping f = get_docfile( rest ) )
      return ({ 0555, strlen(f->contents), time(), 0, 0, 0, 0 });

  array(string|Stat) ret = low_stat_file(locale, rest, id);
  return ret && (ret[1]);
}

constant base ="<use file='%s' /><tmpl title='%s'>%s</tmpl>";

mixed find_dir( string f, object id )
{
  while( strlen( f ) && (f[0] == '/' ))
    f = f[1..];
  
  if (f == "")
    return Locale.list_languages("roxen_config");

  string locale;
  string rest;

  sscanf(f, "%[^/]/%s", locale, rest);

  multiset languages;
    languages=(multiset)Locale.list_languages("roxen_config");

  if (rest || languages[locale]) {
    return get_dir(path + "standard/" + (rest || ""));
  }
  return get_dir(path + "standard/" + locale);
}

mapping logged_in = ([]);

mixed find_file( string f, object id )
{
  int is_docs;
  User user;

  string host;
  if( array h = gethostbyaddr( id->remoteaddr ) )
    host = h[0];
  else
    host = id->remoteaddr;

  if( user = id->conf->authenticate( id, roxen.config_userdb_module ) )
  {
    if( !id->misc->cf_theme )
      id->misc->cf_theme = ([]);
    id->misc->cf_theme["user-uid"] = user->name();
    id->misc->cf_theme["user-name"] = user->real_name();
    id->misc->remote_config_host = host;
    id->misc->config_user = user->ruser;
    if( (time(1) - logged_in[ user->name()+host ]) > 1800 )
      report_notice(LOCALE("dt", "Administrator logged on as %s from %s.")
		    +"\n", user->name(), host+" ("+id->remoteaddr+")" );
    logged_in[ user->name()+host ] = time(1);
    roxen.adminrequest_get_context( user->name(), host, id );
  }
  else if( !id->misc->internal_get )
  {
    report_notice(LOCALE(0,"Failed login attempt from %s")+"\n",host);
    return id->conf->authenticate_throw( id, "Roxen configuration",
					 roxen.config_userdb_module );
  }
  
  if( !id->misc->internal_get )
  {
    if( (f == "") && !id->misc->pathinfo )
      return http_redirect(fix_relative( "/"+config_setting("locale")+"/",
					 id ), id );
    if( search(f, "/" ) == -1 )
      return http_redirect(fix_relative( "/"+f+"/", id ), id );

    string encoding = config_setting( "charset" );
    if( encoding != "utf-8" )
      catch { charset_decoder=Locale.Charset.decoder( encoding ); };
    else
      charset_decoder = 0;
    id->set_output_charset( encoding );

    id->since = 0;
    catch 
    {
      if( !id->misc->request_charset_decoded )
      {
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
          map( indices(id->variables), decode_variable );
        }
        else
        {
          void decode_variable( string v )
          {
            id->variables[v] = utf8_to_string( id->variables[v] );
          };
          f = utf8_to_string( f );
          id->not_query = utf8_to_string( id->not_query );
          map( indices(id->variables), decode_variable );
        }
      }
    };
  }

  while( strlen( f ) && (f[0] == '/' ))
    f = f[1..];

  string locale, df, rest, type="";
  mixed retval;

  sscanf(f, "%[^/]/%s", locale, rest);

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
  }

  if( docs && rest && (sscanf( rest, "docs/%s", rest ) ))
  {
    if( mapping f = get_docfile( rest ) )
    {
      is_docs = 1;
      string data = f->contents;
      f = 0;
      if( type == "text/html" )
      {
        string title;
        sscanf( data, "%*s<title>%s</title>", title );
        sscanf( data, "%*s<br clear=\"all\">%s", data );
        sscanf( data, "%s</body>", data );
        retval = "<topmenu selected='docs' base='"+
               query_location()+locale+"/'/>"
               "<content>"+data+"</content>";
        if( title )
          retval="<title>: Docs "+html_encode_string(title)+"</title>" +
                           retval;
      } else
        retval = data;
    }
  }
  else
  {
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
     case -1:  case -3: case -4:
       return 0; /* Not suitable (device or no file) */
     case -2: /* directory */
       return -1;
     default:
       if (f[-1] == '/')
         return 0;	/* Let the PATH_INFO module handle it */
    }
    id->realfile = realfile;
    retval = Stdio.File( realfile, "r" );
    if( id->misc->internal_get )
      return retval;
  }

  if( id->variables["content-type"] )
    return http_file_answer( retval, id->variables["content-type"] );

  if( locale != "standard" ) 
    roxen.set_locale( locale );

  if( !retval )
    return 0;

  if( type  == "text/html" )
  {
    string data, title="", pre;
    if( stringp( retval ) )
      data = retval;
    else 
      data = retval->read();

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

    if(!is_docs)
    {
      NOCACHE();
      retval->expires = time(1);
    }
    retval->stat = 0;
    retval->len = strlen( retval->data );
    if( locale != "standard" ) 
      roxen.set_locale( "standard" );
  }
  if( stringp( retval ) )
    retval = http_string_answer( retval, type );

  return retval;
}

void start(int n, Configuration cfg)
{
  if( cfg )
  {
    if( !(docs = DBManager.get( "docs", cfg ) ) )
    {
      if( DBManager.get( "docs" ) )
      {
        report_warning( "The database 'docs' exists, but this server can "
                        "not read from it.\n"
                        "Documentation will be unavailable.\n" );
      }
      else
      {
        Filesystem.System T;
        report_notice( "Creating the 'docs' database\n");
        catch(T = Filesystem.Tar( "config_interface/docs.tar" ));
        if( !T )
          report_notice( "Failed to open the documentation tar-file.\n");
        else
        {
          DBManager.create_db( "docs", "docs", 1 );
          DBManager.set_permission( "docs", cfg, DBManager.WRITE );
          docs = DBManager.get( "docs", cfg );
          catch(docs->query( "DROP TABLE docs" ));
          docs->query( "CREATE TABLE docs "
                     "(name VARCHAR(80) PRIMARY KEY,contents MEDIUMBLOB)");
          void rec_process( string dir )
          {
            foreach( T->get_dir( dir ), string f )
            {
              if( T->stat( f )->isdir() )
                rec_process( f );
              else
              {
                if( search( f, "internal-roxen" ) != -1 ) continue;
                docs->query( "INSERT INTO docs VALUES (%s,%s)", f,
                             T->open(f, "r")->read());
              }
            }
          };
          rec_process("/");
        }
      }
    }

    cfg->add_modules(({
      "config_tags", "contenttypes",    "indexfiles",
      "gbutton",     "wiretap",         "graphic_text",    "pathinfo",
      "pikescript",  "translation_mod", "rxmlparse",       "rxmltags",
      "tablist",     "update",          "cimg",            "auth_httpcookie"
    }));
  }
  call_out( zap_old_modules, 0 );
}

void zap_old_modules()
{
  if( my_configuration()->find_module("awizard#0") )
    my_configuration()->disable_module( "awizard#0" );
  if( my_configuration()->find_module("config_userdb#0") )
    my_configuration()->disable_module( "config_userdb#0" );
}


void create()
{
  defvar( "location", "/", LOCALE(264,"Mountpoint"), TYPE_LOCATION,
          LOCALE(265,"Usually / is a good idea") );


  roxen.add_permission( "View Settings", LOCALE(192, "View Settings"));
  roxen.add_permission( "Edit Users",    LOCALE(193, "Edit Users"));
  roxen.add_permission( "Update",    LOCALE(349, "Update Client"));
  roxen.add_permission( "Edit Global Variables",
			LOCALE(194, "Edit Global Variables"));
  roxen.add_permission( "Tasks", LOCALE(196, "Tasks"));
  roxen.add_permission( "Restart", LOCALE(197, "Restart"));
  roxen.add_permission( "Shutdown", LOCALE(198, "Shutdown"));
  roxen.add_permission( "Create Site", LOCALE(199, "Create Sites"));
  roxen.add_permission( "Add Module", LOCALE(200, "Add Modules"));
}
