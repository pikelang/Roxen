// ExtScript.pmod -- external script handler for Roxen
//
// Originally by Leif Stensson <leif@roxen.com>, June/July 2000.
//
// $Id$

// 

mapping scripthandlers = ([ ]);

#ifdef EXTSCRIPT_DEBUG
#define DEBUGMSG(X...) werror (X)
#else
#define DEBUGMSG(X...) 0
#endif

class Handler
{
  Process.Process
             proc;
  Stdio.File pipe;
  array(string) command;
  mapping(string:mixed)
             settings;
  int        runcount = 0;
  int        timeout;
  RequestID  nb_id;
  function   nb_when_done;
  int        nb_status = 0, nb_returncode = 0;
  string     nb_output = 0, nb_errmsg = 0, nb_headers = 0, nb_data;
  Thread.Mutex
             mutex = Thread.Mutex();
  Thread.MutexKey
             run_lock = 0;

  void terminate()
  {
    Thread.MutexKey lock = mutex ? mutex->lock() : 0;
    if (proc && !proc->status() && pipe)
      // send 'exit' command to subprocess
      pipe->write("X");
    proc = 0;
    pipe = 0;
  }

  int busy()
  {
    if (run_lock)
      return 1;
    if (mutex)
      return !mutex->trylock(2);
    return 0;
  }

  int procstat()
  {
    return proc ? proc->status() : -1;
  }

  int probe()
  {
    return timeout < time();
  }

  protected void putvar(string vtype, string vname, string vval)
  // Send a variable name and value to the subprocess. The
  // one-character string in vtype indicates the type; "E" is
  // an environment variable, "I" a Roxen-internal RequestID
  // object variable, "F" a FORM variable, "H" a request header
  // variable, and "L" a configuration variable for the script
  // helper subprocess. The last category includes "cd", which
  // is the current directory that should be used for running
  // scripts.
  {
    if (!vtype || strlen(vtype) != 1)
      error("Bad variable type in external script .\n");
    pipe->write("%s%c%s%3c", vtype, strlen(vname), vname, strlen(vval));
    pipe->write(vval);
  }

  array get_results()
  { array result = 0;
    if (run_lock && nb_status)
    {
      if (nb_errmsg)
          result = ({ -1, nb_errmsg, 0 });
      else if (nb_output)
          result = ({ nb_returncode, nb_output, nb_headers });
      else
          result = ({ -1, "Script error", 0 });
      nb_errmsg = 0;
      nb_output = 0;
    }
    if (result)
        run_lock = 0;
    return result;
  }

  void finalize(void|RequestID id1)
  {
    if (run_lock)
    { Thread.MutexKey tmplock = run_lock;
      RequestID id = id1 ? id1 : nb_id; // nb_id can get reset before we're done.
      DEBUGMSG("ExtScript/finalize: %O %O\n", id, run_lock);
      if (nb_when_done)
        nb_when_done(id, get_results());
      run_lock = 0;
      nb_id    = 0;
    }
  }

  protected void read_callback(mixed fid, string data)
  { if (!run_lock || !stringp(data) || strlen(data) < 1)
      { return;}
    if (nb_data != 0)
      { data = nb_data + data; nb_data = 0;}
    string ptype = data[0..0];
//    DEBUGMSG(sprintf("ExtScript/rcb0: %O %O\n", nb_id, run_lock));
    if ( (< "+", "*", "?", "=" >) [ ptype ] )
    { if (strlen(data) < 4)
        { nb_data = data; return;}
      int len = data[2]*256 + data[3];
      if (strlen(data) < 4+len)
        { nb_data = data; return;}
      if (strlen(data) > 4+len)
        { nb_data = data[4+len..];
          data    = data[..3+len];
        }
    }
    DEBUGMSG(sprintf("<%s:%d>", ptype, strlen(data)));
    switch (ptype)
    { case "X":
        finalize();
        return;
      case "=":
        array arr = data[4..] / "=";
        if (arr[0] == "RETURNCODE")
          if (sscanf(arr[1], "%d", nb_returncode) != 1)
            nb_returncode = 200;
        if (arr[0] == "HEADERS")
            nb_headers = arr[1..] * "=";
        if (arr[0] == "ADDHEADER")
            nb_headers = (nb_headers || "") + arr[1]*"=" + "\n";
        break;
      case "+":
        nb_output = (nb_output || "") + data[4..];
        break;
      case "*":
	DEBUGMSG("ExtScript/rcb*: %O %O\n", nb_id, run_lock);
	nb_output = (nb_output || "") + data[4..];
        nb_status = 1;
        finalize(nb_id);
        break;
      case "?":
        nb_errmsg = "ERROR: " + data[4..];
        nb_status = 2;
        finalize();
        break;

      /* more cases here to support "script callbacks" */

      default:
        werror(sprintf("ExtScript: bad command code 0x%02X from subprocess\n",
                        data[0]));
        break;
    }
  }

  array launch(string mode, string arg, RequestID id,
               void|int|function nonblock)
  {
    Thread.MutexKey lock = mutex ? mutex->lock(1) : 0;

    timeout = time() + 190;

    if (!proc || proc->status() != 0)
    {
      pipe = Stdio.File();
      Stdio.File pipe_other = pipe->pipe(); // Stdio.PROP_IPC);

      DEBUGMSG("(L1)");

      mapping opts = ([ "stdin": pipe_other, "stdout": pipe_other ]);
#if constant(system.getuid)
      if (system.getuid() == 0)
      { if (settings->set_uid > 0)
          opts["uid"] = settings->set_uid;
        if (settings->set_gid > 0)
          opts["gid"] = settings->set_gid;
	else if (settings->set_uid && settings->set_gid != -1)
        {
	  // If we have set the uid, create_process may change the
	  // group ID to the user's primary group ID, which is not
	  // what we want here.
	  opts["gid"] = system.getgid();
	}
      }
#endif

      mixed bt;
      if (bt = catch {
        proc = Process.create_process(command, opts);
	  })
	{
	  werror("ExtScript, create_process failed: " +
                 describe_backtrace(bt) + "\n");
          return ({ -1, "unable to start helper process" });
        }

      DEBUGMSG("(L2)");
      runcount = 0;
      pipe_other = 0;
      pipe->write("QP"); // send 'ping'
      DEBUGMSG("(L2p)");
      string res = pipe->read(4);
      if (!stringp(res) || sizeof(res) < 4 || res[0] != '=')
	return ({ -1, "external process didn't respond" +
                        sprintf(" (Got: %O)", res) });
      DEBUGMSG("(NewSubprocess)");
      if (mode == "run")
        putvar("L", "cd", dirname(arg));
      if (mappingp(settings))
        foreach( ({ "libdir", "cd" }), string s)
          if (settings[s] && stringp(settings[s]))
            putvar("L", s, settings[s]);
    }

    if (id)
    {
      int len, returncode = 200; string headers;

      DEBUGMSG("{");
      // Reset script variables.
      pipe->set_blocking();
      pipe->write("R");

      // Environment variables.
      putvar("E", "GATEWAY_INTERFACE", "RoxenExtScript/0.9");

      foreach( ({ ({ "remoteaddr", "REMOTE_ADDR" }),
                  ({ "raw_url", "DOCUMENT_URI" }),
                  ({ "not_query", "DOCUMENT_NAME" }),
                  ({ "method", "REQUEST_METHOD" }),
                  ({ "prot", "SERVER_PROTOCOL" }),
                  ({ "realfile", "SCRIPT_FILENAME" })
               }), array x)
          if (stringp(id[x[0]]))
                putvar("E", x[1], id[x[0]]);

      foreach( ({ ({ "accept", "HTTP_ACCEPT" }),
                  ({ "connection", "HTTP_CONNECTION" }),
                  ({ "referer", "HTTP_REFERER" }),
                  ({ "user-agent", "HTTP_USER_AGENT" }),
                  ({ "pragma",     "HTTP_PRAGMA" }),
                  ({ "host", "HTTP_HOST" })
               }), array x)
          if (stringp(id->request_headers[x[0]]))
                putvar("E", x[1], id->request_headers[x[0]]);

      // Transfer Roxen-internal request info.
      foreach( ({ "query", "not_query", "raw", "remoteaddr", "realfile",
                  "virtfile", "prot", "method", "rawauth", "realauth",
                  "raw_url" }),
               mixed v)
        if (stringp(v) && stringp(id[v]) && strlen(id[v]) < 1000000)
           putvar("I", v, id[v]);
      if (arrayp(id->auth) && sizeof(id->auth) > 1)
      {
        if (stringp(id->auth[0]) && stringp(id->auth[1]))
        {
	  putvar("I", "auth_type", id->auth[0]);
          putvar("E", "AUTH_TYPE", id->auth[0]);
          array arr = id->auth[1] / ":";
          putvar("I", "auth_user", arr[0]);
          putvar("E", "REMOTE_USER", arr[0]);
          if (sizeof(arr) > 1)
	    putvar("I", "auth_passwd", arr[1]);
        }
        else if (sizeof(id->auth) == 3 && intp(id->auth[0]))
        {
	  putvar("I", "auth_type", "Basic");
          putvar("E", "AUTH_TYPE", "Basic");
          if (stringp(id->auth[1]))
          {
	    putvar("I", "auth_user", id->auth[1]);
            putvar("E", "REMOTE_USER", id->auth[1]);
          }
          if (stringp(id->auth[2]))
	    putvar("I", "auth_passwd", id->auth[2]);
        }
      }

      if (stringp(id->query))
	putvar("E", "QUERY_STRING", id->query);
      
      // Transfer explicit environment variables.
      mapping ee = id->misc->explicit_script_env;
      if (mappingp(ee))
        foreach(indices(ee), mixed v)
          if (stringp(v) && stringp(ee[v]) && strlen(ee[v]) < 25000)
            putvar("E", v, ee[v]);

      // Transfer request headers
      mapping(string:string|array(string)) hd;
      foreach( indices(hd = id->request_headers), mixed v)
        if (stringp(v) && stringp(hd[v]) && strlen(hd[v]) < 1000000)
           putvar("H", v, hd[v]);

      // Transfer FORMs variables.
      FakedVariables va;
      foreach(indices(va = id->variables), mixed v)
        if (stringp(v) && stringp(va[v]) && strlen(va[v]) < 1000000)
           putvar("F", v, va[v]);

      // ping - check if subprocess is still alive
      pipe->write("QP");
      string res = pipe->read(4);
      if (!stringp(res) || sizeof(res) != 4 || res[0] != '=' || res[3] != 0)
      {
	pipe = 0; proc = 0; DEBUGMSG("@");
        lock = 0;
        DEBUGMSG("ExtScript/restart\n");
        return launch(mode, arg, id, nonblock);
      }

      // start operation
      DEBUGMSG("$");
      pipe->write("%c%3c%s", (mode == "eval" ? 'C' : 'S'), strlen(arg), arg);
      string output = "";

      nb_output = nb_errmsg = nb_returncode = nb_headers = 0;
      nb_data = 0; nb_status = 0; nb_when_done = 0; nb_id = id ? id : nb_id;
      if (nonblock)
      { if (functionp(nonblock))
            nb_when_done = nonblock;
	DEBUGMSG("ExtScript/launch/nonblock: %O\n", nb_id);
	if (!catch ( pipe->set_nonblocking(read_callback, 0, finalize) ) )
        { run_lock = lock;
          return ({ });
        }
      }

      while (sizeof(res = pipe->read(1)) > 0)
      {
	DEBUGMSG("."+res);
        if (res == "a")
	  continue;
        else if (res == "X")
	  return ({ -1, "SCRIPT ERROR (1)" });
        else if (res == "+" || res == "*" || res == "?" || res == "=")
        {
	  string tmp = pipe->read(3);
          len = tmp[1]*256 + tmp[2];
	  DEBUGMSG(len + "<");
	  // The len check is paranoia since read() might hang in
	  // older pikes on NT when it's zero.
          tmp = len ? pipe->read(len) : "";
          DEBUGMSG(">");
          if (stringp(tmp))
          {
	    if (res == "=")
            {
	      array arr = tmp / "=";
              if (arr[0] == "RETURNCODE")
              {
		DEBUGMSG(":ExtScript:RETURNCODE=" + arr[1]*"=" + "\n");
                if (sscanf(arr[1], "%d", returncode) != 1)
                  returncode = 200;
              }
              else if (arr[0] == "HEADERS")
              {
		headers = arr[1..] * "=";
              }
              else if (arr[0] == "ADDHEADER")
              {
		headers = (headers || "") + arr[1..]*"=" + "\n";
                DEBUGMSG(":ExtScript:ADDHEADER=" + arr[1..]*"=" + "\n");
              }
            }
            else if (res == "?")
            {
	      return ({ -1, tmp });
            }
            else
	      output += tmp;
          }
          if (res == "*" || res == "?") break;
        }
        /* else ... support queries from script ... */
      }
      DEBUGMSG("<Done.>");
      if (res == "" || res == 0)
	return ({ -1, "SCRIPT I/O ERROR (2)" });

      if (++runcount > 5000)
	proc = 0, pipe = 0, runcount = 0;

      DEBUGMSG("}");

      return headers ? ({ returncode, output, headers })
                     : ({ returncode, output });
    }
    else return ({ -1, "[Internal error?]" });
  }

  array run(string path, RequestID id, void|int|function nonblock)
  { return launch("run", path, id, nonblock);
  }

  array eval(string expr, RequestID id, void|int|function nonblock)
  { return launch("eval", expr, id, nonblock);
  }

  void create(string helper_program_path, void|mapping settings0)
  {
    settings = settings0 ? settings0 : ([ ]);
    proc = 0; pipe = 0;
    timeout = time() + 300;
    command = ({ helper_program_path, "--cmdsocket=3" });
#ifdef __NT__
    string binpath = helper_program_path;
    string ft, cmd;

    mixed bt = catch {
      string ext = "." + reverse(array_sscanf(reverse(binpath), "%[^.].")[0]);
      DEBUGMSG("Looking up extension %O\n", ext);
      ft = RegGetValue(HKEY_CLASSES_ROOT, ext, "");
      DEBUGMSG("ft:%O\n", ft);
      cmd = RegGetValue(HKEY_CLASSES_ROOT, ft+"\\shell\\open\\command", "");
      DEBUGMSG("cmd:%O\n", cmd);
    };
    if (bt) {
      werror("Failed to lookup in registry:\n%s\n",
	     describe_backtrace(bt));
    }
    if (cmd) {
      // Perform %-substitution.
      command = ({});
      foreach(Process.split_quoted_string(cmd, 1), string arg) {
	if (sizeof(arg) && arg[0] == '%') {
	  int argno;
	  if (arg == "%*") {
	    command += ({ "--cmdsocket=3" });
	  } else if (sscanf(arg, "%%%d", argno)) {
	    if (argno == 1) {
	      command += ({ binpath });
	    } else if (argno == 2) {
	      command += ({ "--cmdsocket=3" });
	    }
	  } else {
	    command += ({ arg });
	  }
	} else {
	  command += ({ arg });
	}
      }
    } else {
      string s = Stdio.read_file(binpath, 0, 1);
      if (s && has_prefix(s, "#!")) {
	command = Process.split_quoted_string(s[2..], 1) + command;
      } else {
	// Hope we can execute it anyway...
	// Not likely, but we can hope.
      }
    }
#endif /* __NT__ */
    DEBUGMSG("Resulting command: %O\n", command);
  }
}

Thread.Mutex dispatchmutex = Thread.Mutex();

protected int lastobjdiag = 0;

protected void objdiag()
{
  if (lastobjdiag < time()-25)
  {
    lastobjdiag = time();
    DEBUGMSG("Subprocess status:\n");
    foreach(indices(scripthandlers), string binpath)
    {
      mapping m = scripthandlers[binpath];
      string line = "  " + binpath;
      int     n = 0;
      foreach(m->handlers, Handler h)
  	if (h)
  	  line += "  H" + (++n) + "=" + h->procstat();
      DEBUGMSG(line + "\n");
      if (!n && cleaner) {
	cleaner->stop();
        cleaner = 0;
      }
    }
  }
}

protected int lastcleanup = 0;

protected roxen.BackgroundProcess cleaner;

void periodic_cleanup()
{
  int now = time();
  if (lastcleanup+42 < now)
  {
    lastcleanup = now;
    foreach(indices(scripthandlers), string binpath)
    {
      mapping m = scripthandlers[binpath];
      if (m->expire < now)
      {
        Thread.MutexKey lock = m->mutex->lock();
  	DEBUGMSG("(Z)");
  	if (m->handlers[0])
  	{ if (m->handlers[0]->probe())
  	  { DEBUGMSG("(*T*)");
  	    m->handlers[0]->terminate();
  	  }
  	}
  
  	if (sizeof(m->handlers) > 1)
  	   m->handlers = m->handlers[1..];
  	else
  	   m->handlers = ({ 0 });
  	now = time();
  	m->expire   = now+600/(2+sizeof(m->handlers));
  	lock = 0;
      }
    }
  }
  objdiag();
}

Handler getscripthandler(string binpath, void|int multi, void|mapping settings)
{
  mapping m;
  Handler  h;
  Thread.MutexKey lock;
  int     i;

  if (!intp(multi) || multi < 1) multi = 1;

  if (lastcleanup+900 < time()) {
    if (!cleaner) {
      cleaner = roxen.BackgroundProcess(50, periodic_cleanup);
    }
  }

  if (!(m = scripthandlers[binpath])) 
  {
    lock = dispatchmutex->lock();
    scripthandlers[binpath] = m =
       ([
	 "handlers": ({ Handler(binpath) }),
          "expire": time() + 600,  
          "mutex": Thread.Mutex(),
          "binpath": binpath
        ]);
  }

  lock = m->mutex->lock();

  for(i = 0; i < multi && i < sizeof(m->handlers); ++i)
    if (h = m->handlers[i])
    {
      if (!h->busy())
      {
	if (!h->procstat())
          return h;
        else return h;
      }
    }

  for(i = 0; i < sizeof(m->handlers); ++i)
    if (m->handlers[i] == 0)
      return m->handlers[i] = Handler(binpath);

  if (i < multi && multi < 10) // Another handler.
  {
    m->handlers += ({ h = Handler(binpath, settings) });
    return h;
  }

  return m->handlers[random(sizeof(m->handlers))];
}




