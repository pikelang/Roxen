#include <config.h>

// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.

// Support for user Pike-scripts, like CGI, but handled internally in
// the server, and thus much faster, but blocking, and somewhat less
// secure.

// This is an extension module.

constant cvs_version=
"$Id: pikescript.pike,v 1.50 1999/12/09 00:57:43 grubba Exp $";

constant thread_safe=1;
mapping scripts=([]);

inherit "module";
inherit "roxenlib";
#include <module.h>

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

#if constant(__builtin.security)
// EXPERIMENTAL: Try using the credential system.
constant security = __builtin.security;
object luser = class {}();
object luser_creds = security.Creds(luser, 0, 0);
#endif /* constant(__builtin.security) */

void create()
{
  defvar("exts", ({ "lpc", "ulpc", "µlpc","pike" }), "Extensions", 
         TYPE_STRING_LIST,
	 "The extensions to parse");

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
#if constant(__builtin.security)
  defvar( "trusted", 0,
	  "Pike scripts are trusted",
	  TYPE_FLAG,
	  "If this option is true, scripts will be able to do everything "
	  "the Roxen server can do.");
#endif /* constant(__builtin.security) */
}

array (string) query_file_extensions()
{
  return QUERY(exts);
}

#ifdef THREADS
mapping locks = ([]);
#endif

array|mapping call_script(function fun, object got, object file)
{
  mixed result, err;
  string s;
  object privs;
  if(!functionp(fun)) {
    roxen_perror("call_script() failed: %O is not a function!\n", fun);
    return 0;
  }
  string|array (int) uid, olduid, us;

  if(got->rawauth && (!QUERY(rawauth) || !QUERY(clearpass)))
    got->rawauth=0;
  if(got->realauth && !QUERY(clearpass))
    got->realauth=0;

#ifdef THREADS
  object key;
  if(!function_object(fun)->thread_safe)
  {
    if(!locks[fun]) locks[fun]=Thread.Mutex();
    key = locks[fun]->lock();
  }
#endif

#if constant(__builtin.security)
  if (!QUERY(trusted)) {
    // EXPERIMENTAL: Call with low credentials.
    err = catch(result = call_with_creds(luser_creds, fun, got)); 
  } else
#else /* !constant(__builtin.security) */
    err = catch(result = fun(got)); 
#endif /* constant(__builtin.security) */

  // roxen_perror("call_script() err: %O result:%O\n", err, result);

  if(privs) 
    destruct(privs);

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

  if(!result) {
    // roxen_perror("call_script() failed: No result.\n");
    return 0;
  }

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
    throw( err[1] );
  }
  return err || "";
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
