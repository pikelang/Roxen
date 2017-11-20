// This is a roxen module. Copyright © 1999 - 2009, Roxen IS.

//inherit "module";
inherit "roxen-module://filesystem";

#include <module.h>

import Parser.XML.Tree;

//<locale-token project="mod_webapp">LOCALE</locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("mod_webapp",X,Y)
// end of the locale related stuff

constant cvs_version = "$Id$";

constant thread_safe=1;
constant module_unique = 0;

protected inherit "http";

#define WEBAPP_CHAINING

#ifdef WEBAPP_DEBUG
# define WEBAPP_WERR(X) werror("WebApp: "+X+"\n")
# define WRAP_WERR(X) WEBAPP_WERR(sprintf("%s[%d]: ", clazz, _ident) + X)
#else
# define WEBAPP_WERR(X)
# define WRAP_WERR(X)
#endif

#if constant(system.normalize_path)
#define NORMALIZE_PATH(X)	system.normalize_path(X)
#else /* !constant(system.normalize_path) */
#define NORMALIZE_PATH(X)	(X)
#endif /* constant(system.normalize_path) */

string status_info="";

constant module_type = MODULE_LOCATION | MODULE_TAG | MODULE_PROVIDER;

LocaleString module_name = LOCALE(1,"Java: Java Web Application bridge");
LocaleString module_doc =
LOCALE(2,"An interface to Java <a href=\"http://java.sun.com/"
       "products/servlet/index.html""\">Servlets</a>.");

#if constant(Servlet.servlet)
//#if 1

// map from servlet name to various info about the servlet
// Each servlet maps to a mapping that contains the following info:
//   Servlet.servlet servlet;
//   int(-1..1) loaded;
//   int(-1..1) initialized;
//   string url;
//   mapping(string:string) initparams;
//   string servlet-name;
//   string display-name;
//   string description;
//   string servlet-class;
//   //string jsp-file; (not implemented!)
//   string load-on-startup;
//   ....
mapping(string:mapping(string:string|mapping|Servlet.servlet)) servlets = ([ ]);

// map from url patterns to servlet name
mapping(string:mapping(string:string)) servletmaps = ([
  "path" : ([ ]),
  "ext" : ([ ]),
  "exact" : ([ ]),
  "default" : ([ ]),
  "any" : ([ ]),
  "chaining" : ([ ]),
]);

// map from url-patterns to servlet name read from web.xml
mapping(string:string) url_to_servlet = ([ ]);

// hold the pike wrapper for RoxenServletContext
object conf_ctx;

// hold the pike wrapper for URLClassLoader
object cls_loader;

// Info about this Web Application collected from web.xml
mapping(string:string) webapp_info = ([ ]);

// Context parameters from web.xml
mapping(string:string) webapp_context = ([ ]);

// Content type globs that are matched against the content type
// returned from the servlet to determine if rxml parsing should be done
array(string) rxmlmap;


protected mapping http_low_answer(int errno, string data, string|void desc)
{
  mapping res = Roxen.http_low_answer(errno, data);

  if (desc) {
    res->rettext = desc;
  }

  return res;
}

void stop()
{
  // Generate a list sorted on reverse init order
  array ind = indices(servlets);
  sort(values(servlets)->prio, ind);
  ind = reverse(ind);

  // Unload servlets in reverse priority order
  foreach ( ind, string serv) {
    if (servlets[serv]->loaded == 1)
      destruct(servlets[serv]->servlet);
  }

  if (objectp(conf_ctx)) {
    destruct(conf_ctx);
    conf_ctx= 0;
  }

  servlets = ([ ]);
  webapp_info = ([ ]);
  webapp_context = ([ ]);
  url_to_servlet = ([ ]);

  servletmaps = ([
    "path" : ([ ]),
    "ext" : ([ ]),
    "exact" : ([ ]),
    "default" : ([ ]),
    "any" : ([ ]),
    "chaining" : ([ ]),
  ]);
}

protected mapping(string:string) make_initparam_mapping(mapping(string:string) p)
{
  if (!p)
    p = ([ ]);

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
                                data["name"] = String.trim_all_whites(c->value_of_node());
                                break;
                              case "param-value":
                                data["value"] = String.trim_all_whites(c->value_of_node());
                                break;
                            }
                          }, data);
      if (data["name"] && data["value"])
        return 1;
      else
        return 0;
}

void do_parse_servlet(Node c, mapping(string:string|int|mapping(string:string)) data)
{
  mapping(string:string) param = ([ ]);
  int prio;
  switch (c->get_tag_name())
    {
    case "icon":
      break;
    case "servlet-name":
      data["servlet-name"] = String.trim_all_whites(c->value_of_node());
      break;
    case "display-name":
      data["display-name"] = String.trim_all_whites(c->value_of_node());
      break;
    case "description":
      data["description"] = String.trim_all_whites(c->value_of_node());
      break;
    case "servlet-class":
      data["servlet-class"] = String.trim_all_whites(c->value_of_node());
      break;
    case "jsp-file":
      //data["jsp-file"] = String.trim_all_whites(c->value_of_node());
      break;
    case "init-param":
      param = ([ ]);
      if (parse_param(c, param))
        {
          if (data["initparams"] == 0)
            data["initparams"] = ([ ]);
          data["initparams"] += ([ param["name"] : param["value"] ]);
        }
      break;
    case "load-on-startup":
      data["load-on-startup"] = String.trim_all_whites(c->value_of_node());
      prio = (int)data["load-on-startup"];
      //convert prio to negative numbers with -1 as the lowest priority
      //to make it easier to sort on prio (prio not set will be load on demand)
      if (prio > 0)
        data["prio"] = prio - 65536;
      else
        data["prio"] = -1;
        
      break;
    case "security-role-ref":
      break;
    }
}

void parse_servlet(Node c)
{
  mapping(string:string) data = ([ ]);

  c->iterate_children(do_parse_servlet, data);

  if (data["servlet-name"] && data["servlet-class"])
    {
      WEBAPP_WERR(sprintf("servlet %s parsed:\n%O", data["servlet-name"], data));
      if (servlets[data["servlet-name"]])
        {
          report_error(LOCALE(26, "Duplicate entry of %s in web.xml\n"),
                       data["servlet-name"]);
          status_info+=sprintf(LOCALE(27,"<pre>Duplicate entry of %s in web.xml</pre>"),
                              data["servlet-name"]);
        }
      else
        {
          servlets[data["servlet-name"]] = data;
        }
    }
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
      parse_servlet(c);
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
    case "chaining-mapping":
      data = ([ ]);
      c->iterate_children(lambda (Node c, mapping(string:string) data) {
                            switch (c->get_tag_name())
                            {
                              case "servlet-name":
                                data["name"] = String.trim_all_whites(c->value_of_node());
                                break;
                              case "mime-pattern":
                                data["type"] = String.trim_all_whites(c->value_of_node());
                                break;
                            }
                          }, data);
      if (data["type"] && data["name"])
        servletmaps["chaining"][lower_case(data["type"])] = data["name"];
      break;
  }
}

protected int is_unavailable_exception(mixed e)
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

  if (query("rxml")) {
    rxmlmap = replace(query("rxmltypes"), ({",", " ", ";"}), ({"\n"})*3)/"\n" - ({""});
  }
  else
    rxmlmap = ({ });

  string warname = query("warname");
  if (has_suffix(warname, ".war"))
    {
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

  webapp_info["webapp"] = (warname/"/")[-1];

  if(warname=="servlets/NONE") {
    status_info = (string) LOCALE(3, "No Web Application selected");
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

  status_info="";
  if (webapp)
  {
    webapp->iterate_children(parse_webapp);
  }
  else
    {
      status_info += LOCALE(7, "Deployment descriptor is corrupt");
      return (0);
    }

  // Build the classpath used by the classloader for this Web App
  array(string) codebase = ({ });
  codebase += ({ combine_path(warname, "WEB-INF/classes") });
  if (Stdio.is_dir(combine_path(warname, "WEB-INF/lib"))) {
    array jars = Filesystem.System()->get_dir(combine_path(warname, "WEB-INF/lib"), "*.jar");
    codebase += map(jars, lambda (string jar) {
                            return combine_path(warname, "WEB-INF/lib", jar);
                          } );
  }
  codebase += map(query("codebase")-({""}), lambda (string arg) {
                                              return glob_expand(arg);
                                            } )*({ });

#ifdef ENABLE_JSP
  switch (query("jspengine"))
  {
    case "None":
      break;

    case "GNUJSP":
      if (!url_to_servlet["*.jsp"])
      {
        codebase += glob_expand("java/lib/gnujsp/*.jar");

        mapping(string:string) data = ([ ]);
        url_to_servlet["*.jsp"] = "gnujsp_internal";

#ifdef __NT__
        string sep = ";";
#else
        string sep = ":";
#endif
        string scratchdir = warname + "/WEB-INF/jsp";
        mkdir(scratchdir);
        string compiler = "builtin-javac -classpath " +
          ( ({ "%classpath%", "%scratchdir%" }) + codebase )*sep +
          " -d %scratchdir% -deprecation %source%";

        data["servlet-name"] = "gnujsp_internal";
        data["display-name"] = "GNUJSP";
        data["description"] = "GNUJSP is a free implementation of Sun's Java Server Pages.";
        data["servlet-class"] = "org.gjt.jsp.JspServlet";
        data["initparams"] = ([
          "debug"             : query("jspdebug")?"true":"false",
#ifdef WEBAPP_DEBUG
          "pathdebug"         : query("jspdebug")?"true":"false",
#else
          "pathdebug"         : "false",
#endif
          "usepackages"       : "true",
          "checkdependancies" : "true",
          "checkclass"        : "true",
          "keepJava"          : "false",
          "scratchdir"        : scratchdir,
          "compiler"          : compiler,
        ]);
        data["load-on-startup"] = "";
        data["prio"] = -1;
        servlets[data["servlet-name"]] = data;

        codebase += ({ (getenv("JREHOME")||"java/jre") + "/lib/tools.jar" });
      }
      else
        report_warning("A servlet mapping for *.jsp exists! GNUJSP disabled.\n");
      break;

    case "Jasper":
      if (!url_to_servlet["*.jsp"])
      {
        codebase += glob_expand("java/lib/jasper/*.jar");

        mapping(string:string) data = ([ ]);
        url_to_servlet["*.jsp"] = "jasper_internal";

#ifdef __NT__
        string sep = ";";
#else
        string sep = ":";
#endif
        string scratchdir = warname + "/WEB-INF/jsp";
        mkdir(scratchdir);
        string classpath = codebase * sep;

        data["servlet-name"] = "jasper_internal";
        data["display-name"] = "Jasper";
        data["description"] = "Part of Apache Tomcat";
        data["servlet-class"] = "org.apache.jasper.servlet.JspServlet";
        data["initparams"] = ([
          "keepgenerated"     : "true",
          "largefile"         : "false",
          "mappedfile"        : "false",
          "debug"             : query("jspdebug")?"true":"false",
          "sendErrToClient"   : query("jspsenderrtoclient")?"true":"false",
          "scratchdir"        : scratchdir,
          "classpath"         : classpath,
        ]);
        data["load-on-startup"] = "";
        data["prio"] = -1;
        servlets[data["servlet-name"]] = data;

        codebase += ({ (getenv("JREHOME")||"java/jre") + "/lib/tools.jar" });
      }
      else
        report_warning("A servlet mapping for *.jsp exists! Jasper disabled.\n");
      break;
  }
#endif // ENABLE_JSP

  WEBAPP_WERR(sprintf("codebase:\n%O", codebase));


  mixed exc2 = catch {
    cls_loader = Servlet.loader(codebase);
    //conf_ctx = Servlet.conf_context(conf);
    conf_ctx = Servlet.context(conf, this_object(), roxen_path("$VVARDIR/servlettmp/"));
  };
  
  if(exc2)
  {
    report_error(LOCALE(4, "Servlet: %s\n"),describe_backtrace(exc2));
    status_info+=sprintf(LOCALE(5, "<pre>%s</pre>"),describe_error(exc2));
  }
  else
  {
    if (sizeof(webapp_context) > 0)
      conf_ctx->set_init_parameters(webapp_context);

    // Sort the url patterns into different categories for easier lookup
    // later on
    foreach ( indices(url_to_servlet), string url) {
      if (!servlets[url_to_servlet[url]])
        continue;

      servlets[url_to_servlet[url]]->url =
        (servlets[url_to_servlet[url]]->url || ({ }) ) + ({ url });

      if (url == "/")
        servletmaps["default"][url] = url_to_servlet[url];
      else if (url[..1] == "*.")
        servletmaps["ext"][url] = url_to_servlet[url];
      else if (sizeof(url) > 1 && url[0] == '/' &&
               url[sizeof(url)-2..] == "/*")
        servletmaps["path"][url] = url_to_servlet[url];
      else
        servletmaps["exact"][url] = url_to_servlet[url];
    }
    
    // Generate a list sorted on init order
    array ind = indices(servlets);
    sort(values(servlets)->prio, ind);

    // Preload servlets in priority order
    foreach ( ind, string serv) {
      WEBAPP_WERR(sprintf("servlet: %s prio: %O", serv, servlets[serv]->prio));
      if (servlets[serv]->prio < 0 || query("preloadall"))
        load_servlet(servlets[serv]);
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
  return "<h2>" +
    ( webapp_info["display-name"] && sizeof(webapp_info["display-name"]) > 0 ?
      webapp_info["display-name"] :
      webapp_info["webapp"] ) +
    "</h2>" +
    (webapp_info["description"] ?
     webapp_info["description"] :
          "") +
    LOCALE(8, "<table border=0>")+
    "<tr><td colspan=4><hr /></td></tr>" +
    "<tr>" +
    "<th align=left>Name</th>" +
    "<th align=left>Mapping&nbsp;&nbsp;&nbsp;</th>" +
    "<th align=left>Class</th>" +
    "<th align=left>Description" +
    "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;" +
    "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;" +
    "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;" +
    "</th>" +
    "</tr>" +
    "<tr><td colspan=4><hr /></td></tr>" +

    ((map(indices(servlets),
          lambda(string serv) {
            string ret = "<tr valign=top>";

            ret += "<th align=left>";
            ret += ( servlets[serv]["display-name"] ||
                     servlets[serv]["servlet-name"] );
            ret += "</th>";

            if (servlets[serv]->url) {
              ret += "<td nowrap>";
              ret += (servlets[serv]->url*",");
              ret += "</td>";
              ret += "<td nowrap>";
              ret += servlets[serv]["servlet-class"];
              ret += "</td>";
            }
            else
              ret += "<td></td><td></td>";

            ret += "<td rowspan=2>";
            if (servlets[serv]->description)
              ret += servlets[serv]->description;
            ret += "</td>";

            ret += "</tr><tr valign=top>";

            ret += "<td colspan=3>";
            if (servlets[serv]->initialized == 1)
              ret += servlets[serv]->servlet->info() ||
                LOCALE(10, "<i>No servlet information available</i>");
            else if (!servlets[serv]->loaded)
              ret += LOCALE(29, "<i>Servlet not loaded.</i>");
            else if (servlets[serv]->loaded == -1)
              {
                ret += "<font color='&usr.warncolor;'>";
                ret += LOCALE(30, "<b>Servlet failed to load!</b>");
                ret += "</font>";
              }
            else if (!servlets[serv]->initialized)
              ret += LOCALE(31, "<i>Servlet not initialized</i>");
            else if (servlets[serv]->initialized == -1)
              {
                ret += "<font color='&usr.warncolor;'>";
                ret += LOCALE(32, "<b>Servlet failed to initialize!</b>");
                ret += "</font>";
              }
            ret += "</td>";

            ret += "</tr>";
            return ret;
          })
      )*"<tr><td colspan=4><hr /></td></tr>") +
    "<tr><td colspan=4><hr /></td></tr>" +
    "</table>" + status_info;
}

string query_name()
{
  string name = query("warname");
  if (sizeof(name) > 20) {
    return sprintf(LOCALE(33,"Java: WAR loaded from %s...%s"),
		   name[..7], name[sizeof(name)-8..]);
  }
  return sprintf(LOCALE(11, "Java: WAR loaded from %s"), name);
}

mapping(string:function) query_action_buttons()
{
  return ([ "Load all servlets":load_all ]);
}

multiset(string) query_provides()
{
  return (< "webapp" >);
}

void load_all()
{
  WEBAPP_WERR("Loading all servlets");

  // Generate a list sorted on init order
  array ind = indices(servlets);
  sort(values(servlets)->prio, ind);

  // Preload servlets in priority order
  foreach ( ind, string serv) {
    load_servlet(servlets[serv]);
  }
}


protected int ident=1;

class BaseWrapper
{
  protected constant clazz = "BaseWrapper";
  protected object _file;
  protected object _id;
  protected string _data;
  protected string header;
  protected string retcode;
  protected string rettext;
  mapping(string:string) headermap = ([ ]);
  protected int _ident;
  protected int first=1;
  int collect=0;
  string content_type;
  multiset ignore_heads = (<
    "content-length",
    "content-type",
  >);

  string _sprintf()
  {
    return "BaseWrapper(#" + _ident + ", collect: " + collect + ")";
  }

  int check(string ct)
  {
    WRAP_WERR("BASE check called");
    return 0;
  }

  void set_collect(int i)
  {
    collect = i;
  }

  int write(string data)
  {
    if (!data)
      return 0;

    if (first) {
      array(string) headers;
      int hend;
      _data += data;
    
      //WRAP_WERR(sprintf("got first:\n'%s'", data));

      if ((hend=search(_data, "\r\n\r\n")) != -1) {
        first=0;
        header = _data[..hend+3];
        _data = _data[hend+4..];

        //WRAP_WERR(sprintf("found header(len %d):\n'%s'", sizeof(header),header));
        //WRAP_WERR(sprintf("with data(len %d):\n'%s'", sizeof(_data), _data));
        WRAP_WERR(sprintf("found header!"));
        headers = (header/"\r\n")-({ "" });

        if (_file)
          set_collect(0);
        else
          set_collect(2);
        
        array(string) line = (headers[0]/" ");
        retcode = line[1];
        rettext = (sizeof(line)>2) ? (line[2..])*" " : 0;

        string name, value;
        foreach(headers[1..], string h) {
          WRAP_WERR(sprintf("header=%s", h || "null"));
          if (sscanf(h, "%s:%s", name, value) == 2) {
            WRAP_WERR(sprintf("name=%s, value=%s", name || "null", value || "null"));
            if ( !ignore_heads[lower_case(name)] )
              Roxen.add_http_header(headermap, name,
                                    String.trim_all_whites(value));
            if (lower_case(name) == "content-type") {
              content_type = String.trim_all_whites((value/";")[0]);
              WRAP_WERR(sprintf("content-type: '%s'", content_type));
              if (retcode == "200" && check(content_type)) {
                WRAP_WERR("check returned true");
                set_collect(1);
              }
              else
                WRAP_WERR("check returned false");
            }
          }
        }

        if (!collect) {
          WRAP_WERR(sprintf("first collect:"));
          flush();
        }
      }
    }
    else if (collect) {
      WRAP_WERR(sprintf("more collect (%d)", sizeof(data)));
      _data += data;
      ;
    }
    else {
      //WRAP_WERR(sprintf("got more:\n'%s'", data));
      return _file->write(data);
    }
    
    return strlen(data);
  }

  void flush()
  {
    int len;
    WRAP_WERR(sprintf("flush called:"));
    while (sizeof(header) > 0) {
      len = _file->write(header);
      if (len < 0)
        return;
      //WRAP_WERR(sprintf("flushed %d:\n'%s'", len,header));
      header=header[len..];
    }
    while (sizeof(_data) > 0) {
      len = _file->write(_data);
      if (len < 0)
        return;
      //WRAP_WERR(sprintf("flushed %d:\n'%s'", len,_data));
      _data=_data[len..];
    } 
  }

  int close(void|string how)
  {
    WRAP_WERR(sprintf("close called: first=%d, collect=%d",
                        first, collect));
    if (collect) {
      return 1;
    }
    else if (first) {
      flush();
    }
    return _file->close(how);
  }

  string get_data(void|int clear)
  {
    //WRAP_WERR(sprintf("get_data called: clear=%d, data=%s",clear, _data));
    string tmp = _data;
    if (clear)
      _data = "";
    return tmp;
  }

  string get_header(void|int clear)
  {
    string tmp = header;
    if (clear)
      header = "";
    return tmp;
  }

  mixed `->(string n)
  {
    //WRAP_WERR(sprintf("`->(%s)", n));
    mixed val = this_object()[n];
    if (!zero_type(val)) return val;

    //WRAP_WERR(sprintf("::`->(%s)", n));
    val = ::`->(n);
    if (!zero_type(val)) return val;

    //WRAP_WERR(sprintf("predef::`->(%s)", n));
    return _file && predef::`->(_file, n);
  }

  void create(object file, object id)
  {
    _ident = ident++;
    _file = file;
    _id = id;
    _data = "";
    WRAP_WERR("create called");
  }
}

class RXMLParseWrapper
{
  inherit BaseWrapper;
  
  protected constant clazz = "RXMLWrapper";

  string _sprintf()
  {
    return "RXMLParseWrapper(#" + _ident + ", collect: " + collect + ")";
  }

  int check(string ct)
  {
    WRAP_WERR("RXML check called");
    if (query("rxml")) {
      return sizeof(filter(rxmlmap,
                           lambda(string gl, string ct) {
                             return glob(gl, ct);
                           },
                           ct)) > 0;
    }
  }

  void set_id_headers()
  {
    WRAP_WERR("set_id_headers called");
    if (!_id->misc->moreheads) _id->misc->moreheads = ([]);
    _id->misc->moreheads += headermap;
  }

  mapping get_result()
  {
    WRAP_WERR("RXML get_result called");
    Roxen.add_http_header(headermap, "Cache-control",
                          "no-cache");
    _id->misc->cacheable = 0;
    set_id_headers();
    mapping res;
    if (collect == 1)
    {
      res = Roxen.http_rxml_answer(get_data(1), _id);
      //WEBAPP_WERR(sprintf("get_result returns rxml_answer=%O", res));
    }
    else
    {
      string ct = content_type;
      if (!ct || strlen(ct) == 0)
        ct = "text/plain";
      res = ([ "data":get_data(1),
               "type":ct,
               "extra_heads":headermap,
               "error":(int)retcode,
               "rettext":rettext ]);
      //WEBAPP_WERR(sprintf("get_result returns string_answer=%O", res));
    }
//     WRAP_WERR(sprintf("_id->misc=%O",
//                       mkmapping(indices(_id->misc), values(_id->misc))));
    return res;
  }

}

class ServletChainingWrapper
{
  inherit BaseWrapper;
  
  protected constant clazz = "ChainingWrapper";

  string _sprintf()
  {
    return "ServletChainingWrapper(#" + _ident + ", collect: " + collect + ")";
  }

  int check(string ct)
  {
    WRAP_WERR("CHAIN check called");
    return map_servlet_chain(ct)?1:0;
  }
}


//  Servlet loading mutex
Thread.Mutex load_mutex = Thread.Mutex();


int load_servlet(mapping(string:string|mapping|Servlet.servlet|int) servlet)
{
  //  Serialize initializations so concurrent threads won't init the same
  //  servlet several times.
  Thread.MutexKey key = load_mutex->lock();
  
  string classname = servlet["servlet-class"];

  if (!servlet->loaded)
    {
      if (classname) {
        WEBAPP_WERR(sprintf("Trying to load %s from %s",
                            servlet["servlet-name"], classname));
        mixed exc = catch(servlet->servlet = Servlet.servlet(classname, cls_loader));
        if(exc)
          {
            servlet->loaded = -1;
            report_error(LOCALE(4, "Servlet: %s\n"),exc[0]);
            status_info=sprintf(LOCALE(5, "<pre>%s</pre>"),exc[0]);
          }
        else
          if(servlet->servlet)
            {
              servlet->loaded = 1;
            }
      }
    }
  
  if ( servlet->loaded == 1 &&
       ( !servlet->initialized ||
         ( servlet->initialized == -1 && !servlet->permanent)))
    {
      mixed e = catch {
        WEBAPP_WERR(sprintf("Trying to initialize %s",
                            servlet["servlet-name"]));
        servlet->servlet->init(conf_ctx, make_initparam_mapping(servlet["initparams"]), servlet["servlet-name"]);
        servlet->initialized = 1;
      };
      if (e)
        {
          if (is_unavailable_exception(e))
            {
              servlet->initialized = -1; // mark unavailable exception
              servlet->permanent = e[2];
              servlet->exc_msg = e[1];
              servlet->retry = e[3];
            }
          else
            {
              servlet->initialized = -2; // mark unknown exception
              //report_error(LOCALE(4, "Servlet: %s\n"),e[0]);
              report_error(LOCALE(4, "Servlet: %s\n"),describe_backtrace(e));
              status_info=sprintf(LOCALE(5, "<pre>%s</pre>"),e[0]);
            }
        }
    }
}

mapping(string:string|mapping|Servlet.servlet|array) match_anyservlet(string f, RequestID id)
{
  mapping(string:string|mapping|Servlet.servlet|array) ret;
  if (query("anyservlet") && has_prefix(f, "/servlet/"))
    {
      //WEBAPP_WERR(sprintf("match_anyservlet(%s)", f));
      mixed fa = f/"/";
      if (sizeof(fa)>2)
        {
          string classname = fa[2];
          if (classname && sizeof(classname)>0) {
            WEBAPP_WERR("match on 'any'!!");
            if (servletmaps["any"][classname])
              ret = servlets[servletmaps["any"][classname]];
            else if ( servlets[classname] )
              {
                // A new servlet mapping to an old servlet name. Setup
                // the structures for it.
                servlets[classname]["url"] += ({ fa[..2]*"/" });
                ret = servlets[classname];

                servletmaps["any"][classname] = classname;
              }
            else
              {
                // A new servlet class. Setup the structures for it.
                ret = ([ ]);
                ret["servlet-class"] = classname;
                ret["servlet-name"] = classname;
                ret["url"] = ({ fa[..2]*"/" });
                servlets[ret["servlet-name"]] = ret;

                servletmaps["any"][classname] = classname;
              }
          }
          if (ret)
            {
              id->misc->servlet_path = fa[..2]*"/";
              if (sizeof(fa)>3)
                id->misc->path_info = "/" + fa[3..]*"/";
              return ret;
            }
        }
    }

  //WEBAPP_WERR("NO match on 'any'!!");
  return 0;
}

mapping(string:string|mapping|Servlet.servlet) match_exact_servlet(string f, RequestID id)
{
  return servletmaps["exact"] && servletmaps["exact"][f] &&
    servlets[servletmaps["exact"][f]];
}

mapping(string:string|mapping|Servlet.servlet) match_path_servlet(string f, RequestID id)
{
  foreach(indices(servletmaps["path"]), string p)
    {
//        WEBAPP_WERR(sprintf("match_path_servlet(%s) trying %s (p[..sizeof(p)-3]='%s')",
//               f, p, p[..sizeof(p)-3]));
//        WEBAPP_WERR(sprintf("servlet_path='%s', path_info='%s'",
//                            id->misc->servlet_path || "(null)",
//                            id->misc->path_info || "(null)"));
      if (p[..sizeof(p)-3] == f)
        {
          WEBAPP_WERR(sprintf("match on path=%s !!", p));
          return servlets[servletmaps["path"][p]];
        }
    }

  //WEBAPP_WERR("NO match on 'path'!!");
  array a = f/"/";
  if (sizeof(a)<3)
    return 0;
  else
    {
      id->misc->servlet_path = a[..sizeof(a)-2]*"/";
      id->misc->path_info = "/" + (a[sizeof(a)-1]||"") + (id->misc->path_info||"");
      return match_path_servlet(id->misc->servlet_path, id);
    }
}

mapping(string:string|mapping|Servlet.servlet) match_ext_servlet(string f, RequestID id)
{
  foreach(indices(servletmaps["ext"]), string e)
    {
//       WEBAPP_WERR(sprintf("match_ext_servlet(%s) trying %s " +
//              "(e[1..]='%s', f[sizeof(f)-sizeof(e)..]='%s')",
//              f, e, e[1..], f[sizeof(f)-sizeof(e)+1..]));
      if (e[1..] == f[sizeof(f)-sizeof(e)+1..])
        {
          WEBAPP_WERR("match on 'ext' "+e+"!");
	  mixed s = servlets[servletmaps["ext"][e]];
	  // Kludge to be able to mount jsp pages on a mountpoint
	  // other than / with gnujsp.
	  if(s["servlet-class"] == "org.gjt.jsp.JspServlet") {
	    WEBAPP_WERR("applying pathinfo kludge");
	    id->misc->path_info = id->misc->servlet_path;
	  }
          return s;
        }
    }

  //WEBAPP_WERR("NO match on 'ext'!!");
  return 0;
}

mapping(string:string|mapping|Servlet.servlet) match_default_servlet(string f, RequestID id)
{
  return servletmaps["default"] && servletmaps["default"][f] &&
    servlets[servletmaps["default"][f]];
}

mapping(string:string|mapping|Servlet.servlet) map_servlet(string f, RequestID id)
{
  mapping(string:string|mapping|Servlet.servlet) serv;
  string index = combine_path("/", f);

  id->misc->servlet_path = index;
  id->misc->path_info = 0;
  serv = match_anyservlet(index, id);
  if (!serv) {
    id->misc->servlet_path = index;
    id->misc->path_info = 0;
    serv = match_exact_servlet(index, id);
  }
  if (!serv) {
    id->misc->servlet_path = index;
    id->misc->path_info = 0;
    serv = match_path_servlet(index, id);
  }
  if (!serv) {
    id->misc->servlet_path = index;
    id->misc->path_info = 0;
    serv = match_ext_servlet(index, id);
  }
  if (!serv) {
    id->misc->servlet_path = index;
    id->misc->path_info = 0;
    serv = match_default_servlet(index, id);
  }
  
  if (serv)
    {
      load_servlet(serv);
      return serv;
    }

  return 0;
}

mapping(string:string|mapping|Servlet.servlet) map_servlet_chain(string type)
{
  mapping(string:string|mapping|Servlet.servlet) serv;
  string s = servletmaps["chaining"][lower_case(type)];

  //WEBAPP_WERR(sprintf("trying chain type=%s", type));
  //WEBAPP_WERR(sprintf("trying chainmap=%O", servletmaps["chaining"]));

  if (s) {
    WEBAPP_WERR(sprintf("match on chain=%s !!", s));
    serv = servlets[s];
  }

  if (serv)
    {
      //WEBAPP_WERR(sprintf("match on chain servlet: %s !!", serv["servlet-name"]));
      load_servlet(serv);
      return serv;
    }

  return 0;
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
  string oldf = f;
  WEBAPP_WERR("Request for \""+f+"\"" +
		  (id->misc->internal_get ? " (internal)" : ""));

  string norm_f;

  catch {
    /* NOTE: NORMALIZE_PATH() may throw errors. */
    norm_f = NORMALIZE_PATH(norm_f = decode_path(path + f));
#if constant(system.normalize_path)
    if (!has_prefix(norm_f, normalized_path) &&
#ifdef __NT__
	(norm_f+"\\" != normalized_path)
#else /* !__NT__ */
	(norm_f+"/" != normalized_path)
#endif /* __NT__ */
	) {
      errors++;
      report_error(LOCALE(36, "Path verification of %O failed:\n"
			  "%O is not a prefix of %O\n"
			  ), oldf, normalized_path, norm_f);
      return http_low_answer(403, "<h2>File exists, but access forbidden "
			     "by user</h2>");
    }
    
    /* Adjust not_query */
    id->not_query = mountpoint + replace(norm_f[sizeof(normalized_path)..],
					 "\\", "/");
    if (sizeof(oldf) && (oldf[-1] == '/')) {
      id->not_query += "/";
    }

    /* Adjust f */
    f = replace(norm_f[sizeof(normalized_path)..], "\\", "/");
    if (sizeof(oldf) && (oldf[-1] == '/')) {
      f += "/";
    }
#endif /* constant(system.normalize_path) */
  };


  mapping(string:string|mapping|Servlet.servlet) servlet;
  string loc = id->misc->mountpoint = query("mountpoint");
  if (loc[-1] == '/')
    id->misc->mountpoint = loc[..sizeof(loc)-2];

  string path_info = id->misc->path_info;
  servlet = map_servlet(f, id);

  if (!servlet) {
    if (!is_special(f, id)) {
      id->misc->path_info = path_info;
      return ::find_file(f, id);
    }
    else 
      return 0;
  }
  else {
    if (servlet->initialized == 1)
      {
        if(id->my_fd == 0 && id->misc->trace_enter)
          ; /* In "Resolve path...", kluge to avoid backtrace. */
        else {
          object rxml_wrapper;
          object org_fd = id->my_fd;
          
          org_fd && org_fd->set_read_callback(0);
          org_fd && org_fd->set_close_callback(0);

          // Don't set to blocking mode if SSL.
          if (org_fd && !org_fd->CipherSpec) {
            org_fd->set_blocking();
          }

          if (mixed e = catch {
            rxml_wrapper = RXMLParseWrapper(org_fd, id);
	    id = id->clone_me();
            id->my_fd = rxml_wrapper;

#ifdef WEBAPP_CHAINING
            object chain_wrapper;
            mapping(string:string|mapping|Servlet.servlet) serv;
            int x=1;
            do {
              WEBAPP_WERR(sprintf("Chaining preparing: '%s'", servlet["servlet-name"]));
              chain_wrapper = ServletChainingWrapper(rxml_wrapper, id);
              id->my_fd = chain_wrapper;
              servlet->servlet->service(id);
              if (chain_wrapper->collect) {
                serv = map_servlet_chain(chain_wrapper->content_type);
                if (serv && serv->initialized == 1) {
                  id->data = chain_wrapper->get_data();
                  //werror("Chained data:\n" + hexdump(id->data));
                  servlet = serv;
                }
                else
                  x=0xffff;
              }
              WEBAPP_WERR(sprintf("Chaining: x=%d, collect=%d",
                                  x, chain_wrapper->collect));
              // Limit the chaining to 3 servlets!!
            } while (x++<3 && chain_wrapper->collect);

            if (x == 0xffff || (x>=3 && chain_wrapper->collect)) {
              id->misc->cacheable = 5;
              return http_low_answer(500, "<title>Servlet Error - chaining failed</title>"
                                     "<h1>Servlet Error - chaining failed</h1>"
                                     "<h2>Location: " +
                                     loc + f + "</h2>"
                                     "<b>The servlet you tried to run failed "
                                     "during chaining. Please contact the "
                                     "server administrator about this "
                                     "problem.</b>");
            }
#else /* WEBAPP_CHAINING */
            servlet->servlet->service(id);
#endif /* WEBAPP_CHAINING */

            if (rxml_wrapper->collect) {
              mixed res = rxml_wrapper->get_result();
              //WEBAPP_WERR(sprintf("res=%O", res ));
              return res;
            }

          })
          {
            throw(e);
          }
        }
        
        return Roxen.http_pipe_in_progress();
      }
    else if  (servlet->initialized == -1)
      if (servlet->permanent)
        {
          WEBAPP_WERR("Permanently unavailable detected in find_file");
          return http_low_answer(503, "<h1>Error: 503</h1>"
                                 "<h2>Location: " +
                                 loc + f + "</h2>"
                                 "<b>Permanently Unavailable</b><br><br>"
                                 "Service is permanently unavailable<br>");
        }
      else
        {
          WEBAPP_WERR("Service unavailable detected in find_file");
          id->misc->cacheable = servlet->retry;
          return http_low_answer(503, "<h1>Error: 503</h1>\n"
                                 "<h2>Location: " +
                                 loc + f + "</h2>"
                                 "<b>" + servlet->exc_msg + "</b><br><br>"
                                 "Service is unavailable, try again in " +
                                 servlet->retry + " seconds<br>");
        }
    else
      {
        return 0;
      }
  }
}

mixed call_servlet( RXML.Frame frame, RequestID id, string f, string name )
{
  string oldf = f;
  WEBAPP_WERR("Request for \""+f+"\"" +
		  (id->misc->internal_get ? " (internal)" : ""));

  string norm_f;

  catch {
    /* NOTE: NORMALIZE_PATH() may throw errors. */
    norm_f = NORMALIZE_PATH(norm_f = decode_path(path + f));
#if constant(system.normalize_path)
    if (!has_prefix(norm_f, normalized_path) &&
#ifdef __NT__
	(norm_f+"\\" != normalized_path)
#else /* !__NT__ */
	(norm_f+"/" != normalized_path)
#endif /* __NT__ */
	) {
      errors++;
      report_error(LOCALE(36, "Path verification of %O failed:\n"
			  "%O is not a prefix of %O\n"
			  ), oldf, normalized_path, norm_f);
      frame->parse_error("File " + f + " exists, but access forbidden "
			     "by user");
    }
    
    /* Adjust not_query */
    id->not_query = mountpoint + replace(norm_f[sizeof(normalized_path)..],
					 "\\", "/");
    if (sizeof(oldf) && (oldf[-1] == '/')) {
      id->not_query += "/";
    }

    /* Adjust f */
    f = replace(norm_f[sizeof(normalized_path)..], "\\", "/");
    if (sizeof(oldf) && (oldf[-1] == '/')) {
      f += "/";
    }
#endif /* constant(system.normalize_path) */
  };


  mapping(string:string|mapping|Servlet.servlet) servlet;
  string loc = id->misc->mountpoint = query("mountpoint");
  if (loc[-1] == '/')
    id->misc->mountpoint = loc[..sizeof(loc)-2];

  if (name && sizeof(name) > 0)
  {
    WEBAPP_WERR(sprintf("call_servlet: name=%s, f=%s", name, f));
    servlet = servlets[name];
    servlet && load_servlet(servlet);
    id->misc->servlet_path = combine_path("/", f);
    id->misc->path_info = 0;
  }
  if(!servlet) {
    servlet = map_servlet(f, id);
  }

  if (!servlet) {
      frame->parse_error("Servlet not found!\n");
  }
  else {
    if (servlet->initialized == 1)
      {
        if(id->my_fd == 0 && id->misc->trace_enter)
          ; /* In "Resolve path...", kluge to avoid backtrace. */
        else {
          object rxml_wrapper;

          if (mixed e = catch {
	    mapping request_headers = copy_value(id->request_headers);
            rxml_wrapper = RXMLParseWrapper(0, id);
	    id = id->clone_me();
            id->my_fd = rxml_wrapper;
	    id->request_headers = request_headers;

#ifdef WEBAPP_CHAINING
            object chain_wrapper;
            mapping(string:string|mapping|Servlet.servlet) serv;
            int x=1;
            do {
              WEBAPP_WERR(sprintf("Chaining preparing: '%s'", servlet["servlet-name"]));
              chain_wrapper = ServletChainingWrapper(rxml_wrapper, id);
              id->my_fd = chain_wrapper;
              servlet->servlet->service(id);
              if (chain_wrapper->collect) {
                serv = map_servlet_chain(chain_wrapper->content_type);
                if (serv && serv->initialized == 1) {
                  id->data = chain_wrapper->get_data();
                  //werror("Chained data:\n" + hexdump(id->data));
                  servlet = serv;
                }
                else
                  x=0xffff;
              }
              WEBAPP_WERR(sprintf("Chaining: x=%d, collect=%d",
                                  x, chain_wrapper->collect));
              // Limit the chaining to 3 servlets!!
            } while (x++<3 && chain_wrapper->collect);

            if (x == 0xffff || (x>=3 && chain_wrapper->collect)) {
              id->misc->cacheable = 5;
              frame->parse_error( "Servlet Error - chaining failed\n"
                                  "Location: " +
                                  loc + f + "\n"
                                  "The servlet you tried to run failed "
                                  "during chaining. \nPlease contact the "
                                  "server administrator about this "
                                  "problem.\n");
            }
#else /* WEBAPP_CHAINING */
            servlet->servlet->service(id);
#endif /* WEBAPP_CHAINING */

            if (rxml_wrapper->collect) {
              mixed res = rxml_wrapper->get_result();
              //WEBAPP_WERR(sprintf("res=%O", res ));
              
              return res;
            }
            WEBAPP_WERR(sprintf("rxml_wrapper=%O\n", rxml_wrapper));

          })
          {
            throw(e);
          }
        }
        
        frame->parse_error("Internal Error! Collect not set!\n");
      }
    else if  (servlet->initialized == -1)
      if (servlet->permanent)
        {
          WEBAPP_WERR("Permanently unavailable detected in call_servlet");
          frame->parse_error("Permanently Unavailable\n"
                             "Location: " +
                             loc + f + "\n"
                             "Service is permanently unavailable\n");
        }
      else
        {
          WEBAPP_WERR("Service unavailable detected in call_servlet");
          id->misc->cacheable = servlet->retry;
          frame->parse_error("Service Unavailable\n"
            "Location: " +
            loc + f + "\n" +
            servlet->exc_msg + "\n"
            "Service is unavailable, try again in " +
            servlet->retry + " seconds\n");
        }
    else
    {
      return 0;
    }
  }
}

class TagServlet 
{
  inherit RXML.Tag;
  constant name = "servlet";
  mapping(string:RXML.Type) req_arg_types = ([
    "webapp": RXML.t_text(RXML.PEnt)
  ]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "name": RXML.t_text(RXML.PEnt),
    "uri": RXML.t_text(RXML.PEnt),
    "no-headers": RXML.t_text(RXML.PEnt)
  ]);
  //array(RXML.Type) result_types = ({RXML.t_any});

  class Frame {
    inherit RXML.Frame;

    array do_enter(RequestID id) {
      return 0;
    }

    array do_return(RequestID id) {
      WEBAPP_WERR(sprintf("args=%O\n%s\n", args, query_name()));
      if(!args->uri && !args->name)
	parse_error("Neither uri nor name specified.\n");
      foreach (id->conf->get_providers("webapp"), RoxenModule m)
      {
        WEBAPP_WERR(sprintf("module:%O\n", m->query_name()));
        if (m->query("tagtarget") == args->webapp)
        {
          if(!objectp(id))
            error("No ID passed to 'TagServlet do_return'\n");

          // id->misc->common is here for compatibility; it's better to use
          // id->root_id->misc.
          if ( !id->misc )
            id->misc = ([]);
          if ( !id->misc->common )
            id->misc->common = ([]);

          RequestID fake_id = id->clone_me();

          fake_id->misc->common = id->misc->common;
          fake_id->misc->internal_get = 1;
	  // Restore headers.
	  fake_id->request_headers = copy_value(id->request_headers);
	  // Remove fake_id->raw to prevent the java bridge to use the
	  // raw and incorrect url.
	  fake_id->raw = 0;

          string uri;
          if (args->uri) {
	    // Use variables from provided uri, not id->real_variables.
	    fake_id->real_variables = ([]);
	    // Scan the provided uri for query variables.
            uri = fake_id->scan_for_query (args->uri);
	  } else
	    uri = id->not_query;

          uri = Roxen.fix_relative (uri, id);

          fake_id->raw_url=uri+(fake_id->query? "?"+fake_id->query: "");
          fake_id->not_query=uri;

	  // Remove mountpoint from the faked uri.
	  string f = has_prefix(uri, mountpoint)? uri[sizeof(mountpoint)..]: uri;

          mapping hdrs = m->call_servlet(this_object(), fake_id,
                                         f, args->name || "");

          CACHE( fake_id->misc->cacheable );
          destruct (fake_id);
          
          if (!mappingp(hdrs) && !objectp(hdrs)) {
            run_error("do_return(%O): uri = %O\n   hdrs = %O is not a mapping.\n",
                         id, uri, hdrs);
          }

	  if (!args["no-headers"]) {
	    if (hdrs->error && hdrs->error != 200) {
	      RXML_CONTEXT->set_misc (" _error", hdrs->error);
	      if (hdrs->rettext)
		RXML_CONTEXT->set_misc (" _rettext", hdrs->rettext);
	    }
	    if (hdrs->extra_heads)
	      RXML_CONTEXT->extend_scope ("header", hdrs->extra_heads);
	  }
//               foreach(rxml_wrapper->headermap, string h)
//               {
//                 if (stringp(rxml_wrapper->headermap[h]))
//                 {
//                   WEBAPP_WERR(sprintf("add_response_header(%s, %s)",
//                                       h,  rxml_wrapper->headermap[h]));
//                   id->add_response_header(h, rxml_wrapper->headermap[h]);
//                 }
//                 else
//                   foreach(rxml_wrapper->headermap[h], string v)
//                   {
//                     WEBAPP_WERR(sprintf("add_response_header(%s, %s)",
//                                         h,  rxml_wrapper->headermap[h]));
//                     id->add_response_header(h, v);
//                   }
//               }
          result = hdrs["data"];

          return 0;
        }
      }
      parse_error("No Web Application with name '" + args->webapp + "' found!\n");
      return 0;
    }

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

// Place holder to be able to find tagdoc.
class TagServlet 
{
  inherit RXML.Tag;
  constant name = "servlet";
  class Frame {
    inherit RXML.Frame;
  }
}
#endif


// NOTE: base is modified destructably!
private array(string) my_combine_path_array(array(string) base, string part)
{
  if ((part == ".") || (part == "")) {
    if ((part == "") && (!sizeof(base))) {
      return(({""}));
    } else {
      return(base);
    }
  } else if ((part == "..") && sizeof(base) &&
             (base[-1] != "..") && (base[-1] != "")) {
    base[-1] = part;
    return(base);
  } else {
    return(base + ({ part }));
  }
}

private array(string) glob_expand(string glob_path)
{
#ifdef __NT__
  glob_path = replace( glob_path, "\\", "/" );
#endif
  WEBAPP_WERR(sprintf("glob_expand(%s)",glob_path));
  string|array(string) ret_path = glob_path;

  // FIXME: Does not check if "*" or "?" was quoted!
  if (replace(ret_path, ({"*", "?"}), ({ "", "" })) != ret_path) {

    // Globs in the file-name.

    array(string|array(string)) matches = ({ ({ }) });
    multiset(string) paths; // Used to filter out duplicates.
    int i;
    //foreach(my_combine_path("", path)/"/", string part) {
    foreach(ret_path/"/", string part) {
      paths = (<>);
      if (replace(part, ({"*", "?"}), ({ "", "" })) != part) {
        // Got a glob.
        array(array(string)) new_matches = ({});
        foreach(matches, array(string) path) {
          array(string) dir;
          dir = Filesystem.System()->get_dir(combine_path("", path*"/"));
          if (dir && sizeof(dir)) {
            dir = glob(part, dir);
            if ((< '*', '?' >)[part[0]]) {
              // Glob-expanding does not expand to files starting with '.'
              dir = Array.filter(dir, lambda(string f) {
                                        return (sizeof(f) && (f[0] != '.'));
                                      });
            }
            foreach(sort(dir), string f) {
              array(string) arr = my_combine_path_array(path, f);
              string p = arr*"/";
              if (!paths[p]) {
                paths[p] = 1;
                new_matches += ({ arr });
              }
            }
          }
        }
        matches = new_matches;
      } else {
        // No glob
        // Just add the part. Modify matches in-place.
        for(i=0; i<sizeof(matches); i++) {
          matches[i] = my_combine_path_array(matches[i], part);
          string path = matches[i]*"/";
          if (paths[path]) {
            matches[i] = 0;
          } else {
            paths[path] = 1;
          }
        }
        matches -= ({ 0 });
      }
      if (!sizeof(matches)) {
        break;
      }
    }
    if (sizeof(matches)) {
      // Array => string
      for (i=0; i < sizeof(matches); i++) {
        matches[i] *= "/";
      }
      // Filter out non-existing or forbiden files/directories
      /*
      matches = Array.filter(matches,
                             lambda(string short, string cwd,
                                    object m_id) {
                               object id = RequestID2(m_id);
                               id->method = "LIST";
                               id->not_query = combine_path(cwd, short);
                               return(id->conf->stat_file(id->not_query,
                                                          id));
                             }, cwd, master_session);
      */
      if (sizeof(matches)) {
        ret_path = matches;
      }
    }
  }
  if (stringp(ret_path)) {
    // No glob
    //ret_path = ({ my_combine_path("", ret_path) });
    ret_path = ({ combine_path("", ret_path) });
  }

  return ret_path;
}

class ClassPathList
{
  inherit Variable.FileList;

  array verify_set( string|array(string) value )
  {
    if(stringp(value))
      value = ({ value });
    string warn = "";
    foreach( value-({""}), string value ) {
      array(string) value_exp = glob_expand(value);
      if (sizeof(value_exp) > 0)
        foreach(value_exp, string val2) {
          Stat s = r_file_stat( val2 );
          Stdio.File f = Stdio.File();
          if( !s )
            warn += val2 + LOCALE(12, " does not exist\n");
          else if( s[ ST_SIZE ] == -2 )
            ;
          else if( !(f->open( val2, "r" )) )
            warn += LOCALE(13, "Can't read ") + val2 + "\n";
          else {
            if( f->read(2) != "PK" )
              warn += val2 + LOCALE(14, " is not a JAR file\n");
            f->close();
          }
        }
      else
        warn += value + LOCALE(12, " does not exist\n");
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
    while (has_suffix(value, "/"))
      value = value[..sizeof(value)-2];
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

protected int invisible_cb(RequestID id, Variable.Variable i )
{
  return 1;
}

protected string isprint(int c)
{
  if (c>=0x20 && c<0x80)
    return sprintf("%c", c);

  return ".";
}

protected string hexdump(string s)
{
  int count = 0;
  string ret = "";
  array(array(int)) saa;
  sscanf(s, "%{%c%}", saa);
  foreach(saa*({})/16.0, array(int) a)
  {
    ret += sprintf("%4x: %-36{%{%02x%} %} %{%s%}\n",
                   count,
                   (a/4.0)/1.0,
                   map(a, isprint) );
    count += 16;
  }
  return ret;
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

  defvar("rxmltypes", "text/xml text/html", LOCALE(37, "RXMLTypes"), TYPE_TEXT,
	 LOCALE(9, "Content types that should be passed on to the "
                "RXML Parser."), 0,
         lambda() { return !query("rxml"); } );

  defvar("codebase",
         ClassPathList( ({""}), VAR_MORE,
                        LOCALE(20, "Class path"),
                        LOCALE(21, "Any number of directories and/or JAR "
                               "files from which to load the "
                               "support classes.") ) );

  defvar("parameters", "", LOCALE(22, "Parameters"), TYPE_TEXT,
	 LOCALE(23, "Parameters for all servlets on the form "
                "<tt><i>name</i>=<i>value</i></tt>, one per line.") );

#ifdef ENABLE_JSP
  defvar("jspengine", "None",
         LOCALE(38, "Servlet engine"), TYPE_MULTIPLE_STRING,
         LOCALE(39, "Select the jsp engine that should handle files with "
                "the .jsp extension."),
         ({ "None", "GNUJSP", "Jasper" })
         );

  defvar("jspdebug", 0, LOCALE(40, "JSP Debug"), TYPE_FLAG|VAR_MORE,
	 LOCALE(41, "Enable debug output from the JSP engine."), 0,
         lambda() { return query("jspengine") == "None"; } );

  defvar("jspsenderrtoclient", 0, LOCALE(42, "Send Errors To Client"),
         TYPE_FLAG|VAR_MORE,
	 LOCALE(43, "Return jsp compilation errors to the client."), 0,
         lambda() { return query("jspengine") != "Jasper"; } );

#endif // ENABLE_JSP

  defvar("tagtarget", "", LOCALE(44, "Target name"), TYPE_STRING|VAR_MORE,
	 LOCALE(28, "Target name to use in the servlet tag to reference "
                "this Web Application. Leave empty to exclude "
                "from the servlet tag.") );

  defvar("anyservlet", 0, LOCALE(24, "Access any servlet"), TYPE_FLAG|VAR_MORE,
	 LOCALE(25, "Use a servlet mapping that mounts any servlet onto "
                "&lt;Mount Point&gt;/servlet/") );

  defvar("preloadall", 0, LOCALE(34, "Preload all servlets"),
         TYPE_FLAG|VAR_MORE,
	 LOCALE(35, "Load all servlets at module initialization time "
                "even if load-on-startup is not specified in web.xml") );
}

TAGDOCUMENTATION
#ifdef manual
constant tagdoc=([
"servlet":#"<desc type='tag'><p><short>
 Inserts the content produced by running a servlet.</short>
</p></desc>

<attr name='webapp' value='string' required='required'>
 <p>The Web Application that contains the servlet.</p>
</attr>

<attr name='name' value='string'>
 <p>The name of the servlet. This is taken from the &lt;servlet-name&gt;
 entry in the web.xml file.</p>
</attr>

<attr name='uri' value='string'>
 <p>The uri of the servlet. This is matched against the &lt;url-pattern&gt;
 entry in the web.xml file if the name attribute is not given, otherwise
 it is just passed on to the servlet as the servlet path.</p>
</attr>

<attr name='no-headers'>
 <p>If set no headers from the result will be set in the page.</p>
</attr>"
,

//----------------------------------------------------------------------


    ]);
#endif
