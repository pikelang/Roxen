// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.
// Perl script and tag handler module.
// by Leif Stensson.

#include <roxen.h>
#include <module.h>

//<locale-token project="mod_perl">LOCALE</locale-token>
// USE_DEFERRED_LOCALE;
#define LOCALE(X,Y)  _DEF_LOCALE("mod_perl",X,Y)

#include <module.h>
inherit "module";
inherit "roxenlib";

string cvs_version =
       "$Id$";

constant module_type = MODULE_FILE_EXTENSION | MODULE_TAG;

constant module_name = "Scripting: Perl support";
constant module_doc =
   "This module provides a faster way of running Perl scripts with Roxen. "
   "The module also optionally provides a &lt;perl&gt;..&lt;/perl&gt; "
   "container (and a corresponding processing instruction &lt;?perl ... "
   "?&gt;) to run Perl code from inside RXML pages."; 

protected string recent_error = 0;
protected int parsed_tags = 0, script_calls = 0, script_errors = 0;

protected mapping handler_settings = ([ ]);

protected int cache_output;

protected string script_output_mode;

constant thread_safe = 1;

#ifdef THREADS
protected object mutex = Thread.Mutex();
#endif

void create()
{
  defvar("extensions", ({ "pl", "perl" }),
    LOCALE(1,"Extensions"), TYPE_STRING_LIST,
    LOCALE(2,"List of URL extensions that indicate that the document "
	   "is a Perl script."));

#if 0
  defvar("libdir", "./perl",
    LOCALE(3, "Roxen Perl Directory"), TYPE_DIR,
    LOCALE(4, "This is the name of a directory with Roxen-related Perl "
    "stuff. It should normally point to `perl' in the Roxen server directory, "
    "but you may want to point it elsewhere if you want to modify the "
    "code."));
#endif

  defvar("showbacktrace", 0,
    LOCALE(5, "Show Backtraces"), TYPE_FLAG,
    LOCALE(6, "This setting decides whether to deliver a backtrace in the "
	   "document if an error is caught while a script runs."));

  defvar("tagenable", 0,
    LOCALE(7, "Enable Perl Tag"), TYPE_FLAG,
    LOCALE(8, "This setting decides whether to enable parsing of Perl code "
	   "in RXML pages, in &lt;perl&gt;..&lt;/perl&gt; containers."));

  defvar("scriptout", "HTTP",
    LOCALE(9, "Script output"), TYPE_MULTIPLE_STRING,
    LOCALE(10, "How to treat script output. HTML means treat it as a plain "
    "HTML document. RXML is similar, but passes it through the RXML parser "
    "before returning it to the client. HTTP is the traditional CGI "
    "output style, where the script is responsible for producing the "
    "HTTP headers before the document, as well as the main document "
    "data."),
         ({ "HTML", "RXML", "HTTP" })
        );

  defvar("rxmltag", 0,
    LOCALE(11, "RXML-parse tag results"), TYPE_FLAG,
    LOCALE(12, "Whether to RXML parse tag results or not."));

#if constant(system.NetWkstaUserEnum)
  // WinNT.
  defvar("helper", "perl/bin/ntperl.pl",
    LOCALE(13, "Perl Helper"), TYPE_FILE,
    LOCALE(14, "Path to the helper program used to start a Perl subprocess. "
    "The default for this setting is `perl/bin/ntperl.pl'."));
#else
  // Assume Unix.
  defvar("helper", "perl/bin/perlrun",
    LOCALE(13, "Perl Helper"), TYPE_FILE,
    LOCALE(15, "Path to the helper program used to start a Perl subprocess. "
    "The default for this setting is `perl/bin/perlrun'."));
#endif

  defvar("parallel", 3,
    LOCALE(16, "Parallel scripts"), TYPE_MULTIPLE_INT,
    LOCALE(17, "Number of scripts/tags that may be evaluated in parallel. "
    "Don't set this higher than necessary, since it may cause the server "
    "to block (by using all available threads). The default for this "
    "setting is 3."),
         ({ 1, 2, 3, 4, 5, 6 }) );

  defvar("caching", 0,
	 LOCALE(18, "Cache output"), TYPE_FLAG,
	 LOCALE(19, "Whether to cache the result of scripts. This is usually "
		"not desirable, so the default for this setting is No."));

#if constant(getpwnam)
  defvar("identity", "nobody:*",
    LOCALE(20, "Run Perl as..."), TYPE_STRING,
    LOCALE(21, "User and group to run Perl scripts and tags as. The default "
    "for this option is `nobody:*'. Note that Roxen can't change user ID "
    "unless it has sufficient permissions to do so. `*' means `use "
    "same as Roxen'."));
#endif
}

string status()
{
  string s = "<b>Script calls</b>: " + script_calls + " <br />\n" +
             "<b>Script errors</b>: " + script_errors + " <br />\n" +
             "<b>Parsed tags</b>: "  + parsed_tags + " <br />\n";

#if constant(getpwnam)
  if (handler_settings->set_uid)
        s += sprintf("<b>Subprocess UID</b>: set uid=%O <br />\n",
                     handler_settings->set_uid);
  else
        s += "<b>Subprocess UID</b>: same as Roxen<br />\n";
#endif

  s += "<b>Helper script</b>: ";
  if (Stdio.File(query("helper"), "r"))
       s += "found: " + query("helper")+" <br />\n";
  else
       s += "not found.<br />\n";

  if (recent_error)
       s += "<b>Most recent error</b>: " + recent_error + " <br />\n";

  return s;
}

protected object gethandler()
{ return ExtScript.getscripthandler(query("helper"),
                                    query("parallel"), handler_settings);
}

protected void fix_settings()
{
  mapping s = ([ ]);

#if constant(getpwnam)
  if (sscanf(query("identity"), "%s:%s", string u, string g) == 2)
  {
    array ua = getpwnam(u), ga = getgrnam(g);

    if (!ua) ua = getpwuid((int) u);
    if (!ga) ga = getgrgid((int) g);

    if (ua) s->set_uid = ua[2];
    if (ga) s->set_gid = ga[2];
  }
#endif

  handler_settings = s;

  cache_output = query("caching");
}

protected void periodic()
{
  fix_settings();
  ExtScript.periodic_cleanup();
  call_out(periodic, 900);
}

void start()
{
  periodic();
  script_output_mode = query("scriptout");
}

protected void add_headers(string headers, object id)
{ string header, name, value;
  if (headers)
    foreach(headers / "\r\n", header)
    { if (sscanf(header, "%[^:]:%s", name, value) == 2)
        switch (name)
        { case "Content-Type":
          case "Content-Encoding":
          case "Content-Languages":
            // Might require special treatment in the future?
            ;
	  default:
	    id->add_response_header (name, value);
        }
    }
}

protected void do_response_callback(RequestID id, array result)
{
//  werror("perl:do_response_callback: %O %O\n", id, result);
  id->connection()->write("HTTP/1.0 200 OK\r\n");
  if (arrayp(result) && sizeof(result) > 1)
  { if (sizeof(result) > 2 && stringp(result[2]))
    {
      foreach(result[2] / "\r\n" - "", string s)
          id->connection()->write(s + "\r\n");
      id->connection()->write("\r\n");
    }
    id->connection()->write(result[1]);
  }
  id->connection()->close();
}

mixed handle_file_extension(Stdio.File file, string ext, object id)
{
  object h = gethandler();

  if (id->realfile && stringp(id->realfile))
  { array result;

    if (!cache_output)
    {
      NOCACHE();
    }

    if (!h)
      return Roxen.http_string_answer("<h1>Script support failed.</h1>");

    mixed bt;

    if (script_output_mode == "HTTP")
       bt = catch (result = h->run(id->realfile, id, do_response_callback));
    else
       bt = catch (result = h->run(id->realfile, id));

    ++script_calls;

    if (bt)
    {
      ++script_errors;
      report_error("Perl script `" + id->realfile + "' failed.\n");
      if (query("showbacktrace"))
        return Roxen.http_string_answer("<h1>Script Error!</h1>\n<pre>" +
                       describe_backtrace(bt) + "\n</pre>");
      else
        return Roxen.http_string_answer("<h1>Script Error!</h1>");
    }
    else if (arrayp(result))
    { string r = sizeof(result) > 1 ? result[1] : "";

//      werror("Result: " + sprintf("%O", r) + "\n");
      if (r == "") r = " "; // Some browsers don't like null answers.
      if (!stringp(r)) r = "(not a string)";

      switch (script_output_mode)
      {
        case "RXML":
          if (sizeof(result) > 2 && stringp(result[2]))
               add_headers(result[2], id);
          return Roxen.http_rxml_answer(r, id);

        case "HTML":
          if (sizeof(result) > 2 && stringp(result[2]))
               add_headers(result[2], id);
          return Roxen.http_string_answer(r);

        case "HTTP":
          if (sizeof(result) > 0)
          {
            id->connection()->write("HTTP/1.0 200 OK\r\n");
            id->connection()->write(r);
            id->connection()->close();
//            werror("id/perl: connection closed.\n");
          }
//          else werror("id/perl: nonblocking.\n");

          return Roxen.http_pipe_in_progress();

        default:
          return Roxen.http_string_answer("SCRIPT ERROR: "
                                          "bad output mode configured.\n");
      }
    }
    else
      return Roxen.http_string_answer(sprintf("RESULT: %O", result));
  }

#if 1
  return http_string_answer("Script file not accessible in this filesystem "
			    "(no real file).");
#else
  // Possible security leak allowing people to read the contents
  // of script files.
  return 0;
#endif
}

constant simpletag_perl_flags = 0;

mixed simpletag_perl(string tag, mapping attr, string contents, object id,
                     RXML.Frame frame)
{
  if (!query("tagenable"))
       RXML.run_error("Perl tag not enabled in this server.");

  object h = gethandler();

  if (!h)
        RXML.run_error("Perl tag support unavailable.");

  NOCACHE();

  array result;
  mixed bt = catch (result = h->eval(contents, id));
  ++parsed_tags;

  if (bt)
  {
    werror("Perl tag backtrace:\n" + describe_backtrace(bt) + "\n");
    RXML.run_error("Perl tag");
  }
  else if (sizeof(result) > 1)
  { if (result[0] < 0 || !stringp(result[1]))
      return "SCRIPT ERROR: " + sprintf("%O", result[1]);
    else if (query("rxmltag"))
    {
      frame->result_type = frame->result_type(RXML.PXml);
      return Roxen.parse_rxml(result[1], id);
    }
    else
      return result[1];
  }
  else
    return sprintf("SCRIPT ERROR: bad result: %O", result);

  return "<b>(?perl?)</b>";
}

mixed simple_pi_tag_perl(string tag, mapping attr, string contents, object id,
                     RXML.Frame frame)
{
  return simpletag_perl(tag, attr, contents, id, frame);
}

array(string) query_file_extensions()
{
  return query("extensions");
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"?perl":#"<desc type='pi'><p><short hide='hide'>
 Perl processing instruction tag.</short>This processing intruction
 tag allows for evaluating Perl code directly in the document.</p>

 <p>Note: Read the installation and configuration documentation in the
 Administration manual to set up the Perl support properly. If the
 correct parameters are not set the Perl code might not work properly
 or security issues might arise.</p>

 <p>There is also a <tag>perl</tag>...<tag>/perl</tag> container tag
 available.</p>
</desc>",

  ]);
#endif
