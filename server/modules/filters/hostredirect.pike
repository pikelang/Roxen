// This is a roxen module. (c) Informationsvävarna AB 1996.

// This module redirects requests to different places, depending on the
// hostname that was used to access the server. It can be used as a
// cheap way (IP number wise) to do virtual hosting. Note that this
// won't work with all clients.

string cvs_version = "$Id: hostredirect.pike,v 1.4 1996/12/19 10:17:02 neotron Exp $";
#include <module.h>
inherit "module";
inherit "roxenlib";

void create()
{
  defvar("hostredirect", "", "Redirect rules", TYPE_TEXT_FIELD, 
	 "Syntax:<pre>"
         "    ab.domain.com             /ab/\n"
         "    bc.domain.com             /bc/\n"
         "    main.domain.com           /\n"
         "    default                   /serverlist.html</pre>"
	 "If someone access the server at http://ab.domain.com/text.html, "
	 "it will be internally redirected to http://ab.domain.com/ab/text.html. "
	 "If someone accesses http://bc.domain.com/bc/text.html, the URL "
	 "won't be modified. The <tt>default</tt> line is a special case which points "
	 "on a file which is used when no hosts match. It is very recommended that this file "
	 "contains a list of all the servers, with correct URL's. If someone visits "
	 "with a client that doesn't send the <tt>host</tt> header, the module won't "
	 "do anything at all.");
}
mapping patterns = ([]);

void start()
{
  array a;
  string s;
  patterns = ([]);
  foreach(replace(QUERY(hostredirect), "\t", " ")/"\n", s)
  {
    a = s/" " - ({""});
    if(sizeof(a)>=2) {
      if(a[1][0] != '/')
	a[1] = "/"+ a[1];
      if(a[0] != "default" && strlen(a[1]) > 1 && a[1][-1] == '/')
	a[1] = a[1][0..strlen(a[1])-2];
      patterns[lower_case(a[0])] = a[1];
      
    }
  }
}

mixed register_module()
{
  return ({ MODULE_FIRST, 
	    "Host Redirect", 
	    ("This module redirects requests to different places, "
             "depending on the hostname that was used to access the " 
             "server. It can be used as a cheap way (IP number wise) "
             "to do virtual hosting. <i>Note that this won't work with "
             "all clients.</i>"), 
	      ({}), 1, });
}

string comment()
{
  return "No comments!";
}

mixed first_try(object id)
{
  string host;

  if(id->misc->host_redirected || !sizeof(patterns))
    return 0;
  
  id->misc->host_redirected = 1;
  if(!(host = id->misc->host) ||
     (host = replace(id->my_fd->query_address(1)," ",":")))
    return 0;
  
  host = lower_case((host / ":")[0]); // Remove port number
  
  if(!patterns[host]) {
    if(patterns["default"]) 
      id->not_query = patterns["default"];
    return 0;
  }

  if(search(id->not_query, patterns[host]) == 0) {
    // Already have the correct beginning...
    return 0;
  }
  id->not_query = patterns[host]+ id->not_query;
  return 0;
}
