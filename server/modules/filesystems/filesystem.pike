// This is a roxen module. Copyright © 1996 - 2001, Roxen IS.

// This is a virtual "file-system".
// It will be located somewhere in the name-space of the server.
// Also inherited by some of the other filesystems.

inherit "module";
inherit "socket";

constant cvs_version= "$Id: filesystem.pike,v 1.116 2002/07/01 09:23:07 anders Exp $";
constant thread_safe=1;

#include <module.h>
#include <roxen.h>
#include <stat.h>
#include <request_trace.h>


//<locale-token project="mod_filesystem">LOCALE</locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("mod_filesystem",X,Y)
// end of the locale related stuff

#ifdef FILESYSTEM_DEBUG
# define FILESYSTEM_WERR(X) werror("Filesystem: "+X+"\n")
#else
# define FILESYSTEM_WERR(X)
#endif

#ifdef QUOTA_DEBUG
# define QUOTA_WERR(X) werror("QUOTA: "+X+"\n")
#else
# define QUOTA_WERR(X)
#endif

#if constant(system.normalize_path)
#define NORMALIZE_PATH(X)	system.normalize_path(X)
#else /* !constant(system.normalize_path) */
#define NORMALIZE_PATH(X)	(X)
#endif /* constant(system.normalize_path) */

constant module_type = MODULE_LOCATION;
LocaleString module_name = LOCALE(51,"File systems: Normal File system");
LocaleString module_doc =
LOCALE(2,"This is the basic file system module that makes it possible "
       "to mount a directory structure in the virtual file system of "
       "your site.");
constant module_unique = 0;

int redirects, accesses, errors, dirlists;
int puts, deletes, mkdirs, moves, chmods;

static mapping http_low_answer(int errno, string data, string|void desc)
{
  mapping res = Roxen.http_low_answer(errno, data);

  if (desc) {
    res->rettext = desc;
  }

  return res;
}

static int do_stat = 1;

string status()
{
  return "<h2>"+LOCALE(3,"Accesses to this filesystem")+"</h2>"+
    (redirects?"<b>"+LOCALE(4,"Redirects")+"</b>: "+redirects+"<br>":"")+
    (accesses?"<b>"+LOCALE(5,"Normal files")+"</b>: "+accesses+"<br>"
     :LOCALE(6,"No file accesses")+"<br>")+
    (query("put")&&puts?"<b>"+LOCALE(7,"PUTs")+"</b>: "+puts+"<br>":"")+
    (query("put")&&mkdirs?"<b>"+LOCALE(8,"MKDIRs")+"</b>: "+mkdirs+"<br>":"")+
    (query("put")&&query("delete")&&moves?
     "<b>"+LOCALE(9,"Moved files")+"</b>: "+moves+"<br>":"")+
    (query("put")&&chmods?"<b>"+LOCALE(10,"CHMODs")+"</b>: "+chmods+"<br>":"")+
    (query("delete")&&deletes?"<b>"+LOCALE(11,"Deletes")+"</b>: "+deletes+"<br>":"")+
    (errors?"<b>"+LOCALE(12,"Permission denied")+"</b>: "+errors
     +" ("+LOCALE(13,"not counting .htaccess")+")<br>":"")+
    (dirlists?"<b>"+LOCALE(14,"Directories")+"</b>:"+dirlists+"<br>":"");
}

void create()
{
  defvar("mountpoint", "/", LOCALE(15,"Mount point"),
	 TYPE_LOCATION|VAR_INITIAL|VAR_NO_DEFAULT,
	 LOCALE(16,"Where the module will be mounted in the site's virtual "
		"file system."));

  defvar("searchpath", "NONE", LOCALE(17,"Search path"),
	 TYPE_DIR|VAR_INITIAL|VAR_NO_DEFAULT,
	 LOCALE(18,"The directory that contains the files."));

  defvar(".files", 0, LOCALE(19,"Show hidden files"), TYPE_FLAG|VAR_MORE,
	 LOCALE(20,"If set, hidden files, ie files that begin with a '.', "
		"will be shown in directory listings." ));

  defvar("dir", 1, LOCALE(21,"Enable directory listings per default"),
	 TYPE_FLAG|VAR_MORE,
	 LOCALE(22,"If set, it will be possible to get a directory listings "
		"from directories in this file system. It is possible to "
		"force a directory to never be browsable by putting a "
		"<tt>.www_not_browsable</tt> or a <tt>.nodiraccess</tt> file "
		"in it. Similarly it is possible to let a directory be "
		"browsable, even if the file system is not, by putting a "
		"<tt>.www_browsable</tt> file in it.\n"));

  defvar("nobrowse", ({ ".www_not_browsable", ".nodiraccess" }),
	 LOCALE(23,"List prevention files"), TYPE_STRING_LIST|VAR_MORE,
	 LOCALE(24,"All directories containing any of these files will not be "
		"browsable."));


  defvar("tilde", 0, LOCALE(25,"Show backup files"), TYPE_FLAG|VAR_MORE,
	 LOCALE(26,"If set, files ending with '~', '#' or '.bak' will "+
		"be shown in directory listings"));

  defvar("put", 0, LOCALE(27,"Handle the PUT method"), TYPE_FLAG,
	 LOCALE(28,"If set, it will be possible to upload files with the HTTP "
		"method PUT, or through FTP."));

  defvar("delete", 0, LOCALE(29,"Handle the DELETE method"), TYPE_FLAG,
	 LOCALE(30,"If set, it will be possible to delete files with the HTTP "
		"method DELETE, or through FTP."));

  defvar("check_auth", 1, LOCALE(31,"Require authentication for modification"),
	 TYPE_FLAG,
	 LOCALE(32,"Only allow users authenticated by a authentication module "
		"to use methods that can modify the files, such as PUT or "
		"DELETE. If this is not set the file system will be a "
		"<b>very</b> public one since anyone will be able to edit "
		"files."));

  defvar("stat_cache", 0, LOCALE(33,"Cache the results of stat(2)"),
	 TYPE_FLAG|VAR_MORE,
	 LOCALE(34,"A performace option that can speed up retrieval of files "
		"from NFS with up to 50%. In turn it uses some memory and the "
		"file system will not notice that files have changed unless "
		"it gets a pragma no-cache request (produced e.g. by "
		"Alt-Ctrl-Reload in Netscape). Therefore this option should "
		"not be used on file systems that change a lot."));

  defvar("access_as_user", 0, LOCALE(35,"Access files as the logged in user"),
	 TYPE_FLAG|VAR_MORE,
	 LOCALE(36,"If set, the module will access files as the authenticated "
		"user. This assumes that a authentication module which imports"
		" the users from the operating systems, such as the <i>User "
		"database</i> module is used. This option is very useful for "
		"named FTP sites, but it will have severe performance impacts "
		"since all threads will be locked for each access."));

  defvar("access_as_user_db",
	 Variable.UserDBChoice( " all", VAR_MORE,
				 LOCALE(53,"Authentication database to use"), 
				 LOCALE(54,"The User database module to use "
					"when authenticating users for the "
					"access file as the logged in user "
					"feature."),
				my_configuration()));

  defvar( "access_as_user_throw", 0,
	  LOCALE(55,"Access files as the logged in user forces login"),
	  TYPE_FLAG|VAR_MORE,
	  LOCALE(56,"If true, a user will have to be logged in to access files in "
		 "this filesystem") );

  defvar("no_symlinks", 0, LOCALE(37,"Forbid access to symlinks"),
	 TYPE_FLAG|VAR_MORE,
	 LOCALE(38,"It set, the file system will not follow symbolic links. "
		"This option can lower performace by a lot." ));

  defvar("charset", "iso-8859-1", LOCALE(39,"File contents charset"),
	 TYPE_STRING,
	 LOCALE(40,"The charset of the contents of the files on this file "
		"system. This variable makes it possible for Roxen to use "
		"any text file, no matter what charset it is written in. If"
		" necessary, Roxen will convert the file to Unicode before "
		"processing the file."));

  defvar("path_encoding", "iso-8859-1", LOCALE(41,"Filename charset"),
	 TYPE_STRING,
	 LOCALE(42,"The charset of the file names of the files on this file "
		"system. Unlike the <i>File contents charset</i> variable, "
		"this might not work for all charsets simply because not "
		"all browsers support anything except ISO-8859-1 "
		"in URLs."));

  defvar("internal_files", ({}), LOCALE(43,"Internal files"), TYPE_STRING_LIST,
	 LOCALE(44,"A list of glob patterns that matches files which should be "
		"considered internal. Internal files cannot be requested "
		"directly from a browser, won't show up in directory listings "
		"and can never be uploaded, moved or deleted by a browser."
		"They can only be accessed internally, e.g. with the RXML tags"
		" <tt>&lt;insert&gt;</tt> and <tt>&lt;use&gt;</tt>."));
}

string path, mountpoint, charset, path_encoding, normalized_path;
int stat_cache, dotfiles, access_as_user, no_symlinks, tilde;
array(string) internal_files;
UserDB access_as_user_db;
int access_as_user_throw;
void start()
{
  tilde = query("tilde");
  charset = query("charset");
  path_encoding = query("path_encoding");
  no_symlinks = query("no_symlinks");
  access_as_user = query("access_as_user");
  access_as_user_throw = query("access_as_user_throw");
  access_as_user_db =
    my_configuration()->find_user_database( query("access_as_user_db") );
  dotfiles = query(".files");
  path = query("searchpath");
  mountpoint = query("mountpoint");
  stat_cache = query("stat_cache");
  internal_files = query("internal_files");

  

#if constant(system.normalize_path)
  if (catch {
    if ((<'/','\\'>)[path[-1]]) {
      normalized_path = system.normalize_path(path + ".");
    } else {
      normalized_path = system.normalize_path(path);
    }
#ifdef __NT__
    normalized_path += "\\";
#else /* !__NT__ */
    normalized_path += "/";
#endif /* __NT__ */    
  }) {
    report_error(LOCALE(1, "Path verification of %s failed.\n"), mountpoint);
    normalized_path = path;
  }
#else /* !constant(system.normalize_path) */
  normalized_path = path;
#endif /* constant(system.normalize_path) */
  FILESYSTEM_WERR("Online at "+query("mountpoint")+" (path="+path+")");
  cache_expire("stat_cache");
}

string query_location()
{
  return mountpoint;
}


#define FILTER_INTERNAL_FILE(f, id) \
  (!id->misc->internal_get && sizeof (filter (internal_files, glob, (f/"/")[-1])))

#define SETUID(X)							\
  if( access_as_user && !id->misc->internal_get)                        \
  {									\
    User uid = id->conf->authenticate( id,access_as_user_db );		\
    if( access_as_user_throw && !uid )                                  \
       return id->conf->authenticate_throw( id, "User",access_as_user_db);\
    if( uid && uid->uid() )						\
      privs=Privs(X, uid->uid(), uid->gid() );		\
  }

#define SETUID_TRACE(X,LEVELS)						\
  if( access_as_user && !id->misc->internal_get)                        \
  {									\
    User uid = id->conf->authenticate( id,access_as_user_db );		\
    if( access_as_user_throw && !uid ) {                                 \
       int levels = (LEVELS);						\
       while(levels--) TRACE_LEAVE("");					\
       TRACE_LEAVE(X ": Auth required.");				\
       return id->conf->authenticate_throw( id, "User",access_as_user_db);\
    }									\
    if( uid && uid->uid() )						\
      privs=Privs(X, uid->uid(), uid->gid() );		\
  }

#define SETUID_NT(X)							\
  if( access_as_user && !id->misc->internal_get)                        \
  {									\
    User uid = id->conf->authenticate( id,access_as_user_db );		\
    if( uid && uid->uid() )						\
      privs=Privs(X, uid->uid(), uid->gid() );		\
  }

mixed stat_file( string f, RequestID id )
{
  Stat fs;

  FILESYSTEM_WERR("stat_file for \""+f+"\"" +
		  (id->misc->internal_get ? " (internal)" : ""));

  f = path+f;

  if (FILTER_INTERNAL_FILE (f, id))
    return 0;

  if(stat_cache && !id->pragma["no-cache"] &&
     (fs=cache_lookup("stat_cache",f)))
    return fs[0];
  object privs;
  SETUID_NT("Statting file");

  /* No security currently in this function */
  fs = file_stat(decode_path(f));
  privs = 0;
  if(!stat_cache) return fs;
  cache_set("stat_cache", f, ({fs}));
  return fs;
}

string real_file( string f, RequestID id )
{
  if(stat_file( f, id )) {
    catch {
      return NORMALIZE_PATH(decode_path(path + f));
    };
  }
}

int dir_filter_function(string f, RequestID id)
{
  if(f[0]=='.' && !dotfiles)           return 0;
  if(!tilde && Roxen.backup_extension(f))  return 0;
  return 1;
}

array(string) list_lock_files() {
  return query("nobrowse");
}

array find_dir( string f, RequestID id )
{
  array dir;

  FILESYSTEM_WERR("find_dir for \""+f+"\"" +
		  (id->misc->internal_get ? " (internal)" : ""));

  object privs;
  SETUID_NT("Read dir");

  if (catch {
    f = NORMALIZE_PATH(decode_path(path + f));
  } || !(dir = get_dir(f))) {
    privs = 0;
    return 0;
  }
  privs = 0;

  if(!query("dir"))
    // Access to this dir is allowed.
    if(! has_value(dir, ".www_browsable"))
    {
      errors++;
      return 0;
    }

  // Access to this dir is not allowed.
  if( sizeof(dir & query("nobrowse")) )
  {
    errors++;
    return 0;
  }

  dirlists++;

  // Pass _all_ files, hide none.
  if(tilde && dotfiles &&
     (!sizeof( internal_files ) || id->misc->internal_get))
    return dir;

  dir = Array.filter(dir, dir_filter_function, id);

  if (!id->misc->internal_get)
    foreach (internal_files, string globstr)
      dir -= glob (globstr, dir);

  return dir;
}


mapping putting = ([]);

void done_with_put( array(object|string) id_arr )
{
//  werror("Done with put.\n");
  object to;
  object from;
  object id;
  string oldf;

  [to, from, id, oldf] = id_arr;

  FILESYSTEM_WERR(sprintf("done_with_put(%O)\n"
			  "from: %O\n",
			  id_arr, mkmapping(indices(from), values(from))));

  to->close();
  from->set_blocking();
  m_delete(putting, from);

  if (putting[from] && (putting[from] != 0x7fffffff)) {
    // Truncated!
    id->send_result(http_low_answer(400,
				    "<h2>Bad Request - "
				    "Expected more data.</h2>"));
  } else {
    id->send_result(http_low_answer(200, "<h2>Transfer Complete.</h2>"));
  }
}

void got_put_data( array (object|string) id_arr, string data )
{
// werror(strlen(data)+" .. ");

  object to;
  object from;
  object id;
  string oldf;

  [to, from, id, oldf] = id_arr;

  // Truncate at end.
  data = data[..putting[from]];

  if (id->misc->quota_obj &&
      !id->misc->quota_obj->check_quota(oldf, sizeof(data))) {
    to->close();
    from->set_blocking();
    m_delete(putting, from);
    id->send_result(http_low_answer(413, "<h2>Out of disk quota.</h2>",
				    "413 Out of disk quota"));
    return;
  }

  int bytes = to->write( data );
  if (bytes < sizeof(data)) {
    // Out of disk!
    to->close();
    from->set_blocking();
    m_delete(putting, from);
    id->send_result(http_low_answer(413, "<h2>Disk full.</h2>"));
    return;
  } else {
    if (id->misc->quota_obj &&
	!id->misc->quota_obj->allocate(oldf, bytes)) {
      to->close();
      from->set_blocking();
      m_delete(putting, from);
      id->send_result(http_low_answer(413, "<h2>Out of disk quota.</h2>",
				      "413 Out of disk quota"));
      return;
    }
    if (putting[from] != 0x7fffffff) {
      putting[from] -= bytes;
    }
    if(putting[from] <= 0) {
      putting[from] = 0;	// Paranoia
      done_with_put( id_arr );
    }
  }
}

string decode_path( string p )
{
  if( path_encoding != "iso-8859-1" )
    p = Locale.Charset.encoder( path_encoding )->feed( p )->drain();
#ifndef __NT__
  if( String.width( p ) != 8 )
    p = string_to_utf8( p );
#else
  while( strlen(p) && p[-1] == '/' )
    p = p[..strlen(p)-2];
#endif
  return p;
}


int _file_size(string X, RequestID id)
{
  Stat fs;
  if( stat_cache )
  {
    array(Stat) cached_fs;
    if(!id->pragma["no-cache"] &&
       (cached_fs = cache_lookup("stat_cache", X)))
    {
      id->misc->stat = cached_fs[0];
      return cached_fs[0] ? cached_fs[0][ST_SIZE] : -1;
    }
  }
  if(fs = file_stat(decode_path(X)))
  {
    id->misc->stat = fs;
    if( stat_cache ) cache_set("stat_cache",(X),({fs}));
    return fs[ST_SIZE];
  } else if( stat_cache )
    cache_set("stat_cache",(X),({0}));
  return -1;
}

int contains_symlinks(string root, string path)
{
  array arr = path/"/";
  Stat rr;

  foreach(arr - ({ "" }), path) {
    root += "/" + path;
    if (rr = file_stat(decode_path(root), 1)) {
      if (rr[1] == -3) {
	return(1);
      }
    } else {
      return(0);
    }
  }
  return(0);
}

mixed find_file( string f, RequestID id )
{
  TRACE_ENTER("find_file(\""+f+"\")", 0);
  object o;
  int size;
  string tmp;
  string oldf = f;

  FILESYSTEM_WERR("Request for \""+f+"\"" +
		  (id->misc->internal_get ? " (internal)" : ""));

  /* only used for the quota system, thus rather unessesary to do for
     each request....
  */
#define URI combine_path(mountpoint + "/" + oldf, ".")

  string norm_f;

  catch {
    /* NOTE: NORMALIZE_PATH() may throw errors. */
    f = norm_f = NORMALIZE_PATH(f = decode_path(path + f));
#if constant(system.normalize_path)
    if (!has_prefix(norm_f, normalized_path) &&
#ifdef __NT__
	(norm_f+"\\" != normalized_path)
#else /* !__NT__ */
	(norm_f+"/" != normalized_path)
#endif /* __NT__ */
	) {
      errors++;
      report_error(LOCALE(52, "Path verification of %O failed:\n"
			  "%O is not a prefix of %O\n"
			  ), oldf, normalized_path, norm_f);
      TRACE_LEAVE("");
      TRACE_LEAVE("Permission denied.");
      return http_low_answer(403, "<h2>File exists, but access forbidden "
			     "by user</h2>");
    }

    /* Adjust not_query */
    id->not_query = mountpoint + replace(norm_f[sizeof(normalized_path)..],
					 "\\", "/");
    if (sizeof(oldf) && (oldf[-1] == '/')) {
      id->not_query += "/";
    }
#endif /* constant(system.normalize_path) */
  };

  size = _file_size( f, id );

  FILESYSTEM_WERR(sprintf("_file_size(%O, %O) ==> %d\n", f, id, size));

  /*
   * FIXME: Should probably move path-info extraction here.
   * 	/grubba 1998-08-26
   */

  switch(id->method)
  {
  case "GET":
  case "HEAD":
  case "POST":

    switch(-size)
    {
    case 1:
    case 3:
    case 4:
      TRACE_LEAVE("No file");
      return 0; /* Is no-file */

    case 2:
      TRACE_LEAVE("Is directory");
      return -1; /* Is dir */

    default:
      if( oldf[ -1 ] == '/' ||	/* Trying to access file with '/' appended */
	  !norm_f) {		/* Or a file that is not normalizable. */
	return 0;
      }

      if(!id->misc->internal_get) 
      {
	if (!dotfiles
	    && sizeof (tmp = (id->not_query/"/")[-1])
	    && tmp[0] == '.') 
        {
	  TRACE_LEAVE("Is .-file");
	  return 0;
	}
	if (FILTER_INTERNAL_FILE (f, id)) 
        {
	  TRACE_LEAVE ("Is internal file");
	  return 0;
	}
      }

      TRACE_ENTER("Opening file \"" + f + "\"", 0);

      object privs;
      SETUID_TRACE("Open file", 1);

      o = Stdio.File( );
      if(!o->open(norm_f, "r" )) o = 0;
      privs = 0;

      if(!o || (no_symlinks && (contains_symlinks(path, oldf))))
      {
	errors++;
	report_error(LOCALE(45,"Open of %s failed. Permission denied.\n"),f);

	TRACE_LEAVE("");
	TRACE_LEAVE("Permission denied.");
	return http_low_answer(403, "<h2>File exists, but access forbidden "
			       "by user</h2>");
      }

      id->realfile = norm_f;
      TRACE_LEAVE("");
      accesses++;
      TRACE_LEAVE("Normal return");
      if( charset != "iso-8859-1" )
      {
        if( id->misc->set_output_charset )
          id->misc->set_output_charset( charset, 2 );
        id->misc->input_charset = charset;
      }
      return o;
    }
    break;

  case "MKDIR":
    if(!query("put"))
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MKDIR disallowed (since PUT is disallowed)");
      return 0;
    }

    if (FILTER_INTERNAL_FILE (f, id)) {
      id->misc->error_code = 405;
      TRACE_LEAVE("MKDIR disallowed (since the dir name matches internal file glob)");
      return 0;
    }

    if (size != -1) {
      TRACE_LEAVE("MKDIR failed. Directory name already exists. ");
      return 0;
    }

    if(query("check_auth") && (!id->conf->authenticate( id ) ) ) {
      TRACE_LEAVE("MKDIR: Permission denied");
      return Roxen.http_auth_required("foo",
				"<h1>Permission to 'MKDIR' denied</h1>");
    }
    mkdirs++;
    object privs;
    SETUID_TRACE("Creating file", 0);

    if (query("no_symlinks") && (contains_symlinks(path, oldf))) {
      privs = 0;
      errors++;
      report_error(LOCALE(46,"Creation of %s failed. Permission denied.\n"),
		   oldf);
      TRACE_LEAVE("MKDIR: Contains symlinks. Permission denied");
      return http_low_answer(403, "<h2>Permission denied.</h2>");
    }

    int code = mkdir(f);
    privs = 0;

    TRACE_ENTER("MKDIR: Accepted", 0);

    if (code) {
      chmod(f, 0777 & ~(id->misc->umask || 022));
      TRACE_LEAVE("MKDIR: Success");
      TRACE_LEAVE("Success");
      return Roxen.http_string_answer("Ok");
    } else {
      TRACE_LEAVE("MKDIR: Failed");
      TRACE_LEAVE("Failure");
      return 0;
    }

    break;

  case "PUT":
    if(!query("put"))
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("PUT disallowed");
      return 0;
    }

    if (FILTER_INTERNAL_FILE (f, id)) {
      id->misc->error_code = 405;
      TRACE_LEAVE("PUT of internal file is disallowed");
      return 0;
    }

    if(query("check_auth") &&  (!id->conf->authenticate( id ) ) ) {
      TRACE_LEAVE("PUT: Permission denied");
      return Roxen.http_auth_required("foo",
				"<h1>Permission to 'PUT' files denied</h1>");
    }

    puts++;

    QUOTA_WERR("Checking quota.\n");
    if (id->misc->quota_obj && (id->misc->len > 0) &&
	!id->misc->quota_obj->check_quota(URI, id->misc->len)) {
      errors++;
      report_warning(LOCALE(47,"Creation of %s failed. Out of quota.\n"),f);
      TRACE_LEAVE("PUT: Out of quota.");
      return http_low_answer(413, "<h2>Out of disk quota.</h2>",
			     "413 Out of disk quota");
    }


    SETUID_TRACE("Saving file", 0);

    if (query("no_symlinks") && (contains_symlinks(path, oldf))) {
      privs = 0;
      errors++;
      report_error(LOCALE(46,"Creation of %s failed. Permission denied.\n"),f);
      TRACE_LEAVE("PUT: Contains symlinks. Permission denied");
      return http_low_answer(403, "<h2>Permission denied.</h2>");
    }

    rm(f);
    mkdirhier(f);

    if (id->misc->quota_obj) {
      QUOTA_WERR("Checking if the file already existed.");
      if (size > 0) {
	QUOTA_WERR("Deallocating " + size + "bytes.");
	id->misc->quota_obj->deallocate(URI, size);
      }
    }

    object to = open(f, "wct");
    privs = 0;

    TRACE_ENTER("PUT: Accepted", 0);

    /* Clear the stat-cache for this file */
    if (stat_cache) {
      cache_set("stat_cache", f, 0);
    }

    if(!to)
    {
      id->misc->error_code = 403;
      TRACE_LEAVE("PUT: Open failed");
      TRACE_LEAVE("Failure");
      return 0;
    }

    // FIXME: Race-condition.
    chmod(f, 0666 & ~(id->misc->umask || 022));

    putting[id->my_fd] = id->misc->len;
    if(id->data && strlen(id->data))
    {
      // FIXME: What if sizeof(id->data) > id->misc->len ?
      if (id->misc->len > 0) {
	putting[id->my_fd] -= strlen(id->data);
      }
      int bytes = to->write( id->data );
      if (id->misc->quota_obj) {
	QUOTA_WERR("Allocating " + bytes + "bytes.");
	if (!id->misc->quota_obj->allocate(f, bytes)) {
	  TRACE_LEAVE("PUT: A string");
	  TRACE_LEAVE("PUT: Out of quota");
	  return http_low_answer(413, "<h2>Out of disk quota.</h2>",
				 "413 Out of disk quota");
	}
      }
    }
    if(!putting[id->my_fd]) {
      TRACE_LEAVE("PUT: Just a string");
      TRACE_LEAVE("Put: Success");
      return Roxen.http_string_answer("Ok");
    }

    if(id->clientprot == "HTTP/1.1") {
      id->my_fd->write("HTTP/1.1 100 Continue\r\n");
    }
    id->my_fd->set_id( ({ to, id->my_fd, id, URI }) );
    id->my_fd->set_nonblocking(got_put_data, 0, done_with_put);
    TRACE_LEAVE("PUT: Pipe in progress");
    TRACE_LEAVE("PUT: Success so far");
    return Roxen.http_pipe_in_progress();
    break;

   case "CHMOD":
    // Change permission of a file.
    // FIXME: !!

    if(!query("put"))
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("CHMOD disallowed (since PUT is disallowed)");
      return 0;
    }

    if (FILTER_INTERNAL_FILE (f, id)) {
      id->misc->error_code = 405;
      TRACE_LEAVE("CHMOD of internal file is disallowed");
      return 0;
    }

    if(query("check_auth") &&  (!id->conf->authenticate( id ) ) )  {
      TRACE_LEAVE("CHMOD: Permission denied");
      return Roxen.http_auth_required("foo",
				"<h1>Permission to 'CHMOD' files denied</h1>");
    }


    SETUID_TRACE("CHMODing file", 0);

    if (query("no_symlinks") && (contains_symlinks(path, oldf))) {
      privs = 0;
      errors++;
      TRACE_LEAVE("CHMOD: Contains symlinks. Permission denied");
      return http_low_answer(403, "<h2>Permission denied.</h2>");
    }

    array err = catch(chmod(f, id->misc->mode & 0777));
    privs = 0;

    chmods++;

    TRACE_ENTER("CHMOD: Accepted", 0);

    if (stat_cache) {
      cache_set("stat_cache", f, 0);
    }

    if(err)
    {
      id->misc->error_code = 403;
      TRACE_LEAVE("CHMOD: Failure");
      TRACE_LEAVE("Failure");
      return 0;
    }
    TRACE_LEAVE("CHMOD: Success");
    TRACE_LEAVE("Success");
    return Roxen.http_string_answer("Ok");

   case "MV":
    // This little kluge is used by ftp2 to move files.

     // FIXME: Support for quota.

    if(!query("put"))
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MV disallowed (since PUT is disallowed)");
      return 0;
    }
    if(!query("delete") && size != -1)
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MV disallowed (DELE disabled, can't overwrite file)");
      return 0;
    }

    if(size < -1)
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MV: Cannot overwrite directory");
      return 0;
    }

    if(query("check_auth") && (!id->conf->authenticate( id ) ) )  {
      TRACE_LEAVE("MV: Permission denied");
      return Roxen.http_auth_required("foo",
				"<h1>Permission to 'MV' files denied</h1>");
    }
    string movefrom;
    if(!id->misc->move_from ||
       !(movefrom = id->conf->real_file(id->misc->move_from, id))) {
      id->misc->error_code = 405;
      errors++;
      TRACE_LEAVE("MV: No source file");
      return 0;
    }

    if (FILTER_INTERNAL_FILE (movefrom, id) ||
	FILTER_INTERNAL_FILE (f, id)) {
      id->misc->error_code = 405;
      TRACE_LEAVE("MV to or from internal file is disallowed");
      return 0;
    }

    SETUID_TRACE("Moving file", 0);

    if (query("no_symlinks") &&
	((contains_symlinks(path, oldf)) ||
	 (contains_symlinks(path, id->misc->move_from)))) {
      privs = 0;
      errors++;
      TRACE_LEAVE("MV: Contains symlinks. Permission denied");
      return http_low_answer(403, "<h2>Permission denied.</h2>");
    }

    code = mv(movefrom, f);
    privs = 0;

    moves++;

    TRACE_ENTER("MV: Accepted", 0);

    /* Clear the stat-cache for this file */
    if (stat_cache) {
      cache_set("stat_cache", movefrom, 0);
      cache_set("stat_cache", f, 0);
    }

    if(!code)
    {
      id->misc->error_code = 403;
      TRACE_LEAVE("MV: Move failed");
      TRACE_LEAVE("Failure");
      return 0;
    }
    TRACE_LEAVE("MV: Success");
    TRACE_LEAVE("Success");
    return Roxen.http_string_answer("Ok");

  case "MOVE":
    // This little kluge is used by NETSCAPE 4.5

    // FIXME: Support for quota.

    if(!query("put"))
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MOVE disallowed (since PUT is disallowed)");
      return 0;
    }
    if(size != -1)
    {
      id->misc->error_code = 404;
      TRACE_LEAVE("MOVE failed (no such file)");
      return 0;
    }

    if(query("check_auth") && (!id->conf->authenticate( id ) ) )  {
      TRACE_LEAVE("MOVE: Permission denied");
      return Roxen.http_auth_required("foo",
                                "<h1>Permission to 'MOVE' files denied</h1>");
    }

    if(!sizeof(id->misc["new-uri"] || "")) {
      id->misc->error_code = 405;
      errors++;
      TRACE_LEAVE("MOVE: No dest file");
      return 0;
    }
    string new_uri = combine_path(URI + "/../",
				  id->misc["new-uri"]);

    // FIXME: The code below doesn't allow for this module being overloaded.
    if (new_uri[..sizeof(mountpoint)-1] != mountpoint) {
      id->misc->error_code = 405;
      TRACE_LEAVE("MOVE: Dest file on other filesystem.");
      return(0);
    }
    string moveto = path + "/" + new_uri[sizeof(mountpoint)..];

    if (FILTER_INTERNAL_FILE (f, id) ||
	FILTER_INTERNAL_FILE (moveto, id)) {
      id->misc->error_code = 405;
      TRACE_LEAVE("MOVE to or from internal file is disallowed");
      return 0;
    }

    size = _file_size(moveto,id);

    if(!query("delete") && size != -1)
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MOVE disallowed (DELE disabled, can't overwrite file)");
      return 0;
    }

    if(size < -1)
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MOVE: Cannot overwrite directory");
      return 0;
    }

    SETUID_TRACE("Moving file", 0);

    if (query("no_symlinks") &&
        ((contains_symlinks(path, f)) ||
         (contains_symlinks(path, moveto)))) {
      privs = 0;
      errors++;
      TRACE_LEAVE("MOVE: Contains symlinks. Permission denied");
      return http_low_answer(403, "<h2>Permission denied.</h2>");
    }

    code = mv(f, decode_path(moveto));
    privs = 0;

    TRACE_ENTER("MOVE: Accepted", 0);

    moves++;

    /* Clear the stat-cache for this file */
    if (stat_cache) {
      cache_set("stat_cache", moveto, 0);
      cache_set("stat_cache", f, 0);
    }

    if(!code)
    {
      id->misc->error_code = 403;
      TRACE_LEAVE("MOVE: Move failed");
      TRACE_LEAVE("Failure");
      return 0;
    }
    TRACE_LEAVE("MOVE: Success");
    TRACE_LEAVE("Success");
    return Roxen.http_string_answer("Ok");


  case "DELETE":
    if(!query("delete") || size==-1)
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("DELETE: Disabled");
      return 0;
    }

    if (FILTER_INTERNAL_FILE (f, id)) {
      id->misc->error_code = 405;
      TRACE_LEAVE("DELETE of internal file is disallowed");
      return 0;
    }

    if(query("check_auth") && (!id->conf->authenticate( id ) ) )  {
      TRACE_LEAVE("DELETE: Permission denied");
      return http_low_answer(403, "<h1>Permission to DELETE file denied</h1>");
    }

    if (query("no_symlinks") && (contains_symlinks(path, oldf))) {
      errors++;
      report_error(LOCALE(48,"Deletion of %s failed. Permission denied.\n"),f);
      TRACE_LEAVE("DELETE: Contains symlinks");
      return http_low_answer(403, "<h2>Permission denied.</h2>");
    }

    report_notice(LOCALE(49,"DELETING the file %s.\n"),f);
    accesses++;

    SETUID_TRACE("Deleting file", 0);

    /* Clear the stat-cache for this file */
    if (stat_cache) {
      cache_set("stat_cache", f, 0);
    }

    if(!rm(f))
    {
      privs = 0;
      id->misc->error_code = 405;
      TRACE_LEAVE("DELETE: Failed");
      return 0;
    }
    privs = 0;
    deletes++;

    if (id->misc->quota_obj && (size > 0)) {
      id->misc->quota_obj->deallocate(oldf, size);
    }

    TRACE_LEAVE("DELETE: Success");
    return http_low_answer(200,(f+" DELETED from the server"));

  default:
    TRACE_LEAVE("Not supported");
    return 0;
  }
  TRACE_LEAVE("Not reached");
  return 0;
}

string query_name()
{
  return sprintf((string)LOCALE(50,"%s from %s"), mountpoint, path);
}
