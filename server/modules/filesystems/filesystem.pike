// This is a roxen module. (c) Informationsvävarna AB 1996.

// This is a virtual "file-system".
// It will be located somewhere in the name-space of the server.
// Also inherited by some of the other filesystems.
string cvs_version = "$Id: filesystem.pike,v 1.10 1997/02/14 03:42:57 per Exp $";
#include <module.h>
#include <stat.h>

#if DEBUG_LEVEL > 20
# ifndef FILESYSTEM_DEBUG
#  define FILESYSTEM_DEBUG
# endif
#endif

inherit "module";
inherit "roxenlib";
inherit "socket";

import Array;

int redirects, accesses, errors, dirlists;
int puts, deletes;

static int do_stat = 1;

string status()
{
  return ("<h2>Accesses to this filesystem</h2>"+
	  (redirects?"<b>Redirects</b>: "+redirects+"<br>":"")+
	  (accesses?"<b>Normal files</b>: "+accesses+"<br>"
	   :"No file accesses<br>")+
	  (QUERY(put)&&puts?"<b>Puts</b>: "+puts+"<br>":"")+
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

  defvar(".files", 0, "Show hidden files", TYPE_FLAG,
	 "If set, hidden files will be shown in dirlistings and you "
	 "will be able to retrieve them.");

  defvar("dir", 1, "Enable directory listings per default", TYPE_FLAG,
	 "If set, you have to create a file named .www_not_browsable ("
	 "or .nodiraccess) in a directory to disable directory listings."
	 " If unset, a file named .www_browsable in a directory will "
	 "_enable_ directory listings.\n");

  defvar("tilde", 0, "Show backupfiles", TYPE_FLAG,
	 "If set, files ending with '~' or '#' or '.bak' will "+
	 "be shown in directory listings");

  defvar("put", 1, "Handle the 'PUT' method", TYPE_FLAG,
	 "If set, PUT can be used to upload files to the server.");

  defvar("delete", 0, "Handle the 'DELETE' method", TYPE_FLAG,
	 "If set, DELETE can be used to delete files from the "
	 "server.");

  defvar("check_auth", 1, "Require authentication for modification",
	 TYPE_FLAG,
	 "Only allow authenticated users to use methods other than "
	 "GET and POST. If unset, this filesystem will be a _very_ "
	 "public one (anyone can edit files located on it)");

  defvar("stat_cache", 1, "Cache the results of stat(2)",
	 TYPE_FLAG,
	 "This can speed up the retrieval of files up to 60/70% if you"
	 " use NFS, but it does use some memory.");
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
  if(!stat_cache)
    return file_stat(path + f); /* No security currently in this function */
  array fs;
  if(!id->pragma["no-cache"]&&(fs=cache_lookup("stat_cache",path+f)))
    return fs;
  fs = file_stat(path+f);
  cache_set("stat_cache",path+f,fs);
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

  if(!(dir = get_dir( path + f )))
    return 0;

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

  return filter(dir, dir_filter_function);
}


mapping putting = ([]);

void done_with_put( array(object) id )
{
//  perror("Done with put.\n");
  id[0]->close();
  id[1]->write("HTTP/1.0 200 Created\r\nContent-Length: 0\r\n\r\n");
  id[1]->close();
  m_delete(putting, id[1]);
  destruct(id[0]);
  destruct(id[1]);
}

void got_put_data( array (object) id, string data )
{
// perror(strlen(data)+" .. ");
  id[0]->write( data );
  putting[id[1]] -= strlen(data);
  if(putting[id[1]] <= 0)
    done_with_put( id );
}

int _file_size(string X,object id)
{
  array fs;
  if(!id->pragma["no-cache"]&&(fs=cache_lookup("stat_cache",(X))))
  {
    id->misc->stat = fs;
    return fs[ST_SIZE];
  }
  if(fs = file_stat(X))
  {
    id->misc->stat = fs;
    cache_set("stat_cache",(X),fs);
    return fs[ST_SIZE];
  }
  return -1;
}

#define FILE_SIZE(X) (stat_cache?_file_size((X),id):Stdio.file_size(X))

mixed find_file( string f, object id )
{
  object o;
  int size;
  string tmp;
#ifdef FILESYSTEM_DEBUG
  perror("FILESYSTEM: Request for "+f+"\n");
#endif
  size = FILE_SIZE( f = path + f );

  switch(id->method)
  {
  case "GET":
  case "HEAD":
  case "POST":
  
    switch(-size)
    {
    case 1:
      return 0; /* Is no-file */

    case 2:
      return -1; /* Is dir */

    default:
      if(f[ -1 ] == '/') /* Trying to access file with '/' appended */
      {
	redirects++;
	return http_redirect(id->not_query[..sizeof(id->not_query)-2], id);
      }

      if(!id->misc->internal_get && QUERY(.files)
	 && (tmp = (id->not_query/"/")[-1])
	 && tmp[0] == '.')
	return 0;

      o = open( f, "r" );

      if(!o)
      {
	errors++;
	report_error("Open of " + f + " failed. Permission denied.\n");
	return http_low_answer(403, "<h2>File exists, but access forbidden "
			       "by user</h2>");
      }

      id->realfile = f;
      accesses++;
#ifdef COMPAT
      if(QUERY(html)) /* Not very likely, really.. */
	return ([ "type":"text/html", "file":o, ]);
#endif
      return o;
    }
    break;
  
  case "PUT":
    if(!QUERY(put))
      return 0;
    
    if(QUERY(check_auth) && (!id->auth || !id->auth[0]))
      return http_auth_required("foo","<h1>Permission to 'PUT' files denied</h1>");
    
    puts++;
    
#if 0
    perror("PUT "+id->not_query+" ; "+id->misc->len+" bytes for "+
	   id->misc->gecos+" (uid="+id->misc->uid+"; gid="+id->misc->gid+")\n");
#endif
#if efun(geteuid)
    int ouid, ogid, dosetuid;
    if(id->misc->uid && !getuid()) // We want to create the files
	            		    //	with the correct uid/gid.
    {
      dosetuid = 1; ouid = geteuid(); ogid = getegid();
      seteuid(getuid());
      setegid( (int)id->misc->gid );
#if efun(initgroups)
      initgroups( id->auth[1], (int)id->misc->gid );
#endif
      seteuid( (int)id->misc->uid );
    }
#endif
    rm( f );
    mkdirhier( f );
    object to = open(f, "wc");
#if efun(geteuid)
    if(dosetuid)
    {
      array ou;
      ou = roxen->user_from_uid( ouid, id );
      seteuid(0);
#if efun(initgroups)
      if(ou) initgroups( ou[0], ogid );
#endif
      seteuid( ouid );
      setegid( ogid );
    }
#endif

    if(!to)
      return 0;    

    putting[id->my_fd]=id->misc->len;
    if(id->data && strlen(id->data))
    {
      putting[id->my_fd] -= strlen(id->data);
      to->write( id->data );
    }
    if(!putting[id->my_fd])
      return http_string_answer("Ok");

    if(id->prot == "HTTP/1.1")
      id->my_fd->write("HTTP/1.1 100 Continue\r\n");
    id->my_fd->set_id( ({ to, id->my_fd }) );
    id->my_fd->set_nonblocking(got_put_data, 0, done_with_put);
    return http_pipe_in_progress();
    break;

  case "DELETE":
    if(!QUERY(delete) || size==-1)
      return 0;
    if(QUERY(check_auth) && !id->misc->auth_ok)
      return http_low_answer(403, "<h1>Permission to DELETE file denied</h1>");

    deletes++;
    report_error("DELETING the file "+f+"\n");
    accesses++;
    rm(f);
    return http_low_answer(200,(f+" DELETED from the server"));

  default:
    return 0;
  }
  report_error("Not reached..\n");
  return 0;
}

string query_name()
{
  return sprintf("<i>%s</i> mounted on <i>%s</i>", query("searchpath"),
		 query("mountpoint"));
}

