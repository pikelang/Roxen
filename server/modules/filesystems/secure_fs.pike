// This is a roxen module. (c) Informationsvävarna AB 1996.

// A somewhat more secure version of the normal filesystem. This
// module user regular expressions to regulate the access of files.

constant cvs_version = "$Id: secure_fs.pike,v 1.7 1997/08/31 03:47:21 peter Exp $";
constant thread_safe=1;

#include <module.h>
inherit "filesystem";

array register_module()
{
  return ({ MODULE_LOCATION,
	    "Secure file system module",
	    "This is a (somewhat) more secure filesystem module. It "
            "allows an per-regexp level security." });
}

array seclevels = ({ });

#define  regexp(_) (Regexp(_)->match)

#define ALLOW 1
#define DENY 2
#define USER 3

void start()
{
  string sl, sec;
  array ips=({ }), users=({ }), denys=({});

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
	ips += ({ ({ regexp(replace(pat, ({ "?", "*", "." }),
				       ({ ".", ".*", "\." }))),
			ALLOW, 
			regexp(replace(value, ({ "?", ".", "*" }),
				       ({ ".", "\.", ".*" })))
			}) });
	break;

       case "denyip":
	denys += ({ ({ regexp(replace(pat, ({ "?", ".", "*" }),
				       ({ ".", "\.", ".*" }))),
			DENY, 
			regexp(replace(value, ({ "?", ".", "*" }),
				       ({ ".", "\.", ".*" })))
			}) });
	break;

       case "allowuser":
	users += ({ ({ regexp(replace(pat, ({ "?", ".", "*", "," }),
				       ({ ".", "\.", ".*","|" }))),
			USER,
			value,
		      }) });
	break;
      }
    }
  }
  seclevels = ips+users+denys;
  ::start();
}

void create()
{
  defvar("sec", 

	 "# Only allow from local host, or persons with a valid account\n"
	 "*:  allow ip=127.0.0.1\n"
	 "*:  allow user=any\n",
	 "Security patterns",

	 TYPE_TEXT_FIELD,

	 "This is the 'pattern: security level=value' list.<br>"
	 "Each security level can be any or more from this list:<br>"
	 "<hr noshade>"
	 "allow ip=pattern<br>"
	 "deny ip=pattern<br>"
	 "allow user=username,...<br>"
	 "<hr noshade>"
	 "In patterns: * is on or more characters, ? is one character.<p>");
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
	 if(!(id->auth && id->auth[0]))
	   return http_auth_failed("user");
	 foreach(level[2]/",", uname)
	   if((id->auth[1]==uname) || (uname=="any") || (uname=="*"))
	     return 0;
	 break;
      }
  }
  if(need_auth)
    return http_auth_failed("user");
  return  1;
}


// Overlay the normal find_file function, that's all this module has to do.
mixed find_file(string f, object id)
{
  mixed tmp, tmp2;
  if(tmp2=::find_file(f, id))
    if(tmp=not_allowed(f, id))
      return intp(tmp)?0:tmp;
  return tmp2;
}



