// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.

// A somewhat more secure version of the normal filesystem. This
// module user regular expressions to regulate the access of files.

// Mk II changes by Henrik P Johnson <hpj@globecom.net>.

constant cvs_version = "$Id$";
constant thread_safe = 1;

#include <module.h>
inherit "modules/filesystems/filesystem";

//<locale-token project="mod_secure_fs">_</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_secure_fs",X,Y)
// end of the locale related stuff

constant module_type = MODULE_LOCATION;
LocaleString module_name = _(1,"File systems: Secure file system");
LocaleString module_doc  = 
_(2,
 "This is a file system module that allows for more fine-grained control\n"
 "over the Roxen's built-in module security. Instead of just having security\n"
 "pattern for the whole module it is possible to create several patterns.\n"
 "Glob patterns are used to decide which parts of the file system each\n"
  "pattern affects.\n"
  "\n"
  "<p>The module also supports form based authentication. The same type of\n"
  "access control can be achieved, in a different way, by using the\n"
  "<i>.htaccess support</i> module.\n");
constant module_unique = 0;

array seclevels = ({ });

#define  regexp(_) (Regexp(_)->match)

#define ALLOW 1
#define DENY 2
#define USER 3

void start()
{
  string sl;
  array new_seclevels = ({});

  foreach(replace(query("sec"),({" ","\t","\\\n"}),({"","",""}))/"\n", sl)
  {
    if(!strlen(sl) || sl[0]=='#')
      continue;
    string pat, type, value;
    if(sscanf(sl, "%s:%s=%s", pat, type, value)==3)
    {
      switch(type)
      {
      case "allowip":
	new_seclevels += ({ ({ regexp(replace(pat, ({ "?", "*", "." }),
					      ({ ".", ".*", "\." }))),
			       ALLOW, 
			       regexp(replace(value, ({ "?", ".", "*" }),
					      ({ ".", "\.", ".*" })))
	}) });
	break;

      case "denyip":
	new_seclevels += ({ ({ regexp(replace(pat, ({ "?", ".", "*" }),
					      ({ ".", "\.", ".*" }))),
			       DENY, 
			       regexp(replace(value, ({ "?", ".", "*" }),
					      ({ ".", "\.", ".*" })))
	}) });
	break;

      case "allowuser":
	new_seclevels += ({ ({ regexp(replace(pat, ({ "?", ".", "*", "," }),
					      ({ ".", "\.", ".*","|" }))),
			       USER,
			       value,
	}) });
	break;
      }
    }
  }
  seclevels = new_seclevels;
  ::start();
}

int dont_use_page()
{
  return(!query("page"));
}

void create()
{
  defvar("sec", 
	 "# Only allow from localhost, or persons with a valid account\n"
	 "*:  allow ip=127.0.0.1\n"
	 "*:  allow user=any\n",
	 _(3,"Security patterns"),

	 TYPE_TEXT_FIELD|VAR_INITIAL,

	 (0,"This is the security pattern list, which follows the format"
	 "<br><tt>files: security pattern</tt><p>"
	 "Each <i>security pattern</i> can be any from this list:<br>"
	 "<hr noshade>"
	 "allow ip=pattern<br>"
	 "deny ip=pattern<br>"
	 "allow user=user name,...<br>"
	 "<hr noshade>"
	 "<i>Files</i> are a glob pattern matching the files of the file "
	 "system that will be affected by the security pattern. '*' will "
	 "match one or more characters, '?' will match one character."));

  defvar("page", 0, _(4,"Use form authentication"), TYPE_FLAG,
         (0,"If set it will produce a page containing a login form instead "
	  "of sending a HTTP authentication needed header."), 0 );
  defvar("expire", 60*15, (0,"Authentication expire time"),
         TYPE_INT,
         _(5,"New authentication will be required if no page has been "
	  "requested within this time, in seconds."),
         0, dont_use_page);
  defvar("authpage",
	 "<HTML><HEAD><TITLE>Authentication needed</TITLE></HEAD><BODY>\n"
         "<FORM METHOD=post ACTION=$File>\n"
         "<INPUT NAME=httpuser><P>\n"
         "<INPUT NAME=httppass TYPE=password><P>\n"
         "<INPUT TYPE=submit VALUE=Authenticate>\n"
         "</FORM>\n"
         "</BODY></HTML>",
         _(6,"Form authentication page."),
         TYPE_TEXT_FIELD,
         _(7,"Should contain an form with input fields named <i>httpuser</i> "
	   "and <i>httppass</i>. "
	   "The string $File will be replaced with the URL to the current "
	   "page being accessed and "
	   "$Me with the URL to the site."),
         0, dont_use_page);

  ::create();
}

mixed not_allowed(string f, object id)
{
  array level;
  int need_auth;
  
  if(id->remoteaddr == "internal") return 0;

  foreach(seclevels, level)
  {
    if(level[0](f)) // The pattern match for this filename...
      switch(level[1])
      {
       case ALLOW: // allow ip=...
	 if(level[2](id->remoteaddr))
	   return 0; // Match. It's ok.
	 break;
	
       case DENY:  // deny ip=...
	// If match, this IP-number will never be permitted access. No need to
	// check any more. User and allow patterns are always checked first.
	 if(level[2](id->remoteaddr))
	   return http_low_answer(403, "<h2>Access forbidden</h2>"); 
	 break;
	
	
       case USER:  // allow user=...
	 string uname;
	 need_auth = 1;
	 if (query("page") && id->cookies["httpauth"]) {
	   string user,pass,last;
	   array(string) y=({ "","" });
	   sscanf(id->cookies["httpauth"],"%s:%s:%s", user, pass, last);
	   y[1]=user+":"+pass;
	   id->auth=id->conf->auth_module->auth(y,id);
	 }

	 if(!(id->auth && id->auth[0])) {
	   if(query("page")) {
	     return http_low_answer(200,
				    replace(Roxen.parse_rxml(query("authpage"), id),
					    ({"$File", "$Me"}), 
					    ({id->not_query,
					      id->conf->query("MyWorldLocation")})));

	   } else {
	     return Roxen.http_auth_required("user", 0, id);
	   }
	 }
	 foreach(level[2]/",", uname) {
	   if((id->auth[1]==uname) || (uname=="any") || (uname=="*")) {
	     return 0;
	   }
	 }
	 break;
      }
  }
  if(need_auth) {
    if(query("page")) {
      return http_low_answer(200,
			     replace(Roxen.parse_rxml(query("authpage"), id),
				     ({"$File", "$Me"}), 
				     ({id->not_query,
				       id->conf->query("MyWorldLocation")})));
    } else {
      return Roxen.http_auth_required("user", 0 , id);
    }
  }
  return  1;
}


// Overlay the normal find_file function, that's all this module has to do.
mixed find_file(string f, object id)
{
  mixed tmp, tmp2;
  string user,pass;

  if (query("page")) {
    int last;
    if (stringp(id->cookies["httpauth"])) {
      sscanf(id->cookies["httpauth"],"%s:%s:%d", user, pass, last);
    } else if (id->cookies["httpauth"]) {
      report_warning(sprintf("secure_fs: find_file():\n"
			     "Unexpected value for cookie \"httpauth\":\n"
			     "%O\n",
			     id->cookies["httpauth"]));
    }
    if(!last || (last+query("expire") < time(1)))
      m_delete(id->cookies,"httpauth");
    if(id->variables["httpuser"]&&id->variables["httppass"])
      id->cookies["httpauth"]=sprintf("%s:%s:%d", id->variables["httpuser"],
				      id->variables["httppass"], time(1));
  }

  if(tmp2=::find_file(f, id))
    if(tmp=not_allowed(f, id))
      return intp(tmp)?0:tmp;

  if (intp(tmp2) || !query("page") || !id->cookies["httpauth"])
    return tmp2;

  if (!id->misc->moreheads) id->misc->moreheads = ([]);
  id->misc->moreheads["Set-Cookie"] =
    "httpauth="+
    Roxen.http_encode_cookie(sprintf("%s:%s:%d", user||"", pass||"", time(1)))+
    "; path=/";
  return tmp2;
}
