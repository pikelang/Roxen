#include <module.h>
#include <roxen.h>

inherit "module";
inherit "roxenlib";

constant cvs_version="$Id: autoreg.pike,v 1.3 1998/09/21 15:45:00 js Exp $";


mapping engines =
  ([ "Altavista": ([ "host":"add-url.altavista.digital.com",
		     "path":"/cgi-bin/newurl",
		     "vars": ([ "ad":"1" ]),
		     "url_var":"q" ]),
     "Infoseek":  ([ "host":"www.infoseek.com",
		     "path":"/AddURL/addurl",
		     "vars": ([ "sv":"IS",
				"lk":"ip-noframes",
				"nh":"10", 
				"pg":"URL.html",
				"CAT":"Add/Update URL" ]),
		     "url_var":"url" ]),
     "Hotbot":    ([ "host":"www.hotbot.com",
		     "path":"/addurl.asp",
		     "vars": ([ "MM":"1",
				"success_page":"http://www.hotbot.com/addurl.asp",
				"failure_page":"http://www.hotbot.com/oops.asp",
				"ACTION":"subscribe",
				"SOURCE":"hotbot",
				"ip":"194.52.182.125",
				"redirect":"http://www.hotbot.com/addurl2.html",
				"email":"autoreg@idonex.se" ]),
		     "url_var":"newurl" ]),
     "Webcrawler":([ "host":"webcrawler.com",
		     "path":"/cgi-bin/addURL.cgi",
		     "vars": (["action":"add"]),
		     "url_var":"url" ]), // METHOD=POST
     "Lycos":     ([ "host":"www.lycos.com",
		     "path":"/cgi-bin/spider_now.pl",
		     "vars": (["email":"autoreg@idonex.se"]),
		     "url_var":"query" ]),
  ]);
			      
			      
array register_module()
{
  return ({ MODULE_PARSER,
	    "AutoReg",
	    "" });
}

void connect_and_send_query(string host, string path)
{
  object o=Stdio.File();
  werror(host+": "+path+"\n");
  o->connect(host,80);
  o->write("GET "+path+" HTTP/1.0\r\n\r\n");
//  Stdio.write_file("/home/js/AutoSite/"+host+".html",o->read());
  o->close();
}

string tag_register(string tag_name, mapping args, object id)
{
  foreach(indices(engines), string engine)
  {
    string rest="?";
    foreach(indices(engines[engine]->vars),string var)
      rest+=http_encode_string(var)+"="+http_encode_string(engines[engine]->vars[var])+"&";
    rest+=http_encode_string(engines[engine]->url_var)+"="+
      http_encode_string(args->url);
    thread_create(connect_and_send_query,engines[engine]->host,engines[engine]->path+rest);
  }
  return "<b>Registered: "+sort(indices(engines))*", "+".</b>";
}
  

mapping query_tag_callers()
{
  return ([ "autoreg-register-url" : tag_register ]);
}
