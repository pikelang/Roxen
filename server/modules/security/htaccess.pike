// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.

// .htaccess compability by David Hedbor <neotron@roxen.com>
//   Changed into module by Per Hedbor <per@roxen.com>
//   Support for many extensions added by Henrik Grubbström <grubba@roxen.com>
//
// The canonical documentation for the .htaccess format seems to be
//   http://httpd.apache.org/docs/1.3/mod/mod_access.html

constant cvs_version="$Id$";
constant thread_safe=1;

#include <module.h>
#include <roxen.h>
inherit "module";

//#define HTACCESS_DEBUG

#ifdef HTACCESS_DEBUG
# include <request_trace.h>
# define HT_WERR(X) werror("HTACCESS: %s\n",X)
#else
# define TRACE_ENTER(A,B)
# define TRACE_LEAVE(A)
# define HT_WERR(X)
#endif

constant module_type = MODULE_SECURITY|MODULE_LAST|MODULE_URL|MODULE_USERDB;
constant module_name = "Authentication: .htaccess support";
constant module_doc  = "Almost complete support for NCSA/Apache "
  ".htaccess files. See "
  "<a href=\"http://hoohoo.ncsa.uiuc.edu/docs/setup/access/Overview.html\">"
  "http://hoohoo.ncsa.uiuc.edu/docs/setup/access/Overview.html</a> for more information.<br />\n"
  "\n"
  "Some non-standard options are supported:"

  "<ul><li>"
  "All filenames can be specified as 'locate file', which will cause the"
  " file to be located above (closer to the root of) the currently"
  " requested file in the virtual filesystem. This can be used to, as an"
  " example, specify the password file as 'locate .htpasswd', in a"
  " top-level htaccess file, then have password files located in the"
  " subdirectories.</li>"
  "<li>Files can be specified as files in the virtual filesystem, relative "
  " to the path of the requested file (note: Not relative to "
  "the .htaccess file)</li>"
  "<li>Non-standard commands inside &lt;Limit&gt; tags:<pre>"
  "require ip ip/bits\n"
  "require ip ip:mask\n"
  "require time hh:mm-hh:mm\n"
  "require day day[,day...]   (day either english day name or number (1=monday)\n"
  "require accept_language language\n"
  "require luck percent%\n"
  "deny ip ip/bits[,ip/bits]\n"
  "deny ip ip:mask[,ip:mask]\n"
  "deny ip pattern\n"
  "deny user name[,name,...]\n"
  "deny group name[,name,...]\n"
  "deny dns pattern\n"
  "deny day day[,day...]\n"
  "deny time HH:MM-HH:MM\n"
  "deny referer pattern\n</pre>"
  "deny accept_language language\n"
  "deny luck percent%\n"
  "<li> All methods used by HTTP, and also the methods used by FTP, "
  "can be used to specify when the &lt;Limit&gt; tag will take effect.</ul>"
  ;

void create()
{
  defvar("file", ".htaccess", "Htaccess file name", TYPE_STRING|VAR_MORE);
  defvar("denyhtlist", ({".htaccess", ".htpasswd", ".htgroup"}),
	 "Deny file list", TYPE_STRING_LIST,
	 "Always deny access to these files. This is useful to protect "
	 "htaccess related files.");

}

// Thread.Local ui = Thread.Local( );

string read( string f, RequestID id )
{
  if( !f ) return 0;
  if( sscanf( f, "locate %s", f ) )
    return VFS.find_above_read( id->not_query, f, id )[1];

  if( f[0] != '/' )
    f = Roxen.fix_relative( f, id );

  Stat st;
  if( (st=file_stat( f ) )&& st->isreg )
    return Stdio.read_file( f );

  return id->conf->try_get_file( f, id );
}

#define READ(X) read( (X), id )

/* Check if the person accessing this page should be denied or not. */
mapping|string|int htaccess(mapping access, RequestID id)
{
  id->misc->ht_authinfo = ([
    "groupfile":READ( access->authgroupfile ),
    "userfile":READ( access->authuserfile ),
  ]);   
  if(access->redirect)
    foreach( access->redirect, string r )
    {
      string from, to;

      if(sscanf(r, "%s %s", from, to) < 2)
	return Roxen.http_redirect(r, id);

      if( has_value(id->not_query, from) )
	return Roxen.http_redirect(to,id);
    }
  
  HT_WERR(sprintf("Verifying access. method: %O", id->method));
  string method;
  if(!access[method = lower_case(id->method)])
  {
    if(access->all)
      method = "all";
    else switch(method)
    {
      case "list":   case "dir":
	if (access->list) {
	  method = "list";
	  break;
	} else if (access->dir) {
	  method = "dir";
	  break;
	}
      case "stat":  case "head":
      case "cwd":   case "post":
	if (access->head) {
	  method = "head";
	  break;
	} else if (access->get) {
	  method = "get";
	  break;
	}
      case "get":
	if (access->head) {
	  method = "head";
	  break;
	}
	return 0;

      default:
	if (access->put) {
	  method = "put";
	  break;
	}
	return 1;
    }
  }
#ifdef HTACCESS_DEBUG
  report_debug(sprintf("HTACCESS: access[%O]: %O\n", method, access[method]));
#endif /* HTACCESS_DEBUG */
  return access[ method ]( id );
}

function(RequestID:mapping|int) allow_deny( function allow,
					    function deny,
					    int order )
{
#ifdef HTACCESS_DEBUG
  report_debug("HTACCESS: allow_deny(%O, %O, %s)\n",
	       allow, deny, 
	       ([1:"allow, deny", -1:"mutual-failure",
		 0:"deny, allow"])[order] || "UNKNOWN");
#endif /* HTACCESS_DEBUG */
  // Sanity check.
  if (!allow && !deny) {
    error("At least one of allow or deny must be a function!\n");
  }
  return lambda( RequestID id ) {
	   mixed not_allowed = allow && allow( id );
	   mixed denied  = deny && deny( id );
	   // Note: not_allowed is 1 or a mapping if none of the allow
	   //       patterns matched.
	   //       denied is 0 if none of the deny patterns matched.
#ifdef HTACCESS_DEBUG
	   report_debug("HTACCESS: not_allowed: %O\n"
			"          denied: %O\n"
			"          order: %s\n"
			"          allow: %O\n"
			"          deny: %O\n",
			not_allowed, denied,
			([1:"allow, deny", -1:"mutual-failure",
			  0:"deny, allow"])[order] || "UNKNOWN",
			allow, deny);
#endif /* HTACCESS_DEBUG */
	   // Note: Returns 1 or a mapping on access denied.
	   //       Returns 0 on access permitted.
	   switch( order )
	   {
	     case -1: // mutual-failure
	       // Deprecated, equvivalent to allow,deny.
	     case 1: //allow,deny
	       // * At least one allow pattern MUST match.
	       // AND
	       // * All deny patterns MUST NOT match.
	       if( not_allowed ) return not_allowed;
	       return denied;

	     case 0: // deny,allow
	       // * All deny patterns MUST NOT match.
	       // OR
	       // * At least one allow pattern MUST match.
	       if( !denied ) return 0;
	       return not_allowed;
	   }
	   return 0;
	 };
}
					    

mapping parse_and_find_htaccess( RequestID id )
{
  mapping access = ([ ]);
  string parse_limit(Parser.HTML pr, mapping m, string s )
  {
    string line, ent;
    string|int data;

    int any_ok = 0, order = 1;

    string roxen_allow = "", roxen_deny = "";

    // The following two are used for grouping.
    mapping(string:array(string)) allow = ([]);
    mapping(string:array(string)) deny = ([]);

    // Flush the grouped patterns. 
    void flush_patterns()
    {
      foreach(indices(allow), string cat) {
	roxen_allow += "allow "+cat+"="+(allow[cat]*",") + "\n";
      }
      allow = ([]);
      foreach(indices(deny), string cat) {
	roxen_deny += "deny "+cat+"="+(deny[cat]*",") + "\n";
      }
      deny = ([]);
    };

    if( access->authname )
    {
      flush_patterns();
      roxen_allow += "realm "+access->authname+"\n";
      roxen_deny += "realm "+access->authname+"\n";
    }
    if( access->userdb )
    {
      flush_patterns();
      roxen_allow += "userdb "+access->userdb+"\n";
      roxen_deny += "userdb "+access->userdb+"\n";
    }
    if( access->authmethod )
    {
      flush_patterns();
      roxen_allow += "authmethod "+access->authmethod+"\n";
      roxen_deny += "authmethod "+access->authmethod+"\n";
    }
    
    if(!sizeof(m))
      m = ([ "all": 1 ]);

    foreach( replace(s, "\r", "\n") / "\n"-({""}), line )
    {
      line = (replace(line, "\t", " ") / " " - ({""})) * " ";

      if(!strlen(line) || has_prefix(line, "#"))
	continue;

      if(line[0] == ' ') /* There can be only one /Connor MacLeod */
	line = line[1..];

      line = lower_case(line);

      if( line == "deny all" )
	roxen_deny += "deny ip=*\n";
      else if( line == "allow all" )
	roxen_allow += "allow ip=*\n";
      else if(sscanf(line, "realm %s", data)||
	      sscanf(line, "authmethod %s", data)||
	      sscanf(line, "userdb %s", data))
      {
	flush_patterns();
	roxen_allow += line+"\n";
	roxen_deny += line+"\n";
      }
      else if(sscanf(line, "deny from %s", data))
	if (data != "all") {
	  if( (int)data )
	    deny->ip += ({data+"*"});
	  else
	    deny->dns += ({"*"+data});
	}
	else
	  roxen_deny += "deny ip=*\n";
      else if(sscanf(line, "allow from %s", data))
	if( data != "all" ) {
	  if( (int)data )
	    allow->ip += ({data+"*"});
	  else
	    allow->dns += ({"*"+data});
	}
	else
	  roxen_allow += "allow ip=*\n";
      else if(sscanf(line, "require %s %s", ent, data) == 2)
	allow[ent] += (replace(data, ([" ":",","\t":","]))/",") - ({""});
      else if(sscanf(line, "deny %s %s", ent, data) == 2)
	deny[ent] += ({data});
      else if(sscanf(line, "satisfy %s", data))
	if(data == "any")
	  any_ok = 1;
	else
	  any_ok = 0;
      else if(has_prefix(line, "require valid-user"))
	roxen_allow += "allow user=any\n";
      else if(sscanf(line, "referer allow from %s", ent))
	roxen_allow += "allow referer="+ent+"\n";
      else if(sscanf(line, "referer deny from %s", ent))
	roxen_deny += "deny referer="+ent+"\n";
      else if(sscanf(line, "order %s", data))
      {
	data -= " ";
	if(has_prefix(data, "allow"))
	  order = 1;
	else if(has_prefix(data, "mutual-failure"))
	  order = -1;
	else
	  order = 0;
	continue;
#ifdef HTACCESS_DEBUG
      } else {
	report_debug("HTACCESS: Unknown directive %O\n", line);
#endif /* HTACCESS_DEBUG */
      }
    }

    flush_patterns();

    // Make the deny handler default to allowing all.
    // This means that the result will only return 1
    // if there was a rule that matched.
    roxen_deny += "allow ip=*\n";

    if( any_ok ) {
      array(string) rows = roxen_allow/"\n";
      int i;
      for (i=0; i < sizeof(rows); i++) {
	if (has_prefix(rows[i], "allow ")) {
	  rows[i] += " return";
	}
      }
      roxen_allow = rows*"\n";
    }

#ifdef HTACCESS_DEBUG
    report_debug("limit:%{ %s%}\n", indices(m));
    report_debug("  Allow:\n"+roxen_allow+"\n");
    report_debug("  Deny:\n"+roxen_deny+"\n");
#endif /* HTACCESS_DEBUG */
    
    function fun =
      allow_deny( roxen.compile_security_pattern( roxen_allow, this_object() ),
		  roxen.compile_security_pattern( roxen_deny, this_object() ),
		  order );
    
    foreach( indices( m ), string s )
      foreach( Unicode.split_words_and_normalize( s ), string q )
	access[lower_case(Unicode.normalize( s, "C" ))] = fun;
    return "";
  };

  string cache_key;

  array cv = VFS.find_above_read( id->not_query, htfile, id, "htaccess", 1 );

  if( !cv ) return 0;

  [string file,string htaccess,int mtime] = cv;

#ifdef HTACCESS_DEBUG
  report_debug(sprintf("HTACCESS: File:%O, mtime: %d\n"
		       "%{    %s\n%}\n", file, mtime, (htaccess||"-")/"\n"));
#endif /* HTACCESS_DEBUG */
    
  cache_key = "htaccess:parsed:" + id->conf->name + ":" + (id->misc->host||"*");

  array in_cache;
  if((in_cache = cache_lookup(cache_key, file)) && (mtime <= in_cache[0]))
    return in_cache[1];

  if (!htaccess) {
    // Failed to read htaccess file -- Use paranoia fallback.
    htaccess =
      "<limit get post head put>\n"
      "  deny all\n"
      "</limit>";
    report_debug(sprintf("HTACCESS: Failed to read htaccess file: %O\n"
			 "HTACCESS: Using paranoia fallback:\n"
			 "%{    %s\n%}\n", file, htaccess/"\n"));
  }

  if( !strlen(htaccess) )
    return 0;

  htaccess = replace(htaccess, ([ "\\\r\n":" ", "\\\n":" ", "\r":"" ]));
  foreach(htaccess / "\n"-({""}), string line)
  {
    string cmd, rest;

    if(!strlen(line) || line[0] == '#')
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
      case "realm":
	access->authname = rest;
	break;

      case "redirecttemp":
      case "redirecttemporary":
      case "redirect":
      case "redirectperm":
      case "redirectpermanent":
	access->redirect += ({ rest });
	break;

      case "authuserfile":
      case "authgroupfile":
	if(!access->userdb )
	  access->userdb = "htaccess";
	// FALL-THROUGH

      case "authname":
      case "userdb":
      case "authmethod":
      case "errorfile":
	access[cmd] = rest;
	break;
    }
  }
  Parser.HTML()->add_container( "limit",parse_limit )
                          ->add_container( "Limit",parse_limit )
                          ->add_container( "LIMIT",parse_limit )
    ->feed(htaccess - "\r")->finish();

  if ((!access->head) && access->get)
    access->head = access->get;

  if(!sizeof( access ) )
    parse_limit( 0, ([ "all":"all" ]), htaccess );

  cache_set(cache_key, file, ({mtime, access}));
  return access;
}

mapping try_htaccess(RequestID id)
{
  mapping access = ([]);
  string file;

  TRACE_ENTER("htaccess->try_htaccess()", try_htaccess);
  if( !( access = parse_and_find_htaccess( id )) ) {
    TRACE_LEAVE("No htaccess-file.");
    return 0;
  }
  NO_PROTO_CACHE();

  // HT_WERR(sprintf("id->misc: %O", id->misc));

  switch(mixed ret = htaccess(access, id))
  {
   case 1:
     if(access->errorfile && (file = READ(access->errorfile)))
       file = Roxen.parse_rxml(file, id);
     TRACE_LEAVE("Access Denied (1)");
     return Roxen.http_low_answer(403, file ||
				  ("<title>Access Denied</title>"
				   "<h2 align=center>Access Denied</h2>"));
    case 2:
      TRACE_LEAVE("Access Denied (2)");
      return Roxen.http_low_answer(403, "<title>Access Denied</title>"
				   "<h2 align=center>Access Denied</h2>"
				   "<h3>This page is protected based on host- "
				   "or domain-name. "
				   "The server couldn't resolve your hostname."
				   " <b>Your computer might lack a correct "
				   "DNS PTR entry. In that "
				   "case, ask your system administrator to "
				   "add one.</b>");
    default:
      TRACE_LEAVE("Access OK");
      return ret;
  }
}

mapping last_resort(RequestID id)
{
  if( id->misc->internal_get ) // OK.
    return 0;

  TRACE_ENTER("htaccess->last_resort()", last_resort);
  if(strlen(id->not_query)&&id->not_query[0]=='/')
  {
    mapping access = parse_and_find_htaccess( id );
    if(access && (access->nofile || (access->nofile = access->errorfile)))
    {
      string file;
      if( file = READ(access->nofile) )
      {
	TRACE_LEAVE("Custom no-such-file");
	return Roxen.http_rxml_answer( file, id );
      }
    }
  }
  TRACE_LEAVE("OK");
  return 0;
}

mapping remap_url(RequestID id)
{
  if( id->misc->internal_get ) // OK.
    return 0;

  mapping access_violation;

  TRACE_ENTER("htaccess->remap_url()", remap_url);

  // HT_WERR(sprintf("id->misc: %O", id->misc));

  if(strlen(id->not_query)&&id->not_query[0]=='/')
  {
    access_violation = try_htaccess( id );
    if(access_violation) {
      TRACE_LEAVE("Access violation");
      return access_violation;
    } else {
      string s = (id->not_query/"/")[-1];
      if (denylist[lower_case(s)])
      {
	report_debug("Denied access for "+s+"\n");
	id->misc->error_code = 401;
	TRACE_LEAVE("Access Denied");
	return Roxen.http_low_answer(401, "<title>Access Denied</title>"
				     "<h2 align=center>Access Denied</h2>");
      }
    }
  }
  TRACE_LEAVE("OK");

  // HT_WERR(sprintf("id->misc: %O", id->misc));
}

multiset denylist;
string   htfile;
void start(int num, Configuration conf)
{
  module_dependencies(conf, ({ "auth_httpbasic" }));
  denylist = mkmultiset(map(query("denyhtlist"), lower_case));
  htfile = query("file");
}



// UserDB stuff.
constant name = "htaccess";

class HtUser
{
  inherit User;
  constant is_transient = 1;
  protected array pwent;

#ifdef HTACCESS_DEBUG
  int password_authenticate(string password)
  {
    int res = ::password_authenticate(password);
    report_debug(sprintf("HTACCESS: password_authenticate(%O)\n"
			 "  user:%O, crypt:%O ==> %O\n",
			 password, name(), crypted_password(), res));
    return res;
  }
#endif /* HTACCESS_DEBUG */

  string name()             { return pwent[0]; }
  string crypted_password() { return pwent[1]; }
  int uid()                 { return pwent[2]; }
  int gid()                 { return pwent[3]; }
  string gecos()            { return pwent[4]; }
  string real_name()        { return(pwent[4]/",")[0]; }
  string homedir()          { return pwent[5]; }
  string shell()            { return pwent[6]; }
  array compat_userinfo()   { return pwent;    }

  array(string) groups()
  {
    return ((array)(pwent[7]||(<>)))+(({pwent[8]})-({0}));
  }
  
  protected void create( UserDB p, array _pwent )
  {
    ::create( p );
    pwent = _pwent;
  }
}

class HtGroup
{
  inherit Group;
  constant is_transient = 1;

  array grent;
  int gid()                { return grent[2]; }
  string name()            { return grent[0]; }
  array(string) members()  { return (array)grent[3]; }

  protected void create( UserDB p, array _grent )
  {
    ::create( p );
    grent = _grent;
  }
}

array(mapping) parse_groupfile( string f )
{
  if( !f ) return ({([]),([])});
  mapping u2g = ([]);
  mapping groups = ([]);
  int gid = 10000;
  foreach( f / "\n", string r )
  {
    array(string) q = r/":";
    string members;
    string passwd = "";
    int this_gid;
    switch( sizeof( q ) ) 
    {
    default:
      continue;
    case 2: // group:members
      this_gid = gid++;
      members = q[1];
      break;
    case 4: // group:passwd:gid:members
      passwd = q[1];
      this_gid = (int)q[2];
      members = q[3];
      break;
    }
    // NB: members can be separated by either space or comma.
    multiset(string) user_set =
      (multiset(string))(replace(members, ",", " ")/" " - ({""}));
    foreach(indices(user_set), string u)
    {
      if( u2g[u] )
	u2g[u]+=(<q[0]>);
      else
	u2g[u]=(<q[0]>);
    }
    groups[q[0]] = ({ q[0], passwd, this_gid, user_set });
    groups[this_gid] = groups[q[0]];
  }
  return ({ groups, u2g });
}

mapping parse_userfile( string f, mapping u2g, mapping groups )
{
  if( !f )  return ([]);
  mapping users = ([]);
  int uid = 10000;
  foreach( f/ "\n", string r )
  {
    array q = r/":";
    switch( sizeof( q ) )
    {
      case 2..6: // user:passwd
	users[q[0]] = ({q[0],q[1],uid++,10000,q[0],"/tmp/","/nosuchshell",
			u2g[q[0]], 0});
	users[uid-1] = users[q[0]];
	break;

      case 7: // user:passwd:uid:gid:name:home:shell
	users[q[0]] = ({ q[0], q[1], (int)q[2], (int)q[3], q[4], q[5], q[6],
			 u2g[q[0]], groups[q[3]]&&groups[q[3]][0] });
	users[(int)q[2]] = users[q[0]];
    }
  }
  return users;
}


User find_user( string s, RequestID id )
{
  if( !id ) return 0;
  mapping uu = id->misc->ht_authinfo||([]);
  mapping groups, u2g, users;

  [groups,u2g] = parse_groupfile(uu->groupfile);
  users = parse_userfile( uu->userfile, u2g, groups );
  if( users[ s ] )
    return HtUser(this_object(),users[s]);
}

User find_user_from_uid( int uid, RequestID|void id )
{
  if( !id ) return 0;
  mapping uu =   id->misc->ht_authinfo||([]);
  mapping groups, u2g, users;

  [groups,u2g] = parse_groupfile(uu->groupfile);
  users  = parse_userfile( uu->userfile, u2g, groups );

  if( users[ uid ] )
    return HtUser( this_object(), users[uid] );
}

array(string) list_users( RequestID|void id )
{
  if( !id ) return 0;
  mapping uu =   id->misc->ht_authinfo||([]);
  return filter(indices(parse_userfile( uu->userfile, 0, 0 )),stringp);
}

Group find_group( string group, RequestID|void id )
{
  if( !id ) return 0;
  mapping uu =   id->misc->ht_authinfo||([]);
  mapping groups = ([]), u2g = ([]);
  [groups,u2g] = parse_groupfile(uu->groupfile);
  if( groups[group] )
    return HtGroup( this_object(), groups[group] );
}

Group find_group_from_gid( int gid, RequestID|void id  )
{
  if( !id ) return 0;
  mapping uu =   id->misc->ht_authinfo||([]);
  mapping groups = ([]), u2g = ([]);
  [groups,u2g] = parse_groupfile(uu->groupfile);
  if( groups[gid] )
    return HtGroup( this_object(), groups[gid] );
}

array(string) list_groups( RequestID|void id )
{
  if( !id ) return 0;
  mapping uu =   id->misc->ht_authinfo||([]);
  mapping groups = ([]), u2g = ([]);
  [groups,u2g] = parse_groupfile(uu->groupfile);
  return filter(indices(groups),stringp);
}
