#include <config.h>

// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.

// Support for user Pike-scripts, like CGI, but handled internally in
// the server, and thus much faster, but blocking, and somewhat less
// secure.

// This is an extension module.

constant cvs_version = "$Id: pikescript.pike,v 1.24 1998/03/20 03:37:36 per Exp $";
constant thread_safe=1;

mapping scripts=([]);

inherit "module";
inherit "roxenlib";
#include <module.h>

#if constant(_static_modules) && efun(thread_create)
constant Mutex=__builtin.mutex;
#endif /* _static_modules */

mixed *register_module()
{
  return ({ 
    MODULE_FILE_EXTENSION,
    "Pike script support", 
    "Support for user Pike-scripts, like CGI, but handled internally in the"
    " server, and thus much faster, but blocking, and less secure.\n"
    "NOTE: This module should not be enabled if you allow anonymous PUT!<br>\n"
    "NOTE: Enabling this module is the same thing as letting your users run programs with the same right as the server!"
    });
}

int fork_exec_p() { return !QUERY(fork_exec); }

void create()
{
  defvar("exts", ({ "lpc", "ulpc", "µlpc","pike" }), "Extensions", TYPE_STRING_LIST,
	 "The extensions to parse");

  defvar("fork_exec", 0, "Fork execution: Enabled", TYPE_FLAG,
	 "If set, pike will fork to execute the script. "
	 "This is a more secure way if you want to let "
	 "your users execute pike scripts. "
	 "Note, that fork_exec must be set for Run scripts as, "
	 "Run user scripts as owner and Change directory variables."
	 "Note, all features of pike-scripts are not available when "
	 "this is enabled.");

  defvar("runuser", "", "Fork execution: Run scripts as", TYPE_STRING,
	"If you start Roxen as root, and this variable is set, root uLPC "
	"scripts will be run as this user. You can use either the user "
	"name or the UID. Note however, that if you don't have a working "
	"user database enabled, only UID's will work correctly. If unset, "
	"scripts owned by root will be run as nobody. ", 0, fork_exec_p);

  defvar("scriptdir", 1, "Fork execution: Change directory", TYPE_FLAG,
	"If set, the current directory will be changed to the directory "
	"where the script to be executed resides. ", 0, fork_exec_p);
  
  defvar("user", 1, "Fork execution: Run user scripts as owner", TYPE_FLAG,
	 "If set, scripts in the home-dirs of users will be run as the "
	 "user. This overrides the Run scripts as variable.", 0, fork_exec_p);

  defvar("exec-mask", "0777", 
	 "Exec mask: Needed", 
	 TYPE_STRING|VAR_MORE,
	 "Only run scripts matching this permission mask");

  defvar("noexec-mask", "0000", 
	 "Exec mask: Forbidden", 
	 TYPE_STRING|VAR_MORE,
	 "Never run scripts matching this permission mask");

#if efun(set_max_eval_time)
  defvar("evaltime", 4, "Maximum evaluation time", TYPE_INT,
	 "The maximum time (in seconds) that a script is allowed to run for. "
	 "This might be changed in the script, but it will stop most mistakes "
	 "like i=0; while(i<=0) i--;.. Setting this to 0 is not a good idea.");
#endif
}

string comment()
{
  return query("exts")*" ";
}

array (string) query_file_extensions()
{
  return QUERY(exts);
}

private string|array(int) runuser;

#ifdef THREADS
mapping locks = ([]);
#endif

void my_error(array err, string|void a, string|void b)
{
  err[0] = ("<font size=+1>"+(b||"Error while executing code in pike script")
	    + "</font><br><p>" +(err[0]||"") + (a||"")
	    + "<br><p>The pike Script will be reloaded automatically.\n");
  throw(err);
}

array|mapping call_script(function fun, object got, object file)
{
  mixed result, err;
  string s;
  object privs;
  if(!functionp(fun))
    return 0;
  string|array (int) uid, olduid, us;

  if(QUERY(fork_exec)) {
    if(fork())
      return ([ "leave_me":1 ]);
    
    catch {
      /* Close all listen ports in copy. */
      foreach(indices(roxen->portno), object o) {
	roxen->do_dest(o);
	roxen->portno[o] = 0;
      }
    };
    
    /* Exit immediately after this request is done. */
    call_out(lambda(){exit(0);}, 0);
    
    if(QUERY(user) && got->misc->is_user && 
       (us = file_stat(got->misc->is_user)))
      uid = us[5..6];
    else if (!getuid() || !geteuid()) {
      if (runuser)
	uid = runuser;
      else
	uid = "nobody";
    }
    if(stringp(uid))
      privs = Privs("Starting pike-script", uid);
    else if(uid)
      privs = Privs("Starting pike-script", @uid);
    setgid(getegid());
    setuid(geteuid());
    if (QUERY(scriptdir) && got->realfile)
      cd(dirname(got->realfile));

  } else {
#ifndef THREADS
    if(got->misc->is_user && (us = file_stat(got->misc->is_user)))
      privs = Privs("Executing pikescript as non-www user", @us[5..6]);
#elif defined(DEBUG)
    if((got->misc->is_user && (us = file_stat(got->misc->is_user)))&&!getuid())

      report_debug("Not executing pike-script as owner, since we are using"
		   " threads. UID is not thread local, sadly enough.\n");
#endif
  }

#ifdef THREADS
  object key;
  if(!QUERY(fork_exec)) {
    if(!function_object(fun)->thread_safe)
    {
      if(!locks[fun]) locks[fun]=Mutex();
      key = locks[fun]->lock();
    }
  }
#endif

#if efun(set_max_eval_time)
  if(catch {
    set_max_eval_time(query("evaltime"));
#endif
    err=catch(result=fun(got)); 
// The eval-time might be exceeded in here..
#if efun(set_max_eval_time)
    remove_max_eval_time(); // Remove the limit.
  })
    remove_max_eval_time(); // Remove the limit.
#endif

  if(privs) destruct(privs);

  if (QUERY(fork_exec)) {
    if (err = catch {
      if (err) {
	err = catch{my_error(err, got->not_query);};
	result = describe_backtrace(err);
      } else if (!stringp(result)) {
	result = sprintf("<h1>Return-type %t not supported for Pike-scripts "
			 "in forking-mode</h1><pre>%s</pre>", result,
			 replace(sprintf("%O", result),
				 ({ "<", ">", "&" }),
				 ({ "&lt;", "&gt;", "&amp;" })));
      }
      result = parse_rxml(result, got, file);
      /* Set the connection to blocking-mode */
      got->my_fd->set_blocking();
      got->my_fd->write("HTTP/1.0 200 OK\n"
			"Content-Type: text/html\n"
			"\n"+result);
    }) {
      perror("Execution of pike-script wasn't nice:\n%s\n",
	     describe_backtrace(err));
    }
    exit(0);
  }
  
  if(err)
    return ({ -1, err });

  if(stringp(result)) {
    return http_string_answer(parse_rxml(result, got, file));
  }

  if(result == -1) return http_pipe_in_progress();

  if(mappingp(result))
  {
    if(!result->type)
      result->type="text/html";
    return result;
  }

  if(objectp(result))
    return result;

  if(!result) return 0;

  return http_string_answer(sprintf("%O", result));
}

mapping handle_file_extension(object f, string e, object got)
{
  int mode = f->stat()[0];
  if(!(mode & (int)query("exec-mask")) ||
     (mode & (int)query("noexec-mask")))
    return 0;  // permissions does not match.


  string file="";
  string s;
  mixed err;
  program p;
  object o;
  if(scripts[got->not_query])
  {
    if(got->pragma["no-cache"])
    {
      // Reload the script from disk, if the script allows it.
      if(!(function_object(scripts[got->not_query])->no_reload
	   && function_object(scripts[got->not_query])->no_reload(got)))
      {
	destruct(function_object(scripts[got->not_query]));
	scripts[got->not_query] = 0;
      }
    }
  }

  function fun;

  if (!functionp(fun = scripts[got->not_query])) {
    file=f->read(655565);   // fix this?
#if constant(cpp)
    file = cpp(file);
#endif
    array (function) ban = allocate(6, "function");
    ban[0] = setegid;
    ban[1] = setgid;
    ban[2] = seteuid;
    ban[3] = setuid;
    //ban[4] = spawne;
    ban[5] = cd;

    add_constant("setegid", 0);
    add_constant("seteuid", 0);
    add_constant("setgid", 0);
    add_constant("setuid", 0);
    //add_constant("spawne", 0);
    add_constant("cd", 0);

    _master->set_inhibit_compile_errors("");
    err=catch(p=compile_string(file, got->realfile));
    if(strlen(_master->errors)) 
      s=_master->errors + "\n\n" + s;
    _master->set_inhibit_compile_errors(0);

    add_constant("setegid", ban[0]);
    add_constant("setgid", ban[1]);
    add_constant("seteuid", ban[2]);
    add_constant("setuid", ban[3]);
    //add_constant("spawne", ban[4]);
    add_constant("cd", ban[5]);

    if(err) {
      destruct(f);
      my_error(err, got->not_query+":\n"+(s?s+"\n\n":"\n"), 
	       "Error while compiling pike script:<br>\n\n");
    }
    if(!p) {
      destruct(f);
      return http_string_answer("<h1>While compiling pike script</h1>\n"+s);
    }
    o=p();
    if (!functionp(fun = scripts[got->not_query]=o->parse)) {
      /* Should not happen */
      destruct(f);
      return http_string_answer("<h1>No string parse(object id) function in pike-script</h1>\n");
    }
  }

  err=call_script(fun, got, f);
  destruct(f);
  if(arrayp(err)) {
    destruct(function_object(fun));
    scripts[got->not_query] = 0;
    my_error(err[1]); // Will interrupt here.
  }
  return err;
}

string status()
{
  string res="", foo;

  if(sizeof(scripts))
  {
    res += "<hr><h1>Loaded scripts</h1><p>";
    foreach(indices(scripts), foo )
      res += foo+"\n";
  } else {
    return "<h1>No loaded scripts</h1>";
  }
  res += "<hr>";

  return ("<pre><font size=+1>" + res + "</font></pre>");

}

void start()
{
  if(QUERY(fork_exec))
  {
    if(!(int)QUERY(runuser))
      runuser = QUERY(runuser);
    else
      runuser = ({ (int)QUERY(runuser), 60001 });
  }

}
