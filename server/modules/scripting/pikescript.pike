#include <config.h>

// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.

// Support for user Pike-scripts, like CGI, but handled internally in
// the server, and thus much faster, but blocking, and somewhat less
// secure.

// This is an extension module.

constant cvs_version = "$Id: pikescript.pike,v 1.44 1999/11/26 03:21:32 per Exp $";
constant thread_safe=1;

mapping scripts=([]);

inherit "module";
inherit "roxenlib";
#include <module.h>

#if constant(_static_modules) && efun(thread_create)
constant Mutex=__builtin.mutex;
#endif /* _static_modules */

array register_module()
{
  return ({ 
    MODULE_FILE_EXTENSION,
    "Pike script support", 
    "Support for user Pike-scripts, like CGI, but handled internally in the"
    " server, and thus much faster, but blocking, and less secure.\n"
    "<br><img src=/image/err_2.gif align=left alt=\"\">"
    "NOTE: This module should not be enabled if you allow anonymous PUT!<br>\n"
    "NOTE: Enabling this module is the same thing as letting your users run"
    " programs with the same right as the server!"
    });
}

int fork_exec_p() { return !QUERY(fork_exec); }

#if constant(__builtin.security)
// EXPERIMENTAL: Try using the credential system.
constant security = __builtin.security;
object luser = class {}();
object luser_creds = security.Creds(luser, 0, 0);
#endif /* constant(__builtin.security) */

void create()
{
  defvar("exts", ({ "lpc", "ulpc", "µlpc","pike" }), "Extensions", TYPE_STRING_LIST,
	 "The extensions to parse");

#ifndef THREADS
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
#endif

  defvar("rawauth", 0, "Raw user info", TYPE_FLAG|VAR_MORE,
	 "If set, the raw, unparsed, user info will be sent to the script. "
	 "Please note that this will give the scripts access to the password "
	 "used. This is not recommended !");

  defvar("clearpass", 0, "Send decoded password", TYPE_FLAG|VAR_MORE,
	 "If set, the decoded password value will be sent to the script. "
	 "This is not recommended !");

  defvar("exec-mask", "0777", "Exec mask: Needed", 
	 TYPE_STRING|VAR_MORE,
	 "Only run scripts matching this permission mask");

  defvar("noexec-mask", "0000", "Exec mask: Forbidden", 
	 TYPE_STRING|VAR_MORE,
	 "Never run scripts matching this permission mask");

  defvar( "autoreload", 1, "Reload scripts automatically",
          TYPE_FLAG,
          "If this option is true, scripts will be reloaded automatically "
          "from disk if they have changed. This requires one stat for each "
          "access to the script, and also one stat for each file the script "
          "inherits, if any.  Please note that pike modules are currently not "
          "automatically reloaded from disk" );

  defvar( "explicitreload", 0, 
          "Reload scripts when the user sends a no-cache header",
          TYPE_FLAG,
          "If this option is true, scripts will be reloaded if the user sends "
          "a pragma: no-cache header (netscape does this when the user presses "
          "shift+reload, IE doesn't), even if they have not changed on disk. "
          " Please note that pike modules are currently not automatically "
          "reloaded from disk" );
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
//   if( !arrayp( err ) )
//     err = (array)err;
//   err[0] = ("<font size=+1>"+(b||"Error while executing code in pike script")
// 	    + "</font><br><p>" +(err[0]||"") + (a||"")
// 	    + "<br><p>The pike Script will be reloaded automatically.\n");
//   throw(err);
  throw( err );
}

array|mapping call_script(function fun, object got, object file)
{
  mixed result, err;
  string s;
  object privs;
  if(!functionp(fun))
    return 0;
  string|array (int) uid, olduid, us;

  if(got->rawauth && (!QUERY(rawauth) || !QUERY(clearpass)))
    got->rawauth=0;
  if(got->realauth && !QUERY(clearpass))
    got->realauth=0;

#ifndef THREADS
#if efun(fork)
  if(QUERY(fork_exec)) {
    if(fork())
      return ([ "leave_me":1 ]);
    
    catch {
      /* Close all listen ports in copy. */
      foreach(indices(roxen->portno), object o) {
	destruct(o);
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

  } else 
#endif
    if(got->misc->is_user && (us = file_stat(got->misc->is_user)))
      privs = Privs("Executing pikescript as non-www user", @us[5..6]);
#else
  object key;
  if(!function_object(fun)->thread_safe)
  {
    if(!locks[fun]) locks[fun]=Mutex();
    key = locks[fun]->lock();
  }
#endif

#if constant(__builtin.security)
  // EXPERIMENTAL: Call with low credentials.
  err = catch(result = call_with_creds(luser_creds, fun, got)); 
#else /* !constant(__builtin.security) */
  err = catch(result = fun(got)); 
#endif /* constant(__builtin.security) */

  if(privs) 
    destruct(privs);

#ifndef THREADS
#if efun(fork)
  if (QUERY(fork_exec)) 
  {
    if (err = catch 
    {
      if (err) 
      {
	err = catch{my_error(err, got->not_query);};
	result = describe_backtrace(err);
      } 
      else if (!stringp(result)) 
      {
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
    }) 
    {
      perror("Execution of pike-script wasn't nice:\n%s\n",
	     describe_backtrace(err));
    }
    exit(0);
  }
#endif
#endif
  if(err)
    return ({ -1, err });

  if(stringp(result)) 
    return http_rxml_answer( result, got );

  if(result == -1) 
    return http_pipe_in_progress();

  if(mappingp(result))
  {
    if(!result->type)
      result->type="text/html";
    return result;
  }

  if(objectp(result))
    return result;

  if(!result) 
    return 0;

  return http_string_answer(sprintf("%O", result));
}

mapping handle_file_extension(object f, string e, object got)
{
  int mode = f->stat()[0];
  if(!(mode & (int)query("exec-mask")) || (mode & (int)query("noexec-mask")))
    return 0;  // permissions does not match.


  string file="";
  string s;
  mixed err;
  program p;
  object o;

  if(scripts[ got->not_query ])
  {
    int reload;
    p = object_program(o=function_object(scripts[got->not_query]));
    if( query( "autoreload" ) )
      reload = (master()->refresh_inherit( p )>0);
    if( query( "explicitreload" ) )
      reload += got->pragma["no-cache"];
    if( reload )
    {
      // Reload the script from disk, if the script allows it.
      if(!(o->no_reload && o->no_reload(got)))
      {
        destruct(o);
        m_delete( scripts, got->not_query);
      }
    }
  }

  function fun;

  if (!(fun = scripts[ got->not_query ]))
  {
    file=f->read(); 

    object e = ErrorContainer();
    master()->set_inhibit_compile_errors(e);
    catch
    {
      if(got->realfile)
        p=(program)got->realfile;
      else
        p=compile_string(cpp(file));
    };
    master()->set_inhibit_compile_errors(0);

    if(!p) 
    {
      if(strlen(e->get()))
      {
        werror(e->get());
        return http_string_answer("<h1>Error compiling pike script</h1><p><pre>"+
                                  html_encode_string(e->get())+"</pre>");
      } 
      return http_string_answer("<h1>Error while compiling pike script</h1>\n");
    }

#if constant(__builtin.security)
    luser_creds->apply(p);
#endif /* constant(__builtin_security) */

    o=p();
    if (!(fun = scripts[got->not_query]=o->parse)) 
      /* Should not happen */
      return http_string_answer("<h1>No string parse(object id) "
                                "function in pike-script</h1>\n");
  }
  got->misc->cacheable=0;
  err=call_script(fun, got, f);
  if(arrayp(err)) 
  {
    m_delete( scripts, got->not_query );
    my_error(err[1]); // Will interrupt here.
  }
  return err;
}

string status()
{
  string res="", foo;

#if constant(__builtin.security)
  res += "<hr><h1>Credential system enabled</h1>\n";
#endif /* constant(__builtin.security) */

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

#ifndef THREADS
#if efun(fork)
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
#endif
#endif
