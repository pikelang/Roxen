#include <module.h>
#include <variables.h>
inherit "module";

/* Roxen PHP module.
 *   (c) David Hedbor  1999
 *   Modified by Per Hedbor 2000
 */
#ifdef PHP_DEBUG
#define DWERROR(X)	report_debug(X)
#else /* !PHP_DEBUG */
#define DWERROR(X)
#endif /* PHP_DEBUG */


#include <roxen.h>
inherit "roxenlib";


constant cvs_version="$Id: php4.pike,v 2.6 2000/04/25 04:55:58 per Exp $";
constant thread_safe=1;
constant module_type=MODULE_FILE_EXTENSION;

constant module_name="PHP Script Support";
constant module_doc =("This module allows Roxen users to run PHP scripts, "
                      "optionally in combination with RXML. ");

#if constant(PHP4.Interpreter)

class PHPScript
{
  PHP4.Interpreter interpreter;
  string command;
  string buffer="";
  // stderr is handled by run().
  mapping (string:string) environment;
  int written, close_when_done;
  RequestID mid;

  void done()
  {
    if(strlen(buffer))
    {
      close_when_done = 1;
      if(QUERY(rxml))
      {
        if( mid )
          buffer = parse_rxml(buffer, mid);
	write_callback();
      }
    } else
      destruct();
  }

  void destroy()
  {
    if( mid )
    {
      mid->file = ([ "len": written, "raw":1 ]);
      mid->do_log();
    }
  }

  void write_callback()
  {
    DWERROR("PHP:Wrapper::write_callback()\n");
    if(!strlen(buffer))
      return;
    int nelems;
    array err = catch { nelems = mid->my_fd->write(buffer); };
    DWERROR(sprintf("PHP:Wrapper::write_callback(): write(%O) => %d\n",
		    buffer, nelems));
    if( err || nelems < 0 )
    // if nelems == 0, network buffer is full. We still want to continue.
    {
      buffer="";
      close_when_done = -1;
    }
    else
    {
      written += nelems;
      buffer = buffer[nelems..];
      DWERROR(sprintf("Done: %d %d...\n", strlen(buffer), close_when_done));
      if(close_when_done && !strlen(buffer)) {
	destruct();
      }
    }
  }

  int write( string what )
  {
    DWERROR(sprintf("PHP:Wrapper::write(%O)\n", what));
    if(close_when_done == -1) // Remote closed
      return -1;
    if(buffer == "" )
    {
      buffer = what;
      if(!QUERY(rxml)) write_callback();
    }
    else
      buffer += what;
    return strlen(what);
  }

  void send_headers(int code, mapping headers)
  {
    DWERROR(sprintf("PHP:PHPWrapper::send_headers(%d,%O)\n", code, headers));
    string result = "", post="";
    string code = errors[code||200];
    int ct_received = 0, sv_received = 0;
    if(headers)
      foreach(indices(headers), string header)
      {
	string value = headers[header];
	if(!header || !value)
	{
	  // Heavy DWIM. For persons who forget about headers altogether.
	  continue;
	}
	header = String.trim_whites(header);
	value = String.trim_whites(value);
	switch(lower_case( header ))
	{
	case "status":
	  code = value;
	  break;

	case "content-type":
	  ct_received=1;
	  result += header+": "+value+"\r\n";
	  break;

	case "server":
	  sv_received=1;
	  result += header+": "+value+"\r\n";
	  break;

	case "location":
	  code = "302 Redirection";
	  result += header+": "+value+"\r\n";
	  break;

	default:
	  result += header+": "+value+"\r\n";
	  break;
	}
      }
    if(!sv_received)
      result += "Server: "+roxen.version()+"/PHP4\r\n";
    if(!ct_received)
      result += "Content-Type: text/html\r\n";
    write("HTTP/1.0 "+code+"\r\n"+result+"\r\n");
  }

  PHPScript run()
  {
    DWERROR("PHP:PHPScript::run()\n");
    mapping options = ([
      "env":environment,
    ]);

    if(!QUERY(rxml))
    {
      mid->my_fd->set_blocking();
      options->my_fd = mid->my_fd;
    }

    mid->my_fd->set_close_callback(done);
    interpreter->run(command, options, this_object(), done);
    return this_object();
  }
  int post_sent;
  string read_post(int length)
  {
    if(!mid->data) return 0;
    string data = mid->data[post_sent..post_sent+length-1];
    post_sent += strlen(data);
    //    werror("%s\n", data);
    return data;
  }
  
  void create( object id )
  {
    DWERROR("PHP:PHPScript()\n");
    interpreter = PHP4.Interpreter();
    mid = id;
    if(!id->realfile)
    {
      id->realfile = id->conf->real_file( id->not_query, id );
      if(!id->realfile)
        error("No real file associated with "+id->not_query+
              ", thus it's not possible to run it as a PHP script.\n");
    }
    command = id->realfile;

    environment =([]);
    environment |= global_env;
    environment |= build_env_vars( id->realfile, id, id->misc->path_info );
    environment |= build_roxen_env_vars(id);
    if(id->misc->ssi_env)     	environment |= id->misc->ssi_env;
    if(id->misc->is_redirected) environment["REDIRECT_STATUS"] = "1";
    if(id->rawauth && QUERY(rawauth))
      environment["HTTP_AUTHORIZATION"] = (string)id->rawauth;
    else
      m_delete(environment, "HTTP_AUTHORIZATION");
    if(QUERY(clearpass) && id->auth && id->realauth ) {
      environment["REMOTE_USER"] = (id->realauth/":")[0];
      environment["REMOTE_PASSWORD"] = (id->realauth/":")[1];
    } else
      m_delete(environment, "REMOTE_PASSWORD");
    if (id->rawauth)
      environment["AUTH_TYPE"] = (id->rawauth/" ")[0];
    // Lets populate more!
    environment["REQUEST_URI"] =  environment["DOCUMENT_URI"];
    environment["PHP_SELF"]    =  environment["DOCUMENT_URI"];

    // Not part of the "standard" PHP environment apparently...
    m_delete(environment, "DOCUMENT_URI");
    
    if(id->misc->user_document_root)
      environment["DOCUMENT_ROOT"] = id->misc->user_document_root;
  }
}

mapping(string:string) global_env = ([]);
void start(int n, object conf)
{
  DWERROR("PHP:start()\n");

  module_dependencies(conf, ({ "pathinfo" }));
  if(conf)
  {
    string tmp=conf->query("MyWorldLocation");
    sscanf(tmp, "%*s//%s", tmp);
    sscanf(tmp, "%s:", tmp);
    sscanf(tmp, "%s/", tmp);
    global_env["SERVER_NAME"]=tmp;
    global_env["SERVER_SOFTWARE"]=roxen.version();
    global_env["GATEWAY_INTERFACE"]="PHP/1.1";
    global_env["SERVER_PROTOCOL"]="HTTP/1.0";
    global_env["SERVER_URL"]=conf->query("MyWorldLocation");

    array us = ({0,0});
    foreach(query("extra_env")/"\n", tmp)
      if(sscanf(tmp, "%s=%s", us[0], us[1])==2)
        global_env[us[0]] = us[1];
  }
}

int|mapping handle_file_extension(object o, string e, object id)
{
  DWERROR("PHP:handle_file_extension()\n");
  roxen->handle(PHPScript(id)->run);
  DWERROR("PHP:handle_file_extension done\n");
  return http_pipe_in_progress();
}
#else

// Do not dump to a .o file if no PHP4 is available, since it will then
// not be possible to get it later on without removal of the .o file.
constant dont_dump_program = 1; 

string status()
{
  return 
#"<font color='&usr.warncolor;'>PHP4 is not available in this roxen.<p>
  To get php4:
  <ol>
    <li> Check php4 out from CVS (there is no release version with roxen support available yet)<br>
         See <a target=new href='http://www.php.net/version4/cvs.php'>the PHP4 CVS instructions</a>
    <li> Configure php4 with --with-roxen="+(getcwd()-"server")+#"
    <li> Make and install php4
    <li> Restart roxen
  </ol></font>";
}

int|mapping handle_file_extension(object o, string e, object id)
{
  return http_string_answer( status(), "text/html" );
}
#endif

array (string) query_file_extensions()
{
  return QUERY(ext);
}

void create(object conf)
{
  defvar("rxml", 0, "Parse RXML in PHP-scripts", TYPE_FLAG,
	 "If this is set, the output from PHP-scripts handled by this "
         "module will be RXMl parsed. NOTE: No data will be returned to the "
         "client until the PHP-script is fully parsed.");

  defvar("extra_env", "", "Extra environment variables", TYPE_TEXT_FIELD,
	 "Extra variables to be sent to the script, format:<pre>"
	 "NAME=value\n"
	 "NAME=value\n"
	 "</pre>Please note that the standard variables will have higher "
	 "priority.");

  defvar("ext",
	 ({"php", "php3", "php4"}),
         "PHP-script extensions", TYPE_STRING_LIST,
         "All files ending with these extensions, will be parsed as "+
	 "PHP-scripts.");

  defvar("rawauth", 0, "Raw user info", TYPE_FLAG|VAR_MORE,
	 "If set, the raw, unparsed, user info will be sent to the script, "
	 " in the HTTP_AUTHORIZATION environment variable. This is not "
	 "recommended, but some scripts need it. Please note that this "
	 "will give the scripts access to the password used.");

  defvar("clearpass", 0, "Send decoded password", TYPE_FLAG|VAR_MORE,
	 "If set, the variable REMOTE_PASSWORD will be set to the decoded "
	 "password value.");
}
