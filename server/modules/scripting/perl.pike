#include <module.h>
inherit "module";
inherit "roxenlib";

// Experimental Perl script and tag handler module.
// by Leif Stensson.

string cvs_version =
       "$Id: perl.pike,v 2.7 2000/09/10 16:47:49 nilsson Exp $";

constant module_type = MODULE_EXPERIMENTAL |
            MODULE_FILE_EXTENSION | MODULE_TAG;

constant module_name = "Perl support";
constant module_doc =
   "EXPERIMENTAL MODULE! This module provides a faster way of running "
   "Perl scripts with Roxen. "
   "The module also optionally provides a &lt;perl&gt;..&lt;/perl&gt; "
   "container to run Perl code from inside RXML pages."; 

static string recent_error = 0;
static int parsed_tags = 0, script_calls = 0, script_errors = 0;

static mapping handler_settings = ([ ]);

constant thread_safe = 1;

#ifdef THREADS
static object mutex = Thread.Mutex();
#endif

void create()
{
  defvar("extensions", ({ "pl", "perl" }), "Extensions", TYPE_STRING_LIST,
    "List of URL extensions that should be taken to indicate that the "
    "document is a Perl script.");

#if 0
  defvar("libdir", "./perl", "Roxen Perl Directory", TYPE_DIR,
    "This is the name of a directory with Roxen-related Perl stuff. It "
    "should normally point to `perl' in the Roxen server directory, "
    "but you may want to point it elsewhere if you want to modify the "
    "code.");
#endif

  defvar("showbacktrace", 0, "Show Backtraces", TYPE_FLAG,
    "This setting decides whether to deliver a backtrace in the document "
    "if an error is caught while a script runs.");

  defvar("tagenable", 0, "Enable Perl Tag", TYPE_FLAG,
    "This setting decides whether to enable parsing of Perl code in "
    "RXML pages, in &lt;perl&gt;..&lt;/perl&gt; containers.");

  defvar("scriptout", "HTML", "Script output", TYPE_MULTIPLE_STRING,
    "How to treat script output. HTML means treat it as a plain HTML "
    "document. RXML is similar, but passes it through the RXML parser "
    "before returning it to the client. HTTP is the traditional CGI "
    "output style, where the script is responsible for producing the "
    "HTTP headers before the document, as well as the main document "
    "data.",
         ({ "HTML", "RXML", "HTTP" })
        );

  defvar("rxmltag", 0, "RXML-parse tag results", TYPE_FLAG,
    "Allow RXML parsing of tag results.");

  defvar("bindir", "perl/bin", "Perl Helper Binaries", TYPE_DIR,
    "Perl helper binaries directory.");

  defvar("parallel", 2, "Parallel scripts", TYPE_MULTIPLE_INT,
    "Number of scripts/tags that may be evaluated in parallel. Don't set "
    "this higher than necessary, since it may cause the server to block. "
    "The default for this setting is 2.",
         ({ 1, 2, 3, 4, 5 }) );

#if constant(getpwnam)
  defvar("identity", "nobody:*", "Run Perl as...", TYPE_STRING,
    "User and group to run Perl scripts and tags as. The default for "
    "this option is `nobody:*'. Note that Roxen can't change user ID "
    "unless it has sufficient permissions to do so. `*' means `use "
    "same as Roxen'.");
#endif
}

string status()
{ string s = "<b>Script calls</b>: " + script_calls + " <br />\n" +
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
  if (Stdio.File(QUERY(bindir)+"/perlrun", "r"))
       s += "found: " + QUERY(bindir)+"/perlrun <br />\n";
  else
       s += "not found.<br />\n";

  if (recent_error)
       s += "<b>Most recent error</b>: " + recent_error + " <br />\n";

  return s;
}

static object gethandler()
{ return ExtScript.getscripthandler(QUERY(bindir)+"/perlrun",
                                    QUERY(parallel), handler_settings);
}

static void fix_settings()
{
  string u, g;
  mapping s = ([ ]);

#if constant(getpwnam)
  if (sscanf(QUERY(identity), "%s:%s", u, g) == 2)
  {
    array ua = getpwnam(u), ga = getgrnam(g);

    if (!ua) ua = getpwuid((int) u);
    if (!ga) ga = getgrgid((int) g);

    if (ua) s->set_uid = ua[2];
    if (ga) s->set_gid = ga[2];
  }
#endif

  handler_settings = s;
}

static void periodic()
{
  fix_settings();
  ExtScript.periodic_cleanup();
  call_out(periodic, 900);
}

void start()
{ fix_settings();
  call_out(periodic, 900);
}

mixed handle_file_extension(Stdio.File file, string ext, object id)
{ object h = gethandler();

  if (id->realfile && stringp(id->realfile))
  { array result;

    NOCACHE();

    if (!h) return http_string_answer("<h1>Script support failed.</h1>");

    mixed bt = catch (result = h->run(id->realfile, id));

    ++script_calls;

    if (bt)
    { ++script_errors;
      report_error("Perl script `" + id->realfile + "' failed.\n");
      if (QUERY(showbacktrace))
        return http_string_answer("<h1>Script Error!</h1>\n<pre>" +
                       describe_backtrace(bt) + "\n</pre>");
      else
        return http_string_answer("<h1>Script Error!</h1>");
    }
    else if (sizeof(result) > 1)
    { string r = result[1];
//      werror("Result: " + sprintf("%O", r) + "\n");
      if (r == "") r = " "; // Some browsers don't like null answers.
      if (!stringp(r)) r = "(not a string)";
      switch (QUERY(scriptout))
      { case "RXML":
          return http_rxml_answer(r, id);
        case "HTML":
          return http_string_answer(r);
        case "HTTP":
	  id->connection()->write("HTTP/1.0 200 OK\r\n");
          id->connection()->write(r);
          id->connection()->close();
          return http_pipe_in_progress();
        default:
          return http_string_answer("SCRIPT ERROR: "
                                    "bad output mode configured.\n");
      }
    }
    else
    { return http_string_answer(sprintf("RESULT: %O", result));
    }
  }

  return http_string_answer("FOO!");

  return 0;
}

constant simpletag_perl_flags = 0;

mixed simpletag_perl(string tag, mapping attr, string contents, object id,
                     RXML.Frame frame)
{
  if (!QUERY(tagenable))
       RXML.run_error("<perl>...</perl> tag not enabled in this server.");

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
    else if (QUERY(rxmltag))
    {
      frame->result_type = frame->result_type(RXML.PXml);
      return parse_rxml(result[1], id);
    }
    else
      return result[1];
  }
  else
    return sprintf("SCRIPT ERROR: bad result: %O", result);

  return "<b>(No perl tag support?)</b>";
}

mixed simple_pi_tag_perl(string tag, mapping attr, string contents, object id,
                     RXML.Frame frame)
{
  return simpletag_perl(tag, attr, contents, id, frame);
}

array(string) query_file_extensions()
{
  return QUERY(extensions);
}




