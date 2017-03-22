// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.

// This module redirects requests to different places, depending on the
// hostname that was used to access the server. It can be used as a
// cheap way (IP number wise) to do virtual hosting. Note that this
// won't work with all clients.

// responsible for the changes to the original version 1.3: Martin Baehr mbaehr@iaeste.or.at

constant cvs_version = "$Id$";
constant thread_safe=1;

inherit "module";
#include <module.h>

#ifdef HOSTREDIRECT_DEBUG
#define dwerror(ARGS...) werror(ARGS)
#else
#define dwerror(ARGS...) 0
#endif

void create()
{
  defvar("hostredirect", "", "Redirect rules", TYPE_TEXT_FIELD,
         "Syntax:<pre>"
         "    <i>domain path</i></pre>"
         "<strong>Examples:</strong><pre>"
         "    ab.domain.com     /ab/\n"
         "    bc.domain.com     /bc/\n"
         "    main.domain.com   /\n"
         "    default           /serverlist.html</pre>"
         "<p>If someone access the server at http://ab.domain.com/text.html, "
         "it will be internally redirected to http://ab.domain.com/ab/text.html. "
         "If someone accesses http://bc.domain.com/bc/text.html, the URL "
         "won't be modified. The <tt>default</tt> line is a special case "
         "which points on a file which is used when no hosts match. It is "
         "very recommended that this file contains a list of all the "
         "servers, with correct URL's. If someone visits with a client "
         "that doesn't send the <tt>host</tt> header, the module won't "
         "do anything at all.</p>\n"
         "v2 also allows the following syntax for HTTP redirects:<pre>"
         "    <tt>[permanent]</tt> <i>domain</i> <i>target</i>\n</pre>"
         "<strong>Examples:</strong><pre>"
         "    permanent domain.com       www.domain.com\n"
         "              ab.domain.org    http://my.university.edu/~me/ab/%p\n"
         "              bc.domain.com    %u/bc/%p%q\n"
         "              default          %u/serverlist.html</pre>"
	 "<p><strong>There are several patterns that can be used "
	 "in the 'target' field:</strong></p>\n"
	 "<dl>\n"
	 "<dh><tt>%p</tt> (Path)</dh>\n"
         "<dd>A <tt>%p</tt> in the 'target' field will be replaced with the full "
         "path of the request.</dd>\n"
	 "<dh><tt>%q</tt> (Query)</dh>\n"
	 "<dd>A <tt>%q</tt> in the 'target' field will be replaced with the "
	 "query string (if any). Note that the query string will be prepended "
	 "with <tt>?</tt> if there's no <tt>?</tt> earlier in the 'target' "
	 "field, and with <tt>&amp;</tt> otherwise. Note also that for "
	 "internal redirects the query variables are passed along to "
	 "the redirect target without any need to use <tt>%q</tt>.</dd>\n"
	 "<dh><tt>%u</tt> (URL)</dh>\n"
	 "<dd>A <tt>%u</tt> in the 'target' field will be replaced with this "
	 "server's URL (useful if you want to send an external redirect "
	 "instead of doing an internal one).</dd>\n"
	 "</dl>\n"
         "<p>If the first string on the line is 'permanent', the http return "
         "code is 301 (moved permanently) instead of 302 (found).</p> "
         "<p>Internal redirects will always have the path and query variables "
	 "added, whether you use <tt>%p</tt> and/or <tt>%q</tt> or not. "
	 "However for HTTP redirects <tt>%p</tt> and/or <tt>%q</tt> are "
	 "mandatory if you want to propagate the path and/or query variables "
	 "respectively. <strong><tt>default</tt> will never add a path, "
	 "even if <tt>%p</tt> is present.</strong> "
         "In fact if <tt>%p</tt> is included it will "
         "just stay and probably not produce the expected result.</p>"
       );
  
  defvar("ignorepaths",
	 Variable.StringList( ({ "/_internal/", "/__internal/", "/internal-roxen-",
				 "/roxen-files/", "/edit", "/__ie/", "/yui/",
			      }), 0, "Ignore paths",
			      "A list of path prefixes that should not be redirected. "
			      "Useful for making global images work in sub sites." ));
  defvar("ignorevariables",
	 Variable.StringList( ({ "__force_path", "__sb_force_login" }),
			      0, "Ignore form variables",
			      "A list of form variables. If one of the form variables "
			      "is set, the request will not be redirected."
			      "Useful for making login redirects to / work in sub "
			      "sites." ));
}

mapping patterns = ([ ]);
mapping(string:int) rcode = ([ ]);

void start(Configuration conf)
{
  array a;
  string s;
  patterns = ([]);
  rcode = ([ ]);
  foreach(replace(query("hostredirect"), "\t", " ")/"\n", s)
  {
    int ret_code = 302;
    a = s/" " - ({""});
    if ( sizeof(a) && a[0]=="permanent" ) {
      ret_code = 301;
      a = a[1..];
    }
    if(sizeof(a)>=2) {
      //if(a[1][0] != '/')  //this can now only be done if we
      //  a[1] = "/"+ a[1]; // don't have a HTTP redirect
      //if(a[0] != "default" && strlen(a[1]) > 1 && a[1][-1] == '/')
      //  a[1] = a[1][0..strlen(a[1])-2];
      patterns[lower_case(a[0])] = a[1];
      rcode[lower_case(a[0])] = ret_code;
    }
  }
}

constant module_type = MODULE_FIRST;
constant module_name = "Host Redirect, v2";
constant module_doc  = "This module redirects requests to different places, "
  "depending on the hostname that was used to access the "
  "server. It can be used as a cheap way (IP number wise) "
  "to do virtual hosting. <i>Note that this won't work with "
  "all clients.</i>"
  "<p>v2 now also allows HTTP redirects (302 as well as 301).</p>";

string get_host(string ignored, RequestID id)
{
  string host;
  if(!((id->misc->host && (host = lower_case(id->misc->host))) ||
       (id->my_fd && id->my_fd->query_address &&
	(host = replace(id->my_fd->query_address(1)," ",":")))))
    return 0;

  host = (host / ":")[0];  // Remove port number
  host = (host / "\0")[0]; // Spoof protection.
  dwerror("HR: get_host: %O\n", host);
  return host;
}

string get_protocol(string ignored, RequestID id)
{
  string prot = lower_case((id->prot/"/")[0]);
  // Check if the request is done via https.
  if(id->my_fd && id->my_fd->get_peer_certificate_info &&
     id->my_fd->query_connection())
    prot = "https";
  dwerror("HR: get_protocol: %O\n", prot);
  return prot;
}

string get_port(string ignored, RequestID id)
{
  string port = id->my_fd && id->my_fd->query_address &&
		(id->my_fd->query_address(1) / " ")[1];
  
  dwerror("HR: host_port: %O\n", port);
  return port;
}

int|mapping first_try(RequestID id)
{
  string host, to;
  int path=0, stripped=0, return_code = 302;

  if(id->misc->host_redirected || !sizeof(patterns) ||
     !has_prefix(lower_case(id->prot), "http"))
  {
    return 0;
  }

  dwerror("HR: %O\n", id->not_query);
  foreach(query("ignorepaths"), string path) {
    dwerror("  IP: %O, %O, [%O]\n", id->not_query, path,
	    has_prefix(id->not_query, path));
    if(has_prefix(id->not_query, path))
      return 0;
  }
  
  foreach(query("ignorevariables"), string var) {
    dwerror("  IP: %O, %O, [%O]\n", id->not_query, var, id->variables[var]);
    if(id->variables[var])
      return 0;
  }

  // We look at the host header...
  id->register_vary_callback("host", get_host);

  if (!(host = get_host(0, id))) return 0;

  if(!patterns[host])
    host = "default";

  to = patterns[host];
  if(!to) {
    //    if(patterns["default"])
    //  id->not_query = patterns["default"];
    //since "default" can also have a HTTP
    //redirect we don't get away that easy
    return 0;
  }
  if(host=="default")
  {
    if((id->referrer) && (sizeof(id->referrer)) &&
       search(id->referer[0],
	      lower_case((id->prot /"/")[0])+"://"+id->misc->host) == 0) {
      return 0;
    }
    // this is some magic here: in order to allow pictures in the defaultpage
    // they need to be referenced beginning with the same url
    // as the redirection:
    // thus if we redirect default to /servers/ pictures must be referenced as
    // /servers/...
    // respetively if we redirect to /servers.html, pictures would have to
    // be referenced with /servers.html... which obviously doesn't work
    // to get around this restriction we could compare the
    // protocoll://host:port of the referer
    // with the ones of this request, and then assume that the referer
    // has already been redirected, which eliminates the need to redirect
    // this as well
    // however i don't know if this may bring up other problems,
    // this doesn't work if the client doesn't send a referer
    // and also i don't know how to handle multiple referers
    // so we might be better off forcing the administrators to have a
    // directory with an automatically loaded index-file as the default
    // redirection anyway
  }

  string url = id->conf->query("MyWorldLocation");
  url=url[..strlen(url)-2];
  to = replace(to, "%u", url);
  return_code = rcode[host];

  string to_prefix = (to/"%p")[0];

  if((host != "default") && (search(to, "%p") != -1))
  {
    to = replace(to, "/%p", "%p");   // maybe there is a better way
    if (id->not_query[-1] == '/')    // to remove double slashes
      to = replace(to, "%p/", "%p"); //

    to = replace(to, "%p", id->not_query);
    path = 1;
  }

  array(string) segments = to/"%q";
  if (sizeof(segments) > 1) {
    if (sizeof(id->query || "")) {
      foreach(segments[..<1]; int i; string seg) {
	if (i || has_value(seg, "?")) {
	  segments[i] += "&";
	} else {
	  segments[i] += "?";
	}
      }
    }
    to = segments * (id->query || "");
  }

  if((strlen(to) > 6 &&
      (to[3]==':' || to[4]==':' ||
       to[5]==':' || to[6]==':')))
  {
    // HTTP redirect
    // We look at the protocol (host header)...
    id->register_vary_callback("host", get_protocol);
    // We look at the port (host header)...
    id->register_vary_callback("host", get_port);
    catch {  // The catch is needed to make sure the url parsing don't backtrace.
      Standards.URI to_uri = Standards.URI(to_prefix);
      Standards.URI cur_uri =
	Standards.URI(get_protocol(0, id)+"://"+id->misc->host+id->not_query);
      
      // Don't redirect if the prot/host/port is the same and the
      // beginning of the path is already correct.
      if(has_prefix(cur_uri->path, to_uri->path) &&
	 cur_uri->scheme == to_uri->scheme &&
	 cur_uri->host == to_uri->host &&
	 cur_uri->port == to_uri->port)
      {
	return 0;
      }
    };
    to = Roxen.http_encode_invalids(to);
    dwerror("HR: %O -> %O (http redirect)\n", id->not_query, to);
    return Roxen.http_low_answer( return_code,
				  "See <a href='"+to+"'>"+to+"</a>")
      + ([ "extra_heads":([ "Location":to,  ]) ]);
  } else {
    // Internal redirect

    if(has_prefix(id->not_query, to_prefix)) {
      // Already have the correct beginning...
      return 0;
    }

    //  if the default file contains images, they will not be found,
    //  because they will be redirected just like the original request
    //  without id->not_query. maybe it's possible to check the referer
    //  and if it matches patterns["default"] add the id->not_query after all.
    if(to[0] != '/')
      to = "/"+ to;
    if((host != "default") && !path && strlen(to) > 1 && to[-1] == '/')
      to = to[0..strlen(to)-2];
    if((host != "default") && !path )
      to +=id->not_query;

    dwerror("HR: %O -> %O (internal redirect)\n", id->not_query, to);
    
    id->misc->host_redirected = 1;
    if (!id->misc->redirected_raw_url) {
      id->misc->redirected_raw_url = id->raw_url;
      id->misc->redirected_not_query = id->not_query;
    }
    id->not_query = id->scan_for_query( to );
    id->raw_url = Roxen.http_encode_invalids(to);
    //if we internally redirect to the proxy,
    //the proxy checks the raw_url for the place toget,
    //so we have to update the raw_url here too, or
    //we need to patch the proxy-module
    return 0;
  }
}
