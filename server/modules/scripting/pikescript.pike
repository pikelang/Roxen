// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.

// Support for user Pike-scripts, like CGI, but handled internally in
// the server, and thus much faster, but blocking, and somewhat less
// secure.

// This is an extension module.

constant cvs_version="$Id$";

constant thread_safe=1;
mapping scripts=([]);

protected class DestructWrapper (object o)
{
  protected void destroy() {if (o) destruct (o);}
}

protected mapping destruct_wrappers = ([]);

#include <config.h>
#include <module.h>
inherit "module";

constant module_type = MODULE_FILE_EXTENSION;
constant module_name = "Scripting: Pike script support";
constant module_doc  = #"
<p>Support for user Pike-scripts, like CGI, but handled internally in the
   server, and thus much faster, but blocking, and less secure.</p>

<p>A script must include the function <tt>mixed parse(RequestID id)</tt>.
   The return argument should be one of these:</p>

<table>
  <tr>
    <td><tt>string</tt>&nbsp;</td>
    <td>RXML code to be parsed and returned to the client.</td>
  </tr><tr>
    <td><tt>mapping</tt>&nbsp;</td>
    <td>WebServer result mapping, typically built via <tt>Roxen.http_*</tt>
        methods.</td>
  </tr><tr>
    <td><tt>-1</tt>&nbsp;</td>
    <td>Dequeues the request from the handler queue but keeps the stream
        open to the client.</td>
  </tr>
</table>

<p>Scripts are compiled and cached in RAM with the path as key. Global
   variables keep their values across invocations as long as the cached
   program remains valid and is the source file is reached via a regular
   filesystem module (i.e. not a Roxen CMS workarea). All accesses to a
   given script are serialized with an internal mutex unless the script
   defines <tt>int thread_safe = 1;</tt>.</p>

<table>
  <tr>
    <td valign='top'><imgs src='&usr.err-2;' alt='Warning' />&nbsp;</td>
    <td>
      <p style='margin-top: 0'>
         NOTE: This module should not be enabled if you allow anonymous PUT!</p>
      <p>NOTE: Enabling this module is the same thing as letting your users run
         programs with the same right as the server!</p>
    </td>
  </tr>
</table>";

#if constant(__builtin.security)
// EXPERIMENTAL: Try using the credential system.
constant security = __builtin.security;
object luser = class {}();
object luser_creds = security.Creds(luser, 0, 0);
#endif /* constant(__builtin.security) */

void create()
{
  defvar("exts", ({ "pike" }), "Extensions",
         TYPE_STRING_LIST|VAR_NOT_CFIF,
	 "The extensions to parse.");

  defvar("rawauth", 0, "Raw user info",
         TYPE_FLAG|VAR_MORE|VAR_NOT_CFIF,
	 "If set, the raw, unparsed, user info will be sent to the script. "
	 "Please note that this will give the scripts access to the password "
	 "used. This is not recommended!");

  defvar("clearpass", 0, "Send decoded password",
         TYPE_FLAG|VAR_MORE|VAR_NOT_CFIF,
	 "If set, the decoded password value will be sent to the script. "
	 "This is not recommended!");

  defvar("exec-mask", "0777", "Exec mask: Needed",
	 TYPE_STRING|VAR_MORE|VAR_NOT_CFIF,
	 "Only run scripts matching this permission mask.");

  defvar("noexec-mask", "0000", "Exec mask: Forbidden",
	 TYPE_STRING|VAR_MORE|VAR_NOT_CFIF,
	 "Never run scripts matching this permission mask.");

  defvar( "autoreload", 1, "Reload scripts automatically",
          TYPE_FLAG,
          "If this option is true, scripts will be reloaded automatically "
          "from disk if they have changed. This requires one stat for each "
          "access to the script, and also one stat for each file the script "
          "inherits, if any.  Please note that pike modules are currently not "
          "automatically reloaded from disk." );

  defvar( "explicitreload", 1,
          "Reload scripts when the user sends a no-cache header",
          TYPE_FLAG,
          "If this option is true, scripts will be reloaded if the user sends "
          "a pragma: no-cache header (netscape does this when the user presses "
          "shift+reload, IE doesn't), even if they have not changed on disk. "
          " Please note that pike modules are currently not automatically "
          "reloaded from disk." );
#if constant(__builtin.security)
  defvar( "trusted", 1,
	  "Pike scripts are trusted",
	  TYPE_FLAG|VAR_NOT_CFIF,
	  "If this option is true, scripts will be able to do everything "
	  "the Roxen server can do.");
#endif /* constant(__builtin.security) */
}

array (string) query_file_extensions()
{
  return query("exts");
}

#ifdef THREADS
mapping locks = ([]);
#endif

array|mapping call_script(function fun, RequestID id, Stdio.File file)
{
  mixed result, err;
  object privs;
  if(!functionp(fun)) {
    report_debug("call_script() failed: %O is not a function!\n", fun);
    return 0;
  }

  if(id->rawauth && (!query("rawauth") || !query("clearpass")))
    id->rawauth=0;
  if(id->realauth && !query("clearpass"))
    id->realauth=0;

#ifdef THREADS
  object key;
  if(!function_object(fun)->thread_safe)
  {
    if(!locks[fun]) locks[fun]=Thread.Mutex();
    key = locks[fun]->lock();
  }
#endif

#if constant(__builtin.security)
  if (!query("trusted")) {
    // EXPERIMENTAL: Call with low credentials.
    // werror(sprintf("call_script(): Calling %O with creds.\n", fun));
    err = catch {
      result = call_with_creds(luser_creds, fun, id);
      // werror(sprintf("call_with_creds() succeeded; result = %O\n", result));
    };
  } else
#endif /* constant(__builtin.security) */
    err = catch {
      result = fun(id);
      // werror(sprintf("calling of script succeeded; result = %O\n", result));
    };

  // werror("call_script() err: %O result:%O\n", err, result);

  if(privs)
    destruct(privs);

  if(err)
    return ({ -1, err });

  if(stringp(result))
    return Roxen.http_rxml_answer( result, id );

  if(result == -1)
    return Roxen.http_pipe_in_progress();

  if(mappingp(result))
  {
    if(!result->type)
      result->type="text/html";
    return result;
  }

  if(objectp(result))
    return result;

  if(!result) {
    // werror("call_script() failed: No result.\n");
    return 0;
  }

  return Roxen.http_string_answer(sprintf("%O", result));
}

mapping handle_file_extension(Stdio.File f, string e, RequestID id)
{
  int mode = f->stat()[0];
  if(!(mode & (int)query("exec-mask")) || (mode & (int)query("noexec-mask")))
    return 0;  // permissions does not match.

  // do it before the script is processes, so the script can change the value.
  id->misc->cacheable=0;

  string file="";
  mixed err;
  program p;
  object o;
  DestructWrapper avoid_destruct = destruct_wrappers[id->not_query];

  if(scripts[ id->not_query ])
  {
    int reload;
    p = object_program(o=function_object(scripts[id->not_query]));
    if( query( "autoreload" ) )
      reload = (master()->refresh_inherit( p )>0);
    if( query( "explicitreload" ) )
      reload += id->pragma["no-cache"];

    if( reload )
    {
      // Reload the script from disk, if the script allows it.
      if(!(o->no_reload && o->no_reload(id)))
      {
        master()->refresh( p, 1 );
	// Destruct the script instance as soon as no other thread is
	// executing it.
	m_delete (destruct_wrappers, id->not_query);
	avoid_destruct = 0;
        p = 0;
        m_delete( scripts, id->not_query);
      }
    }
  }

  function fun;

  if (!(fun = scripts[ id->not_query ]))
  {
    file=f->read();

    object e = ErrorContainer();
    master()->set_inhibit_compile_errors(e);
    mixed re = catch
    {
      object key = Roxen.add_scope_constants( "rxml_scope_" );
      if(id->realfile)
        p=(program)id->realfile;
      else
        p=compile_string(cpp(file));
      destruct( key );
    };
    master()->set_inhibit_compile_errors(0);

    if(!p)
    {
      // force reload on next access. Really.
      master()->clear_compilation_failures();

      if(strlen(e->get()))
      {
        report_debug(e->get());
        return Roxen.http_string_answer("<h1>Error compiling pike script</h1><p><pre>"+
                                  Roxen.html_encode_string(e->get())+"</pre>");
      }
      throw( re );
    }

#if constant(__builtin.security)
    if (!query("trusted")) {
      // EXPERIMENTAL: Lower the credentials.
      luser_creds->apply(p);
    }
#endif /* constant(__builtin_security) */

    o=p();
    if (!(fun = scripts[id->not_query]=o->parse))
      /* Should not happen */
      return Roxen.http_string_answer("<h1>No string parse(object id) "
                                "function in pike-script</h1>\n");
    avoid_destruct = destruct_wrappers[id->not_query] = DestructWrapper (o);
  }

  err = call_script(fun, id, f);
  if(mappingp(err)) return err;
  if(arrayp(err))
  {
    m_delete( scripts, id->not_query );
    throw( err[1] );
  }
  if (stringp(err || "")) {
    return Roxen.http_string_answer(err || "");
  }
  report_error("PIKESCRIPT: Unexpected return value %O from script %O\n",
	       err, id->not_query);
  return Roxen.http_string_answer("");
}

string status()
{
  string res="", foo;

#if constant(__builtin.security)
  res += "<hr><h3>Credential system enabled</h3>\n";
#endif /* constant(__builtin.security) */

  if(sizeof(scripts))
  {
    res += "<hr><h3>Loaded scripts</h3><p>";
    foreach(indices(scripts), foo )
      res += foo+"\n";
  } else {
    return "<h3>No loaded scripts</h3>";
  }
  res += "<hr>";

  return ("<pre><font size=\"+1\">" + res + "</font></pre>");
}
