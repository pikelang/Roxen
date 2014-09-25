//
// $Id$
//
// Support for files with php markup.
//
// 2005-03-09 Henrik Grubbström
//

#include <module.h>
#include <roxen.h>

inherit "cgi.pike";

constant cvs_version = "$Id$";

constant module_type = MODULE_FILE_EXTENSION;
constant module_name = "Scripting: PHP scripting support";
constant module_doc  = "Support for the "
  "<a href=\"http://www.php.net/\">PHP</a> scripting engine.";

// #define PHP_DEBUG

#ifdef PHP_DEBUG
# define DWERR(X ...) werror("PHP: "+sprintf(X)+"\n")
#else /* !CGI_DEBUG */
# define DWERR(X ...)
#endif /* CGI_DEBUG */

string find_in_path(string fname, string pathstr)
{
  array(string) path;
#if defined(__NT__) || defined(__AmigaOS__)
  path = pathstr / ";";
#else
  path = pathstr / ":";
#endif

  foreach(path, string p) {
    if (file_stat(p = combine_path(p, fname))) return p;
  }
  return 0;
}

void create(Configuration conf)
{
  ::create(conf);

  defvar("command", Variable.File(find_in_path("php", getenv("PATH")) ||
				  "/usr/local/bin/php",
				  VAR_INITIAL, "PHP interpreter",
				  "This is the full path to the php "
				  "interpreter."));
  defvar("ext", Variable.StringList(({ "php" }), 0, "PHP-script extensions",
				       "List of extensions to send though "
				       "the php interpreter."));
}

array(string) query_file_extensions()
{
  return query("ext");
}

class PHPScript
{
  Stdio.File scriptfd;
  array (string) arguments;
  Stdio.File stdin;
  Stdio.File stdout;
  // stderr is handled by run().
  mapping (string:string) environment;
  int blocking;

  string priority;   // generic priority
  object pid;       // the process id of the CGI script
  string tosend;   // data from the client to the script.

  RequestID mid;
#if UNIX
  mapping (string:int)    limits;
  int uid, gid;
  array(int) extra_gids;
#endif
#ifdef __NT__
  function(string,array(string):array(string)) nt_opencommand;
#endif

  void check_pid()
  {
    DWERR("PHPScript::check_pid()");

    if(!pid || pid->status())
    {
      remove_call_out(kill_script);
      destruct();
      return;
    }
    call_out( check_pid, 0.1 );
  }

  Stdio.File get_fd()
  {
    DWERR("PHPScript::get_fd()");

    // Send input to script..
    Stdio.sendfile(0/*tosend*/,scriptfd,-1,-1,0,stdin,
		   lambda(int i,mixed q){
		     DWERR("Wrote %d bytes to stdin.\n", i);
		     stdin->close();
		     stdin=0;
		   });

    // And then read the output.
    if(!blocking)
    {
      Stdio.File fd = CGIWrapper(stdout, mid, kill_script)->get_fd();
      stdout = 0;
      if( query("rxml") )
        fd = RXMLWrapper( fd,mid,kill_script )->get_fd();
      call_out( check_pid, 0.1 );
      return fd;
    }
    //
    // Blocking (<insert file=foo.cgi> and <!--#exec cgi=..>)
    // Quick'n'dirty version.
    //
    // This will not be parsed. At all. And why is this not a problem?
    //   o <insert file=...> dicards all headers.
    //   o <insert file=...> does RXML parsing on it's own (automatically)
    //   o The user probably does not want the .cgi rxml-parsed twice,
    //     even though that's the correct solution to the problem (and rather
    //     easy to add, as well)
    //
    remove_call_out( kill_script );
    return stdout;
  }

  // HUP, PIPE, INT, TERM, KILL
  protected constant kill_signals = ({ 1, 13, 2, 15, 9 });
  protected constant kill_interval = 3;
  protected int next_kill;

  void kill_script()
  {
    DWERR(sprintf("PHPScript::kill_script()"
		  "next_kill: %d\n", next_kill));

    if(pid && !pid->status())
    {
      int signum = 9;
      if (next_kill < sizeof(kill_signals)) {
	signum = kill_signals[next_kill++];
      }
      if(pid->kill)  // Pike 0.7, for roxen 1.4 and later
        pid->kill(signum);
      else
        kill( pid->pid(), signum); // Pike 0.6, for roxen 1.3
      call_out(kill_script, kill_interval);
    }
  }

  PHPScript run()
  {
    DWERR("PHPScript::run()");

    Stdio.File t, stderr;
    stdin  = Stdio.File();
    stdout = Stdio.File();
    switch( query("stderr") )
    {
     case "main log file":
       stderr = Stdio.stderr;
       break;
     case "custom log file":
       stderr = Roxen.open_log_file( query( "cgilog" ) );
       break;
     case "browser":
       stderr = stdout;
       break;
    }

    mapping options = ([
      "stdin":stdin,
      "stdout":(t=stdout->pipe(/*Stdio.PROP_IPC|Stdio.PROP_NONBLOCK*/)),
      "stderr":(stderr==stdout?t:stderr),
      "env":environment,
      "noinitgroups":1,
    ]);
    stdin = stdin->pipe(/*Stdio.PROP_IPC|Stdio.PROP_NONBLOCK*/);

    if (mid->realfile ||
	(mid->realfile = mid->conf->real_file(mid->not_query, mid))) {
      options->cwd = combine_path(getcwd(), mid->realfile, "..");
    }

#if UNIX
    if(!getuid())
    {
      if (uid >= 0) {
	options->uid = uid;
      } else {
	// Some OS's (HPUX) have negative uids in /etc/passwd,
	// but don't like them in setuid() et al.
	// Remap them to the old 16bit uids.
	options->uid = 0xffff & uid;

	if (options->uid <= 10) {
	  // Paranoia
	  options->uid = 65534;
	}
      }
      if (gid >= 0) {
	options->gid = gid;
      } else {
	// Some OS's (HPUX) have negative gids in /etc/passwd,
	// but don't like them in setgid() et al.
	// Remap them to the old 16bit gids.
	options->gid = 0xffff & gid;

// 	if (options->gid <= 10) {
// 	  // Paranoia
// 	  options->gid = 65534;
// 	}
      }

      // this is not really 100% correct, since it will keep the group list
      // of roxen when starting a script as a different user when that user
      // should really have no extra groups at all, but on Linux this fails
      // for some reason. So, when the extra group list is empty, ignore it
      if( sizeof( extra_gids ) ) 
        options->setgroups = extra_gids;
      else
        options->setgroups = ({ gid });
        
      if( !uid && query("warn_root_cgi") )
        report_warning( "CGI: Running "+command+" as root (as per request)" );
    }
    if(query("nice"))
    {
      m_delete(options, "priority");
      options->nice = query("nice");
    }
    if( limits )
      options->rlimit = limits;
#endif

    DWERR(sprintf("Options: %O\n", options));

#ifdef __NT__
    if(!(pid = Process.Process( nt_opencommand(query("command"),
					       arguments),
				options )))
#else
    if(!(pid = Process.Process( ({ query("command") }) + arguments,
				options )))
#endif /* __NT__ */
      error("Failed to create PHP process.\n");
    if(query("kill_call_out"))
      call_out( kill_script, query("kill_call_out")*60 );
    return this_object();
  }


  void create( RequestID id, Stdio.File o )
  {
    DWERR("PHPScript()");

    mid = id;
    scriptfd = o;

    if(id->misc->orig && this_thread() == roxen.backend_thread)
      // An <insert file=...> and we are
      // currently in the backend thread.
      blocking = 1;

#if UNIX
#define LIMIT(L,X,Y,M,N) if(query(#Y)!=N){if(!L)L=([]);L->X=query(#Y)*M;}
    [uid,gid,extra_gids] = verify_access( id );
    LIMIT( limits, core, coresize, 1, -2 );
    LIMIT( limits, cpu, maxtime, 1, -2 );
    LIMIT( limits, fsize, filesize, 1, -2 );
    LIMIT( limits, nofiles, open_files, 1, 0 );
    LIMIT( limits, stack, stack, 1024, -2 );
    LIMIT( limits, data, datasize, 1024, -2 );
    LIMIT( limits, map_mem, datasize, 1024, -2 );
    LIMIT( limits, mem, datasize, 1024, -2 );
#undef LIMIT
#endif

    environment =(query("env")?getenv():([]));
    environment |= global_env;
    environment |= Roxen.build_env_vars( id->realfile, id, id->misc->path_info );
    environment |= Roxen.build_roxen_env_vars(id);
    if(id->misc->ssi_env)
      environment |= id->misc->ssi_env;
    if(id->misc->is_redirected)
      environment["REDIRECT_STATUS"] = "1";
    if(id->rawauth && query("rawauth"))
      environment["HTTP_AUTHORIZATION"] = (string)id->rawauth;
    else
      m_delete(environment, "HTTP_AUTHORIZATION");
    if(query("clearpass") && id->auth && id->realauth ) {
      environment["REMOTE_USER"] = (id->realauth/":")[0];
      environment["REMOTE_PASSWORD"] = (id->realauth/":")[1..]*":";
    } else {
      m_delete(environment, "REMOTE_PASSWORD");
    }
    if (id->rawauth) {
      environment["AUTH_TYPE"] = (id->rawauth/" ")[0];
    }

    environment->PHP_SELF = environment->DOCUMENT_URI =
      environment->SCRIPT_NAME;

    // Make sure php doesn't think it's a cgi script.
    m_delete(environment, "SCRIPT_FILENAME");
    m_delete(environment, "SERVER_SOFTWARE");
    m_delete(environment, "SERVER_NAME");
    m_delete(environment, "GATEWAY_INTERFACE");
    m_delete(environment, "REQUEST_METHOD");

    // Protect against execution of arbitrary code in broken bash.
    foreach(environment; string e; string v) {
      if (has_prefix(v, "() {")) {
	report_warning("CGI: Function definition in environment variable:\n"
		       "CGI: %O=%O\n",
		       e, v);
	environment[e] = " " + v;
      }
    }

#if 0
    if(environment->INDEX)
      arguments = Array.map(environment->INDEX/"+", http_decode_string);
    else
#endif /* 0 */
      arguments = ({});
  }
}

mapping handle_file_extension(object o, string e, RequestID id)
{
  if (!(<"GET", "HEAD">)[id->method]) return 0;
  NOCACHE();
  return Roxen.http_stream(PHPScript(id, o)->run()->get_fd());
}
