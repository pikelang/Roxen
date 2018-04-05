// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.

// This is a virtual "file-system".
// It will be located somewhere in the name-space of the server.
// Also inherited by some of the other filesystems.

inherit "module";
inherit "socket";

constant cvs_version= "$Id$";
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

#if constant(System.normalize_path)
#define NORMALIZE_PATH(X)	System.normalize_path(X)
#else /* !constant(System.normalize_path) */
#define NORMALIZE_PATH(X)	(X)
#endif /* constant(System.normalize_path) */

constant module_type = MODULE_LOCATION;
LocaleString module_name = LOCALE(51,"File systems: Normal File system");
LocaleString module_doc =
LOCALE(2,"This is the basic file system module that makes it possible "
       "to mount a directory structure in the virtual file system of "
       "your site.");
constant module_unique = 0;

int redirects, accesses, errors, dirlists;
int puts, deletes, mkdirs, moves, chmods;

protected mapping http_low_answer(int errno, string data, string|void desc)
{
  mapping res = Roxen.http_low_answer(errno, data);

  if (desc) {
    res->rettext = desc;
  }

  return res;
}

// Note: This does a TRACE_LEAVE.
protected mapping(string:mixed) errno_to_status (int err, int(0..1) create,
						 RequestID id)
{
  switch (err) {
    case System.ENOENT:
      if (!create) {
	SIMPLE_TRACE_LEAVE ("File not found");
	id->misc->error_code = Protocols.HTTP.HTTP_NOT_FOUND;
	return 0;
      }
      // Fall through.

    case System.ENOTDIR:
      TRACE_LEAVE(sprintf("%s: Missing intermediate.", id->method));
      id->misc->error_code = Protocols.HTTP.HTTP_CONFLICT;
      return 0;

    case System.ENOSPC:
      SIMPLE_TRACE_LEAVE("%s: Insufficient space", id->method);
      return Roxen.http_status (Protocols.HTTP.DAV_STORAGE_FULL);

    case System.EPERM:
      TRACE_LEAVE(sprintf("%s: Permission denied", id->method));
      return Roxen.http_status(Protocols.HTTP.HTTP_FORBIDDEN,
			       "Permission denied.");

    case System.EEXIST:
      TRACE_LEAVE(sprintf("%s failed. Directory name already exists. ",
			  id->method));
      // FIXME: More methods are probably allowed, but what use is
      // that header anyway?
      return Roxen.http_method_not_allowed("GET, HEAD",
					   "Collection already exists.");

#if constant(System.ENAMETOOLONG)
    case System.ENAMETOOLONG:
      SIMPLE_TRACE_LEAVE ("Path too long");
      return Roxen.http_status (Protocols.HTTP.HTTP_URI_TOO_LONG);
#endif

    default:
      SIMPLE_TRACE_LEAVE ("Unexpected I/O error: %s", strerror (err));
      return Roxen.http_status (Protocols.HTTP.HTTP_INTERNAL_ERR,
				"Unexpected I/O error: %s",
				strerror (err));
  }
}

protected int do_stat = 1;

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

  defvar("no-parse", 0, LOCALE(65, "Raw files"), TYPE_FLAG|VAR_MORE,
	 LOCALE(66, "If set files from this filesystem will be returned "
		"without any further processing. This disables eg RXML "
		"parsing of files."));

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
  path = encode_path(query("searchpath"));
  mountpoint = query("mountpoint");
  stat_cache = query("stat_cache");
  internal_files = map(query("internal_files"), encode_path);

  

#if constant(System.normalize_path)
  if (catch {
    if ((<'/','\\'>)[path[-1]]) {
      normalized_path = System.normalize_path(path + ".");
    } else {
      normalized_path = System.normalize_path(path);
    }
  }) {
    report_error(LOCALE(1, "Path verification of %s failed.\n"), mountpoint);
    normalized_path = path;
  }
#else /* !constant(System.normalize_path) */
  normalized_path = path;
#endif /* constant(System.normalize_path) */
  if ((normalized_path == "") || !(<'/','\\'>)[normalized_path[-1]]) {
#ifdef __NT__
    normalized_path += "\\";
#else /* !__NT__ */
    normalized_path += "/";
#endif /* __NT__ */    
  }
  FILESYSTEM_WERR("Online at "+query("mountpoint")+" (path="+path+")");
  cache_expire("stat_cache");
}

string query_location()
{
  return mountpoint;
}

ADT.Trie query_snmp_mib(array(int) base_oid, array(int) oid_suffix)
{
  return SNMP.SimpleMIB(base_oid, oid_suffix,
			({
			  UNDEFINED,
			  SNMP.String(query_location, "location",
				      "Mount point in the virtual filesystem."),
			  SNMP.String(query_name, "name"),
			  SNMP.String(lambda() {
					return query("charset");
				      }, "charset"),
			  SNMP.Counter(lambda() {
					 return accesses;
				       }, "accesses"),
			  SNMP.Counter(lambda() {
					 return errors;
				       }, "errors"),
			  SNMP.Counter(lambda() {
					 return redirects;
				       }, "redirects"),
			  SNMP.Counter(lambda() {
					 return dirlists;
				       }, "dirlists"),
			  SNMP.Counter(lambda() {
					 return puts;
				       }, "puts"),
			  SNMP.Counter(lambda() {
					 return mkdirs;
				       }, "mkdirs"),
			  SNMP.Counter(lambda() {
					 return moves;
				       }, "moves"),
			  SNMP.Counter(lambda() {
					 return chmods;
				       }, "chmods"),
			  SNMP.Counter(lambda() {
					 return deletes;
				       }, "deletes"),
			}));
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
  if( access_as_user && !id->misc->internal_get )                       \
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

  f = path + encode_path(f);

  if (FILTER_INTERNAL_FILE (f, id))
    return 0;

  if(stat_cache && !id->pragma["no-cache"] &&
     (fs=cache_lookup("stat_cache",f)))
    return fs[0];
  object privs;
  SETUID_NT("Statting file");

  /* No security currently in this function */
  fs = file_stat(f);
  privs = 0;
  if(!stat_cache) return fs;
  cache_set("stat_cache", f, ({fs}));
  return fs;
}

//! Convert to filesystem encoding.
//!
//! @note
//!   Note that the @expr{"iso-8859-1"@} encoding will perform
//!   conversion to utf-8 for wide strings OSes other than NT.
string encode_path( string p )
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

//! Convert from filesystem encoding.
string decode_path(string p)
{
#ifdef __NT__
  // The filesystem on NT uses wide characters.
  return p;
#else
  // While filesystems on other OSes typically are 8bit.
  switch(lower_case(path_encoding)) {
  case "iso-8859-1":
    return p;
  case "utf8": case "utf-8":
    // NB: We assume that the filesystem will normalize
    //     the path as appropriate.
    return Unicode.normalize(utf8_to_string(p), "NFC");
  default:
    return Charset.decoder(path_encoding)->feed(p)->drain();
  }
#endif /* !__NT__ */
}

string real_path(string f, RequestID id)
{
  f = normalized_path + encode_path(f);
  if (FILTER_INTERNAL_FILE(f, id)) return 0;
  catch {
    f = NORMALIZE_PATH(f);
    if (has_prefix(f, normalized_path) ||
#ifdef __NT__
	(f+"\\" == normalized_path)
#else /* !__NT__ */
	(f+"/" == normalized_path)
#endif /* __NT__ */
	) {
      return f;
    }
  };
  return 0;
}

string real_file( string f, RequestID id )
{
  if(stat_file( f, id )) {
    return real_path(f, id);
  }
}

// We support locking if put is enabled.
mapping(string:mixed) lock_file(string path, DAVLock lock, RequestID id)
{
  if (!query("put")) return 0;
  if (query("check_auth") && (!id->conf->authenticate( id )) ) {
    TRACE_LEAVE("LOCK: Permission denied");
    return
      // FIXME: Sane realm.
      Roxen.http_auth_required("foo",
			       "<h1>Permission to 'LOCK' files denied</h1>",
			       id);
  }
  register_lock(path, lock, id);
  return 0;
}

mapping(string:mixed) unlock_file(string path, DAVLock lock, RequestID|int(0..0) id)
{
  if (!query("put")) return 0;
  if (id && query("check_auth") && (!id->conf->authenticate( id )) ) {
    TRACE_LEAVE("UNLOCK: Permission denied");
    return
      // FIXME: Sane realm.
      Roxen.http_auth_required("foo",
			       "<h1>Permission to 'UNLOCK' files denied</h1>",
			       id);
  }
  unregister_lock(path, lock, id);
  return 0;
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

protected variant mapping(string:mixed)|int(0..1) write_access(string path,
							       int(0..1) recursive,
							       RequestID id)
{
  SIMPLE_TRACE_ENTER(this, "write_access(%O, %O, %O)\n", path, recursive, id);
  if(query("check_auth") && (!id->conf->authenticate( id ) ) ) {
    SIMPLE_TRACE_LEAVE("%s: Authentication required.", id->method);
    // FIXME: Sane realm.
    // FIXME: Recursion and htaccess?
    return
      Roxen.http_auth_required("foo",
			       sprintf("<h1>Permission to '%s' denied</h1>",
				       id->method), id);
  }
  TRACE_LEAVE("Fall back to the default write access checks.");
  return ::write_access(encode_path(path), recursive, id);
}

array find_dir( string f, RequestID id )
{
  array dir;

  FILESYSTEM_WERR("find_dir for \""+f+"\"" +
		  (id->misc->internal_get ? " (internal)" : ""));

  object privs;
  SETUID_NT("Read dir");

  if (catch {
    f = NORMALIZE_PATH(path + encode_path(f));
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

  if (path_encoding != "iso-8859-1") {
    dir = map(dir, decode_path);
  }

  if (!id->misc->internal_get)
    foreach (internal_files, string globstr)
      dir -= glob (globstr, dir);

  return dir;
}

void recursive_rm(string real_dir, string virt_dir,
		  int(0..1) check_status_needed, RequestID id)
{
  SIMPLE_TRACE_ENTER(this, "Deleting all files in directory %O...", real_dir);
  foreach(get_dir(real_dir) || ({}), string fname) {
    string real_fname = combine_path(real_dir, fname);
    string virt_fname = virt_dir + "/" + decode_path(fname);

    Stat stat = file_stat(real_fname);
    SIMPLE_TRACE_ENTER(this, "Deleting %s %O.",
		       stat?(stat->isdir?"directory":"file"):"missing",
		       real_fname);
    if (!stat) {
      id->set_status_for_path(virt_fname, 404);
      TRACE_LEAVE("File not found.");
      continue;
    }
    if (stat->isdir) {
      virt_fname += "/";
    }
    int(0..1)|mapping sub_status;
    if (mappingp(sub_status = write_access(virt_fname, 1, id))) {
      id->set_status_for_path(virt_fname, sub_status->error);
      TRACE_LEAVE("Write access denied.");
      continue;
    }
    if (stat->isdir) {
      recursive_rm(real_fname, virt_fname, sub_status, id);
    }

    /* Clear the stat-cache for this file */
    if (stat_cache) {
      cache_set("stat_cache", real_fname, 0);
    }

    if (!rm(real_fname)) {
#if constant(System.EEXIST)
      if (errno() != System.EEXIST)
#endif
      {
	id->set_status_for_path(virt_fname, 403);
	TRACE_LEAVE("Deletion failed.");
      }
#if constant(System.EEXIST)
      else {
	TRACE_LEAVE("Directory not empty.");
      }
#endif
    } else {
      deletes++;

      unlock_path(virt_fname, id);

      if (id->misc->quota_obj && stat->isreg()) {
	id->misc->quota_obj->deallocate(virt_fname,
					stat->size());
      }
      TRACE_LEAVE("Ok.");
    }
  }
  TRACE_LEAVE("Done.");
}

mapping putting = ([]);

void done_with_put( array(object|string|int) id_arr )
{
//  werror("Done with put.\n");
  object to;
  object from;
  object id;
  string oldf;
  int size;

  [to, from, id, oldf, size] = id_arr;

  FILESYSTEM_WERR(sprintf("done_with_put(%O)\n"
			  "from: %O\n",
			  id_arr, mkmapping(indices(from), values(from))));

  to->close();
  from->set_blocking();
  m_delete(putting, from);

  if (putting[from] && (putting[from] != 0x7fffffff)) {
    // Truncated!
    id->send_result(Roxen.http_status(400,
				      "Bad Request - "
				      "Expected more data."));
  } else {
    id->send_result(Roxen.http_status((size < 0)?201:200,
				      "Transfer Complete."));
  }
}

void got_put_data( array(object|string|int) id_arr, string data )
{
// werror(strlen(data)+" .. ");

  object to;
  object from;
  object id;
  string oldf;
  int size;

  [to, from, id, oldf, size] = id_arr;

  // Truncate at end.
  data = data[..putting[from]];

  if (id->misc->quota_obj &&
      !id->misc->quota_obj->check_quota(oldf, sizeof(data))) {
    to->close();
    from->set_blocking();
    m_delete(putting, from);
    id->send_result(Roxen.http_status(507, "Out of disk quota."));
    return;
  }

  int bytes = to->write( data );
  if (bytes < sizeof(data)) {
    // Out of disk!
    to->close();
    from->set_blocking();
    m_delete(putting, from);
    id->send_result(Roxen.http_status(507, "Disk full."));
    return;
  } else {
    if (id->misc->quota_obj &&
	!id->misc->quota_obj->allocate(oldf, bytes)) {
      to->close();
      from->set_blocking();
      m_delete(putting, from);
      id->send_result(Roxen.http_status(507, "Out of disk quota."));
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

int _file_size(string X, RequestID id)
{
  Stat fs;
  X = path + encode_path(X);
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
  if(fs = file_stat(X))
  {
    id->misc->stat = fs;
    if( stat_cache ) cache_set("stat_cache",(X),({fs}));
    return fs[ST_SIZE];
  } else if( stat_cache )
    cache_set("stat_cache",(X),({0}));
  return -1;
}

//! Return @expr{1@} if the (virtual) @[path] from
//! the (real) @[root] follows symbolic links.
int contains_symlinks(string root, string path)
{
  if (has_suffix(root, "/")) {
    root = root[..<1];
  }
  foreach(path/"/" - ({ "" }), path) {
    root += "/" + encode_path(path);
    Stat rr;
    if (rr = file_stat(root, 1)) {
      if (rr[1] == -3) {
	return(1);
      }
    } else {
      return(0);
    }
  }
  return(0);
}

//! @[chmod()] that doesn't throw errors.
string safe_chmod(string path, int mask)
{
  return describe_error(catch {
      chmod(path, mask);
      return 0;
    });
}

mapping make_collection(string coll, RequestID id)
{
  TRACE_ENTER(sprintf("make_collection(%O)", coll), this_object());

  string norm_f = real_path(coll, id);

  if (!norm_f) {
    TRACE_LEAVE(sprintf("%s: Bad path", id->method));
    return Roxen.http_status(405, "Bad path.");
  }

  if(!query("put"))
  {
    TRACE_LEAVE(sprintf("%s disallowed (since PUT is disallowed)",
			id->method));
    return Roxen.http_status(405, "Disallowed.");
  }

  int size = _file_size(coll, id);

  if (size != -1) {
    TRACE_LEAVE(sprintf("%s failed. Directory name already exists. ",
			id->method));
    if (id->method == "MKCOL") {
      return Roxen.http_status(405,
			       "Collection already exists.");
    }
    return 0;
  }

  // Disallow if the name is locked, or if the parent directory is locked.
  mapping(string:mixed) ret =
    write_access(({coll + "/", combine_path(coll, "../")}), 0, id);
  if (ret) return ret;

  mkdirs++;
  object privs;
  SETUID_TRACE("Creating directory/collection", 0);

  if (query("no_symlinks") && (contains_symlinks(path, coll))) {
    privs = 0;
    errors++;
    report_error(LOCALE(46,"Creation of %O failed. Permission denied.\n"),
		 coll);
    TRACE_LEAVE(sprintf("%s: Contains symlinks. Permission denied",
			id->method));
    return Roxen.http_status(403, "Permission denied.");
  }

  int code = mkdir(norm_f);
  int err_code = errno();

  TRACE_ENTER(sprintf("%s: Accepted", id->method), 0);

  if (code) {
    string msg = safe_chmod(norm_f, 0777 & ~(id->misc->umask || 022));
    privs = 0;
    if (msg) {
      TRACE_LEAVE(sprintf("%s: chmod %O failed: %s", id->method, norm_f, msg));
    } else {
      TRACE_LEAVE(sprintf("%s: chmod ok", id->method));
    }
    TRACE_LEAVE(sprintf("%s: Success", id->method));
    return Roxen.http_status(201, "Created");
  }
  privs = 0;

  TRACE_LEAVE(sprintf("%s: Failed", id->method));
  return errno_to_status (err_code, 1, id);
}

class CacheCallback(string f, int orig_size)
{
  int(0..1) `()(RequestID id, mixed key)
  {
    return _file_size(f, id) == orig_size;
  }
}

mixed find_file( string f, RequestID id )
{
  TRACE_ENTER("find_file(\""+f+"\")", 0);
  object o;
  int size;
  string tmp;
  string oldf = f;
  object privs;
  int code;

  FILESYSTEM_WERR("Request for \""+f+"\"" +
		  (id->misc->internal_get ? " (internal)" : ""));

  /* only used for the quota system, thus rather unessesary to do for
     each request....
  */
#define URI combine_path(mountpoint, f, ".")

  string norm_f;

  catch {
    /* NOTE: NORMALIZE_PATH() may throw errors. */
    norm_f = NORMALIZE_PATH(path + encode_path(f));
#if constant(System.normalize_path)
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
      return Roxen.http_status(403, "File exists, but access forbidden "
			       "by user");
    }

    // Regenerate f from norm_f.
    f = decode_path(replace(norm_f[sizeof(normalized_path)..], "\\", "/"))
    if (has_suffix(oldf, "/") && !has_suffix(f, "/")) {
      // Restore the "/" stripped by encode_path() on NT.
      f += "/";
    }

    /* Adjust not_query */
    id->not_query = mountpoint + f;
#endif /* constant(System.normalize_path) */
  };

  // NOTE: Sets id->misc->stat.
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

      SETUID_TRACE("Open file", 1);

      o = Stdio.File( );
      if(!o->open(norm_f, "r" )) o = 0;
      privs = 0;

      if(!o || (no_symlinks && (contains_symlinks(path, f))))
      {
	errors++;
	report_error(LOCALE(45,"Open of %s failed. Permission denied.\n"),f);

	TRACE_LEAVE("");
	TRACE_LEAVE("Permission denied.");
	return Roxen.http_status(403, "File exists, but access forbidden "
				 "by user");
      }

      // Add a cache callback.
      id->misc->_cachecallbacks += ({ CacheCallback(f, size) });

      id->realfile = norm_f;
      TRACE_LEAVE("");
      accesses++;
      if( charset != "iso-8859-1" )
      {
	if( id->set_output_charset )
	  id->set_output_charset( charset, 2 );
        id->misc->input_charset = charset;
      }
      if (query("no-parse")) {
	TRACE_ENTER("Content-type mapping module", id->conf->types_module);
	array(string) tmp = id->conf->type_from_filename(norm_f, 1);
	TRACE_LEAVE(tmp?sprintf("Returned type %s %s.", tmp[0], tmp[1]||"")
		    : "Missing type.");
	TRACE_LEAVE("No parse return");
	return Roxen.http_file_answer(o, tmp[0]) + ([ "encoding":tmp[1] ]);
      }
      TRACE_LEAVE("Normal return");
      return o;
    }
    break;

  case "MKCOL":
    if (id->request_headers["content-type"] || sizeof (id->data)) {
      // RFC 2518 8.3.1:
      // If a server receives a MKCOL request entity type it does not support
      // or understand it MUST respond with a 415 (Unsupported Media Type)
      // status code.
      SIMPLE_TRACE_LEAVE ("MKCOL failed since the request has content.");
      return Roxen.http_status(415, "Unsupported media type.");
    }
    /* FALL_THROUGH */
  case "MKDIR":
#if 1
    mixed ret = make_collection(f, id);
    if (ret) return ret;
    if (id->misc->error_code) {
      return Roxen.http_status(id->misc->error_code);
    }
    return 0;
#else /* !1 */
    if(!query("put"))
    {
      id->misc->error_code = 405;
      TRACE_LEAVE(sprintf("%s disallowed (since PUT is disallowed)",
			  id->method));
      return 0;
    }

    if (FILTER_INTERNAL_FILE (f, id)) {
      id->misc->error_code = 405;
      TRACE_LEAVE(sprintf("%s disallowed (since the dir name matches internal file glob)",
			  id->method));
      return 0;
    }

    if (size != -1) {
      TRACE_LEAVE(sprintf("%s failed. Directory name already exists. ",
			  id->method));
      if (id->method == "MKCOL") {
	return Roxen.http_status(405,
				 "Collection already exists.");
      }
      return 0;
    }

    if (mapping(string:mixed) ret = write_access(f + "/", 0, id)) {
      TRACE_LEAVE("MKCOL: Write access denied.");
      return ret;
    }

    mkdirs++;
    SETUID_TRACE("Creating directory/collection", 0);

    if (query("no_symlinks") && (contains_symlinks(path, f))) {
      privs = 0;
      errors++;
      report_error(LOCALE(46,"Creation of %O failed. Permission denied.\n"),
		   oldf);
      TRACE_LEAVE(sprintf("%s: Contains symlinks. Permission denied",
			  id->method));
      return Roxen.http_status(403, "Permission denied.");
    }

    TRACE_ENTER(sprintf("%s: Accepted", id->method), 0);

    code = mkdir(f);
    int err_code = errno();

    if (code) {
      string msg = safe_chmod(f, 0777 & ~(id->misc->umask || 022));
      privs = 0;
      if (msg) {
	TRACE_LEAVE(sprintf("%s: chmod %O failed: %s", id->method, f, msg));
      } else {
	TRACE_LEAVE(sprintf("%s: Success", id->method));
      }
      TRACE_LEAVE("Success");
      if (id->method == "MKCOL") {
	return Roxen.http_status(201, "Created");
      }
      return Roxen.http_string_answer("Ok");
    } else {
      privs = 0;
      SIMPLE_TRACE_LEAVE("%s: Failed (err: %d: %s)",
			 id->method, err_code, strerror(err_code));
      TRACE_LEAVE("Failure");
      if (id->method == "MKCOL") {
	if (err_code ==
#if constant(System.ENOENT)
	    System.ENOENT
#else
	    2
#endif
	    ) {
	  return Roxen.http_status(409, "Missing intermediate.");
	} else {
	  return Roxen.http_status(507, "Failed.");
	}
      }
      return 0;
    }
#endif /* !1 */
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

    if (mapping(string:mixed) ret = write_access(f, 0, id)) {
      TRACE_LEAVE("PUT: Locked");
      return ret;
    }

    if (size == -2) {
      // RFC 4918 9.7.2:
      // A PUT request to an existing collection MAY be treated as an
      // error (405 Method Not Allowed).
      id->misc->error_code = 405;
      TRACE_LEAVE("PUT: Is directory.");
      return 0;
    }

    puts++;

    QUOTA_WERR("Checking quota.\n");
    if (id->misc->quota_obj && (id->misc->len > 0) &&
	!id->misc->quota_obj->check_quota(URI, id->misc->len)) {
      errors++;
      report_warning(LOCALE(47,"Creation of %O failed. Out of quota.\n"),f);
      TRACE_LEAVE("PUT: Out of quota.");
      return Roxen.http_status(507, "Out of disk quota.");
    }

    if (query("no_symlinks") && (contains_symlinks(path, f))) {
      errors++;
      report_error(LOCALE(46,"Creation of %O failed. Permission denied.\n"),f);
      TRACE_LEAVE("PUT: Contains symlinks. Permission denied");
      return Roxen.http_status(403, "Permission denied.");
    }

    SETUID_TRACE("Saving file", 0);

    rm(norm_f);
    // mkdirhier(norm_f);

    if (id->misc->quota_obj) {
      QUOTA_WERR("Checking if the file already existed.");
      if (size > 0) {
	QUOTA_WERR("Deallocating " + size + "bytes.");
	id->misc->quota_obj->deallocate(URI, size);
      }
    }

    object to = Stdio.File();

    TRACE_ENTER("PUT: Accepted", 0);

    /* Clear the stat-cache for this file */
    if (stat_cache) {
      cache_set("stat_cache", norm_f, 0);
    }

    if(!to->open(norm_f, "wct", 0666))
    {
      int err = to->errno();
      privs = 0;
      TRACE_LEAVE("PUT: Open failed");
      mixed ret = errno_to_status (err, 1, id);
      if (ret) return ret;
      if (id->misc->error_code) {
	return Roxen.http_status(id->misc->error_code);
      }
      return 0;
    }

    // FIXME: Race-condition.
    string msg = safe_chmod(norm_f, 0666 & ~(id->misc->umask || 022));
    privs = 0;

    Stdio.File my_fd = id->connection();

    putting[my_fd] = id->misc->len;
    if(strlen(id->data))
    {
      // Note: What if sizeof(id->data) > id->misc->len ?
      //   This is not a problem, since that has been handled
      //   by the protocol module.
      if (id->misc->len > 0) {
	putting[my_fd] -= strlen(id->data);
      }
      int bytes = to->write( id->data );
      if (id->misc->quota_obj) {
	QUOTA_WERR("Allocating " + bytes + "bytes.");
	if (!id->misc->quota_obj->allocate(URI, bytes)) {
	  TRACE_LEAVE("PUT: A string");
	  TRACE_LEAVE("PUT: Out of quota");
	  return Roxen.http_status(507, "Out of disk quota.");
	}
      }
    }
    if(!putting[my_fd]) {
      TRACE_LEAVE("PUT: Just a string");
      TRACE_LEAVE("Put: Success");
      if (size < 0) {
	return Roxen.http_status(201, "Created.");
      } else {
	// FIXME: Isn't 204 better? /mast
	return Roxen.http_string_answer("Ok");
      }
    }

    id->ready_to_receive();
    my_fd->set_id( ({ to, my_fd, id, URI, size }) );
    my_fd->set_nonblocking(got_put_data, 0, done_with_put);
    TRACE_LEAVE("PUT: Pipe in progress");
    TRACE_LEAVE("PUT: Success so far");
    return Roxen.http_pipe_in_progress();
    break;

  case "CHMOD": {
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

    if (mapping(string:mixed) ret = write_access(f, 0, id)) {
      TRACE_LEAVE("CHMOD: Locked");
      return ret;
    }

    SETUID_TRACE("CHMODing file", 0);

    if (query("no_symlinks") && (contains_symlinks(path, f))) {
      privs = 0;
      errors++;
      TRACE_LEAVE("CHMOD: Contains symlinks. Permission denied");
      return Roxen.http_status(403, "Permission denied.");
    }

    string msg = safe_chmod(norm_f, id->misc->mode & 0777);
    int err_code = errno();
    privs = 0;

    chmods++;

    TRACE_ENTER("CHMOD: Accepted", 0);

    if (stat_cache) {
      cache_set("stat_cache", f, 0);
    }

    if(msg)
    {
      TRACE_LEAVE(sprintf("CHMOD: Failure: %s", msg));
      return errno_to_status (err_code, 0, id);
    }
    TRACE_LEAVE("CHMOD: Success");
    TRACE_LEAVE("Success");
    return Roxen.http_string_answer("Ok");
  }

  case "MV": {
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

    string movefrom;
    if(!id->misc->move_from ||
       !has_prefix(id->misc->move_from, mountpoint) ||
       !(movefrom = id->conf->real_file(id->misc->move_from, id))) {
      id->misc->error_code = 405;
      errors++;
      TRACE_LEAVE("MV: No source file");
      return 0;
    }

    string relative_from = id->misc->move_from[sizeof(mountpoint)..];

    if (FILTER_INTERNAL_FILE (movefrom, id) ||
	FILTER_INTERNAL_FILE (f, id)) {
      id->misc->error_code = 405;
      TRACE_LEAVE("MV to or from internal file is disallowed");
      return 0;
    }

    if (query("no_symlinks") &&
	((contains_symlinks(path, f)) ||
	 (contains_symlinks(path, id->misc->move_from)))) {
      errors++;
      TRACE_LEAVE("MV: Contains symlinks. Permission denied");
      return Roxen.http_status(403, "Permission denied.");
    }

    // NB: Consider the case of moving of directories containing locked files.
    if (mapping(string:mixed) ret =
	write_access(({ f, relative_from }), 1, id)) {
      TRACE_LEAVE("MV: Locked");
      return ret;
    }

    SETUID_TRACE("Moving file", 0);

    code = mv(movefrom, norm_f);
    int err_code = errno();
    privs = 0;

    moves++;

    TRACE_ENTER("MV: Accepted", 0);

    /* Clear the stat-cache for this file */
    if (stat_cache) {
      cache_set("stat_cache", movefrom, 0);
      cache_set("stat_cache", norm_f, 0);
    }

    if(!code)
    {
      TRACE_LEAVE("MV: Move failed");
      return errno_to_status (err_code, 1, id);
    }
    TRACE_LEAVE("MV: Success");
    TRACE_LEAVE("Success");
    return Roxen.http_string_answer("Ok");
  }

  case "MOVE": {
    // This little kluge is used by NETSCAPE 4.5 and RFC 2518.

    // FIXME: Support for quota.

    if(!query("put"))
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MOVE disallowed (since PUT is disallowed)");
      return 0;
    }
    if(size == -1)
    {
      id->misc->error_code = 404;
      TRACE_LEAVE("MOVE failed (no such file)");
      return 0;
    }

    string new_uri = id->misc["new-uri"] || "";
    if (new_uri == "") {
      id->misc->error_code = 405;
      errors++;
      TRACE_LEAVE("MOVE: No dest file");
      return 0;
    }

    // FIXME: The code below doesn't allow for this module being overloaded.
    if (!has_prefix(new_uri, mountpoint)) {
      id->misc->error_code = 405;
      TRACE_LEAVE("MOVE: Dest file on other filesystem.");
      return(0);
    }
    new_uri = new_uri[sizeof(mountpoint)..];
    string moveto = real_path(new_uri, id);

    // Workaround for Linux, Tru64 and FreeBSD.
    if (has_suffix(moveto, "/")) {
      moveto = moveto[..sizeof(moveto)-2];
    }

    if (FILTER_INTERNAL_FILE (f, id) ||
	FILTER_INTERNAL_FILE (new_uri, id)) {
      id->misc->error_code = 405;
      TRACE_LEAVE("MOVE to or from internal file is disallowed");
      return 0;
    }

    if (query("no_symlinks") &&
        ((contains_symlinks(path, norm_f)) ||
         (contains_symlinks(path, moveto)))) {
      privs = 0;
      errors++;
      TRACE_LEAVE("MOVE: Contains symlinks. Permission denied");
      return Roxen.http_status(403, "Permission denied.");
    }

    // NB: Consider the case of moving of directories containing locked files.
    mapping(string:mixed) ret = write_access(({ f, new_uri }), 1, id);
    if (ret) {
      TRACE_LEAVE("MOVE: Locked");
      return ret;
    }
    ret = write_access(combine_path(f, "../"), 0, id);
    if (ret) {
      TRACE_LEAVE("MOVE: Parent directory locked");
      return ret;
    }

    if (norm_f == moveto) {
      privs = 0;
      errors++;
      TRACE_LEAVE("MOVE: Source and destination are the same path.");
      return Roxen.http_status(403, "Permission denied.");
    }

    size = _file_size(new_uri, id);

    SETUID_TRACE("Moving file", 0);

    if (size != -1) {
      // Destination exists.

      TRACE_ENTER(sprintf("Destination exists: %d\n", size), 0);
      int(0..1) overwrite =
	!id->request_headers->overwrite ||
	id->request_headers->overwrite == "T";
      if (!overwrite) {
	privs = 0;
	TRACE_LEAVE("");
	TRACE_LEAVE("MOVE disallowed (overwrite header:F).");
	return Roxen.http_status(412);
      }
      if(!query("delete"))
      {
	privs = 0;
	id->misc->error_code = 405;
	TRACE_LEAVE("");
	TRACE_LEAVE("MOVE disallowed (DELE disabled)");
	return 0;
      }
      TRACE_LEAVE("Overwrite allowed.");
      if (overwrite || (size > -1)) {
        Stdio.Stat src_st = stat_file(f, id);
        Stdio.Stat dst_st = stat_file(new_uri, id);
        // Check that src and dst refers to different inodes.
        // Needed on case insensitive filesystems.
        if (src_st->mode != dst_st->mode ||
            src_st->size != dst_st->size ||
            src_st->ino != dst_st->ino ||
            src_st->dev != dst_st->dev) {
          TRACE_ENTER(sprintf("Deleting destination: %O...\n", new_uri), 0);
          mapping(string:mixed) res = recurse_delete_files(new_uri, id);
          if (res && (!sizeof (res) || res->error >= 300)) {
            privs = 0;
            TRACE_LEAVE("");
            TRACE_LEAVE("MOVE: Recursive delete failed.");
            if (sizeof (res))
              set_status_for_path (new_uri, res->error, res->rettext);
            return ([]);
          }
          TRACE_LEAVE("Recursive delete ok.");
        }
      } else {
	privs = 0;
	TRACE_LEAVE("MOVE: Cannot overwrite directory");
	return Roxen.http_status(412);
      }
    }

    TRACE_ENTER(sprintf("MOVE: mv(%O, %O)...\n", norm_f, moveto), 0);
    code = mv(norm_f, moveto);
    int err_code = errno();
    privs = 0;
    TRACE_LEAVE(sprintf("==> %d (errno: %d: %s)\n",
			code, err_code, strerror(err_code)));

    TRACE_ENTER("MOVE: Accepted", 0);

    moves++;

    /* Clear the stat-cache for this file */
    if (stat_cache) {
      cache_set("stat_cache", new_uri, 0);
      cache_set("stat_cache", f, 0);
    }

    if(!code)
    {
      SIMPLE_TRACE_LEAVE("MOVE: Move failed (%s)", strerror (err_code));
      mixed ret = errno_to_status (err_code, 1, id);
      if (ret) return ret;
      if (id->misc->error_code) {
	return Roxen.http_status(id->misc->error_code);
      }
      return 0;
    }
    TRACE_LEAVE("MOVE: Success");
    TRACE_LEAVE("Success");
    if (size != -1) return Roxen.http_status(204);
    return Roxen.http_status(201);
  }

  case "DELETE":
    if (size==-1) {
      id->misc->error_code = 404;
      TRACE_LEAVE("DELETE: Not found");
      return 0;
    }
    if(!query("delete"))
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

    if (query("no_symlinks") && (contains_symlinks(path, f))) {
      errors++;
      report_error(LOCALE(48,"Deletion of %s failed. Permission denied.\n"),f);
      TRACE_LEAVE("DELETE: Contains symlinks");
      return Roxen.http_status(403, "Permission denied.");
    }

    if ((size < 0) &&
	(String.trim_whites(id->request_headers->depth||"infinity") !=
	 "infinity")) {
      // RFC 2518 8.6.2:
      //   The DELETE method on a collection MUST act as if a "Depth: infinity"
      //   header was used on it.
      TRACE_LEAVE(sprintf("DELETE: Bad depth header: %O.",
			  id->request_headers->depth));
      return Roxen.http_status(400, "Unsupported depth.");
    }

    if (size < 0) {
      mapping|int(0..1) res =
	write_access(({ combine_path(f, "../"), f }), 1, id);
      if (mappingp(res)) {
	SIMPLE_TRACE_LEAVE("DELETE: Recursive write access denied.");
	return res;
      }
#if 0
      report_notice(LOCALE(64,"DELETING the directory %s.\n"), f);
#endif

      accesses++;

      SETUID_TRACE("Deleting directory", 0);

      int start_ms_size = id->multi_status_size();
      recursive_rm(norm_f, query_location() + f, res, id);

      if (!rm(norm_f) && errno() != System.ENOENT) {
	if (id->multi_status_size() > start_ms_size) {
	  if (errno() != System.EEXIST
#if constant (System.ENOTEMPTY)
	      && errno() != System.ENOTEMPTY
#endif
	     )
	  {
	    return errno_to_status (errno(), 0, id);
	  }
	} else {
	  return errno_to_status (errno(), 0, id);
	}

	if (id->multi_status_size() > start_ms_size) {
	  TRACE_LEAVE("DELETE: Partial failure.");
	  return ([]);
	}
      } else {
	unlock_path(f, id);
      }
    } else {
      mapping|int(0..1) res =
	write_access(({ combine_path(f, "../"), f }), 0, id);
      if (res) {
	SIMPLE_TRACE_LEAVE("DELETE: Write access denied.");
	return res;
      }

#if 0
      report_notice(LOCALE(49,"DELETING the file %s.\n"),f);
#endif

      accesses++;

      /* Clear the stat-cache for this file */
      if (stat_cache) {
	cache_set("stat_cache", f, 0);
      }

      SETUID_TRACE("Deleting file", 0);

      if(!rm(norm_f))
      {
	privs = 0;
	id->misc->error_code = 405;
	TRACE_LEAVE("DELETE: Failed");
	return 0;
      }
      privs = 0;
      deletes++;

      unlock_path(f, id);

      if (id->misc->quota_obj && (size > 0)) {
	id->misc->quota_obj->deallocate(URI, size);
      }
    }
    TRACE_LEAVE("DELETE: Success");
    return Roxen.http_status(204,(norm_f+" DELETED from the server"));

  default:
    id->misc->error_code = 501;
    SIMPLE_TRACE_LEAVE("%s: Not supported", id->method);
    return 0;
  }
  TRACE_LEAVE("Not reached");
  return 0;
}

mapping copy_file(string source, string dest, PropertyBehavior behavior,
		  Overwrite overwrite, RequestID id)
{
  SIMPLE_TRACE_ENTER(this, "COPY: Copy %O to %O.", source, dest);
  Stat source_st = stat_file(source, id);
  if (!source_st) {
    TRACE_LEAVE("COPY: Source doesn't exist.");
    return Roxen.http_status(404, "File not found.");
  }
  if (!query("put")) {
    TRACE_LEAVE("COPY: Put not allowed.");
    return Roxen.http_status(405, "Not allowed.");
  }
  mapping|int(0..1) res =
    write_access(({ dest, combine_path(dest, "../")}) , 0, id);
  if (mappingp(res)) return res;
  string dest_path = path + encode_path(dest);
  dest_path = NORMALIZE_PATH (dest_path);
  if (query("no_symlinks") && (contains_symlinks(path, dest))) {
    errors++;
    report_error(LOCALE(57,"Copy to %O failed. Permission denied.\n"),
		 dest);
    TRACE_LEAVE("COPY: Contains symlinks. Permission denied");
    return Roxen.http_status(403, "Permission denied.");
  }
  Stat dest_st = stat_file(dest, id);
  if (dest_st) {
    SIMPLE_TRACE_ENTER (this, "COPY: Destination exists");
    switch(overwrite) {
    case NEVER_OVERWRITE:
      TRACE_LEAVE("");
      TRACE_LEAVE("");
      return Roxen.http_status(412, "Destination already exists.");
    case DO_OVERWRITE:
      if (!query("delete")) {
	TRACE_LEAVE("COPY: Deletion not allowed.");
	TRACE_LEAVE("");
	return Roxen.http_status(405, "Not allowed.");
      }
      object privs;
      SETUID_TRACE("Deleting destination", 0);
      if (dest_st->isdir) {
	int start_ms_size = id->multi_status_size();
	recursive_rm(dest_path, mountpoint + dest, 1, id);

	werror ("dest_path %O\n", dest_path);
	if (!rm(dest_path) && errno() != System.ENOENT) {
	  privs = 0;
	  if (id->multi_status_size() > start_ms_size) {
	    if (errno() != System.EEXIST
#if constant (System.ENOTEMPTY)
		&& errno() != System.ENOTEMPTY
#endif
	       )
	    {
	      TRACE_LEAVE("");
	      return errno_to_status (errno(), 0, id);
	    }
	  } else {
	    TRACE_LEAVE("");
	    return errno_to_status (errno(), 0, id);
	  }

	  if (id->multi_status_size() > start_ms_size) {
	    privs = 0;
	    TRACE_LEAVE("COPY: Partial failure in destination directory delete.");
	    TRACE_LEAVE("");
	    return ([]);
	  }
	} else {
	  unlock_path(dest, id);
	}
	SIMPLE_TRACE_LEAVE("COPY: Delete ok.");
      } else if (source_st->isdir) {
	if (!rm(dest_path)) {
	  privs = 0;
	  if (errno() != System.ENOENT)
	  {
	    mapping(string:mixed) status = errno_to_status (errno(), 0, id);
	    if (!status) status = (["error": id->misc->error_code]);
	    id->set_status_for_path(mountpoint + dest,
				    status->error, status->rettext);
	    TRACE_LEAVE("");
	    return ([]);
	  }
	  SIMPLE_TRACE_LEAVE("COPY: File deletion failed (destination disappeared).");
	} else {
	  SIMPLE_TRACE_LEAVE("COPY: File deletion ok.");

	  unlock_path(dest, id);
	}
      } else {
	SIMPLE_TRACE_LEAVE("COPY: No need to perform deletion.");
      }
      privs = 0;
      break;
    case MAYBE_OVERWRITE:
      if ((source_st->isreg != dest_st->isreg) ||
	  (source_st->isdir != dest_st->isdir)) {
	TRACE_LEAVE("COPY: Resource types for source and destination differ.");
	TRACE_LEAVE("");
	return Roxen.http_status(412, "Destination and source are different resource types.");
      } else if (source_st->isdir) {
	TRACE_LEAVE("Already done (both are directories).");
	TRACE_LEAVE("");
	return Roxen.http_status(204, "Destination already existed.");
      }
      break;
    }
  }

  if (source_st->isdir) {
    mkdirs++;
    object privs;
    SETUID_TRACE("Creating directory/collection", 0);

    int code = mkdir(dest_path);
    int err_code = errno();

    if (code) {
      string msg = safe_chmod(dest_path, 0777 & ~(id->misc->umask || 022));
      privs = 0;
      if (msg) {
	TRACE_LEAVE(sprintf("Chmod %O failed: %s", dest_path, msg));
      } else {
	TRACE_LEAVE("Success");
      }
      return Roxen.http_status(dest_st?204:201, "Created");
    } else {
      return errno_to_status (err_code, 1, id);
    }
  } else {
    string source_path = path + encode_path(source);
    source_path = NORMALIZE_PATH (source_path);
    if (query("no_symlinks") && (contains_symlinks(path, source))) {
      errors++;
      report_error(LOCALE(57,"Copy to %O failed. Permission denied.\n"),
		   dest);
      TRACE_LEAVE("COPY: Contains symlinks. Permission denied");
      return Roxen.http_status(403, "Permission denied.");
    }
    puts++;

    QUOTA_WERR("Checking quota.\n");
    if (id->misc->quota_obj && (id->misc->len > 0) &&
	!id->misc->quota_obj->check_quota(mountpoint + dest,
					  source_st->size)) {
      errors++;
      report_warning(LOCALE(47,"Creation of %O failed. Out of quota.\n"),
		     dest_path);
      TRACE_LEAVE("PUT: Out of quota.");
      return Roxen.http_status(507, "Out of disk quota.");
    }
    object source_file = Stdio.File();
    if (!source_file->open(source_path, "r")) {
      TRACE_LEAVE("Failed to open source file.");
      return Roxen.http_status(404);
    }
    // Workaround for Linux, Tru64 and FreeBSD.
    if (has_suffix(dest_path, "/")) {
      dest_path = dest_path[..sizeof(dest_path)-2];
    }
    object privs;
    SETUID_TRACE("COPY: Copying file.", 0);
    object dest_file = Stdio.File();
    if (!dest_file->open(dest_path, "cwt")) {
      privs = 0;
      return errno_to_status (errno(), 1, id);
    }
    privs = 0;
    int len = source_st->size;
    while (len > 0) {
      string buf = source_file->read((len > 4096)?4096:len);
      if (buf && sizeof(buf)) {
	int sub_len;
	len -= (sub_len = sizeof(buf));
	while (sub_len > 0) {
	  int written = dest_file->write(buf);
	  if ((sub_len -= written) > 0) {
	    if (!written) {
	      SIMPLE_TRACE_LEAVE("Write failed with errno %d",
				 dest_file->errno());
	      dest_file->close();
	      source_file->close();
	      return Roxen.http_status(Protocols.HTTP.DAV_STORAGE_FULL);
	    }
	    buf = buf[written..];
	  }
	}
      } else {
	break;
      }
    }
    if (len > 0) {
      SIMPLE_TRACE_LEAVE("Read failed with %d bytes left.", len);
    } else {
      SIMPLE_TRACE_LEAVE("Copy complete.");
    }
    dest_file->close();
    source_file->close();
    return Roxen.http_status(dest_st?Protocols.HTTP.HTTP_NO_CONTENT:
			     Protocols.HTTP.HTTP_CREATED);
  }
}

string query_name()
{
  if (path) {
    if (sizeof(path) > 20) {
      return sprintf((string)LOCALE(63,"%s from %s...%s"),
		     mountpoint, path[..7], path[sizeof(path)-8..]);
    }
    return sprintf((string)LOCALE(50,"%s from %s"), mountpoint, path);
  }
  return "NOT MOUNTED";
}
