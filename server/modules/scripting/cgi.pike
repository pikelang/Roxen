// This is a roxen module. Copyright � 1996 - 2009, Roxen IS.
//

constant cvs_version = "$Id$";

#if !defined(__NT__) && !defined(__AmigaOS__)
# define UNIX 1
#else
# define UNIX 0
#endif

#include <module.h>
#include <roxen.h>
inherit "module";

/* maximum size of the header before sending and error message and
 * killing the script.
 */
#define MAXHEADERLEN 32769

/* Message sent if the header is too long */

#define LONGHEADER "HTTP/1.0 500 Buggy CGI Script\r\n\
Content-Type: text/html\r\n\r\n\
<title>CGI-Script Error</title> \n\
<h1>CGI-Script Error</h1> \n\
The CGI script you accessed is not working correctly. It tried \n\
to send too much header data (probably due to incorrect separation between \n\
the headers and the body). Please notify the author of the script of this\n\
problem.\n"

/* Message sent if no header is sent at all */

#define NOHEADER "HTTP/1.0 500 Buggy CGI Script\r\n\
Content-Type: text/html\r\n\r\n\
<title>CGI-Script Error</title> \n\
<h1>CGI-Script Error</h1> \n\
The CGI script you accessed is not working correctly. It didn't \n\
send any header data (possibly due to incorrect separation between \n\
the headers and the body). Please notify the author of the script of this\n\
problem.\n"


#ifdef CGI_DEBUG
# define DWERR(X) werror("CGI: "+X+"\n")
#else /* !CGI_DEBUG */
# define DWERR(X)
#endif /* CGI_DEBUG */

constant module_unique = 0;
constant module_type = MODULE_LOCATION | MODULE_FILE_EXTENSION | MODULE_TAG;
constant module_name = "Scripting: CGI scripting support";
constant module_doc  = "Support for the <a href=\"http://hoohoo.ncsa.uiuc.edu/docs/cgi/"
  "interface.html\">CGI/1.1 interface</a>, and more.";

#if UNIX
/*
** All this code to handle UID, GID and some other permission
** problems gracefully.
**
** Sometimes I really like single user systems like NT. :-)
**
*/
mapping pwuid_cache = ([]);
mapping cached_groups = ([]);

array get_cached_groups_for_user( int uid )
{
  if(cached_groups[ uid ] && cached_groups[ uid ][1]+3600>time(1))
    return cached_groups[ uid ][0];
  return (cached_groups[uid] = ({ get_groups_for_user( uid ), time(1) }))[0];
}

array lookup_user( string what )
{
  array uid;
  if(pwuid_cache[what]) return pwuid_cache[what];
  if((int)what)
    uid = getpwuid( (int)what );
  else
    uid = getpwnam( what );
  if(uid)
    return pwuid_cache[what] = ({ uid[2],uid[3] });
  report_warning("CGI: Failed to get user information for ["+
                 what+"] (assuming nobody)\n");
  catch {
    return getpwnam("nobody")[2..3];
  };
  report_error("CGI: Failed to get user information for nobody! "
               "Assuming 65535,65535\n");
  return ({ 65535, 65535 });
}

array init_groups( int uid, int gid )
{
  if(!query("setgroups"))
    return ({});
  return get_cached_groups_for_user( uid )-({ gid });
}

array verify_access( RequestID id )
{
  mixed us;
  if(!getuid())
  {
    if(query("user") && id->misc->is_user &&
       (us = file_stat(id->misc->is_user)) &&
       (us[5] >= 10))
    {
      // Scan for symlinks
      string fname = "";
      Stat a;
      Stat b;
      foreach(id->misc->is_user/"/", string part)
      {
        fname += part;
        if ((fname != "")) {
          if(((!(a = file_stat(fname, 1))) || ((< -3, -4 >)[a[1]])))
          {
            // Symlink or device encountered.
            // Don't allow symlinks from directories not owned by the
            // same user as the file itself.
            // Assume that symlinks from directories owned by users 0-9
	    // are safe.
	    // Assume that top-level symlinks are safe.
            if (!a || (a[1] == -4) ||
                (b && (b[5] != us[5]) && (b[5] >= 10)) ||
                !query("allow_symlinks")) {
              error("CGI: Bad symlink or device encountered: \"%s\"\n", fname);
	    }
	    /* This point is only reached if a[1] == -3.
	     * ie symlink encountered, and query("allow_symlinks") == 1.
	     */

	    // Stat what the symlink points to.
	    // NB: This can be fooled if root is stupid enough to symlink
	    //     to something the user can move.
	    a = file_stat(fname);
	    if (!a || a[1] == -4) {
	      error("CGI: Bad symlink or device encountered: \"%s\"\n",
		    fname);
	    }
          }
	  b = a;
	}
        fname += "/";
      }
      us = ({ us[5], us[6] }); // Yes, there is a reason for not having [5..6]
    }
    else if(us)
      us = ({ us[5], us[6] }); // Yes, there is a reason for not having [5..6]
    else
      us = lookup_user( query("runuser") );
  } else
    us = ({ getuid(), getgid() });
  return ({ us[0], us[1], init_groups( us[0], us[1] ) });
}
#endif


/* Basic wrapper.
**
**  This program sends everything from the fd given as argument to
**  a new filedescriptor. The other end of that FD is available by
**  calling get_fd()
**
**  The wrappers are used to parse the data from the CGI script in
**  several different ways.
**
**  There is a reason for the abundant FD-use, this code must support
**  the following operation operation modes:
**
** Non parsed no header parsing:
**  o nonblocking w/o threads
**  o nonblocking w threads
**  o blocking w/o threads
**  o blocking w threads
**
** Parsed no header parsing:
**  o nonblocking w/o threads
**  o nonblocking w threads
**  o blocking w/o threads
**  o blocking w threads
**
** Non parsed:
**  o nonblocking w/o threads
**  o nonblocking w threads
**  o blocking w/o threads
**  o blocking w threads
**
** Parsed:
**  o nonblocking w/o threads
**  o nonblocking w threads
**  o blocking w/o threads
**  o blocking w threads
**
**  Right now this is handled more or less automatically by the
**  Stdio.File module and the operating system. :-)
*/

class Wrapper
{
  constant name="Wrapper";
  string buffer = "";
  Stdio.File fromfd, tofd, tofdremote;
  RequestID mid;
  mixed done_cb;
  int close_when_done;
  int callback_disabled;

  void write_callback()
  {
    DWERR("Wrapper::write_callback()");

    if(!strlen(buffer))
      return;
    int nelems = tofd->write( buffer );

    DWERR(sprintf("Wrapper::write_callback(): write(%O) => %d",
		    buffer, nelems));

    if( nelems < 0 )
      // if nelems == 0, network buffer is full. We still want to continue.
    {
      buffer="";
      destroy();
    } else if( nelems > 0 ) {
      buffer = buffer[nelems..];
      if(close_when_done && !strlen(buffer)) {
        destroy();
	return;
      }

      // If the buffer just went below the low watermark, let it refill.
      if (buffer_high && strlen(buffer) < buffer_low &&
	  strlen(buffer)+nelems >= buffer_low && callback_disabled)
      {
	fromfd->set_nonblocking( read_callback, 0, close_callback );
	callback_disabled = 0;
      }
    }
  }

  void read_callback( mixed id, string what )
  {
    DWERR(sprintf("Wrapper::read_callback(%O, %O)", id, what));

    process( what );
  }

  void close_callback()
  {
    DWERR("Wrapper::close_callback()");

    done();
  }

  void output( string what )
  {
    DWERR(sprintf("Wrapper::output(%O)", what));

    if(buffer == "" )
    {
      buffer=what;
      write_callback();
    } else
      buffer += what;

    // If we have filled our buffer, stop asking for more data.
    if (buffer_high && strlen(buffer) > buffer_high && !callback_disabled)
    {
      fromfd->set_nonblocking( 0, 0, 0 );
      callback_disabled = 1;
    }
  }

  void destroy()
  {
    DWERR("Wrapper::destroy()");

    catch(done_cb(this_object()));
    catch(tofd->set_blocking());
    catch(fromfd->set_blocking());
    catch(tofd->close());
    catch(fromfd->close());
    tofd=fromfd=0;
  }

  object get_fd()
  {
    DWERR("Wrapper::get_fd()");

    /* Get rid of the reference, so that it gets closed properly
     * if the client breaks the connection.
     */
    object fd = tofdremote;
    tofdremote = 0;

    return fd;
  }

  void create( Stdio.File _f, RequestID _m, mixed _done_cb )
  {
    DWERR("Wrapper()");

    fromfd = _f;
    mid = _m;
    done_cb = _done_cb;
    tofdremote = Stdio.File( );
    tofd = tofdremote->pipe( ); // Stdio.PROP_NONBLOCK

    if (!tofd) {
      error("Failed to create pipe. errno: %s\n", strerror(errno()));
    }

#ifdef CGI_DEBUG
    function read_cb = class
    {
      void read_cb(mixed id, string s)
      {
	DWERR(sprintf("Wrapper::tofd->read_cb(%O, %O)", id, s));
      }
      void destroy()
      {
	DWERR(sprintf("Wrapper::tofd->read_cb Zapped from:"
			"%s\n", describe_backtrace(backtrace())));
      }
    }()->read_cb;
#else /* !CGI_DEBUG */
    function read_cb = lambda(){};
#endif /* CGI_DEBUG */
    /* NOTE: Thread-race:
     *       close_callback may get called directly,
     *       in which case both fds will get closed.
     */
    /* FIXME: What if the other end of tofd does a shutdown(3N)
     *        on the backward direction?
     */
    tofd->set_nonblocking( read_cb, write_callback, destroy );
    fromfd->set_nonblocking( read_callback, 0, close_callback );
  }


  // override these to get somewhat more non-trivial behaviour
  void done()
  {
    DWERR(sprintf("Wrapper::done(%d)", strlen(buffer)));

    if(strlen(buffer))
      close_when_done = 1;
    else
      destroy();
  }

  void process( string what )
  {
    DWERR(sprintf("Wrapper::process(%O)", what));

    output( what );
  }
}



/* RXML wrapper.
**
** Simply waits until the CGI-script is done, then
** parses the result and sends it to the client.
** Please note that the headers are also parsed.
*/
class RXMLWrapper
{
  inherit Wrapper;
  constant name="RXMLWrapper";

  string data="";

  void done()
  {
    DWERR("RXMLWrapper::done()");

    if(strlen(data))
    {
      output( Roxen.parse_rxml( data, mid ) );
      data="";
    }
    ::done();
  }

  void process( string what )
  {
    DWERR(sprintf("RXMLWrapper::process(%O)", what));

    data += what;
  }
}




/* CGI wrapper.
**
** Simply waits until the headers has been received, then
** parse them according to the CGI specification, and send
** them and the rest of the data to the client. After the
** headers are received, all data is sent as soon as it's
** received from the CGI script
*/
class CGIWrapper
{
  inherit Wrapper;
  constant name="CGIWrapper";

  string headers="";

  void done()
  {
    DWERR("CGIWrapper::done()");
    if(!mode && !parse_headers( ))
      output( NOHEADER );
    ::done();
  }

  string handle_headers( string headers )
  {
    DWERR(sprintf("CGIWrapper::handle_headers(%O)", headers));

    string result = "", post="";
    string code = "200 OK";
    int ct_received = 0, sv_received = 0;
    foreach((headers-"\r") / "\n", string h)
    {
      string header, value;
      sscanf(h, "%s:%s", header, value);
      if(!header || !value)
      {
        // Heavy DWIM. For persons who forget about headers altogether.
        post += h+"\n";
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
      result += "Server: "+roxen.version()+"\r\n";
    if(!ct_received)
      result += "Content-Type: text/html\r\n";
    return "HTTP/1.0 "+code+"\r\n"+result+"\r\n"+post;
  }

  // Rewritten by David. Before it bugged when headers were terminated with
  // \n\n, but the document contained \r\n\r\n somewhere in it. More complex
  // now, but it works and parsing-time-wise it should be about the same.

  int parse_headers( )
  {
    DWERR("CGIWrapper::parse_headers()");

    int pos, skip = 4, force_exit;
    if(strlen(headers) > MAXHEADERLEN)
    {
      DWERR("CGIWrapper::parse_headers()::Incorrect Headers");
      output( LONGHEADER );
      close_when_done = 1;
      mode++;
      done();
      return 1;
//       destroy( );
    }
    pos = search(headers, "\r\n\r\n");
    if(pos == -1) {
      // Check if there's a \n\n instead.
      pos = search(headers, "\n\n");
      if(pos == -1) {
	// Still haven't found the end of the headers.
	return 0;
      }
      skip = 2;
    } else {
      // Check if there's a \n\n before the \r\n\r\n.
      int pos2 = search(headers[..pos], "\n\n");
      if(pos2 != -1) {
	pos = pos2;
	skip = 2;
      }
    }
    string tmphead = headers;
    headers = "";

    output( handle_headers( tmphead[..pos-1] ) );
    output( tmphead[pos+skip..] );

    if(force_exit)
      call_out(done, 0);
    return 1;
  }

  protected int mode;
  void process( string what )
  {
    DWERR(sprintf("CGIWrapper::process(%O)", what));

    switch( mode )
    {
     case 0:
       headers += what;
       if(parse_headers( ))
         mode++;
       break;
     case 1:
       output( what );
    }
  }
}

#ifdef __NT__
mapping(string:object) nt_opencommands = ([]);

class NTOpenCommand
{
  protected array(string) line;
  protected array(string) repsrc;
  protected int starpos;

  protected int expiry;

  int expired()
  {
    return time(1)>expiry;
  }

  array(string) open(string file, array(string) args)
  {
    array(string) res;
    if (repsrc) {
      res = map(line, replace, repsrc,
		(({file})+args+
		 (sizeof(args)+1>=sizeof(repsrc)? ({}) :
		  allocate(sizeof(repsrc)-sizeof(args)-1, "")))
		[..sizeof(repsrc)-1]);
      if(starpos>=0)
	res = res[..starpos-1]+args+res[starpos+1..];
    } else {
      // Check for #!
      string s = Stdio.read_file(file, 0, 1);
      if (s && has_prefix(s, "#!")) {
	res = Process.split_quoted_string(s[2..]) + ({ file }) + args;
      } else {
	error(sprintf("CGI: Unknown filetype %O\n", file));
      }
    }
    return res;
  }

  void create(string ext)
  {
    string ft, cmd;

    catch {
      ft = RegGetValue(HKEY_CLASSES_ROOT, ext, "");
      cmd = RegGetValue(HKEY_CLASSES_ROOT, ft+"\\shell\\open\\command", "");
    };
    if(!ft || !cmd) {
      // Unknown filetype/command.
      // Will try #! in open().
      repsrc = 0;
    } else {
      line = cmd/" "-({""});
      starpos = search(line, "%*");
      int i=-1, n=0;
      do {
	int t;
	i = search(cmd, "%", i+1);
	if(i>=0 && sscanf(cmd[i+1..], "%d", t)==1 && t>n)
	  n=t;
      } while(i>=0);
      for( int i = 0; i<n; i++ )
        cmd = replace( cmd, "\"%"+i+"\"", "%"+i );
      repsrc = map(indices(allocate(n)), lambda(int a) {
                                           return sprintf("%%%d", a+1);
                                         }); 
    }
    expiry = time(1)+600;
    nt_opencommands[ext]=this_object();
  }
}
#endif

class CGIScript
{
  string command;
  array (string) arguments;
  Stdio.File stdin;
  Stdio.File stdout;
  // stderr is handled by run().
  mapping (string:string) environment;
  int blocking;

  string priority;   // generic priority
  object pid;       // the process id of the CGI script
  string tosend;   // data from the client to the script.
  Stdio.File ffd; // pipe from the client to the script
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
    DWERR("CGIScript::check_pid()");

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
    DWERR("CGIScript::get_fd()");

    // Send input to script..
    if( tosend || ffd )
      Stdio.sendfile(({tosend||""}),ffd,-1,-1,0,stdin,
                     lambda(int i,mixed q){ stdin->close();stdin=0; });
    else
    {
      stdin->close();
      stdin=0;
    }

    // And then read the output.
    if(!blocking)
    {
      Stdio.File fd = stdout;
      if( (command/"/")[-1][0..2] != "nph" )
        fd = CGIWrapper( fd,mid,kill_script )->get_fd();
      if( query("rxml") )
        fd = RXMLWrapper( fd,mid,kill_script )->get_fd();
      stdout = 0;
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
    DWERR(sprintf("CGIScript::kill_script()"
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

  CGIScript run()
  {
    DWERR("CGIScript::run()");

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
      "cwd":dirname( command ),
      "env":environment,
      "noinitgroups":1,
    ]);
    stdin = stdin->pipe(/*Stdio.PROP_IPC|Stdio.PROP_NONBLOCK*/);

#if UNIX
    ;{ string s;
       if(sizeof(s=query("chroot")))
	 options->chroot = s;
     }
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
    if(!(pid = Process.Process( nt_opencommand(command, arguments), options )))
#else
    if(!(pid = Process.Process( ({ command }) + arguments, options )))
#endif /* __NT__ */
      error("Failed to create CGI process.\n");
    if(query("kill_call_out"))
      call_out( kill_script, query("kill_call_out")*60 );
    return this_object();
  }


  void create( RequestID id )
  {
    DWERR("CGIScript()");

    mid = id;

#ifndef THREADS
    if(id->misc->orig) // An <insert file=...> operation, and we have no threads.
      blocking = 1;
#else
    if(id->misc->orig && this_thread() == roxen.backend_thread)
      blocking = 1;
    // An <insert file=...> and we are
    // currently in the backend thread.
#endif
    if(!id->realfile)
    {
      id->realfile = id->conf->real_file( id->not_query, id );
      if(!id->realfile)
        error("No real file associated with "+id->not_query+
              ", thus it's not possible to run it as a CGI script.\n");
    }
    command = combine_path(getcwd(), id->realfile);
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

#ifdef __NT__
    {
      string extn = "exe";
      sscanf(reverse(command), "%s.", extn);
      extn = "."+lower_case(reverse(extn));
      object ntopencmd = nt_opencommands[extn];
      if(!ntopencmd || ntopencmd->expired())
	ntopencmd = NTOpenCommand(extn);
      nt_opencommand = ntopencmd->open;
    }
#endif

    environment =(query("env")?getenv():([]));
    environment |= global_env;
    environment |= Roxen.build_env_vars( id->realfile, id, id->misc->path_info );
    if (query("roxen_env"))
      environment |= Roxen.build_roxen_env_vars(id);
    if(id->misc->ssi_env)
      environment |= id->misc->ssi_env;
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

    if(environment->INDEX)
      arguments = Array.map(environment->INDEX/"+", http_decode_string);
    else
      arguments = ({});

    tosend = id->data;
    if( id->method == "PUT" )
      ffd = id->my_fd;
  }
}

mapping(string:string) global_env = ([]);
string searchpath, location;
int handle_ext, noexec, buffer_high, buffer_low;

void start(int n, Configuration conf)
{
  DWERR("start()");

  searchpath = combine_path(getcwd(), query("searchpath"));
  handle_ext = query("ex");
#if UNIX
  noexec = query("noexec");
#endif
  module_dependencies(conf, ({ "pathinfo" }));
  location = query("location");
  buffer_high = query("max_buffer") > 0 && query("max_buffer") * 1024;
  buffer_low = buffer_high / 2;
  
  if(conf)
  {
    string tmp=conf->query("MyWorldLocation");
    sscanf(tmp, "%*s//%s", tmp);
    sscanf(tmp, "%s:", tmp);
    sscanf(tmp, "%s/", tmp);
    global_env["SERVER_NAME"]=tmp;
    global_env["SERVER_SOFTWARE"]=roxen.version();
    global_env["GATEWAY_INTERFACE"]="CGI/1.1";
    global_env["SERVER_PROTOCOL"]="HTTP/1.0";
    global_env["SERVER_URL"]=conf->query("MyWorldLocation");

    array us = ({0,0});
    foreach(query("extra_env")/"\n", tmp)
      if(sscanf(tmp, "%s=%s", us[0], us[1])==2)
        global_env[us[0]] = us[1];
  }
}

Stat stat_file( string f, RequestID id )
{
  DWERR("stat_file()");
  return file_stat( real_file( f, id ) );
}

string real_file( string f, RequestID id )
{
  DWERR("real_file()");
  return combine_path( searchpath, f );
}

mapping handle_file_extension(object o, string e, RequestID id)
{
  DWERR("handle_file_extension()");
  if(!handle_ext) 
    return 0;
#if UNIX
  if(o && !(o->stat()[0]&0111))
    if(noexec)
      return 0;
    else
      return Roxen.http_low_answer(500, "<title>CGI - File Not Executable</title>"
			     "<h1>CGI Error - File Not Executable</h1><b>"
			     "The script you tried to run is not executable."
			     "Please contact the server administrator about "
			     "this problem.</b>");

#endif
  NOCACHE();
  return Roxen.http_stream( CGIScript( id )->run()->get_fd() );
}

array(string) find_dir( string f, RequestID id )
{
  DWERR("find_dir()");

  if(query("ls"))
    return get_dir(real_file( f,id ));
}

int|object(Stdio.File)|mapping find_file( string f, RequestID id )
{
  DWERR("find_file()");

  Stat stat=stat_file(f,id);
  if(!stat) return 0;

  NOCACHE();

#if UNIX
  if(!(stat[0]&0111))
  {
    if(noexec)
      return Stdio.File(real_file(f, id), "r");
    report_notice( "CGI: "+real_file(f,id)+" is not executable\n");
    return Roxen.http_low_answer(500, "<title>CGI Error - Script Not Executable</title>"
			   "<h1>CGI Error - Script Not Executable</h1> <b>"
			   "The script you tried to run is not executable. "
			   "Please contact the server administrator about "
			   "this problem.</b>");
  }
#endif
  if(stat[1] < 0)
    if(!query("ls"))
      return Roxen.http_low_answer(403, "<title>CGI Directory Listing "
			     "Disabled</title><h1>Listing of CGI directories "
			     "is disabled.</h1>");
    else
      return -1;
  if(!strlen(f) || f[-1] == '/')
    // Make foo.cgi/ be handled using PATH_INFO
    return 0;
  id->realfile = real_file( f,id );
  return Roxen.http_stream( CGIScript( id )->run()->get_fd() );
}



/*
** Variables et. al.
*/
array (string) query_file_extensions()
{
  return query("ext");
}

string query_location()
{
  return location;
}

int run_as_user_enabled() { return (getuid() || !query("user")); }
void create(Configuration conf)
{
  defvar("env", Variable.Flag(0, VAR_MORE, "Pass environment variables",
	 "If this is set, all environment variables roxen has will be "
         "passed to CGI scripts, not only those defined in the CGI/1.1 standard. "
	 "This includes PATH. For a quick test, try this script with "
	 "and without this variable set:"
	 "<pre>"
	 "#!/bin/sh\n\n"
         "echo Content-type: text/plain\n"
	 "echo ''\n"
	 "env\n"
	 "</pre>"));

  defvar("rxml", Variable.Flag(0, VAR_MORE, "Parse RXML in CGI-scripts",
	 "If this is set, the output from CGI-scripts handled by this "
         "module will be RXMl parsed. NOTE: No data will be returned to the "
         "client until the CGI-script is fully parsed."));

  defvar("extra_env", Variable.Text("", VAR_MORE, "Extra environment variables",
	 "Extra variables to be sent to the script, format:<pre>"
	 "NAME=value\n"
	 "NAME=value\n"
	 "</pre>Please note that normal CGI variables will override these."));

  defvar("roxen_env",
	 Variable.Flag(1, VAR_MORE, "Extended environment variables",
	   "<p>Pass extra enviroment variables to simplify "
	   "cgi script authoring.</p>\n"
	   "<table><tr><th align='left'>For each:</th>"
	   "<th align='left'>Environment variable</th>"
	   "<th align='left'>Notes</th></tr>\n"
	   "<tr><td>Cookie</td>"
	   "<td><tt>COOKIE_<i>cookiename</i>=<i>cookievalue</i></tt></td>"
	   "<td>&nbsp;</td></tr>\n"
	   "<tr><td>Variable</td>"
	   "<td><tt>VAR_<i>variablename</i>=<i>variablename</i></tt></td>"
	   "<td>Multiple values are separated with <tt>'#'</tt>.</td></tr>"
	   "<tr><td>Variable</td>"
	   "<td><tt>QUERY_<i>variablename</i>=<i>variablename</i></tt></td>"
	   "<td>Multiple values are separated with "
	   "<tt>' '</tt> (space).</td></tr>\n"
	   "<tr><td>Prestate</td>"
	   "<td><tt>PRESTATE_<i>x</i>=true</tt></td>"
	   "<td>&nbsp;</td></tr>\n"
	   "<tr><td>Config</td>"
	   "<td><tt>CONFIG_<i>x</i>=true</tt></td>"
	   "<td>&nbsp;</td></tr>\n"
	   "<tr><td>Supports flag</td>"
	   "<td><tt>SUPPORTS_<i>x</i>=true</tt></td>"
	   "<td>&nbsp;</td></tr>\n"
	   "</table>"));

  defvar("location", Variable.Location("/cgi-bin/", 0, "CGI-bin path",
	 "This is where the module will be inserted in the "
	 "namespace of your server. The module will, per default, also"
	 " service one or more extensions, from anywhere in the "
	 "namespace."));

  defvar("searchpath", Variable.Directory("NONE/", VAR_INITIAL, "Search path",
	 "This is where the module will find the CGI scripts in the <b>real</b> "
	 "file system."));

  defvar("ls", Variable.Flag(0, 0, "Allow listing of cgi-bin directory",
	 "If set, the users can get a listing of all files in the CGI-bin "
	 "directory."));

  defvar("ex", Variable.Flag(1, 0, "Handle *.cgi",
	 "Also handle all '.cgi' files as CGI-scripts, as well "
	 " as files in the cgi-bin directory. This emulates the behaviour "
	 "of the Apache server (the extensions to handle can be set in the "
	 "CGI-script extensions variable)."));

  defvar("ext", Variable.StringList(({ "cgi",
#ifdef __NT__
	   "exe",
#endif
	 }), 0, "CGI-script extensions",
         "All files ending with these extensions, will be parsed as "+
	 "CGI-scripts."));

  defvar("stderr", Variable.StringChoice("main log file",
	 ({ "main log file", "custom log file", "browser" }), 0,
	 "Log CGI errors to...",
	 "By changing this variable you can select where error messages "
	 "(which means all text written to stderr) from "
	 "CGI scripts should be sent. By default they will be written to the "
	 "main log file - logs/debug/[name-of-configdir].1. You can also "
	 "choose to send the error messages to a special log file or to the "
	 "browser.\n"));

  defvar("cgilog", GLOBVAR(logdirprefix)+
	 Roxen.short_name(conf? conf->name:".")+"/cgi.log",
	 "Log file", TYPE_STRING,
	 "Where to log errors from CGI scripts. You can also choose to send "
	 "the errors to the browser or to the main Roxen log file. "
	 " Some substitutions of the file name will be done to allow "
	 "automatic rotating:"
	 "<pre>"
	 "%y    Year  (i.e. '1997')\n"
	 "%m    Month (i.e. '08')\n"
	 "%d    Date  (i.e. '10' for the tenth)\n"
	 "%h    Hour  (i.e. '00')\n</pre>", 0,
	 lambda() { return (query("stderr") != "custom log file"); });

  defvar("rawauth", Variable.Flag(0, VAR_MORE, "Raw user info",
	 "If set, the raw, unparsed, user info will be sent to the script, "
	 " in the HTTP_AUTHORIZATION environment variable. This is not "
	 "recommended, but some scripts need it. Please note that this "
	 "will give the scripts access to the password used."));

  defvar("clearpass", Variable.Flag(0, VAR_MORE, "Send decoded password",
	 "If set, the variable REMOTE_PASSWORD will be set to the decoded "
	 "password value."));

  defvar("cgi_tag", Variable.Flag(1, 0, "Provide the <cgi> and <runcgi> tags",
	 "If set, the &lt;cgi&gt; and &lt;runcgi&gt; tags will be available."));

  defvar("priority", "normal", "Limits: Priority", TYPE_STRING_LIST,
         "The priority, in somewhat general terms (for portability, this works on "
         " all operating systems). 'realtime' is not recommended for CGI scripts. "
         "On most operating systems, a process with this priority can "
         "monopolize the CPU and IO resources, even preemtping the kernel "
         "in some cases.",
         ({
           "lowest",
           "low",
           "normal",
           "high",
           "higher",
           "realtime",
         })
#if UNIX
         ,lambda(){return query("nice");}
#endif
           );
#if UNIX
  defvar("noexec", Variable.Flag(1, 0, "Treat non-executable"
				 " files as ordinary files",
	 "If this flag is set, non-executable files will be returned "
	 "as normal files to the client. Otherwise an error message "
	 "will be returned."));

  defvar("warn_root_cgi", 1, "Warn for CGIs executing as root", TYPE_FLAG,
  	 "If this flag is set, a warning will be issued to the event and "
	 " debug log when a script is run as the root user. This will "
	 "only happend if the 'Run scripts as' variable is set to root (or 0)",
	 0, getuid);

  defvar("chroot", Variable.String("", VAR_MORE, "Chroot path",
	 "This is the path that is chrooted to before running a program. "
	 "No chrooting is done if left empty."));

  defvar("runuser", "nobody", "Run scripts as", TYPE_STRING,
	 "If you start roxen as root, and this variable is set, CGI scripts "
	 "will be run as this user. You can use either the user name or the "
	 "UID. Note however, that if you don't have a working user database "
	 "enabled, only UID's will work correctly. If unset, scripts will "
	 "be run as nobody.", 0, getuid);

  defvar("user", 1, "Run user scripts as owner", TYPE_FLAG,
	 "If set, scripts in the home-dirs of users will be run as the "
	 "user. This overrides the Run scripts as variable.", 0, getuid);

  defvar("setgroups", Variable.Flag(1, 0, "Set the supplementary"
				    " group access list",
	 "If set, the supplementary group access list will be set for "
	 "the CGI scripts. This can slow down CGI-scripts significantly "
	 "if you are using eg NIS+. If not set, the supplementary group "
	 "access list will be cleared."));

  defvar("allow_symlinks", 1, "Allow symlinks", TYPE_FLAG,
	 "If set, allows symbolic links to binaries owned by the directory "
	 "owner. Other symlinks are still disabled.<br>\n"
	 "NOTE: This option only has effect if scripts are run as owner.",
	 0, run_as_user_enabled);

  defvar("nice", Variable.Int(0, VAR_MORE, "Limits: Nice value",
	 "The nice level to use when running scripts. "
	 "20 is nicest, and 0 is the most aggressive available to "
	 "normal users. Defining the Nice value to anyting but 0 will override"
         " the 'Priority' setting."));

  defvar("coresize", Variable.Int(0, VAR_MORE, "Limits: Core dump size",
	 "The maximum size of a core-dump, in 512 byte blocks. "
	 "-2 is unlimited."));

  defvar("maxtime", Variable.IntChoice(60, ({ -2, 10, 30, 60, 120, 240 }),
				       VAR_MORE, "Limits: Maximum CPU time",
				       "The maximum CPU time the script might "
				       "use in seconds. -2 is unlimited."));

  defvar("datasize", Variable.Int(-2, VAR_MORE, "Limits: Memory size",
	 "The maximum size of the memory used, in Kb. -2 is unlimited."));

  defvar("filesize", Variable.Int(-2, VAR_MORE, "Limits: Maximum file size",
	 "The maximum size of any file created, in 512 byte blocks. -2 "
	 "is unlimited."));

  defvar("open_files", Variable.IntChoice(64, ({ 64,128,256,512,1024,2048 }),
					  VAR_MORE, "Limits: Maximum "
					  "number of open files",
	 "The maximum number of files the script can keep open at any time. "
         "It is not possible to set this value over the system maximum. "
         "On most systems, there is no limit, but some unix systems still "
         "have a static filetable (Linux and *BSD, basically)."));

  defvar("stack", Variable.Int(-2, VAR_MORE, "Limits: Stack size",
	 "The maximum size of the stack used, in kilobytes. -2 is unlimited."));
#endif

  defvar("kill_call_out", Variable.IntChoice(0, ({ 0, 1, 2, 3, 4, 5, 7, 10, 15 }),
					     VAR_MORE, "Limits: Time "
					     "before killing scripts",
	 "The maximum real time the script might run in minutes before it's "
	 "killed. 0 means unlimited."));
  defvar("max_buffer", 64, "Limits: Output buffer",
	 TYPE_INT|VAR_MORE,
	 "Maximum size of the output buffer in kilo bytes. "
	 "0 means unlimited.");
}

int|string container_runcgi( string tag, mapping args, string cont, RequestID id )
{
  if(!query("cgi_tag"))
    return 0;

  cont=parse_html(cont, ([]), (["attrib":
    lambda(string tag, mapping m, string cont, RequestID id) {
       if(m->name) id->variables[m->name]=cont;
       return "";
    }]),id);

  return parse_html(cont, (["cgi":
    lambda(string tag, mapping m) {
      return tag_cgi(tag, m, id);
    }
  ]),([]));
}

int|string tag_cgi( string tag, mapping args, RequestID id )
{
  DWERR("tag_cgi()");

  if(!query("cgi_tag"))
    return 0;

  if(!args->cache)
    NOCACHE();
  else {
    CACHE( (int)args->cache || 60 );
    m_delete(args, "cache");
  }

  RequestID fid = id->clone_me();
  string file = args->script;
  m_delete(args, "script");
  if(!file)
    RXML.parse_error("No \"script\" argument to the CGI tag.");
  fid->not_query = Roxen.fix_relative( file, id );

#ifdef OLD_RXML_COMPAT
  foreach(indices(args), string arg )
  {
    if(arg[..7] == "default-")
    {
      if(!id->variables[arg[8..]])
        fid->variables[arg[8..]] = args[arg];
    }
    else
      fid->variables[arg] = args[arg];
  }
#endif

  fid->realfile=0;
  fid->method = "GET";
  mixed e = catch
  {
    string data=handle_file_extension( 0, "cgi", fid )->file->read();
    if(!sscanf(data, "%*s\r\n\r\n%s", data))
      sscanf(data, "%*s\n\n%s", data);
    return data;
  };
  NOCACHE();
  return ("Failed to run CGI script: <font color=\"red\"><pre>"+
          (Roxen.html_encode_string(describe_backtrace(e)))+
          "</pre></font>");
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc = ([

  "cgi" : #"<desc tag='tag'><p><short hide='hide'>Runs a CGI script.</short>
Runs a CGI script and inserts the result into the page.</p></desc>

<attr name='script' value='file'><p>
 Path to the CGI file to be executed.</p>
</attr>

<attr name='cache' value='number' default='0'><p>
 The number of seconds the result may be cached. If the attribute is
 given, but without any value or \"0\" as value it will use 60 seconds.</p>
</attr>
",
 ]);
#endif
