// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.

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
	 #"\
A list of patterns to redirect one URL to another. Each line is a
pattern rule according to one of the following formats:

<dl>
<dt>[<tt>permanent</tt>] <i>regexp target</i>
  <dd><p>Any URL path that matches <i>regexp</i> is redirected to
  <i>target</i>. The <i>regexp</i> is assumed to always contain a '*'
  character, otherwise it is interpreted as a <i>prefix</i> instead -
  see next rule.</p>

  <p>You can use '(' and ')' in <i>regexp</i> to extract parts of it.
  The parts can then be insterted into the <i>target</i> pattern with
  $1, $2 etc.</p>

<dt>[<tt>permanent</tt>] <i>prefix target</i>
  <dd><p>Any URL path that begins with <i>prefix</i> is redirected to
  <i>target</i>.</p>

<dt>[<tt>permanent</tt>] <tt>exact</tt> <i>path target</i>
  <dd><p>If the URL path is exactly <i>path</i>, then redirect to
  <i>target</i>.</p>

  <p>These rules are handled more efficiently than the preceding ones.
  While every rule of the preceding types adds a little bit of extra
  processing time to every request, there can be almost any amount of
  'exact' rules without additional slowdown.</p>
</dl>

<p>Rules with the 'exact' keyword are tested first, then the other
rules are tested in the order they are written. Therefore more
specific rules should come before generic ones, and time can be saved
by putting rules which are hit frequently first.</p>

<p>If <i>target</i> isn't an absolute URL then the redirect is handled
internally, otherwise a redirect response is sent. The response uses
302 Moved Temporarily by default, but if the rule is preceded by
'permanent' then a 301 Moved Permanently is sent instead.</p>

<p>\"%f\" in the <i>target</i> field is replaced with the filename of
the matched file, \"%p\" is replaced with the full path, and \"%u\" is
replaced with the base URL of the server.</p>

<p>\"%u\" is useful in front of <i>target</i> to construct an absolute
URL. Note that it does not include an ending '/', so you should
provide one yourself.</p>

<p>In addition, patterns can also be included from another file using
an include directive:

<blockquote><tt>#include &lt;</tt><i>filename</i><tt>&gt;</tt></blockquote>

The path is relative to the Roxen server directory in the real
filesystem.</p>

<p>Other lines beginning with '#' are treated as comments. Empty lines
are ignored.</p>

<p>Some examples:</p>

<pre>/from/.*                        http://to.roxen.com/to/%f
.*\\.cgi                         http://cgi.foo.bar/cgi-bin/%p
/thb/.*                         %u/thb_gone.html
permanent /from/(.*)            %u/to/$1
/roxen/                         http://www.roxen.com/
exact /                         /main/index.html
.*/SE/liu/lysator/(.*)\\.class   /java/classes/SE/liu/lysator/$1.class
/(.*)\\.en\\.html                 /(en)/$1.html
(.*)/index\\.html                %u/$1/
permanent exact /               %u/main/index.html
</pre>

<p><b>Note:</b> The keyword 'permanent' only works if you use an
absolute URL, either literally or by starting <i>target</i> with %u.");

  defvar("poll_interval", 60, "Poll interval", TYPE_INT,
	 "Time in seconds between polls of the files <tt>#include</tt>d "
	 "in the redirect pattern.");
}

array(string(0..255)) redirect_from = ({});
array(string(0..255)) redirect_to = ({});
array(int) redirect_code = ({});
mapping(string(0..255):array(string(0..255)|int)) exact_patterns = ([]);


//! Returns false if AC module reload detected.
bool try_ac_backdoor(RequestID id)
{
  //  Unlimited access privileges using AC backdoor? This is enabled
  //  by setting the Force Access popup menu to a specific value in
  //  the preference wizard.
  mapping acvar = roxen->query_var("AC");
  if (object acmodule = acvar?->loaders[my_configuration()]) {
    //  There is a slight chance that the AC module is reloading at
    //  this moment. We need to detect that and reschedule the
    //  crawling in a couple of seconds.
    if (!acmodule->online_db || !acmodule->online_db->acdb) {
      return false;
    }
    acmodule->online_db->acdb->backdoor_request(id);
  }
  return true;
}

Stdio.Stat virtual_file_stat(string file, RequestID id)
{
  array(int)|Stdio.Stat file_stat =
    my_configuration()->try_stat_file(file, fake_id);
  if (arrayp(file_stat)) {
    file_stat = Stdio.Stat(file_stat);
  }
  return file_stat;
}

class RedirectFile {

  string file;
  // Used for storing the time from last time we checked this file.
  int time;
  // Used for storing the stat from last time we checked this file.
  Stdio.Stat stat;

  protected void create(file, Stdio.Stat|void stat)
  {
    this::file = file;
    this::time = time(1);
    if (stat) {
      this::stat = stat;
    } else {
      this::stat = file_stat();
    }
  }

  Stdio.Stat file_stat()
  {
    return file_stat(file);
  }
}


class VirtualRedirectFile {
  inherit FileInfo;

  Stdio.Stat file_stat()
  {
    Stdio.Stat stat = UNDEFINED;
    RequestID fake_id = roxen.InternalRequestID();
    mixed e = catch {
      fake_id->set_path(file);
      if (!try_ac_backdoor(fake_id)) {
        destruct(fake_id);
        return 0;
      }
      stat = virtual_file_stat(file, fake_id);
    };
    destruct(fake_id);
    if (e) {
      report_warning("Redirect:%d: Error while reading file %s.\n",
        __LINE__, file);
    }
    return stat;
  }
}

void parse_virtual_include_file(string file, int|void no_tries)
{
  if (no_tries >= 9) {
    report_warning("Redirect: Failed to read file %s. (Tried %d times.)\n",
      file, no_tries + 1);
  }
  werror("TRACE: Found a virtual include file: %s\n", file);
  RequestID fake_id = roxen.InternalRequestID();
  mixed e = catch {
    fake_id->set_path(file);
    if (!try_ac_backdoor(fake_id)) {
      destruct(fake_id);
      report_error("Redirect: Failed to parse virtual file [%s] due to "
                   "AC module reload detected. Will try again shortly.\n",
                   file);
      roxen.background_run(10, parse_virtual_include_file, file, ++no_tries);
      return 0;
    }
    Stdio.Stat file_stat = virtual_file_stat(file, fake_id);
    dependencies[file] = VirtualRedirectFile(file, file_stat);
    if (string content = my_configuration()->try_get_file(file, fake_id)) {
      parse_redirect_string(contents, file);
    } else {
      report_warning ("Cannot read redirect patterns from "+file+".\n");
    }

    werror("TRACE: Content:\n%O\n", content);
    werror("TRACE: file stat: %O\n", file_stat);

  };
  destruct(fake_id);
  if (e) {
    report_warning("Redirect:%d: Error while reading file %s.\n",
      __LINE__, file);
  }
}


//! Mapping from filename to
//! @array
//!   @elem int poll_interval
//!     Poll interval in seconds.
//!   @elem int last_poll
//!     Time the file was last polled.
//!   @elem Stdio.Stat stat
//!     Stat at the time of @[last_poll].
//! @endarray
mapping(string(0..255):RedirectFile) dependencies = ([]);

void parse_redirect_string(string what, string|void fname)
{
  werror("TRACE: Parsing redirect strings...\n");
  foreach(replace(what, "\t", " ")/"\n",
	  string(0..255) s)
  {
    werror("TRACE: Redirect string: %s\n", s);
    if (sscanf (s, "#virtual-include%*[ ]<%s>", string file) == 2) {
      parse_virtual_include_file(file);
    }
    else if (sscanf (s, "#include%*[ ]<%s>", string file) == 2) {
      dependencies[file] = RedirectFile(file);(({
      });
      if(string(0..255) contents = Stdio.read_bytes(file))
        parse_redirect_string(contents, file);
      else
        report_warning ("Cannot read redirect patterns from "+file+".\n");
    }
    else if (sizeof(s) && (s[0] != '#')) {
      int ret_code;
      array(string(0..255)) a = s/" " - ({""});
      if (sizeof (a) && a[0] == "permanent") {
	a = a[1..];
	ret_code = 301;
      } else
	ret_code = 302;
      // FIXME: http_encode_invalids() generates upper-case hex-escapes, but
      //        there may be verbatim lower-case escapes in the patterns.
      if(sizeof(a)>=3 && a[0]=="exact") {
	string(0..255) match_url = Roxen.http_encode_invalids(a[1]);
	string(0..255) dest_url = Roxen.http_encode_invalids(a[2]);
	if (exact_patterns[match_url])
	  report_warning ("Duplicate redirect pattern %O.\n", s);
	exact_patterns[match_url] = ({ dest_url, ret_code });
      }
      else if (sizeof(a)==2) {
	string(0..255) from_url = Roxen.http_encode_invalids(a[0]);
	string(0..255) to_url = Roxen.http_encode_invalids(a[1]);
	if (search (redirect_from, from_url) >= 0)
	  report_warning ("Duplicate redirect pattern %O.\n", s);
	redirect_from += ({ from_url });
	redirect_to += ({ to_url });
	redirect_code += ({ ret_code });
      }
      else if (sizeof (a))
	report_warning ("Invalid redirect pattern %O.\n", s);
    }
  }
  return 0;
}

roxen.BackgroundProcess file_poller_proc;

void start_poller()
{
  if (sizeof(dependencies)) {
    int poll_interval = query("poll_interval");
    int next = 0x7fffffff;
    foreach(dependencies;; RedirectFile dependency) {
      int deptime = poll_interval + dependency->time;
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
  foreach(dependencies; string fname; RedirectFile dependency) {
    Stdio.Stat stat = dependency->file_stat();
    if (!((!stat && !dependency->stat) ||
	  (stat && dependency->stat && stat->mtime == dependency->stat->mtime))) {
      // mtime for the file has changed, or it has been created or deleted
      // since last poll.
      changed = 1;
      break;
    }
    dependency->time = time(1);
    dependency->stat = stat;
  }
  if (changed) start();
  else start_poller();
}

void start()
{
  werror("TRACE: Redirect module: Running start...\n");
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
  return sprintf("Number of patterns: "
		 "%d prefix/regexp + %d exact = %d total<br />\n"
		 "Redirects so far: %d",
		 sizeof(redirect_from),sizeof(exact_patterns),
		 sizeof(redirect_from)+sizeof(exact_patterns),
		 redirs);
}


mixed first_try(object id)
{
  if(id->misc->is_redirected)
    return 0;

  string orig_url;
  string from;
  from = orig_url = Roxen.http_encode_invalids(id->not_query);
  if(id->query)
    if(sscanf(id->raw_url, "%*s?%s", string tmp))
      from += "?"+tmp;

  string to;
  int ret_code = 302;

  if (array exact_ent = exact_patterns[from])
    [to, ret_code] = exact_ent;

  else
    for (int i = 0; i < sizeof (redirect_from); i++) {
      string f = redirect_from[i];

      if(has_prefix(from, f))
      {
	to = redirect_to[i] + from[strlen(f)..];
	ret_code = redirect_code[i];
	//  Do not explicitly remove the query part of the URL.
	// sscanf(to, "%s?", to);
	break;
      }

      else if( has_value(f, "*") || has_value( f, "(") ) {
	function split;
	if(f[0] != '^') f = "^" + f;
	if(catch (split = Regexp(f)->split))
	{
	  report_error("REDIRECT: Compile error in regular expression. ("+f+")\n");
	  continue;
	}

	if(array foo = split(from)) {
	  array bar = Array.map(foo, lambda(string s, mapping f) {
				       return "$"+(f->num++);
				     }, ([ "num":1 ]));
	  foo +=({(({""}) + (id->not_query/"/" - ({""})))[-1],
		  id->not_query[1..] });
	  bar +=({ "%f", "%p" });

	  string redir_to = redirect_to[i];
	  to = replace(redir_to, (array(string)) bar, (array(string)) foo);
	  ret_code = redirect_code[i];
	  break;
	}
      }
    }

  if(!to)
    return 0;

  string url = id->url_base()[..<1];
  to = replace(to, "%u", url);
  if(to == url + orig_url
#if 0
     // The following is disabled since it can hardly ever be true. /mast
     || url == orig_url
#endif
    )
    return 0;

  id->misc->is_redirected = 1; // Prevent recursive internal redirects

  redirs++;
  if (sscanf (to, "%*[-+.a-zA-Z0-9]://%*c") == 2)
  {
    return Roxen.http_low_answer( ret_code, "")
      + ([ "extra_heads":([ "Location":Roxen.http_encode_invalids(to) ]) ]);
  } else {
    if (!id->misc->redirected_raw_url) {
      // Keep track of the original raw_url.
      id->misc->redirected_raw_url = id->raw_url;
      id->misc->redirected_not_query = id->not_query;
      // And our destination (in case of chained redirects).
      id->misc->redirected_to = to;
    }

    id->real_variables = id->misc->post_variables ?
      id->misc->post_variables + ([]) : ([]);
    id->variables = FakedVariables(id->real_variables);
    id->raw_url = to;
    id->not_query = id->scan_for_query( to );
    id->not_query = utf8_to_string(Roxen.http_decode_string(id->not_query));
  }
}
