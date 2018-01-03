// This is a roxen module. Copyright © 1999 - 2009, Roxen IS.

inherit "module";

#include <module.h>

string cvs_version = "$Id$";
int thread_safe=1;
constant module_unique = 0;

protected inherit "http";

object servlet;

string status_info="";

constant module_type = MODULE_LOCATION | MODULE_FILE_EXTENSION;
constant module_name = "Java: Java Servlet bridge";
constant module_doc  = "An interface to Java <a href=\"http://java.sun.com/"
  "products/servlet/index.html""\">Servlets</a>.";

#if constant(Servlet.servlet)

void stop()
{
  if(servlet) {
    destruct(servlet);
    servlet = 0;
  }
}

protected mapping(string:string) make_initparam_mapping()
{
  mapping(string:string) p = ([]);
  string n, v;
  foreach(query("parameters")/"\n", string s)
    if(2==sscanf(s, "%[^=]=%s", n, v))
      p[n]=v;
  return p;
}

void start(int x, Configuration conf)
{
  if(x == 2)
    stop();
  else if(x != 0)
    return;

  if(query("classname")=="NONE") {
    status_info = "No servlet class selected";
    return;
  }

  mixed exc = catch(servlet = Servlet.servlet(query("classname"),
					      query("codebase")-({""})));
  status_info="";
  if(exc)
  {
    report_error("Servlet: %s\n",exc[0]);
    status_info=sprintf("<pre>%s</pre>",exc[0]);
  }
  else
    if(servlet)
      servlet->init(Servlet.conf_context(conf), make_initparam_mapping());
}

string status()
{
  return (servlet?
	  servlet->info() || "<i>No servlet information available</i>" :
	  "<font color=red>Servlet not loaded</font>"+"<br>"+
	  status_info);
}

string query_name()
{
  if(query("ex"))
    return sprintf("Servlet %s handling extension %s",
		   query("classname"), query("ext")*", ");
  else
    return sprintf("Servlet %s mounted on %s",
		   query("classname"), query("location"));
}

class RXMLParseWrapper
{
  protected object _file;
  protected object _id;
  protected string _data;

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

mixed find_file( string f, RequestID id )
{
  if(!servlet || query("ex"))
    return 0;

  if(id->my_fd == 0 && id->misc->trace_enter)
    ; /* In "Resolve path...", kluge to avoid backtrace. */
  else {
    id->my_fd->set_read_callback(0);
    id->my_fd->set_close_callback(0);
    id->my_fd->set_blocking();
    id->misc->servlet_path = query("location");
    id->misc->path_info = f;
    id->misc->mountpoint = "";
    if(query("rxml"))
      id->my_fd = (object)RXMLParseWrapper(id->my_fd, id);
    servlet->service(id);
  }

  return Roxen.http_pipe_in_progress();
}

mixed handle_file_extension(object o, string e, RequestID id)
{
  if(!servlet || !query("ex"))
    return 0;
  
  if(id->my_fd == 0 && id->misc->trace_enter)
    ; /* In "Resolve path...", kluge to avoid backtrace. */
  else {
    id->my_fd->set_read_callback(0);
    id->my_fd->set_close_callback(0);
    id->my_fd->set_blocking();
    id->misc->path_info = id->not_query;
    id->misc->mountpoint = "/";
    if(query("rxml"))
      id->my_fd = (object)RXMLParseWrapper(id->my_fd, id);
    servlet->service(id);
  }

  return Roxen.http_pipe_in_progress();
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

int|mapping handle_file_extension(object o, string e, object id)
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
        warn += value+" does not exist\n";
      else if( s[ ST_SIZE ] == -2 )
	;
      else if( !(f->open( value, "r" )) )
        warn += "Can't read "+value+"\n";
      else {
	if( f->read(2) != "PK" )
	  warn += value+" is not a JAR file\n";
	f->close();
      }
    }
    if( strlen( warn ) )
      return ({ warn, value });
    return ::verify_set( value );
  }
}

array(string) query_file_extensions()
{
  return (query("ex")? query("ext") : ({}));
}

void create()
{
  defvar("ex", 0, "File extension servlet", TYPE_FLAG,
	 "Use a servlet mapping based on file extension rather than "
	 "path location.");

  defvar("location", "/servlet/NONE", "Servlet location", TYPE_LOCATION,
	 "This is where the servlet will be inserted in the "
	 "namespace of your server.", 0,
	 lambda() { return query("ex"); });

  defvar("ext", ({}), "Servlet extensions", TYPE_STRING_LIST,
         "All files ending with these extensions, will be handled by "+
	 "this servlet.", 0,
	 lambda() { return !query("ex"); });
  
  defvar("codebase", ClassPathList( ({"servlets"}), 0, "Class path",
				    "Any number of directories and/or JAR "
				    "files from which to load the servlet "
				    "and its support classes.") );
  
  defvar("classname", "NONE", "Class name", TYPE_STRING,
	 "The name of the servlet class to use.");

  defvar("parameters", "", "Parameters", TYPE_TEXT,
	 "Parameters for the servlet on the form "
	 "<tt><i>name</i>=<i>value</i></tt>, one per line.");

  defvar("rxml", 0, "Parse RXML in servlet output", TYPE_FLAG|VAR_MORE,
	 "If this is set, the output from the servlet handled by this "
         "module will be RXML parsed. NOTE: No data will be returned to the "
         "client until the output is fully parsed.");
}

