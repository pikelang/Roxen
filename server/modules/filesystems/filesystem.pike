// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.

// This is a virtual "file-system".
// It will be located somewhere in the name-space of the server.
// Also inherited by some of the other filesystems.

inherit "module";
inherit "roxenlib";
inherit "socket";

constant cvs_version= "$Id: filesystem.pike,v 1.52 1999/05/05 20:19:59 grubba Exp $";
constant thread_safe=1;


#include <module.h>
#include <roxen.h>
#include <stat.h>

#if DEBUG_LEVEL > 20
# ifndef FILESYSTEM_DEBUG
#  define FILESYSTEM_DEBUG
# endif
#endif

// import Array;

#define TRACE_ENTER(A,B) do{if(id->misc->trace_enter)id->misc->trace_enter((A),(B));}while(0)
#define TRACE_LEAVE(A) do{if(id->misc->trace_leave)id->misc->trace_leave((A));}while(0)


int redirects, accesses, errors, dirlists;
int puts, deletes, mkdirs, moves, chmods;

static int do_stat = 1;

string status()
{
  return ("<h2>Accesses to this filesystem</h2>"+
	  (redirects?"<b>Redirects</b>: "+redirects+"<br>":"")+
	  (accesses?"<b>Normal files</b>: "+accesses+"<br>"
	   :"No file accesses<br>")+
	  (QUERY(put)&&puts?"<b>Puts</b>: "+puts+"<br>":"")+
	  (QUERY(put)&&mkdirs?"<b>Mkdirs</b>: "+mkdirs+"<br>":"")+
	  (QUERY(put)&&QUERY(delete)&&moves?
	   "<b>Moved files</b>: "+moves+"<br>":"")+
	  (QUERY(put)&&chmods?"<b>CHMODs</b>: "+chmods+"<br>":"")+
	  (QUERY(delete)&&deletes?"<b>Deletes</b>: "+deletes+"<br>":"")+
	  (errors?"<b>Permission denied</b>: "+errors
	   +" (not counting .htaccess)<br>":"")+
	  (dirlists?"<b>Directories</b>:"+dirlists+"<br>":""));
}

void create()
{
  defvar("mountpoint", "/", "Mount point", TYPE_LOCATION, 
	 "This is where the module will be inserted in the "+
	 "namespace of your server.");

  defvar("searchpath", "NONE", "Search path", TYPE_DIR,
	 "This is where the module will find the files in the real "+
	 "file system");

#ifdef COMPAT
  defvar("html", 0, "All files are really HTML files", TYPE_FLAG|VAR_EXPERT,
	 "If you set this variable, the filesystem will _know_ that all files "
	 "are really HTML files. This might be useful now and then.");
#endif

  defvar(".files", 0, "Show hidden files", TYPE_FLAG|VAR_MORE,
	 "If set, hidden files will be shown in dirlistings and you "
	 "will be able to retrieve them.");

  defvar("dir", 1, "Enable directory listings per default", TYPE_FLAG|VAR_MORE,
	 "If set, you have to create a file named .www_not_browsable ("
	 "or .nodiraccess) in a directory to disable directory listings."
	 " If unset, a file named .www_browsable in a directory will "
	 "_enable_ directory listings.\n");

  defvar("tilde", 0, "Show backupfiles", TYPE_FLAG|VAR_MORE,
	 "If set, files ending with '~' or '#' or '.bak' will "+
	 "be shown in directory listings");

  defvar("put", 0, "Handle the PUT method", TYPE_FLAG,
	 "If set, PUT can be used to upload files to the server.");

  defvar("delete", 0, "Handle the DELETE method", TYPE_FLAG,
	 "If set, DELETE can be used to delete files from the "
	 "server.");

  defvar("check_auth", 1, "Require authentication for modification",
	 TYPE_FLAG,
	 "Only allow authenticated users to use methods other than "
	 "GET and POST. If unset, this filesystem will be a _very_ "
	 "public one (anyone can edit files located on it)");

  defvar("stat_cache", 1, "Cache the results of stat(2)",
	 TYPE_FLAG|VAR_MORE,
	 "This can speed up the retrieval of files up to 60/70% if you"
	 " use NFS, but it does use some memory.");

  defvar("access_as_user", 0, "Access file as the logged in user",
	 TYPE_FLAG|VAR_MORE,
	 "EXPERIMENTAL. Access file as the logged in user.<br>\n"
	 "This is useful for eg named-ftp.");

  defvar("no_symlinks", 0, "Forbid access to symlinks", TYPE_FLAG|VAR_MORE,
	 "EXPERIMENTAL.\n"
	 "Forbid access to paths containing symbolic links.<br>\n"
	 "NOTE: This can cause *alot* of lstat system-calls to be performed "
	 "and can make the server much slower.");
}


mixed *register_module()
{
  return ({ 
    MODULE_LOCATION, 
    "Filesystem", 
    ("This is a virtual filesystem, use it to make files available to "+
     "the users of your WWW-server. If you want to serve any 'normal' "
      "files from your server, you will have to have atleast one filesystem.") 
    });
}

string path;
int stat_cache;

void start()
{
#ifdef THREADS
  if(QUERY(access_as_user))
    report_warning("It is not possible to use 'Access as user' when "
		   "running with threads. Remove -DENABLE_THREADS from "
		   "the start script if you really need this function\n");
#endif
     
  path = QUERY(searchpath);
  stat_cache = QUERY(stat_cache);
#ifdef FILESYSTEM_DEBUG
  perror("FILESYSTEM: Online at "+QUERY(mountpoint)+" (path="+path+")\n");
#endif
}

string query_location()
{
  return QUERY(mountpoint);
}


mixed stat_file( mixed f, mixed id )
{
  array fs;
  if(stat_cache && !id->pragma["no-cache"] &&
     (fs=cache_lookup("stat_cache",path+f)))
    return fs[0];

#ifndef THREADS
  object privs;
  if (((int)id->misc->uid) && ((int)id->misc->gid) &&
      (QUERY(access_as_user))) {
    // NB: Root-access is prevented.
    privs=Privs("Statting file", (int)id->misc->uid, (int)id->misc->gid );
  }
#endif

  fs = file_stat(path + f);  /* No security currently in this function */
#ifndef THREADS
  privs = 0;
#endif
  if(!stat_cache)
    return fs;
  cache_set("stat_cache", path+f, ({fs}));
  return fs;
}

string real_file( mixed f, mixed id )
{
  if(this->stat_file( f, id )) 
/* This filesystem might be inherited by other filesystem, therefore
   'this'  */
    return path + f;
}

int dir_filter_function(string f)
{
  if(f[0]=='.' && !QUERY(.files))           return 0;
  if(!QUERY(tilde) && backup_extension(f))  return 0;
  return 1;
}

array find_dir( string f, object id )
{
  mixed ret;
  array dir;

  object privs;

#ifndef THREADS
  if (((int)id->misc->uid) && ((int)id->misc->gid) &&
      (QUERY(access_as_user))) {
    // NB: Root-access is prevented.
    privs=Privs("Getting dir", (int)id->misc->uid, (int)id->misc->gid );
  }
#endif

  if(!(dir = get_dir( path + f ))) {
    privs = 0;
    return 0;
  }
  privs = 0;

  if(!QUERY(dir))
    // Access to this dir is allowed.
    if(search(dir, ".www_browsable") == -1)
    {
      errors++;
      return 0;
    }

  // Access to this dir is not allowed.
  if(sizeof(dir & ({".nodiraccess",".www_not_browsable",".nodir_access"})))
  {
    errors++;
    return 0;
  }

  dirlists++;

  // Pass _all_ files, hide none.
  if(QUERY(tilde) && QUERY(.files)) /* This is quite a lot faster */
    return dir;

  return Array.filter(dir, dir_filter_function);
}


mapping putting = ([]);

void done_with_put( array(object|string) id_arr )
{
//  perror("Done with put.\n");
  object to;
  object from;
  object id;
  string oldf;

  [to, from, id, oldf] = id_arr;

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
// perror(strlen(data)+" .. ");

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
    id->send_result(http_low_answer(413, "<h2>Out of disk quota.</h2>"));
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
      id->send_result(http_low_answer(413, "<h2>Out of disk quota.</h2>"));
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

int _file_size(string X,object id)
{
  array fs;
  if(!id->pragma["no-cache"]&&(fs=cache_lookup("stat_cache",(X))))
  {
    id->misc->stat = fs[0];
    return fs[0]?fs[0][ST_SIZE]:-1;
  }
  if(fs = file_stat(X))
  {
    id->misc->stat = fs;
    cache_set("stat_cache",(X),({fs}));
    return fs[ST_SIZE];
  } else
    cache_set("stat_cache",(X),({0}));
  return -1;
}

#define FILE_SIZE(X) (stat_cache?_file_size((X),id):Stdio.file_size(X))

int contains_symlinks(string root, string path)
{
  array arr = path/"/";

  foreach(arr - ({ "" }), path) {
    root += "/" + path;
    if (arr = file_stat(root, 1)) {
      if (arr[1] == -3) {
	return(1);
      }
    } else {
      return(0);
    }
  }
  return(0);
}

mixed find_file( string f, object id )
{
  TRACE_ENTER("find_file(\""+f+"\")", 0);

  object o;
  int size;
  string tmp;
  string oldf = f;

#ifdef FILESYSTEM_DEBUG
  roxen_perror("FILESYSTEM: Request for \""+f+"\"\n");
#endif /* FILESYSTEM_DEBUG */

  f = path + f;
#ifdef __NT__
  if(f[-1]=='/') f = f[..strlen(f)-2];
#endif
  size = FILE_SIZE( f );

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
      if(f[ -1 ] == '/') /* Trying to access file with '/' appended */
      {
	/* Neotron was here. I changed this to always return 0 since
	 * CGI-scripts with path info = / won't work otherwise. If
	 * someone accesses a file with "/" appended, a 404 no such
	 * file isn't that weird. Both Apache and Netscape return the
	 * accessed page, resulting in incorrect links from that page.
	 *
	 * FIXME: The proper way to do this would probably be to set path info
	 *   here, and have the redirect be done by the extension modules,
	 *   or by the protocol module if there isn't any extension module.
	 *	/grubba 1998-08-26
	 */
	return 0; 
	/* Do not try redirect on top level directory */
	if(sizeof(id->not_query) < 2)
	  return 0;
	redirects++;

	// Note: Keep the query part.
	/* FIXME: Should probably keep prestates etc too.
	 *	/grubba 1999-01-14
	 */
	string new_query =
	  http_encode_string(id->not_query[..sizeof(id->not_query)-2]) +
	  (id->query?("?" + id->query):"");
	TRACE_LEAVE("Redirecting to \"" + new_query + "\"");
	return http_redirect(new_query, id);
      }

      if(!id->misc->internal_get && QUERY(.files)
	 && (tmp = (id->not_query/"/")[-1])
	 && tmp[0] == '.') {
	TRACE_LEAVE("Is .-file");
	return 0;
      }
#ifndef THREADS
      object privs;
      if (((int)id->misc->uid) && ((int)id->misc->gid) &&
	  (QUERY(access_as_user))) {
	// NB: Root-access is prevented.
	privs=Privs("Getting file", (int)id->misc->uid, (int)id->misc->gid );
      }
#endif

      TRACE_ENTER("Opening file \"" + f + "\"", 0);
      o = open( f, "r" );

#ifndef THREADS
      privs = 0;
#endif

      if(!o || (QUERY(no_symlinks) && (contains_symlinks(path, oldf))))
      {
	errors++;
	report_error("Open of " + f + " failed. Permission denied.\n");
	
	TRACE_LEAVE("");
	TRACE_LEAVE("Permission denied.");
	return http_low_answer(403, "<h2>File exists, but access forbidden "
			       "by user</h2>");
      }

      id->realfile = f;
      TRACE_LEAVE("");
      accesses++;
#ifdef COMPAT
      if(QUERY(html)) {/* Not very likely, really.. */
	TRACE_LEAVE("Compat return");
	return ([ "type":"text/html", "file":o, ]);
      }
#endif
      TRACE_LEAVE("Normal return");
      return o;
    }
    break;
  
  case "MKDIR":
    if(!QUERY(put))
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MKDIR disallowed (since PUT is disallowed)");
      return 0;
    }    

    if(QUERY(check_auth) && (!id->auth || !id->auth[0])) {
      TRACE_LEAVE("MKDIR: Permission denied");
      return http_auth_required("foo",
				"<h1>Permission to 'MKDIR' denied</h1>");
    }
    mkdirs++;
    object privs;

// #ifndef THREADS // Ouch. This is is _needed_. Well well...
    if (((int)id->misc->uid) && ((int)id->misc->gid)) {
      // NB: Root-access is prevented.
      privs=Privs("Creating directory",
		  (int)id->misc->uid, (int)id->misc->gid );
    }
// #endif

    if (QUERY(no_symlinks) && (contains_symlinks(path, oldf))) {
      privs = 0;
      errors++;
      report_error("Creation of " + f + " failed. Permission denied.\n");
      TRACE_LEAVE("MKDIR: Contains symlinks. Permission denied");
      return http_low_answer(403, "<h2>Permission denied.</h2>");
    }

    TRACE_ENTER("MKDIR: Accepted", 0);

    int code = mkdir( f );

    privs = 0;
    if (code) {
      chmod(f, 0777 & ~(id->misc->umask || 022));
      TRACE_LEAVE("MKDIR: Success");
      TRACE_LEAVE("Success");
      return http_string_answer("Ok");
    } else {
      TRACE_LEAVE("MKDIR: Failed");
      TRACE_LEAVE("Failure");
      return 0;
    }

    break;

  case "PUT":
    if(!QUERY(put))
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("PUT disallowed");
      return 0;
    }    

    if(QUERY(check_auth) && (!id->auth || !id->auth[0])) {
      TRACE_LEAVE("PUT: Permission denied");
      return http_auth_required("foo",
				"<h1>Permission to 'PUT' files denied</h1>");
    }

    puts++;

#ifdef QUOTA_DEBUG
    report_debug("Checking quota.\n");
#endif /* QUOTA_DEBUG */
    if (id->misc->quota_obj &&
	!id->misc->quota_obj->check_quota(oldf, id->misc->len)) {
      errors++;
      report_warning("Creation of " + f + " failed. Out of quota.\n");
      TRACE_LEAVE("PUT: Out of quota.");
      return http_low_answer(413, "<h2>Out of quota.</h2>");
    }
    
    object privs;

// #ifndef THREADS // Ouch. This is is _needed_. Well well...
    if (((int)id->misc->uid) && ((int)id->misc->gid)) {
      // NB: Root-access is prevented.
      privs=Privs("Saving file", (int)id->misc->uid, (int)id->misc->gid );
    }
// #endif

    if (QUERY(no_symlinks) && (contains_symlinks(path, oldf))) {
      privs = 0;
      errors++;
      report_error("Creation of " + f + " failed. Permission denied.\n");
      TRACE_LEAVE("PUT: Contains symlinks. Permission denied");
      return http_low_answer(403, "<h2>Permission denied.</h2>");
    }

    TRACE_ENTER("PUT: Accepted", 0);

    rm( f );
    mkdirhier( f );

    if (id->misc->quota_obj) {
#ifdef QUOTA_DEBUG
      report_debug("Checking if the file already exists.\n");
#endif /* QUOTA_DEBUG */
      if (size > 0) {
#ifdef QUOTA_DEBUG
	report_debug("Deallocating " + size + "bytes.\n");
#endif /* QUOTA_DEBUG */
	id->misc->quota_obj->deallocate(oldf, size);
      }
      if (size) {
#ifdef QUOTA_DEBUG
	report_debug("Deleting old file.\n");
#endif /* QUOTA_DEBUG */
	rm(f);
      }
    }

    /* Clear the stat-cache for this file */
    if (stat_cache) {
      cache_set("stat_cache", f, 0);
    }

    object to = open(f, "wct");
    
    privs = 0;

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
#ifdef QUOTA_DEBUG
	report_debug("Allocating " + bytes + "bytes.\n");
#endif /* QUOTA_DEBUG */
	if (!id->misc->quota_obj->allocate(f, bytes)) {
	  TRACE_LEAVE("PUT: A string");
	  TRACE_LEAVE("PUT: Out of quota");
	  return http_low_answer(413, "<h2>Out of quota.</h2>");
	}
      }
    }
    if(!putting[id->my_fd]) {
      TRACE_LEAVE("PUT: Just a string");
      TRACE_LEAVE("Put: Success");
      return http_string_answer("Ok");
    }

    if(id->clientprot == "HTTP/1.1") {
      id->my_fd->write("HTTP/1.1 100 Continue\r\n");
    }
    id->my_fd->set_id( ({ to, id->my_fd, id, oldf }) );
    id->my_fd->set_nonblocking(got_put_data, 0, done_with_put);
    TRACE_LEAVE("PUT: Pipe in progress");
    TRACE_LEAVE("PUT: Success so far");
    return http_pipe_in_progress();
    break;

   case "CHMOD":
    // Change permission of a file. 
    
    if(!QUERY(put))
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("CHMOD disallowed (since PUT is disallowed)");
      return 0;
    }    

    if(QUERY(check_auth) && (!id->auth || !id->auth[0])) {
      TRACE_LEAVE("CHMOD: Permission denied");
      return http_auth_required("foo",
				"<h1>Permission to 'CHMOD' files denied</h1>");
    }
    
    object privs;
    
// #ifndef THREADS // Ouch. This is is _needed_. Well well...
    if (((int)id->misc->uid) && ((int)id->misc->gid)) {
      // NB: Root-access is prevented.
      privs=Privs("CHMODing file", (int)id->misc->uid, (int)id->misc->gid );
    }
    // #endif
    
    if (QUERY(no_symlinks) && (contains_symlinks(path, oldf))) {
      privs = 0;
      errors++;
      TRACE_LEAVE("CHMOD: Contains symlinks. Permission denied");
      return http_low_answer(403, "<h2>Permission denied.</h2>");
    }

    chmods++;

    TRACE_ENTER("CHMOD: Accepted", 0);

    if (stat_cache) {
      cache_set("stat_cache", f, 0);
    }
#ifdef DEBUG
    report_notice(sprintf("CHMODing file "+f+" to 0%o\n", id->misc->mode));
#endif
    array err = catch(chmod(f, id->misc->mode & 0777));
    privs = 0;
    
    if(err)
    {
      id->misc->error_code = 403;
      TRACE_LEAVE("CHMOD: Failure");
      TRACE_LEAVE("Failure");
      return 0;
    }
    TRACE_LEAVE("CHMOD: Success");
    TRACE_LEAVE("Success");
    return http_string_answer("Ok");
    
   case "MV":
    // This little kluge is used by ftp2 to move files. 
    
     // FIXME: Support for quota.

    if(!QUERY(put))
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MV disallowed (since PUT is disallowed)");
      return 0;
    }    
    if(!QUERY(delete) && size != -1)
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

    if(QUERY(check_auth) && (!id->auth || !id->auth[0])) {
      TRACE_LEAVE("MV: Permission denied");
      return http_auth_required("foo",
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
    moves++;
    
    object privs;
    
// #ifndef THREADS // Ouch. This is is _needed_. Well well...
    if (((int)id->misc->uid) && ((int)id->misc->gid)) {
      // NB: Root-access is prevented.
      privs=Privs("Moving file", (int)id->misc->uid, (int)id->misc->gid );
    }
// #endif
    
    if (QUERY(no_symlinks) &&
	((contains_symlinks(path, oldf)) ||
	 (contains_symlinks(path, id->misc->move_from)))) {
      privs = 0;
      errors++;
      TRACE_LEAVE("MV: Contains symlinks. Permission denied");
      return http_low_answer(403, "<h2>Permission denied.</h2>");
    }

    TRACE_ENTER("MV: Accepted", 0);

    /* Clear the stat-cache for this file */
#ifdef __NT__
    //    if(movefrom[-1] == '/')
    //      movefrom = move_from[..strlen(movefrom)-2];
#endif
    if (stat_cache) {
      cache_set("stat_cache", movefrom, 0);
      cache_set("stat_cache", f, 0);
    }
#ifdef DEBUG
    report_notice("Moving file "+movefrom+" to "+ f+"\n");
#endif /* DEBUG */

    int code = mv(movefrom, f);
    privs = 0;

    if(!code)
    {
      id->misc->error_code = 403;
      TRACE_LEAVE("MV: Move failed");
      TRACE_LEAVE("Failure");
      return 0;
    }
    TRACE_LEAVE("MV: Success");
    TRACE_LEAVE("Success");
    return http_string_answer("Ok");

  case "MOVE":
    // This little kluge is used by NETSCAPE 4.5

    // FIXME: Support for quota.
     
    if(!QUERY(put))
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

    if(QUERY(check_auth) && (!id->auth || !id->auth[0])) {
      TRACE_LEAVE("MOVE: Permission denied");
      return http_auth_required("foo",
                                "<h1>Permission to 'MOVE' files denied</h1>");
    }

    if(!sizeof(id->misc["new-uri"] || "")) { 
      id->misc->error_code = 405;
      errors++;
      TRACE_LEAVE("MOVE: No dest file");
      return 0;
    }
    string mountpoint = QUERY(mountpoint);
    string moveto = combine_path(mountpoint + "/" + oldf + "/..",
				 id->misc["new-uri"]);

    if (moveto[..sizeof(mountpoint)-1] != mountpoint) {
      id->misc->error_code = 405;
      TRACE_LEAVE("MOVE: Dest file on other filesystem.");
      return(0);
    }
    moveto = path + moveto[sizeof(mountpoint)..];

    size = FILE_SIZE(moveto);

    if(!QUERY(delete) && size != -1)
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

    object privs;

// #ifndef THREADS // Ouch. This is is _needed_. Well well...
    if (((int)id->misc->uid) && ((int)id->misc->gid)) {
      // NB: Root-access is prevented.
      privs=Privs("Moving file", (int)id->misc->uid, (int)id->misc->gid );
    }
// #endif

    if (QUERY(no_symlinks) &&
        ((contains_symlinks(path, f)) ||
         (contains_symlinks(path, moveto)))) {
      privs = 0;
      errors++;
      TRACE_LEAVE("MOVE: Contains symlinks. Permission denied");
      return http_low_answer(403, "<h2>Permission denied.</h2>");
    }

    TRACE_ENTER("MOVE: Accepted", 0);

    moves++;

    /* Clear the stat-cache for this file */
#ifdef __NT__
    //    if(movefrom[-1] == '/')
    //      movefrom = move_from[..strlen(movefrom)-2];
#endif
    if (stat_cache) {
      cache_set("stat_cache", moveto, 0);
      cache_set("stat_cache", f, 0);
    }
#ifdef DEBUG
    report_notice("Moving file " + f + " to " + moveto + "\n");
#endif /* DEBUG */

    int code = mv(f, moveto);
    privs = 0;

    if(!code)
    {
      id->misc->error_code = 403;
      TRACE_LEAVE("MOVE: Move failed");
      TRACE_LEAVE("Failure");
      return 0;
    }
    TRACE_LEAVE("MOVE: Success");
    TRACE_LEAVE("Success");
    return http_string_answer("Ok");

   
  case "DELETE":
    if(!QUERY(delete) || size==-1)
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("DELETE: Disabled");
      return 0;
    }
    if(QUERY(check_auth) && (!id->auth || !id->auth[0])) {
      TRACE_LEAVE("DELETE: Permission denied");
      return http_low_answer(403, "<h1>Permission to DELETE file denied</h1>");
    }

    if (QUERY(no_symlinks) && (contains_symlinks(path, oldf))) {
      errors++;
      report_error("Deletion of " + f + " failed. Permission denied.\n");
      TRACE_LEAVE("DELETE: Contains symlinks");
      return http_low_answer(403, "<h2>Permission denied.</h2>");
    }

    report_notice("DELETING the file "+f+"\n");
    accesses++;

    if (((int)id->misc->uid) && ((int)id->misc->gid)) {
      // NB: Root-access is prevented.
      privs=Privs("Deleting file", id->misc->uid, id->misc->gid );
    }

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

    if (id->misc->quota_obj) {
      id->misc->quota_obj->deallocate(oldf, size);
    }

    TRACE_LEAVE("DELETE: Success");
    return http_low_answer(200,(f+" DELETED from the server"));

  default:
    TRACE_LEAVE("Not supported");
    return 0;
  }
  report_error("Not reached..\n");
  TRACE_LEAVE("Not reached");
  return 0;
}

string query_name()
{
  return sprintf("<i>%s</i> mounted on <i>%s</i>", query("searchpath"),
		 query("mountpoint"));
}
