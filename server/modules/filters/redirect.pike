// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.

// The redirect module. Redirects requests from one filename to
// another. This can be done using "internal" redirects (much like a
// symbolik link in unix), or with normal HTTP redirects.

constant cvs_version = "$Id: redirect.pike,v 1.13 1998/03/11 19:42:37 neotron Exp $";
constant thread_safe = 1;

#include <module.h>
inherit "module";
inherit "roxenlib";

private int redirs = 0;

void create()
{
  defvar("fileredirect", "", "Redirect patterns", TYPE_TEXT_FIELD, 
	 "Redirect one file to another. The syntax is 'regexp to_URL',"
	 "or 'prefix to_URL', or 'exact file_name to_URL<p>Some examples:'"
	 "<pre>"
         "/from/.*      http://to.idonex.se/to/%f\n"
         ".*\\.cgi       http://cgi.foo.bar/cgi-bin/%p\n"
	 "/thb/.*       %u/thb_gone.html\n"
	 "/roxen/     http://www.roxen.com/\n"
	 "exact / /main/index.html\n"
	 "</pre>"

	 "A %f in the 'to' field will be replaced with the filename of "
	 "the matched file, %p will be replaced with the full path, and %u"
	 "will be replaced with this server's URL (useful if you want to send "
	 "a redirect instead of doing an internal one). The last two "
	 "examples are special cases. <p>"

	 "If the first string on the line is 'exact', the filename following "
	 "must match _exactly_. This is equivalent to entering ^FILE$, but "
	 "faster. "


	 "<p>You can use '(' and ')' in the regular expression to "
	 "separate parts of the from-pattern when using regular expressions." 
	 " The parts can then be insterted into the 'to' string with " 
	 " $1, $2 etc.\n" " <p>More examples:<pre>"
	 ".*/SE/liu/lysator/(.*)\.class    /java/classes/SE/liu/lysator/$1.class\n"
	 "/(.*).en.html                   /(en)/$1.html\n"
	 "(.*)/index.html                 %u/$1/\n</pre>"
	 ""
	 "If the to file isn't an URL, the redirect will always be handled "
	 "internally, so add %u to generate an actual redirect.<p>"
	 ""
	 "<b>Note:</b> "
	 "For speed reasons: If the from pattern does _not_ contain"
	 "any '*' characters, it will not be treated like an regular"
	 "expression, instead it will be treated as a prefix that must "
	 "match exactly." ); 
}

mapping redirect_patterns = ([]);
mapping exact_patterns = ([]);

void start()
{
  array a;
  string s;
  redirect_patterns = ([]);
  exact_patterns = ([]);
  foreach(replace(QUERY(fileredirect), "\t", " ")/"\n", s)
  {
    a = s/" " - ({""});
    if(sizeof(a)>=2)
    {
      if(a[0]=="exact" && sizeof(a)>=3)
	exact_patterns[a[1]] = a[2];
      else
	redirect_patterns[a[0]] = a[1];
    }
  }
}

mixed register_module()
{
  return ({ MODULE_FIRST, 
	    "Redirect Module v2.0", 
	      "The redirect module. Redirects requests from one filename to "
	      "another. This can be done using \"internal\" redirects (much"
	      " like a symbolik link in unix), or with normal HTTP redirects.",
	      ({}), 1, });
}

string comment()
{
  return sprintf("Number of patterns: %d+%d=%d, Redirects so far: %d", 
		 sizeof(redirect_patterns),sizeof(exact_patterns),
		 sizeof(redirect_patterns)+sizeof(exact_patterns),
		 redirs);
}


mixed first_try(object id)
{
  string f, to;
  mixed tmp;

  if(id->misc->is_redirected)
    return 0;

  if(catch {
    string m;
    int ok;
    m = id->not_query;
    if(id->query)
       if(sscanf(id->raw, "%*s?%[^\n\r ]", tmp))
	  m += "?"+tmp;

    foreach(indices(exact_patterns), f)
    {
      if(m == f)
      {
	to = exact_patterns[f];
	ok=1;
	break;	
      }
    }
    if(!ok)
      foreach(indices(redirect_patterns), f)
	if(!search(m, f))
	{
	  to = redirect_patterns[f] + m[strlen(f)..];
	  sscanf(to, "%s?", to);
	  break;
	} else if(search(f, "*")!=-1) {
	  array foo;
	  function split;
	  if(f[0] != '^')
	    split = Regexp("^"+f)->split;
	  else
	    split = Regexp(f)->split;
	  
	  if((foo=split(m)))
	  {
	    array bar = Array.map(foo, lambda(string s, mapping f) {
	      return "$"+(f->num++);
	    }, ([ "num":1 ]));
	    foo +=({(id->not_query/"/"-({""}))[-1], id->not_query[1..] });
	    bar +=({ "%f", "%p" });
	    foo = Array.map(foo, lambda(mixed s) { return (string)s; });
	    bar = Array.map(bar, lambda(mixed s) { return (string)s; });
	    to = replace(redirect_patterns[f], bar, foo);
	    break;
	  }
	}
  })
    report_error("REDIRECT: Compile error in regular expression. ("+f+")\n");

  if(!to)
    return 0;
  
  string url = id->conf->query("MyWorldLocation");
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
     to=replace(to, ({ "\000", " " }), ({"%00", "%20" }));

     return http_low_answer( 302, "") 
	+ ([ "extra_heads":([ "Location":to ]) ]);
  } else {
     id->variables = ([]);
     id->raw_url = http_encode_string(to);
     id->not_query = id->scan_for_query( to );
  }
}


