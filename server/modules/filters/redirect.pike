// This is a roxen module. Copyright © 1996 - 2004, Roxen IS.

// The redirect module. Redirects requests from one filename to
// another. This can be done using "internal" redirects (much like a
// symbolic link in unix), or with normal HTTP redirects.

constant cvs_version = "$Id$";
constant thread_safe = 1;

inherit "module";
#include <module.h>

private int redirs = 0;

void create()
{
  defvar("fileredirect", "", "Redirect patterns", TYPE_TEXT_FIELD|VAR_INITIAL,
	 "Redirect one file to another. The syntax is 'regexp to_URL',"
	 "or 'prefix to_URL', or 'exact file_name to_URL', or 'permanent regexp to_URL', "
	 "or 'permanent prefix to_URL', or 'permanent exact file_name to_URL'. More patterns "
	 "can be read from a file by using '#include &lt;filename&gt;' on a line. "
	 "The path is relative to the Roxen server directory in the real "
	 "filesystem. Other lines beginning with '#' are treated as comments.\n"

	 "<p>Some examples:'"
	 "<pre>"
         "/from/.*      http://to.roxen.com/to/%f\n"
         ".*\\.cgi       http://cgi.foo.bar/cgi-bin/%p\n"
	 "/thb/.*       %u/thb_gone.html\n"
	 "permanent /from/(.*) %u/to/$1\n"
	 "/roxen/       http://www.roxen.com/\n"
	 "exact /       /main/index.html\n"
	 "</pre>"

	 "A %f in the 'to' field will be replaced with the filename of "
	 "the matched file, %p will be replaced with the full path, and %u "
	 "will be replaced with this server's URL (useful if you want to send "
	 "a redirect instead of doing an internal one). The last two "
	 "examples are special cases. <p>"

	 "If the first word (or second word after permanent) on the line is 'exact', the filename following "
	 "must match _exactly_. This is equivalent to entering ^FILE$, but "
	 "faster. "

	 "<p>You can use '(' and ')' in the regular expression to "
	 "separate parts of the from-pattern when using regular expressions."
	 " The parts can then be insterted into the 'to' string with "
	 " $1, $2 etc.\n"

	 "<p>More examples:<pre>"
	 ".*/SE/liu/lysator/(.*)\\.class   /java/classes/SE/liu/lysator/$1.class\n"
	 "/(.*)\\.en\\.html                 /(en)/$1.html\n"
	 "(.*)/index\\.html                %u/$1/\n"
	 "permanent exact / %u/main/index.html\n</pre>"
	 ""
	 "<b>If the to file isn't an URL, the redirect will always be handled "
	 "internally, so add %u to generate an actual redirect (302 Moved Temporarily) "
	 "or with keyword 'permanent' a permanent redirect (301 Moved Permanently).</b><p>"
	 ""
	 "<b>Note 1:</b> "
	 "For speed reasons: If the from pattern does <i>not</i> contain "
	 "any '*' characters, it will not be treated like a regular "
	 "expression, instead it will be treated like a prefix that must "
	 "match exactly."

	 "<p><b>Note 2:</b> "
	 "Included files are not rechecked for changes automatically. You "
	 "have to reload the module to do that."

	 "<p><b>Note 3:</b> "
	 "The keyword 'permanent' in the redirect pattern line, to get a "
	 "301 redirect response header, only works if you use either %u or "
	 "a valid url (e.g. http://www.roxen.com) in the 'to url' pattern." );
  defvar("poll_interval", 60, "Poll interval", TYPE_INT,
	 "Time in seconds between polls of the files <tt>#include</tt>d "
	 "in the redirect pattern.");
}

array(string) redirect_from = ({});
array(string) redirect_to = ({});
array(int) redirect_code = ({});
mapping(string:array(string|int)) exact_patterns = ([]);

//! Mapping from filename to
//! @array
//!   @item int poll_interval
//!     Poll interval in seconds.
//!   @item int last_poll
//!     Time the file was last polled.
//!   @item Stdio.Stat stat
//!     Stat at the time of @[last_poll].
//! @endarray
mapping(string:array(int|Stdio.Stat)) dependencies = ([]);

void parse_redirect_string(string what, string|void fname)
{
  int ret_code = 302;
  foreach(replace(what, "\t", " ")/"\n", string s)
  {
    if (sscanf (s, "#include%*[\t ]<%s>", string file) == 2) {
      dependencies[file] = ({
	query("poll_interval"),
	time(1),
	file_stat(file)
      });
      if(string contents=Stdio.read_bytes(file))
	parse_redirect_string(contents, file);
      else
	report_warning ("Cannot read redirect patterns from "+file+".\n");
    }
    else if (sizeof(s) && (s[0] != '#')) {
      if( has_prefix(s, "permanent ") ) {
	s = s[10..];
	ret_code = 301;
      } else
	ret_code = 302;
      array(string) a = s/" " - ({""});
      if(sizeof(a)>=3 && a[0]=="exact") {
	if (exact_patterns[a[1]])
	  report_warning ("Duplicate redirect pattern %O.\n", a[1]);
	exact_patterns[a[1]] = ({ a[2], ret_code });
      }
      else if (sizeof(a)==2) {
	if (search (redirect_from, a[0]) >= 0)
	  report_warning ("Duplicate redirect pattern %O.\n", a[0]);
	redirect_from += ({a[0]});
	redirect_to += ({a[1]});
	redirect_code += ({ ret_code });
      }
      else if (sizeof (a))
	report_warning ("Invalid redirect pattern %O.\n", a[0]);
    }
  }
}

roxen.BackgroundProcess file_poller_proc;

void start_poller()
{
  if (sizeof(dependencies)) {
    int next = 0x7fffffff;
    foreach(dependencies;; array(int|Stdio.Stat) dependency) {
      int deptime = dependency[0] + dependency[1];
      if (deptime < next) next = deptime;
    }
    next -= time(1);
    if (next < 0) next = 0;
    if (file_poller_proc)
      file_poller_proc->set_period (next);
    else
      file_poller_proc = roxen.BackgroundProcess (next, file_poller);
  }
}

void file_poller()
{
  int changed;
  foreach(dependencies; string fname; array(int|Stdio.Stat) dependency) {
    Stdio.Stat stat = file_stat(fname);
    if (!((!stat && !dependency[2]) ||
	  (stat && dependency[2] && stat->mtime == dependency[2]->mtime))) {
      // mtime for the file has changed, or it has been created or deleted
      // since last poll.
      changed = 1;
    }
    dependency[1] = time(1);
    dependency[2] = stat;
  }
  if (changed) start();
  else start_poller();
}

void start()
{
  redirect_from = ({});
  redirect_to = ({});
  redirect_code = ({});
  exact_patterns = ([]);
  dependencies = ([]);
  parse_redirect_string(query("fileredirect"));
  start_poller();
}

constant module_type = MODULE_FIRST;
constant module_name = "Redirect Module";
constant module_doc  =
  "The redirect module. Redirects requests from one filename to "
  "another. This can be done using \"internal\" redirects (much"
  " like a symbolic link in unix), or with normal HTTP redirects.";
constant module_unique = 0;

string status()
{
  return sprintf("Number of patterns: %d+%d=%d, Redirects so far: %d",
		 sizeof(redirect_from),sizeof(exact_patterns),
		 sizeof(redirect_from)+sizeof(exact_patterns),
		 redirs);
}


mixed first_try(object id)
{
  string f, to;
  mixed tmp;
  int ret_code = 302;
  if(id->misc->is_redirected)
    return 0;

  string m;
  int ok;
  m = id->not_query;
  if(id->query)
    if(sscanf(id->raw_url, "%*s?%s", tmp))
      m += "?"+tmp;

  foreach(indices(exact_patterns), f)
  {
    if(m == f)
    {
      to = exact_patterns[f][0];
      ret_code = exact_patterns[f][1];
      ok=1;
      break;	
    }
  }
  if(!ok)
    for (int i = 0; i < sizeof (redirect_from); i++) {
      string f = redirect_from[i];
      if(has_prefix(m, f))
      {
	to = redirect_to[i] + m[strlen(f)..];
	ret_code = redirect_code[i];
	//  Do not explicitly remove the query part of the URL.
	// sscanf(to, "%s?", to);
	break;
      } else if( has_value(f, "*") || has_value( f, "(") ) {
	array foo;
	function split;
	if(f[0] != '^') f = "^" + f;
	if(catch (split = Regexp(f)->split))
	{
	  report_error("REDIRECT: Compile error in regular expression. ("+f+")\n");
	  continue;
	}

	//  We cannot call split on wide strings so we force UTF8 encoding
	//  of the incoming URL in such cases. If that happens we also
	//  convert the redirect pattern string so we don't get a mix of
	//  different encodings in the destination URL.
	int use_utf8 = String.width(m) > 8;
	if (use_utf8)
	  m = string_to_utf8(m);
	
	if((foo=split(m)))
	{
	  array bar = Array.map(foo, lambda(string s, mapping f) {
				       return "$"+(f->num++);
				     }, ([ "num":1 ]));
	  foo +=({(({""}) + (id->not_query/"/" - ({""})))[-1],
		  id->not_query[1..] });
	  bar +=({ "%f", "%p" });

	  string redir_to = redirect_to[i];
	  if (use_utf8)
	    redir_to = string_to_utf8(redir_to);
	  to = replace(redir_to, (array(string)) bar, (array(string)) foo);
	  if (use_utf8) {
	    //  Try reverting the temporary UTF8 encoding
	    catch { to = utf8_to_string(to); };
	  }
	  ret_code = redirect_code[i];
	  break;
	}
      }
    }

  if(!to)
    return 0;

  string url = id->url_base();
  url=url[..strlen(url)-2];
  to = replace(to, "%u", url);
  if(to == url + id->not_query || url == id->not_query)
    return 0;

  id->misc->is_redirected = 1; // Prevent recursive internal redirects

  redirs++;
  if((strlen(to) > 6 &&
      (to[3]==':' || to[4]==':' ||
       to[5]==':' || to[6]==':')))
  {
    return Roxen.http_low_answer( ret_code, "")
      + ([ "extra_heads":([ "Location":Roxen.http_encode_invalids(to) ]) ]);
  } else {
    id->variables = FakedVariables(id->real_variables = ([]));
    if (!id->misc->redirected_raw_url) {
      // Keep track of the original raw_url.
      id->misc->redirected_raw_url = id->raw_url;
      id->misc->redirected_not_query = id->not_query;
      // And our destination (in case of chained redirects).
      id->misc->redirected_to = to;
    }
    id->raw_url = Roxen.http_encode_invalids(to);
    id->not_query = id->scan_for_query( to );
  }
}
