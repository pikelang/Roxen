// This is a roxen module. (c) Informationsvävarna AB 1996.

// .htaccess compability by David Hedbor, neotron@infovav.se 
//   Changed into module by Per Hedbor, per@infovav.se

string cvs_version = "$Id: htaccess.pike,v 1.7.2.1 1997/03/02 19:23:33 grubba Exp $";
#include <module.h>
inherit "module";
inherit "roxenlib";

import Stdio;

/*#define HTACCESS_DEBUG*/


array *register_module()
{
  return ({ MODULE_SECURITY|MODULE_LAST|MODULE_FIRST, ".htaccess support", 
	      "Almost complete support for NCSA/Apache .htaccess files. See "
	      "<a href=http://hoohoo.ncsa.uiuc.edu/docs/setup/access/Overview.html>http://hoohoo.ncsa.uiuc.edu/docs/setup/access/Overview.html</a> for more information.",
	      ({}), 1 });
}

void create()
{
  defvar("cache_all", 1, "Cache the failures",
	 TYPE_FLAG,
	 "If set, cache failures to find a .htaccess file as well as found "
	 "ones. This will limit the number of stat(2) calls quite dramatically."
	 " This should be set if you have a busy site! It does have at least "
	 " one disadvantage: The user have to press reload to get the new "
	 ".htaccess file parsed."
#ifndef SERIOUS
	 " Since the poor user is quite used to reloading,"
	 " that is not usually a problem. Just blame the client-side cache. "
	 ":-)"
#endif
    );
}


/* Parse the 'limit' tag. This function is called via the builtin
 * SGML parser. 
 */

string parse_limit(string tag, mapping m, string s, mapping id, mapping access)
{
  string line, tmp, ent, item;
  mixed data;
  mapping tmpmap = ([]);
  if(!sizeof(m))
    m = ([ "all": 1 ]);
  
  foreach(s / "\n", line)
  {
    tmp = 0;

    line = (replace(line, "\t", " ") / " " - ({""})) * " ";

    if(!strlen(line))
      continue;

    if(line[0] == ' ') /* There can be only one */
      line = line[1..];

    if(sscanf(line, "deny from %s", data))
      tmp = "deny";
    else if(sscanf(line, "allow from %s", data))
      tmp = "allow";
    else if(sscanf(line, "require %s %s", ent, data) == 2)
      tmp = ent;
    else if(sscanf(line, "satisfy %s", data))
    {
      tmp = "all";
      if(data == "all")
	data = 1;
      else
	data = -1;
    } else if(!search(line, "require valid-user")) {
      tmp = "valid-user";
      data = 1;
    }
    if(sscanf(line, "order %s", data))
    {
      data = replace(data, " ", "");
      if(!search(data, "allow"))
	data = 1;
      else if(!search(data, "mutual-failure"))
	data = -1;
      else 
      	data = 0;
      tmpmap->order = data;
    } else if(tmp)
      if(stringp(data))
	foreach(data / " ", item)
	{
	  if(strlen(item))
	  {
	    if(!multisetp(tmpmap[tmp]))
	      tmpmap[ tmp ] = (<>);
	    tmpmap[ tmp ] += (< item >);
	  }
	}
      else
	tmpmap[tmp] = data;
  }
  if(!tmpmap->all)
    tmpmap->all = 1;

  foreach(indices(m), tmp)
    if(!access[tmp])
      access[tmp] = tmpmap;
    else 
      foreach(indices(tmpmap), data)
	if(access[tmp][data])
	  access[tmp][data] += tmpmap[data];
	else
	  access[tmp][data] = tmpmap[data];
  return "";
}

/* parse the .htaccess file */
mapping|int parse_htaccess(object f, object id, string rht)
{
  string htaccess, line;
  string cache_key;
  int *s;
  mixed in_cache;
  mapping access = ([ ]);
  cache_key = "htaccess:" + id->conf->name;
    

  s = (int *)f->stat();

  if((in_cache = cache_lookup(cache_key, rht)) && (s[3] == in_cache[0]))
    return in_cache[1];

  htaccess = f->read(0x7fffffff);
  
  if(!htaccess || !strlen(htaccess))
    return 0;

  htaccess = replace(htaccess, "\\\n", " ");

  access = ([]); 

  htaccess = parse_html(htaccess, ([]), (["limit": parse_limit ]), id, access);

  foreach(htaccess / "\n"-({""}), line)
  {
    string cmd, rest;

    if(line[0] == "#")
      continue;

    line = (replace(line, "\t", " ") / " " - ({""})) * " ";

    if(!strlen(line))
      continue;
    
    if(line[0]==' ')
      line=line[1..];

    sscanf(line, "%[^ ] %s", cmd, rest);

    cmd = lower_case(cmd);    

    switch(cmd)
    {
     case "redirecttemp":
     case "redirecttemporary":
     case "redirectperm":
     case "redirectpermanent":
      cmd = "redirect";

     case "authuserfile":
     case "authname":
     case "authgroupfile":
     case "redirect":
     case "errorfile": 
      access[cmd] = rest;
      break;

     default:
#ifdef HTACCESS_DEBUG
      perror(".htaccess: Unsupported command: "+ cmd +"\n");
#endif
    }
#ifdef HTACCESS_DEBUG
    perror(sprintf("HTACCESS: Result of .htaccess file parsing -> %O\n", 
		   access));
#endif
  }
  cache_set(cache_key, rht, ({s[3], access}));
  return access;
}

/* The host/ip verifier */
int allowed(multiset allow, string hname, string ip, int def)
{
  string s;
  int ok, i, a;
  array tmp1, tmp2;
  if(!allow || !sizeof(allow))
    return 0;
  foreach(indices(allow), s)
  {
    if(s == "all" || s == ip || s == hname)
    {
      ok = 1;
#ifdef HTACCESS_DEBUG
      perror(sprintf("HTACCESS: IP/hostname access deny/allow exact match:\n"
		     "HTACCESS: (%s -> %s || %s)\n", s, ip, hname));
#endif
    }
    if(!ok && (int)s && (ip/".")[0] == s)
    {
      ok = 1;
#ifdef HTACCESS_DEBUG
      perror(sprintf("HTACCESS: IP/hostname access deny/allow ip match:\n"
		     "HTACCESS: (%s -> %s || %s)\n", s, ip, hname));
#endif
    }
    if(!ok)
    {
      tmp1 = s / "." - ({""});
      tmp2 = hname / "." - ({""});
      a = sizeof(tmp2)  - sizeof(tmp1);
      if(a > -1)
      {
	for(i = 0; i < sizeof(tmp1); i++)
	  if(tmp1[i] != tmp2[a+i])
	  { 
	    ok = -1;
	    break;
	  } 
	if(!ok)
	  ok = 1;
	else 
	  ok = 0;
      }
#ifdef HTACCESS_DEBUG
      if(ok)
	perror(sprintf("HTACCESS: IP/hostname access deny/allow hostname/"
		       "domain match:\n"
		       "HTACCESS: (%s -> %s || %s)\n", s, ip, hname));
#endif
      
    }
    if(!ok)
    {
      tmp2 = ip / "." - ({""});      
      if(sizeof(tmp2) >= sizeof(tmp1))
      {
	for(i = 0; i < sizeof(tmp1); i++)
	  if(tmp1[i] != tmp2[i])
	  { 
	    ok = -1;
	    break;
	  } 
	if(!ok)
	  ok = 1;
	else 
	  ok = 0;
      }
#ifdef HTACCESS_DEBUG
      if(ok)
	perror(sprintf("HTACCESS: IP/hostname access deny/allow ip-number "
		       "match:\nHTACCESS: (%s -> %s || %s)\n", s, ip, hname));
#endif
      
    }
    if(ok)
      break;
  }
  if(!ok && hname == ip)
    ok = def;

  return ok;
}

mapping validate(string aname)
{
  return (["type":"text/html",
	   "error":401,
	   "extra_heads":
	   ([ "WWW-Authenticate":
	     "basic realm=\""+ aname +"\""]),
	   ]);
}

/* Check if the password is correct.  */
int match_passwd(string org, string try)
{
  if(!strlen(org))   return 1;
  if(crypt(try, org)) return 1;
}


/* Check if this user has access */

int validate_user(int|multiset users, array auth, string userfile, object id)
{
  string passwd, line;
#ifdef HTACCESS_DEBUG
  perror(sprintf("HTACCESS: Validating user %s.\n", auth[0]));
#endif

  if(!users) {
#ifdef HTACCESS_DEBUG
    perror("HTACCESS: Warning. No users are allowed to see this page.\n");
#endif
    return 0;
  } else {
    if(multisetp(users) && !users[auth[0]])
    {
#ifdef HTACCESS_DEBUG
      perror(sprintf("HTACCESS: Failed auth. User %s not among the "
		     "valid users.\n", auth[0]));
      perror(sprintf("HTACCESS: Valid users -> %O\n", users));
#endif
      return 0;
    }
  }
  if(!userfile)
  { 
    if(id->auth)
      return id->auth[0];
    return 0;
  }

  if(!(passwd = read_bytes(userfile)))
  {
#ifdef HTACCESS_DEBUG
    perror(sprintf("HTACCESS: Failed to read password file (%s)\n", 
		   userfile));
#endif    
    return 0;
  }
  foreach(passwd/"\n", line)
  {
    string user, pass;
    if(sscanf(line, "%s:%s", user, pass) == 2)
    {
      pass = (pass/":")[0];
      if((users == 1 || users[user]) && (user == auth[0]) &&
	 match_passwd(pass, auth[1]))
      {
#ifdef HTACCESS_DEBUG
	perror("HTACCESS: Successful auth.\n");
#endif      
	return 1;
      }
    }
#ifdef HTACCESS_DEBUG
    else {
      if(user && pass)
      {
	perror("HTACCESS: Failed auth\n");
	if(user == auth[0])
	{
	  perror(sprintf("HTACCESS: %s:%s != ", user, pass));
	  perror(sprintf("%s:%s\n", auth[0], crypt(auth[1])));
	}
      }
    }
#endif      
  }
  return 0;
}

/* Check if the users is a member of the valid group(s) */
int validate_group(multiset grps, array auth, string groupfile, string userfile,
		   object id)
{
  mapping g;
  string groups, cache_key, grp, members, user, s2;
  int *s;
  object f;
  mixed in_cache;

  cache_key = "groupfile:" + roxen->current_configuration->name;

  f = files.file();
  if(!(f->open(groupfile, "r")))
  {
#ifdef HTACCESS_DEBUG
    perror("HTACCESS: The groupfile "+groupfile+" cannot be opened.\n");
#endif
    return 0;
  }

#ifdef DEBUG
  mark_fd(f->query_fd(), ".htaccess groupfile ("+groupfile+")\n");
#endif
  s = (int *)f->stat();
  
  if((in_cache = cache_lookup(cache_key, groupfile))
     && (s[3] == in_cache[0]))
    g = in_cache[1];
  else if(groups = f->read(0x7fffffff)) {
    g = ([]);
    groups = replace(groups, "\\\n", " ");
    foreach(groups/"\n", s2)
    {
      if(sscanf(s2, "%s:%s", grp, members) == 2)
      {
	foreach(replace(members, ({",", "\t"}), ({" ", " "})) / 
		" " - ({""}), user)
	{
	  if(!multisetp(g[grp]))
	    g += ([ grp : (<>) ]);
	  g[grp][user]=1;
	}
      }
    }
    cache_set(cache_key, groupfile, ({s[3], g}));
  }
  f->close;
  destruct(f);
  foreach(indices(grps), grp)
  {
#ifdef HTACCESS_DEBUG
    perror("HTACCESS: Checking for group "+grp+" ... "
	   +(g[grp]?"Existant":"Nope")+"\n");
#endif
    if(g[grp])
      if(validate_user(g[grp], auth, userfile, id))
	return 1;
  }
}

/* Check if the person accessing this page should be denied or not. */
mapping|string|int htaccess(mapping access, object id)
{
  int hok;
  mixed tmp;
  multiset l;

  string htaccess, aname, userfile, tmp2, groupfile, hname, method, errorfile;

  if(access->redirect)
  {
    string from, to;

    if(sscanf(access->redirect, "%s %s", from, to) < 2)
      return http_redirect(access->redirect,id);

    if(search(id->not_query, from) + 1)
      return http_redirect(to,id);
  }

  if(id->remoteaddr)
  {
    if(!((hname=roxen->quick_ip_to_host(id->remoteaddr)) && 
	 hname != id->remoteaddr))
      hname = roxen->blocking_ip_to_host(id->remoteaddr);
  }

  aname      = access->authname || "authorization";
  userfile   = access->authuserfile;
  groupfile  = access->authgroupfile;
#ifdef HTACCESS_DEBUG
  perror("HTACCESS: Verifying access.\n");
#endif

  if(!access[method = lower_case(id->method)])
  {
    if(access->all)
      method = "all";
    else switch(method)
    {
     case "get": case "post": case "head":
      return 1;
      
     case "put": case "delete":
      return 0;
    }
  }
  
  if(!access[method]->allow && !access[method]->deny)
    hok = 1;
  else if(access[method]->order == 1) {
    if(allowed(access[method]->allow, hname, id->remoteaddr, 0))
      hok = 1;
    if(allowed(access[method]->deny, hname, id->remoteaddr, 1))
      hok = 0;
  } else if(access[method]->order == 0) {
    if(allowed(access[method]->deny, hname, id->remoteaddr, 1))
      hok = 0;
    if(allowed(access[method]->allow, hname, id->remoteaddr, 0))
      hok = 1;
  } else 
    hok = (allowed(access[method]->allow, hname, id->remoteaddr, 0) && 
	  allowed(access[method]->deny, hname, id->remoteaddr, 1));
  if(!hok && access[method]->all == 1)
  {
    if(hname == id->remoteaddr)
      return 2;
    return 1;
  } else if(hok && access[method]->all == -1) {
    return 0;
  }
#ifdef HTACCESS_DEBUG
  perror("HTACCESS: Host based access verified and granted.\n");
#endif

  if(access[method]->user || access[method]["valid-user"] 
     || (groupfile && access[method]->group))
  {
#ifdef HTACCESS_DEBUG
    perror("HTACCESS: Verifying user access.\n");
#endif
    if(!id->realauth)
    {
#ifdef HTACCESS_DEBUG
      perror("HTACCESS: No authification string from client.\n");
#endif
      return validate(aname);
    } else {
      string *auth;
      
      auth = id->realauth/":";

      if((access[method]->user && 
	  validate_user(access[method]->user, auth, userfile, id)) ||
	 (access[method]["valid-user"] &&
	  validate_user(1, auth, userfile, id)) ||
	 (access[method]->group &&
	  validate_group(access[method]->group, auth, 
			 groupfile, userfile, id)))
      {
#ifdef HTACCESS_DEBUG
	perror("HTACCESS: User access ok!\n");
#endif
	id->auth = ({ 1, auth[0] });
	return 0;
      } else {
#ifdef HTACCESS_DEBUG
	perror("HTACCESS: User access denied, invalid user.\n");
#endif
	id->auth = ({ 0, auth[0]+":"+auth[1] });
	return validate(aname);
      }
    }
  }
}

inline string dot_dot(string from)
{
  if(from=="/") return "";
  return combine_path(from, "../");
}

string|int cache_path_of_htaccess(string path, object id)
{
  mixed f;
  f = cache_lookup("htaccess_files:"+id->conf->name, path);
#ifdef HTACCESS_DEBUG
  if(f==0)
    perror("HTACCESS: Location of .htaccess file for "+path+" not cached.\n");
  else if(f==-1)
    perror("HTACCESS: Non-existant .htaccess file cached: "+path+"\n");
  else if(f)
    perror("HTACCESS: Existant .htaccess file cached: "+path+"\n");
#endif
  return f;
}

void cache_set_path_of_htaccess(string path, string|int htaccess_file, object id)
{
#ifdef HTACCESS_DEBUG
  perror("HTACCESS: Setting cached location for "
	 +path+" to "+htaccess_file+"\n");
#endif  
  cache_set("htaccess_files:"+id->conf->name, path, htaccess_file);
}

// This function traverse the virtual filepath to see if there are any 
// .htaccess files hiding anywhere. When (and if) if finds one, it returns 
// the full path to it _and_ the actual open file (modified by Per)

array rec_find_htaccess_file(object id, string vpath)
{
/*  vpath is asumed to end in '/', it is the directory path. */
  string path;
  if(vpath == "") return 0;

  if(!id->pragma["no-cache"])
  {
    if((path = cache_path_of_htaccess(vpath,id)) != 0)
    {
      object o;
      if(stringp(path))
      {
	o = open(path, "r");
	return ({ path, o });
      } else if(QUERY(cache_all))
	return 0;
    }
  } /* Not found in cache... */

  if(path = roxen->real_file(vpath, id))
  {
    object f;
    if(f=open(path +".htaccess", "r"))
    {
#ifdef DEBUG
      mark_fd(f->query_fd(), ".htaccess file in "+path);
#endif
      cache_set_path_of_htaccess(vpath, path+".htaccess",id);
      return ({ path +".htaccess", f });
    }
  } 
  array res;
  if(res = rec_find_htaccess_file(id, dot_dot(vpath)))
  {
    cache_set_path_of_htaccess(vpath, res[0], id);
    return res;
  }
  if(QUERY(cache_all))
    cache_set_path_of_htaccess(vpath, -1, id);
  return 0;
}

array find_htaccess_file(object id)
{
  string vpath;

  vpath = id->not_query;

  // Make sure the path does _not_ end with '/', since that would disable
  // checking for /foo/.htaccess when /foo/ is accessed.   The only thing
  // affected is directory listings, but that might be sensitive as well.
  // This is only because of the call to dot_dot below :-)

  if(vpath[-1] == '/') vpath += "gazonk"; 

  return rec_find_htaccess_file( id, dot_dot(vpath) );
}

mapping htaccess_no_file(object id)
{
  mixed tmp;
  mapping access = ([]);
  string file;
  if(!(tmp = find_htaccess_file(id)))
    return 0;

  access = parse_htaccess(tmp[1], id, tmp[0]);

  if(access && access->nofile)
  {
    file = read_bytes(access->nofile);
    if(file) 
    {
      file = parse_rxml(file, id);
      return http_string_answer( file );
    }
  }
  return 0;
}

    

mapping try_htaccess(object id)
{
  mixed tmp;
  mapping access = ([]);

  if(!(tmp = find_htaccess_file(id)))
  {
#ifdef HTACCESS_DEBUG
    perror("HTACCESS: No htaccess file for "+id->not_query+"\n");
#endif
    return 0;
  }

  access = parse_htaccess(tmp[1], id, tmp[0]);

  if(access)
  {
    mixed ret;
    if(ret = htaccess(access, id))
    {
      string file;

      if(ret == 1)
      {
	if(access->errorfile)
	{
	  file = read_bytes(access->errorfile);
	  if(file) file = parse_rxml(file, id);
	}
	return http_low_answer(403, file || 
			       ("<title>Access Denied</title>"
				"<h2 align=center>Access Denied</h2>"));
      }
      

      else if(ret == 2)
	return http_low_answer(403, "<title>Access Denied</title>"
			       "<h2 align=center>Access Denied</h2>"
			       "<h3>The server hadn't resolved your "
			       "hostname. If you try again, "
			       "it might work better.</h3>"
			       "<b>You might lack a valid DNS entry. In that "
			       "case, you will have to talk to your system "
			       "administrator.</b>");

      else if(mappingp(ret))
      {
	if(access->errorfile)
	{
	  file = read_bytes(access->errorfile);
	  if(file) file = parse_rxml(file, id);
	}
	return  (["data":file || 
		 ("<title>Access Denied</title>"
		  "<h2 align=center>Access forbidden by user</h2>") ]) 
	  | ret; /*Mix the returned mapping with the default message :-)*/
      }
    } else
      id->misc->auth_ok = 1;
  }
}

mapping last_resort(object id)
{
  mapping access_violation;
  if(strlen(id->not_query)&&id->not_query[0]=='/')
    if(access_violation = htaccess_no_file( id ))
      return access_violation;
}

mapping first_try(object id)
{
  mapping access_violation;

  if(strlen(id->not_query)&&id->not_query[0]=='/')
  {
    access_violation = try_htaccess( id );
    if(access_violation)
      return access_violation;
  }
}

