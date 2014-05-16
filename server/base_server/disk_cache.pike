// This file is part of Roxen WebServer.
// Copyright © 1996 - 2009, Roxen IS.
// $Id$

#include <config.h>
#include <module_constants.h>
#include <stat.h>


// Still experimental
#define CACHE_DEBUG

#undef CACHE_WERR
#ifdef CACHE_DEBUG
# define CACHE_WERR(X) report_debug("CACHE: "+X+"\n");
#else
# define CACHE_WERR(X)
#endif

#undef QUERY
#define QUERY(x) roxenp()->query(#x)
#define SET(x,Y) roxenp()->set(#x, Y)

string file_name_r(string what, int nd, int hv)
{
  if(nd)
    return sprintf("%x/%s",(hv&511)%nd,file_name_r(what, nd/512, hv/512));
  return sprintf("%x",hv);
}

string file_name(string what)
{
  int hn = hash(what);
  return file_name_r(what, QUERY(hash_num_dirs), hn);
}

/*+----------------------------------------------------------+
  | The cache stream class. Each cache stream is an instance |
  | of this class.                                           |
  +----------------------------------------------------------+*/

class CacheStream ( Stdio.File file, string fname, int new )
{
  inherit "socket";

  string rfile, rfiledone;
  function done_callback;
  mapping headers = ([]);

  int get_code(string from)
  {
    int i;
    sscanf(upper_case(from), "HTTP/%*s %d", i);
    return i;
  }

  string buf;
  int bpos=0;
  string gets()
  {
    string s;
    int p;
    if((p=search(buf, "\n", bpos)) == -1)
      return 0;
    s=buf[bpos..p-1];
    bpos=p+1;
    return s;
  }

#define ROXEN_HEAD_VERS 2
#define ROXEN_HEAD_SIZE 512

  int parse_headers()
  {
    string line, name, value;
    int ret;

    if((ret=file->seek(ROXEN_HEAD_SIZE))!=ROXEN_HEAD_SIZE)
    {
      CACHE_WERR("parse_headers seek failed("+ret+")");

      return 0;
    }
    if(!(buf = file->read(ROXEN_HEAD_SIZE*2))){
      report_debug("parse_headers read failed\n");
      return 0;
    }

    line = replace((gets()||""), ({"\r","\n"}), ({"",""}));
    if(!(headers[" returncode"] = get_code(line)))
      return 0;

    while(strlen(line = replace((gets()||""), ({"\r", "\n"}), ({"", ""}))))
    {
      if(sscanf(line, "%s:%s", name, value) == 2)
      {
        sscanf(value, "%*[ \t]%s", value);
        headers[lower_case(name-" ")] = value;
      } else {
        break;
      }
    }
    headers->headers_size = bpos + ROXEN_HEAD_SIZE;
    return 1;
  }

  int load_headers_compat()
  {
    string file;
    string head;

    if(!sscanf(fname, "%s.done", file))
      file = fname;
    if(head = Stdio.read_bytes(QUERY(cachedir)+file+".head"))
    {
      headers = decode_value(head);
//      report_debug(sprintf("Extracted %d bytes of headers from %s (%O)\n",
//		     strlen(head), fname, headers));
      return 1;
    }
    return 0;
  }

  int load_headers()
  {
    string head;
    mixed err;

     // no initial seek needed if load_headers is called first after open

    if(!(head = file->read(ROXEN_HEAD_SIZE)))
    {
      CACHE_WERR("load_headers - read failed");
      return 0;
    }

    err=catch(headers = decode_value(head));
    if(err)
    {
      if(file->seek(0)!=0)
      {
	CACHE_WERR("load_headers - compat seek failed");
	return 0;
      }
      if(load_headers_compat())
	return 1;

      CACHE_WERR("load_headers ("+QUERY(cachedir)+fname+"): "+err[0]);
      return 0;
    }

    if(headers->head_vers != ROXEN_HEAD_VERS)
    {
      CACHE_WERR("load_headers - check head_vers failed");
      return 0;
    }
    if(file->seek(headers->head_size) != headers->head_size)
    {
      CACHE_WERR("load_headers - final seek failed");
      return 0;
    }
    return 1;
  }

  int save_headers()
  {
    if(headers->head_vers != ROXEN_HEAD_VERS)
    {
      headers->head_vers = ROXEN_HEAD_VERS;
      headers->head_size = ROXEN_HEAD_SIZE;
    }

    string head = encode_value(headers);

    if(sizeof(head) > ROXEN_HEAD_SIZE)
    {
      CACHE_WERR("save_headers - header does not fit: "+headers->name);
      return 0;
    }

    if(!((file->seek(0) == 0) &&
	 file->write(head)))
    {
      report_debug("save headers - failed\n");
      return 0;
    }
    return 1;
  }

  void destroy()
  {
    if(objectp(file))
    {
      if(new)
	catch(rm(rfile)); // roxen might be gone
      catch(destruct(file)); // 'file' might be gone
    }
  }
}


class Cache 
{
#ifdef THREADS
  Thread.Mutex lock = Thread.Mutex();
#endif
  string cd;
  Stdio.File command_stream = Stdio.File();
  int last_resort;

  string to_send="";

  void really_send()
  {
#ifdef THREADS
    mixed key = lock->lock();
#endif
    if(strlen(to_send))
      to_send=to_send[ command_stream->write(to_send) .. ];
#ifdef THREADS
    destruct(key);
    key = 0;
#endif
  }

  void command(mixed ... cmd)
  {
    string d = encode_value(cmd);
    d = sprintf("%8x%s", strlen(d), d);
    to_send += d;
    if(to_send==d) really_send();
  }

  int accessed(string filename, int howmuch)
  {
    command("accessed", filename, howmuch);
  }


  void reinit(string basename)
  {
    command("create", QUERY(cachedir), basename,
	    QUERY(garb_min_garb), QUERY(cache_size),
	    QUERY(cache_max_num_files), QUERY(cache_minimum_left),
	    QUERY(cache_gc_logfile));
  }

  /*
   * Create a new cache object.
   * This involves starting a new pike process, and
   * setting up a pipe for communication
   */
  void nil(){}

  int t=10;
  void do_create(string b)
  {
    t*=2;
    call_out(create, t, b);
  }

  void create(string basename)
  {
    Stdio.File lcs;
    cd = basename;
    lcs = command_stream->pipe();

    // FIXME: Should probably use spawn_pike() here.
    mixed err;
    Process.Process proc;
    if( catch {
      proc = Process.Process(({
        "./start", "--once", "--program", "bin/garbagecollector.pike"
      }), (["stdin":lcs, "nice":19, "uid":0, "gid":0, ]));
    } )
      err = catch {
        proc = Process.Process(({
          "./start", "--once", "--program", "bin/garbagecollector.pike"
        }), (["stdin":lcs,"nice":19, ]));
      };

    if( err )
    {
      report_error("Failed to enable disk-cache system\n%s\n", err[0] );
      return;
    }
    /* Master */
    err = catch {
      destruct(lcs);
      reinit(basename);
      command_stream->set_id(basename);
      command_stream->set_nonblocking(nil, really_send, do_create);
    };
    if (err) {
      report_error(sprintf("Error initiating garbage-collector:\n"
			   "%s\n", describe_backtrace(err)));
    }
    return;
  }

  /*
   * Return some statistics
   */
  string status()
  {
    int i = 10;
    string s, file;
    file = QUERY(cachedir)+"statistics";

    command("statistics");
    while(--i && (Stdio.file_size(file)<5)) sleep(0);
    if(!i) return "cache statistics timeout";
    s=Stdio.read_bytes(file);
    rm(file);
    return s;
  }

  /*
   * Returns the real amount of data if 'f' is set to 1.
   */
  int check(int howmuch, int|void f)
  {
    command( "check", howmuch );
    int c;
    sscanf(Stdio.read_bytes(QUERY(cachedir)+"size")-" ", "%x", c);
    if(f) return c;
    return 0;
  }
}



/*
 | Internal functions
 |
 */

private Cache cache;


/*
 | API functions
 */

public void reinit_garber()
{
  if(!QUERY(cache)) return;
  
  if(!sscanf(QUERY(cachedir), "%*s/roxen_cache"))
    SET(cachedir, "roxen_cache/");

  mkdirhier(QUERY(cachedir)+"logs/oo");
  if(Stdio.file_size(QUERY(cachedir)+"logs")>-2)
  {
    report_error("Cache directory ("+QUERY(cachedir)+") cannot be"
		 " accessed.\nCaching disabled.\n");
    SET(cache,0);
    return;
  }
  if(cache)
    cache->reinit(QUERY(cachedir)+"logs/");
  else
    cache = Cache (QUERY(cachedir)+"logs/");

#define DAY (60*60*24)
  if(QUERY(cache_last_resort))
    cache->last_resort = QUERY(cache_last_resort) * DAY;
}

public void init_garber()
{
  reinit_garber();
}


void default_check_cache_file(Stdio.File file);

CacheStream new_cache_stream(Stdio.File fp, string fn)
{
  CacheStream res;
  if(!QUERY(cache)) return 0;
  res=CacheStream (fp, fn, 1);
#ifdef FD_DEBUG
  mark_fd(fp->query_fd(), "Cache stream to "+fn+"\n");
#endif
  res->done_callback = default_check_cache_file;
  return res;
}

/* Heuristic&Co
 *
 *  (this should be more configurable per proxy module)
 *
 *  - used info
 *
 *     header:
 *             expires
 *             last-modified
 *             transmitted
 *
 *     cache object:
 *             arrival
 *
 *     access time:
 *             now
 *
 *     configured:
 *             last-resort
 *
 *  - checks if header is present
 *
 *     if expires
 *     then
 *             if expires < now
 *             then
 *                     refresh
 *     else if last-modified
 *     then
 *             if (arrival - last-modified) < (now - arrival)
 *             then
 *                     try refresh
 *     else if (transmitted + last-resort) > now
 *     then
 *             refresh
 *
 */

#ifdef CACHE_DEBUG
string age(int x)
{
  int y = time(1) - x;
  return sprintf("age: %d+%02d:%02d:%02d (%d)", y/(DAY), (y%DAY)/(60*60), (y%(60*60))/60, y%60, y);
}
#endif

CacheStream cache_file(string cl, string entry)
{
  if(!QUERY(cache)) return 0;
  string name = cl+"/"+file_name(entry)+".done";
  CacheStream cf;
  Stdio.File fd;

  if(!(fd=open(QUERY(cachedir)+name, "r")))
    return 0;

  cf=new_cache_stream(fd, name);
  cf->done_callback = 0;
  cf->rfile = QUERY(cachedir)+name;

  Stat stat = cf->file->stat();

  if(stat->size <= 0)
  {
    destruct(cf);
    return 0;
  }

  if(!cf->load_headers())
  {
    destruct(cf);
    return 0;
  }

  /* act as proxy only for non http class */
  /*
  if(!cf->headers[" returncode"])
  {
    destruct(cf);
    return 0;
  }
  */

  if(cf->headers->name != entry)
  {
#ifdef CACHE_DEBUG
    CACHE_WERR("hashmatch: "+name+", cached: "+cf->headers->name+", wanted: "+entry);
    if(file_name(cf->headers->name)!=file_name(entry))
      CACHE_WERR("hash function changed");
#endif
    destruct(cf);
    return 0;
  }

  /* non http class cache files get returned here */
  if(!cf->headers[" returncode"]) {
    cf->new = 0;
    return cf;
  }

  //  keep 200, 404, 30[01]
  if((cf->headers[" returncode"] != 200) &&
     (cf->headers[" returncode"]/2 != 150) &&
     (cf->headers[" returncode"] != 404)) {
    CACHE_WERR(name+"("+entry+"): returncode="+cf->headers[" returncode"]);
    destruct(cf);
    return 0;
  }

  /* check content-length again in case files got damaged */
  if((((int)cf->headers["content-length"] <= 0) &&
      (cf->headers[" returncode"] == 200)) ||
     ((int)cf->headers["content-length"] > (stat[ST_SIZE] - cf->headers->headers_size)))
  {
    CACHE_WERR(name+": low content-length="+cf->headers["content-length"]+
	       ", headers_size="+cf->headers->headers_size+
	       ", ST_SIZE="+stat[ST_SIZE]+
	       ", returncode="+cf->headers[" returncode"]);
    destruct(cf);
    return 0;
  }

  if(cf->headers["expires"])
  {
    if(!Roxen.is_modified(cf->headers["expires"], time(1)))
    {
      CACHE_WERR("refresh(expired): " + name + "(" + entry +
		 "), " + age(stat[ST_CTIME]) +
		 ", expires: " + cf->headers["expires"]);
      destruct(cf);
      return 0;
    }
  }
  else if(cf->headers["last-modified"])
  {
    if(QUERY(cache_check_last_modified) &&
       Roxen.is_modified(cf->headers["last-modified"],
		   stat[ST_CTIME] - time(1) + stat[ST_CTIME]))
    {
      CACHE_WERR("refresh(last-modified): " + name + "(" + entry +
		 "), " + age(stat[ST_CTIME]) +
		 ", last-modified: " + cf->headers["last-modified"]);
      destruct(cf);
      return 0;
    }
  }
  else if(QUERY(cache_last_resort))
  {
    if((stat[ST_CTIME] + cache->last_resort) < time(1))
    {
      CACHE_WERR("refresh(last resort=" + cache->last_resort + "): " + name +
		 "(" + entry + "), " + age(stat[ST_CTIME]));
      destruct(cf);
      return 0;
    }
  }
  else
  {
    destruct(cf);
    return 0;
  }

  /* Accessed info is handled during garbage collection via the
   * accesstime of the cachefile
   *
   * cache->accessed(name, 0);
   */

  cf->new = 0;
  return cf;
}

CacheStream create_cache_file(string cl, string entry)
{
  if(!QUERY(cache)) return 0;
  string name = cl+"/"+file_name(entry);
  string rfile = QUERY(cachedir)+name;
  string rfiledone = rfile+".done";
  CacheStream cf;
  Stdio.File fd;
  int i;

  // to reduce IO-load try open before making directories
  if(!(fd=open(rfile, "rwcx")))
  {
    mkdirhier(rfile);

    for(i=10; i>=0; i--) {
      if(fd=open(rfile, "rwcx"))
	break;

      if(i>1) {
	rfile = rfile + "+";
	CACHE_WERR(rfile + "(" + entry + "): Retry open new cachefile");
      } else {
	// Remove this file to have a chance to clean away next time.
	rm(rfile);
	CACHE_WERR(rfile + "(" + entry + "): retry failed (file removed)");
	return 0;
      }
    }
  }

  cache->accessed(name, 0);
  cf=new_cache_stream(fd, name);
  cf->headers->name = entry;
  cf->headers->head_vers = ROXEN_HEAD_VERS;
  cf->headers->head_size = ROXEN_HEAD_SIZE;

  cf->rfile = rfile;
  cf->rfiledone = rfiledone;

  // create roxenheader

  if(cf->file->seek(ROXEN_HEAD_SIZE) != ROXEN_HEAD_SIZE) {
    destruct(cf);
    return 0;
  }
  return cf;
}

void rmold(string fname)
{
  if(QUERY(cache_size)||QUERY(cache_max_num_files)){
    int len;

    len = Stdio.file_size(fname);
    if((len>=0) && rm(fname) && (len > 0))
      cache->check(-len);
  } else {
    rm(fname);
    return;
  }
}

void default_check_cache_file(CacheStream stream)
{
  if (QUERY(cache)) {
    Stat stat = stream->file->stat();

    rmold(stream->rfiledone);

    if(!stream->save_headers()) {
      destruct(stream);
      return;
    }
    stream->file->close();
    mv(stream->rfile, stream->rfiledone);
    cache->accessed(stream->fname+".done",
		    (QUERY(cache_size) || QUERY(cache_max_num_files))?
		    stat[ST_SIZE]:0);
    stream->new = 0;
  }
  destruct(stream);
}

string get_garb_info()
{
  if( cache )
    return "<pre>"+cache->status()+"</pre>";
  return "<pre>No cache</pre>";
}

#define DELETE_AND_RETURN(){rmold(cachef->rfiledone);if(cachef){cachef->new=1;}return;}
#define RETURN() {return;}

void http_check_cache_file(CacheStream cachef)
{
  if(!cachef->file) RETURN();
  Stat stat = cachef->file->stat();
  /*  soo..  Lets check if this is a file we want to keep. */
  /*  Initial screening is done in the proxy module. */
  if(stat[ST_SIZE] <= 0) DELETE_AND_RETURN();

  if(QUERY(cache_size)&&(float)stat[ST_SIZE] >=
     (float)QUERY(cache_size)*1024.0*1024.0)
    DELETE_AND_RETURN();

  // Check for files remaining from the last crash
  if(cachef->rfile[strlen(cachef->rfile)-1]=='+') {
    string tocheck = cachef->rfile;
    Stdio.File tc;
    Stat tc_stat;
    while(tocheck[strlen(tocheck)-1]=='+') {
      tocheck=tocheck[.. strlen(tocheck)-2];
      if((tc = open(tocheck,"rx")) &&
        (tc_stat = tc->stat()) &&
        (tc_stat[ST_SIZE]>=0) &&
        (tc_stat[ST_MTIME]+120<stat[ST_MTIME])) {
	CACHE_WERR(tocheck + ": cleaned away");
	rm(tocheck);
      }
#ifdef CACHE_DEBUG
      else  CACHE_WERR(tocheck + ": not cleaned away");
#endif
    }
  }

  if(!cachef->parse_headers())
    DELETE_AND_RETURN();

  if(cachef->headers[" returncode"] == 304) {
    Stat fstat = file_stat(cachef->rfiledone);
    if(fstat && cachef->headers["last-modified"]) {
      if(Roxen.is_modified(cachef->headers["last-modified"], fstat[ST_CTIME])) {
        rmold(cachef->rfiledone);
#ifdef CACHE_DEBUG
        CACHE_WERR(cachef->rfiledone+"("+cachef->headers->name+"): "+
		   age(fstat[ST_CTIME])+", 304-delete-last-modified: "+
		   cachef->headers["last-modified"]);
      } else {
        CACHE_WERR(cachef->rfiledone+"("+cachef->headers->name+"): "+
		   age(fstat[ST_CTIME])+", 304-last-modified: "+
		   cachef->headers["last-modified"]);
#endif
      }
    }
    RETURN();
  }

// keep 200, 404, 30[01]
  if((cachef->headers[" returncode"] != 200) &&
     (cachef->headers[" returncode"]/2 != 150) &&
     (cachef->headers[" returncode"] != 404))
    DELETE_AND_RETURN();

  if(cachef->headers[" returncode"] == 200) {
    if(cachef->headers["content-length"]) {
      if((int)cachef->headers["content-length"] <=0)
	DELETE_AND_RETURN();
    } else if(QUERY(cache_keep_without_content_length)) {
      if((cachef->headers["content-type"] != "text/html") ||
	 ((cachef->file->tell() > cachef->headers->headers_size) &&
	  (cachef->file->seek(cachef->headers->headers_size) !=
	   cachef->headers->headers_size)))
	DELETE_AND_RETURN();

      string tocheck = lower_case(cachef->file->read(500000));

      if((search(tocheck, "<html>") == -1) ||
	 ((search(tocheck, "</html>") == -1) &&
	  (search(tocheck, "</body>") == -1)))
	DELETE_AND_RETURN();
    }
  }
  if(!cachef->headers["content-length"])
    cachef->headers["content-length"] =
      stat[ST_SIZE] - cachef->headers->headers_size;

  if(cachef->headers["expires"]&&
     !Roxen.is_modified(cachef->headers["expires"], time(1))) {
    CACHE_WERR(cachef->rfile + "(" + cachef->headers->name +
	       "): already expired " + cachef->headers["expires"]);
    DELETE_AND_RETURN();
  }

  if(cachef->headers["pragma"] &&
     (search(cachef->headers["pragma"], "no-cache") != -1))
    DELETE_AND_RETURN();

  if(cachef->headers["set-cookie"])
    DELETE_AND_RETURN();

  if((int)cachef->headers["content-length"] >
     (stat[ST_SIZE] - cachef->headers->headers_size)) {
    CACHE_WERR(cachef->rfile + "(" + cachef->headers->name +
	       "): low content-length=" + cachef->headers["content-length"] +
	       ", headers_size=" + cachef->headers->headers_size +
	       ", ST_SIZE=" + stat[ST_SIZE]);
    DELETE_AND_RETURN();
  }

  int len;
  if((QUERY(cache_size)||QUERY(cache_max_num_files))&&
     (len = Stdio.file_size(cachef->rfiledone)) > 0){
    cache->check(-len);
    len = stat[ST_SIZE];
  }
  else
    len = 0;

  if(!cachef->save_headers())
    DELETE_AND_RETURN();

  mv(cachef->rfile, cachef->rfiledone);
  cache->accessed(cachef->fname+".done", len);
  cachef->file->close();

  cachef->new = 0;
}
