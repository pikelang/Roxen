
// This is a roxen module. (c) Informationsvävarna AB 1996.

// This module redirects requests to different places, depending on the
// hostname that was used to access the server. It can be used as a
// cheap way (IP number wise) to do virtual hosting. Note that this
// won't work with all clients.

// responsible for the changes to the original version 1.3: Martin Baehr mbaehr@iaeste.or.at

constant cvs_version = "$Id: hostredirect.pike,v 1.13 1997/08/31 04:12:40 peter Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "roxenlib";

//#define HOSTREDIRECT_DEBUG
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
         "won't be modified. The <tt>default</tt> line is a special case "
         "which points on a file which is used when no hosts match. It is "
         "very recommended that this file contains a list of all the "
         "servers, with correct URL's. If someone visits with a client "
         "that doesn't send the <tt>host</tt> header, the module won't "
         "do anything at all.<p>\n"
         "v2 also allows the following syntax for HTTP redirects:<pre>"
         "    ab.domain.org             http://my.university.edu/~me/ab/%p\n"
         "    bc.domain.com             %u/bc/%p\n"
         "    default                   %u/serverlist.html</pre>"
         "A <tt>%p</tt> in the 'to' field will be replaced with the full "
         "path, and <tt>%u</tt> will be replaced with this server's URL "
         "(useful if you want to send a redirect instead of doing an "
         "internal one).<p>\n"
         "Internal redirects will always have the path added, whether you "
         "use <tt>%p</tt> or not. however for HTTP redirects <tt>%p</tt> "
         "is mandatory if you want the path. <strong><tt>default</tt> "
         "will never add a path, even if <tt>%p</tt> is present"
         ".</strong> in fact if <tt>%p</tt> is included it will "
         "just stay and probably not produce the expected result."
       );
}

mapping patterns = ([ /* empty */ ]);

void start()
{
  array a;
  string s;
  patterns = ([]);
  foreach(replace(QUERY(hostredirect), "\t", " ")/"\n", s)
  {
    a = s/" " - ({""});
    if(sizeof(a)>=2) {
      //if(a[1][0] != '/')  //this can now only be done if we
      //  a[1] = "/"+ a[1]; // don't have a HTTP redirect
      //if(a[0] != "default" && strlen(a[1]) > 1 && a[1][-1] == '/')
      //  a[1] = a[1][0..strlen(a[1])-2];
      patterns[lower_case(a[0])] = a[1];
#ifdef HOSTREDIRECT_DEBUG
      perror("hostredirect: "+a[0]+" -> "+a[1]+"\n");
#endif      
    }
  }
}

mixed register_module()
{
  return ({ MODULE_FIRST, 
            "Host Redirect, v2", 
            ("This module redirects requests to different places, "
             "depending on the hostname that was used to access the " 
             "server. It can be used as a cheap way (IP number wise) "
             "to do virtual hosting. <i>Note that this won't work with "
             "all clients.</i><p>"
             "v2 now also allows HTTP redirects"), 
              ({}), 1, });
}

string comment()
{
  return "No comments!";
}

mixed first_try(object id)
{
#ifdef HOSTREDIRECT_DEBUG
  perror("_________________________________________________\n");
  perror(sprintf("raw_url: %O\n", id->raw_url));
#endif     
  string host, to;
  int path =0, stripped=0;

  if(id->misc->host_redirected || !sizeof(patterns))
  {
#ifdef HOSTREDIRECT_DEBUG
    perror("redirected\n");
#endif     
    return 0;
  }  

  id->misc->host_redirected = 1;
  if(!((id->misc->host && (host = lower_case(id->misc->host))) ||
       (id->my_fd && (host = replace(id->my_fd->query_address(1)," ",":")))))
    return 0;
  
  host = (host / ":")[0]; // Remove port number
  
  if(!patterns[host])
  {
    host = "default";
  }
  to = patterns[host];
  if(!to) {
    //    if(patterns["default"])
    //since "default" can also have a HTTP
    //  id->not_query = patterns["default"];
    //redirect we don't get away that easy
    return 0;
  }
  if(host=="default")
  {
#ifdef HOSTREDIRECT_DEBUG
    perror("thesearch: %d\n", 
	   search(id->referer[0], 
		  lower_case((id->prot / "/")[0])+"://"+id->misc->host));
    perror(sprintf("referer: %O\nhost: %O\nraw: %O\nurl: %O\n", id->referer, 
		   id->misc->host, id->raw, 
		   lower_case((id->prot /"/")[0])+"://"+id->misc->host));  
#endif     
    if((!id->referrer) || (!sizeof(id->referrer)) ||
       search(id->referer[0],
	      lower_case((id->prot /"/")[0])+"://"+id->misc->host) == 0)
      return 0;
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
#ifdef HOSTREDIRECT_DEBUG
    perror(to+"\n");
#endif     
  string url = id->conf->query("MyWorldLocation");
  url=url[..strlen(url)-2];
  to = replace(to, "%u", url);
#ifdef HOSTREDIRECT_DEBUG
    perror("%u:"+to+"\n");
#endif     


  if((host != "default") && (search(to, "%p") != -1))
  {
    to = replace(to, "/%p", "%p");   // maybe there is a better way
    if (id->not_query[-1] == '/')    // to remove double slashes
      to = replace(to, "%p/", "%p"); // 

    to = replace(to, "%p", id->not_query);
    path = 1;
#ifdef HOSTREDIRECT_DEBUG
        perror("replacing %p\n");
#endif     
  }
  
#ifdef HOSTREDIRECT_DEBUG
  perror("search: id->not_query: "+id->not_query+"\n");
#endif     
  if(search(id->not_query, to) == 0) {
    // Already have the correct beginning...
    return 0;
  }

  if((strlen(to) > 6 && 
      (to[3]==':' || to[4]==':' || 
       to[5]==':' || to[6]==':')))
  {
     to=replace(to, ({ "\000", " " }), ({"%00", "%20" }));
#ifdef HOSTREDIRECT_DEBUG
          perror("return:"+to+"\n");
#endif     
     return http_low_answer( 302, "") 
        + ([ "extra_heads":([ "Location":to ]) ]);
  } else {
#ifdef HOSTREDIRECT_DEBUG
    //    perror("search: %d\n", search(id->referer[0],lower_case((id->prot / "/")[0])+"://"+id->misc->host));
    perror(sprintf("referer: %O\nhost: %O\nprotokoll: %O\nurl: %O\n",
		   id->referer, id->misc->host, id->prot, 
		   lower_case((id->prot /"/")[0])+"://"+id->misc->host));  
#endif     
    //  if the default file contains images, they will not be found, 
    //  because they will be redirected just like the original request
    //  without id->not_query. maybe it's possible to check the referer
    //  and if it matches patterns["default"] add the id->not_query after all.
    if(to[0] != '/')
      to = "/"+ to; 
    if(host != "default" && strlen(to) > 1 && to[-1] == '/')
      to = to[0..strlen(to)-2];
    if((host != "default") && !path )
      to +=id->not_query;

    id->not_query = id->scan_for_query( to );
    id->raw_url = http_encode_string(to);
    //if we internally redirect to the proxy, 
    //the proxy checks the raw_url for the place toget, 
    //so we have to update the raw_url here too, or 
    //we need to patch the proxy-module
    return 0;
  }
}
