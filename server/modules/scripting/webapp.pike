// This is a roxen module. Copyright © 1999 - 2000, Roxen IS.

//inherit "module";
inherit "modules/filesystems/filesystem";

#include <module.h>

import Parser.XML.Tree;

//<locale-token project="mod_webapp">LOCALE</locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("mod_webapp",X,Y)
// end of the locale related stuff

constant cvs_version = "$Id: webapp.pike,v 2.1 2002/01/18 13:42:36 tomas Exp $";

constant thread_safe=1;
constant module_unique = 0;

static inherit "http";

#ifdef WEBAPP_DEBUG
# define WEBAPP_WERR(X) werror("WebApp: "+X+"\n")
#else
# define WEBAPP_WERR(X)
#endif

#if constant(system.normalize_path)
#define NORMALIZE_PATH(X)	system.normalize_path(X)
#else /* !constant(system.normalize_path) */
#define NORMALIZE_PATH(X)	(X)
#endif /* constant(system.normalize_path) */

string status_info="";

constant module_type = MODULE_LOCATION;

LocaleString module_name = LOCALE(1,"Java: Java Web Application bridge");
LocaleString module_doc =
LOCALE(2,"An interface to Java <a href=\"http://java.sun.com/"
       "products/servlet/index.html""\">Servlets</a>.");

#if constant(Servlet.servlet)

// map from various url-patterns to servlet
mapping(string:Servlet.servlet) servlets_path = ([ ]);
mapping(string:Servlet.servlet) servlets_ext = ([ ]);
mapping(string:Servlet.servlet) servlets_exact = ([ ]);
mapping(string:Servlet.servlet) servlets_default = ([ ]);
mapping(string:Servlet.servlet) servlets_any = ([ ]);

// contains mappings read from web.xml
mapping(string:string) servlet_to_class = ([ ]);
mapping(string:string) url_to_servlet = ([ ]);

// hold the pike wrapper for RoxenServletContext
object conf_ctx;

// hold the pike wrapper for URLClassLoader
object cls_loader;

// Info about this Web Application collected from web.xml
mapping(string:string) webapp_info = ([ ]);

// Context parameters from web.xml
mapping(string:string) webapp_context = ([ ]);



static mapping http_low_answer(int errno, string data, string|void desc)
{
  mapping res = Roxen.http_low_answer(errno, data);

  if (desc) {
    res->rettext = desc;
  }

  return res;
}

void stop()
{
  foreach(values(servlets_path),object servlet)
    destruct(servlet);
  servlets_path = ([ ]);
  foreach(values(servlets_ext),object servlet)
    destruct(servlet);
  servlets_ext = ([ ]);
  foreach(values(servlets_exact),object servlet)
    destruct(servlet);
  servlets_exact = ([ ]);
  foreach(values(servlets_default),object servlet)
    destruct(servlet);
  servlets_default = ([ ]);
  foreach(values(servlets_any),object servlet)
    destruct(servlet);
  servlets_any = ([ ]);

  if (objectp(conf_ctx)) {
    destruct(conf_ctx);
    conf_ctx= 0;
  }
}

static mapping(string:string) make_initparam_mapping()
{
  mapping(string:string) p = ([]);

  // FIXME: read parameters from web.xml
  /*
  mapping(string:string) p = ([
    "app.home":"e:/iw/intrawise",
    "app.data":"e:/iw/data",
  ]);
  */

  string n, v;
  foreach(query("parameters")/"\n", string s)
    if(2==sscanf(s, "%[^=]=%s", n, v))
      p[n]=v;

  return p;
}

int parse_param(Node c, mapping(string:string) data)
{
      c->iterate_children(lambda (Node c, mapping(string:string) data) {
                            switch (c->get_tag_name())
                            {
                              case "param-name":
                                data["name"] = c->value_of_node();
                                break;
                              case "param-value":
                                data["value"] = c->value_of_node();
                                break;
                            }
                          }, data);
      if (data["name"] && data["value"])
        return 1;
      else
        return 0;
}

void parse_webapp(Node c)
{
  mapping(string:string) data;
  switch (c->get_tag_name())
  {
    case "icon":
      break;
    case "display-name":
      webapp_info["display-name"] = c->value_of_node();
      break;
    case "description":
      webapp_info["description"] = c->value_of_node();
      break;
    case "distributable":
      // not implemented
      break;
    case "context-param":
      data = ([ ]);
      if (parse_param(c, data))
        webapp_context[data["name"]] = data["value"];
      break;
    case "servlet":
      data = ([ ]);
      c->iterate_children(lambda (Node c, mapping(string:string) data) {
                            switch (c->get_tag_name())
                            {
                              case "servlet-name":
                                data["name"] = String.trim_all_whites(c->value_of_node());
                                break;
                              case "servlet-class":
                                data["class"] = String.trim_all_whites(c->value_of_node());
                                break;
                            }
                          }, data);
      if (data["name"] && data["class"])
        servlet_to_class[data["name"]] = data["class"];
      break;
    case "servlet-mapping":
      data = ([ ]);
      c->iterate_children(lambda (Node c, mapping(string:string) data) {
                            switch (c->get_tag_name())
                            {
                              case "servlet-name":
                                data["name"] = String.trim_all_whites(c->value_of_node());
                                break;
                              case "url-pattern":
                                data["url"] = String.trim_all_whites(c->value_of_node());
                                break;
                            }
                          }, data);
      if (data["url"] && data["name"])
        url_to_servlet[data["url"]] = data["name"];
      break;
    case "session-config":
      break;
    case "mime-mapping":
      break;
    case "welcome-file-list":
      break;
    case "error-page":
      break;
    case "taglib":
      break;
    case "resource-ref":
      break;
    case "security-constraint":
      break;
    case "login-config":
      break;
    case "security-role":
      break;
    case "env-entry":
      break;
    case "ejb-ref":
      break;
  }
}

static int is_unavailable_exception(mixed e)
{
  if (arrayp(e) && sizeof(e)==4 && e[0] == "UnavailableException\n")
    return 1;

  return 0;
}

void start(int x, Configuration conf)
{
  if(x == 2)
    stop();
  else
    if(x != 0)
      return;

  string warname = query("warname");
  //if (search(warname, ".war") >= sizeof(warname)-4) {
  if (has_suffix(warname, ".war"))
    {
      // FIXME: extract archive
      string dir = warname[..sizeof(warname)-5];
      Stat s = r_file_stat( dir );
      if( !s )
        {
          // extract
          WEBAPP_WERR("Extracting warfile '" + warname + "' to '" + dir + "'");
          Servlet.jarutil()->expand(dir, warname);
        }
      else
        {
          WEBAPP_WERR("Destination directory for warfile exists");
        }
      
      warname = dir;
    }

  if(warname=="servlets/NONE") {
    status_info = LOCALE(3, "No Web Application selected");
    return;
  }

  // Parse the deployment descriptor web.xml
  Node webapp;
  mixed exc = catch
  {
    string webfile = combine_path(warname, "WEB-INF/web.xml");
    Node webxml = Parser.XML.Tree->parse_file(webfile);
    webxml->iterate_children(lambda (Node c) {
                               if (c->get_tag_name() == "web-app")
                                 webapp = c;
                             });
  };
  if (exc)
  {
    if (objectp(exc)) {
      status_info = exc->describe();
    }
    else if (arrayp(exc)) {
      report_error(LOCALE(4, "Servlet: %s\n"),exc[0]);
      status_info=sprintf(LOCALE(5, "<pre>%s</pre>"),exc[0]);
    }
    else
      status_info = sprintf(LOCALE(6, "error: \n%O\n"), exc);
    return(0);
  }

  if (webapp)
  {
    webapp->iterate_children(parse_webapp);
  }
  else
    status_info = LOCALE(7, "Deployment descriptor is corrupt");

  // Build the classpath used by the classloader for this Web App
  array(string) codebase = ({ });
  codebase += ({ combine_path(warname, "WEB-INF/classes") });
  if (Stdio.is_dir(combine_path(warname, "WEB-INF/lib"))) {
    array jars = Filesystem.System()->get_dir(combine_path(warname, "WEB-INF/lib"), "*.jar");
    codebase += map(jars, lambda (string jar) {
                            return combine_path(warname, "WEB-INF/lib", jar);
                          } );
  }
  codebase += query("codebase")-({""});
  WEBAPP_WERR(sprintf("codebase:\n%O", codebase));

  status_info="";
  mixed exc2 = catch {
    cls_loader = Servlet.loader(codebase);
    conf_ctx = Servlet.conf_context(conf);
  };
  
  if(exc2)
  {
    report_error(LOCALE(4, "Servlet: %s\n"),exc2[0]);
    status_info+=sprintf(LOCALE(5, "<pre>%s</pre>"),exc2[0]);
  }
  else
  {
    if (sizeof(webapp_context) > 0)
      conf_ctx->set_init_parameters(webapp_context);

    foreach ( indices(url_to_servlet), string url) {
      object servlet;
      mapping(string:object) table;
      if (url == "/")
        table = servlets_default;
      else if (url[..1] == "*.")
        table = servlets_ext;
      else if (sizeof(url) > 1 && url[0] == '/' &&
               url[sizeof(url)-2..] == "/*")
        table = servlets_path;
      else
        table = servlets_exact;
      string classname = servlet_to_class[url_to_servlet[url]];
      if (classname) {
        mixed exc = catch(table[url] = Servlet.servlet(classname,
                                                          //query("codebase")-({""})));
                                                          //codebase ));
                                                          cls_loader ));
        if(exc)
        {
          report_error(LOCALE(4, "Servlet: %s\n"),exc[0]);
          status_info+=sprintf(LOCALE(5, "<pre>%s</pre>"),exc[0]);
        }
        else
          if(table[url])
            {
              mixed e = catch( table[url]->init(conf_ctx, make_initparam_mapping()) );
              if (e)
                if (!is_unavailable_exception(e))
                  throw(e);
            }
      }
    }
  }


  // modify the filesystem configuration
  set("searchpath", warname);
  set(".files", 0);
  set("dir", 0);
  set("tilde", 0);
  set("put", 0);
  set("delete", 0);
  set("check_auth", 0);
  set("stat_cache", 0);
  set("access_as_user", 0);
  set("access_as_user_throw", 0);
  //set("internal_files", ({ "/WEB-INF*", "/META-INF*" }) );

  ::start();
}

string status()
{
  /*
  return (servlet?
	  servlet->info() || "<i>No servlet information available</i>" :
	  "<font color=red>Servlet not loaded</font>"+"<br>"+
	  status_info);
  */

  return LOCALE(8, "<h2>Servlets:</h2>")+
    ((map(indices(servlets_exact),
          lambda(string url) {
            return "<h3>"+
              url+
              LOCALE(9, " mapped to ")+
              servlet_to_class[url_to_servlet[url]]+
              "</h3>"+
              ((servlets_exact[url] && servlets_exact[url]->info()) ||
               LOCALE(10, "<i>No servlet information available</i>") )+
              "<br />"; 
          })+
      map(indices(servlets_path),
          lambda(string url) {
            return "<h3>"+
              url+
              LOCALE(9, " mapped to ")+
              servlet_to_class[url_to_servlet[url]]+
              "</h3>"+
              ((servlets_path[url] && servlets_path[url]->info()) ||
               LOCALE(10, "<i>No servlet information available</i>") )+
              "<br />"; 
          })+
      map(indices(servlets_ext),
          lambda(string url) {
            return "<h3>"+
              url+
              LOCALE(9, " mapped to ")+
              servlet_to_class[url_to_servlet[url]]+
              "</h3>"+
              ((servlets_ext[url] && servlets_ext[url]->info()) ||
               LOCALE(10, "<i>No servlet information available</i>") )+
              "<br />"; 
          })+
      map(indices(servlets_default),
          lambda(string url) {
            return "<h3>"+
              url+
              LOCALE(9, " mapped to ")+
              servlet_to_class[url_to_servlet[url]]+
              "</h3>"+
              ((servlets_default[url] && servlets_default[url]->info()) ||
               LOCALE(10, "<i>No servlet information available</i>") )+
              "<br />"; 
          })+
      map(indices(servlets_any),
          lambda(string url) {
            return "<h3>"+
              "/servlet/" + url+
              LOCALE(9, " mapped to ")+
              url+
              "</h3><br />"+
              ((servlets_any[url] && servlets_any[url]->info()) ||
               LOCALE(10, "<i>No servlet information available</i>") ); 
          })
      )*"<br /><br />") + status_info;
}

string query_name()
{
  return sprintf(LOCALE(11, "WAR loaded from %s"), query("warname"));
}

class RXMLParseWrapper
{
  static object _file;
  static object _id;
  static string _data;

  int write(string data)
  {
    _data += data;
    return strlen(data);
  }

  int close(void|string how)
  {
    _file->write(Roxen.parse_rxml(_data,_id));
    _data="";
    return _file->close(how);
  }

  mixed `->(string n)
  {
    return ::`->(n) || predef::`->(_file, n);
  }

  void create(object file, object id)
  {
    _file = file;
    _id = id;
    _data = "";
  }
}

object match_path_servlet(string f, RequestID id)
{
  foreach(indices(servlets_path), string p)
    {
      WEBAPP_WERR(sprintf("match_path_servlet(%s) trying %s (p[..sizeof(p)-3]='%s')",
             f, p, p[..sizeof(p)-3]));
      if (p[..sizeof(p)-3] == f)
        {
          WEBAPP_WERR("match on 'path'!!");
          return servlets_path[p];
        }
    }

  WEBAPP_WERR("NO match on 'path'!!");
  array a = f/"/";
  if (sizeof(a)<2)
    return 0;
  else
    {
      id->misc->servlet_path = a[..sizeof(a)-2]*"/";
      id->misc->path_info = "/" + a[sizeof(a)-1]||"" + id->misc->path_info||"";
      return match_path_servlet(id->misc->servlet_path, id);
    }
}

object match_ext_servlet(string f, RequestID id)
{
  foreach(indices(servlets_ext), string e)
    {
      WEBAPP_WERR(sprintf("match_ext_servlet(%s) trying %s " +
             "(e[1..]='%s', f[sizeof(f)-sizeof(e)..]='%s')",
             f, e, e[1..], f[sizeof(f)-sizeof(e)+1..]));
      if (e[1..] == f[sizeof(f)-sizeof(e)+1..])
        {
          WEBAPP_WERR("match on 'ext'!!");
          return servlets_ext[e];
        }
    }

  WEBAPP_WERR("NO match on 'ext'!!");
  return 0;
}

object match_anyservlet(string f, RequestID id)
{
  object ret;
  if (query("anyservlet") && has_prefix(f, "/servlet/"))
    {
      WEBAPP_WERR(sprintf("match_anyservlet(%s)", f));
      mixed fa = f/"/";
      if (sizeof(fa)>2)
        {
          string classname = fa[2];
          if (classname) {
            if (servlets_any[classname])
              ret = servlets_any[classname];
            else
              {
                mixed exc =
                  catch(servlets_any[classname] = Servlet.servlet(classname,
                                                                  cls_loader));
                if(exc)
                  {
                    report_error(LOCALE(4, "Servlet: %s\n"),exc[0]);
                    status_info+=sprintf(LOCALE(5, "<pre>%s</pre>"),exc[0]);
                  }
                else
                  if(servlets_any[classname])
                    {
                      servlets_any[classname]->init(conf_ctx, make_initparam_mapping());
                      ret = servlets_any[classname];
                    }
              }
          }
          if (ret)
            {
              id->misc->servlet_path = "/servlet/" + classname;
              if (sizeof(fa)>3)
                id->misc->path_info = "/" + fa[3..]*"/";
              return ret;
            }
        }
    }
  
  WEBAPP_WERR("NO match on 'any'!!");
  return 0;
}

object map_servlet(string f, RequestID id)
{
  string index = combine_path("/", f);
  id->misc->servlet_path = index;
  id->misc->path_info = 0;

  return match_anyservlet(index, id) ||
    servlets_exact[index] ||
    match_path_servlet(index, id) ||
    match_ext_servlet(index, id) ||
    servlets_default[index];
}

int is_special( string f, RequestID id )
{
  string realfile = real_file(f, id);
  if (realfile &&
      (has_prefix(realfile, normalized_path + "WEB-INF") ||
       has_prefix(realfile, normalized_path + "META-INF"))
      )
    return 1;

  return 0;
}

mixed find_file( string f, RequestID id )
{
  WEBAPP_WERR("Request for \""+f+"\"" +
		  (id->misc->internal_get ? " (internal)" : ""));
  object servlet;
  string loc = id->misc->mountpoint = query("mountpoint");
  if (loc[-1] == '/')
    id->misc->mountpoint = loc[..sizeof(loc)-2];

  mixed e = catch( servlet = map_servlet(f, id));
  if (e)
    if (is_unavailable_exception(e))
      {
        WEBAPP_WERR("Unavailable exc detected in find_file");
        if (e[2])
          return http_low_answer(503, "<h1>Error: 503</h1>"
                                 "<h2>Location: " +
                                 loc + f + "</h2>"
                                 "<b>Permanently Unavailable</b><br><br>"
                                 "Service is permanently unavailable<br>");
        else
          {
            id->misc->cacheable = e[3];
            return http_low_answer(503, "<h1>Error: 503</h1>\n"
                                   "<h2>Location: " +
                                   loc + f + "</h2>"
                                   "<b>" + e[1] + "</b><br><br>"
                                   "Service is unavailable, try again in " +
                                   e[3] + " seconds<br>");
          }
      }
  else
      throw(e);

  if (!servlet) {
    WEBAPP_WERR(sprintf("Servlet mapping not found for '%s'!\n"
           "servlets_exact=%O\n"
           "servlets_path=%O\n"
           "servlets_ext=%O\n"
           "servlets_default=%O\n"
           "servlets_any=%O\n"
           , f, servlets_exact, servlets_path, servlets_ext, servlets_default, servlets_any));
    if (!is_special(f, id))
      return ::find_file(f, id);
    else 
      return 0;
  }
  else {
    if(id->my_fd == 0 && id->misc->trace_enter)
      ; /* In "Resolve path...", kluge to avoid backtrace. */
    else {
      id->my_fd->set_read_callback(0);
      id->my_fd->set_close_callback(0);
      id->my_fd->set_blocking();
      if(query("rxml"))
        id->my_fd = RXMLParseWrapper(id->my_fd, id);
      //    WEBAPP_WERR(sprintf("servlet_war: servlet=%O\nid=%O,%O", servlet, id->my_fd, mkmapping(indices(id), values(id))));
      servlet->service(id);
    }

    return Roxen.http_pipe_in_progress();
  }
}


#else


// Do not dump to a .o file if no Java is available, since it will then
// not be possible to get it later on without removal of the .o file.
constant dont_dump_program = 1; 

string status()
{
  return 
#"<font color='&usr.warncolor;'>Java 2 is not available in this roxen.<p>
  To get Java 2:
  <ol>
    <li> Download and install Java
    <li> Restart roxen
  </ol></font>";
}

mixed find_file( string f, RequestID id )
{
  return Roxen.http_string_answer( status(), "text/html" );
}


#endif


class ClassPathList
{
  inherit Variable.FileList;

  array verify_set( string|array(string) value )
  {
    if(stringp(value))
      value = ({ value });
    string warn = "";
    foreach( value-({""}), string value ) {
      Stat s = r_file_stat( value );
      Stdio.File f = Stdio.File();
      if( !s )
        warn += value + LOCALE(12, " does not exist\n");
      else if( s[ ST_SIZE ] == -2 )
	;
      else if( !(f->open( value, "r" )) )
        warn += LOCALE(13, "Can't read ") + value + "\n";
      else {
	if( f->read(2) != "PK" )
	  warn += value + LOCALE(14, " is not a JAR file\n");
	f->close();
      }
    }
    if( strlen( warn ) )
      return ({ warn, value });
    return ::verify_set( value );
  }
}

class WARPath
{
  inherit Variable.File;

  array verify_set( string value )
  {
#ifdef __NT__
    value = replace( value, "\\", "/" );
#endif
    string warn = "";
    Stat s = r_file_stat( value );
    Stdio.File f = Stdio.File();
    if( !s )
      warn += value + LOCALE(12, " does not exist\n");
    else if( s[ ST_SIZE ] == -2 )
      { // directory
        if ( f->open(combine_path(value, "WEB-INF/web.xml"), "r") )
          f->close();
        else
          warn += value + LOCALE(15, " is not a valid Web Application Directory");
      }
    else if( !(f->open( value, "r" )) )
      warn += LOCALE(13, "Can't read ") + value + "\n";
    else {
      if( f->read(2) != "PK" )
        warn += value + LOCALE(14, " is not a JAR file\n");
      f->close();
    }
    if( strlen( warn ) )
      return ({ warn, value });
    return ::verify_set( value );
  }
}

static int invisible_cb(RequestID id, Variable.Variable i )
{
  return 1;
}

void create()
{
  defvar("warname",
         WARPath( "servlets/NONE", VAR_INITIAL|VAR_NO_DEFAULT,
                  LOCALE(16, "Web Application Archive"),
                  LOCALE(17, "The archive file (.war) or directory "
                         "containing the Web Application.") ) );


  // insert and modify the filesystem configuration
  ::create();
  getvar("searchpath")->set_invisibility_check_callback ( invisible_cb );
  getvar(".files")->set_invisibility_check_callback ( invisible_cb );
  getvar("dir")->set_invisibility_check_callback ( invisible_cb );
  getvar("nobrowse")->set_invisibility_check_callback ( invisible_cb );
  getvar("tilde")->set_invisibility_check_callback ( invisible_cb );
  getvar("put")->set_invisibility_check_callback ( invisible_cb );
  getvar("delete")->set_invisibility_check_callback ( invisible_cb );
  getvar("check_auth")->set_invisibility_check_callback ( invisible_cb );
  getvar("stat_cache")->set_invisibility_check_callback ( invisible_cb );
  getvar("access_as_user")->set_invisibility_check_callback ( invisible_cb );
  getvar("access_as_user_db")->set_invisibility_check_callback ( invisible_cb );
  getvar("access_as_user_throw")->set_invisibility_check_callback ( invisible_cb );
  getvar("internal_files")->set_invisibility_check_callback ( invisible_cb );
  // end filesystem


  defvar("rxml", 0,
         LOCALE(18, "Parse RXML in servlet output"), TYPE_FLAG|VAR_MORE,
	 LOCALE(19, "If this is set, the output from the servlets handled by "
                "this module will be RXML parsed. "
                "NOTE: No data will be returned to the "
                "client until the output is fully parsed.") );

  defvar("codebase",
         ClassPathList( ({""}), VAR_MORE,
                        LOCALE(20, "Class path"),
                        LOCALE(21, "Any number of directories and/or JAR "
                               "files from which to load the "
                               "support classes.") ) );

  defvar("parameters", "", LOCALE(22, "Parameters"), TYPE_TEXT,
	 LOCALE(23, "Parameters for the servlet on the form "
                "<tt><i>name</i>=<i>value</i></tt>, one per line.") );

  defvar("anyservlet", 0, LOCALE(24, "Access any servlet"), TYPE_FLAG|VAR_MORE,
	 LOCALE(25, "Use a servlet mapping that mounts any servlet onto "
                "&lt;Mount Point&gt;/servlet/") );
}

