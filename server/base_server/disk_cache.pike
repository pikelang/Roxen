string cvs_version = "$Id: disk_cache.pike,v 1.12 1997/01/26 23:47:07 per Exp $";
#include <stdio.h>
#include <module.h>
#include <simulate.h>

inherit "roxenlib";
object this = this_object();

#undef QUERY
#define QUERY(x) roxenp()->variables->x[VAR_VALUE]

string file_name_r(string what, int nd, int hv)
{
  if(nd)
    return sprintf("%x/%s",(hv&511)%nd,file_name_r(what, nd/512, hv/512));
  return sprintf("%x",hv);
}

string file_name(string what)
{
  int hn = hash(what,0xffffffff);
  return file_name_r(what, QUERY(hash_num_dirs), hn);
}


/* ------------------------
 | The cache stream class. Each cache stream is an instance
 | of this class.
 */

class CacheStream 
{
  inherit "socket";
  string fname;
  object file;
  function done_callback;
  int new;
  mapping headers = ([]);

  int get_code(string from)
  {
    int i;
    sscanf(upper_case(from), "HTTP/%*s %d", i);
    return i;
  }
  
  void parse_headers()
  {
    object(FILE) cf = FILE();
    string line, name, value;
    if(!cf->open(QUERY(cachedir)+fname,"r"))
    {
      perror("open failed: "+QUERY(cachedir)+fname+"\n");
      return;
    }
    headers[" returncode"] = get_code(((cf->gets()||"")-"\r")-"\n");
    while(strlen( (line = ((cf->gets()||"")-"\r")-"\n")))
    {
      if(sscanf(line, "%s:%s", name, value) == 2)
      {
	sscanf(value, "%*[ \t]%s", value);
	headers[lower_case(name-" ")] = value;
      }
    }
    destruct(cf);
  }
  
  void load_headers()
  {
    string file;
    string head;
    if(!sscanf(fname, "%s.done", file))
      file = fname;
    if(head = read_bytes(QUERY(cachedir)+file+".head"))
    {
      headers = decode_value(head);
//      perror(sprintf("Extracted %d bytes of headers from %s (%O)\n",
//		     strlen(head), fname, headers));
    }
  }

  void save_headers()
  {
    string head;
    head = encode_value(headers);
//    perror("Writing heders to "+fname+".head\n");
    rm(QUERY(cachedir)+fname+".head");
    write_file(QUERY(cachedir)+fname+".head", head);
  }
  
  void create(object a, string s, int n)
  {
//    perror("Create cache-stream for "+s+"\n");
    fname = s;
    file = a;
    new = n;
  }

  void destroy()
  {
//   perror("Destroy cache-stream for "+fname+" ("+new+")\n" 
//	  +(describe_backtrace(backtrace())));
    catch(destruct(file)); // 'file' might be gone
    if(new) catch(rm(QUERY(cachedir)+fname)); // roxen might be gone
  }
}


class Cache {
  object lock = ((program) "lock" )();
  object this = this_object();
  string cd;
  object command_stream = File();

  string to_send="";

  void really_send()
  {
    lock->aquire();
    if(strlen(to_send))
      to_send=to_send[ command_stream->write(to_send) .. ];
    lock->free();
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
	    QUERY(garb_min_garb), QUERY(cache_size) );
  }
  
  /*
   * Create a new cache object.
   * This involves starting a new pike process, and
   * setting up a pipe for communication
   */
  void nil(){}

  int t=10;
  void create(string basename);
  void do_create(string b)
  {
    t*=2;
    call_out(create, t, b);
  }
  
  void create(string basename)
  {
    object lcs;
    cd = basename;
    
    lcs = command_stream->pipe();
    if(fork())
    {
      /* Master */ 
      destruct(lcs);
      reinit(basename);
      command_stream->set_nonblocking(nil,really_send,do_create);
      command_stream->set_id(basename);
      return;
    }
    /* Child */
    lcs->dup2( File ("stdin") );
    object privs = ((program)"privs")("Starting the garbage collector");
    exec("bin/pike", "-m", "etc/master.pike", "bin/garbagecollector.pike");
    perror("Failed to start garbage collector (exec failed)!\n");
#if efun(real_perror)
    perror("bin/pike: ");real_perror();
#endif
    exit(0);
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
    while(--i && (file_size(file)<5)) sleep(0);
    if(!i) return "cache statistics timeout";
    s=read_bytes(file);
    rm(file);
    return s;
  }

  /*
   * Returns the real amount of data if 'f' is set to 1.
   */
  int check(int howmuch, int|void f)
  {
    command( "check", howmuch );
    if(f) return (int)("0x"+(read_bytes(QUERY(cachedir)+"size")-" "));
    return 0;
  }
}



/*
 | Internal functions
 |
 */
private int last_init;

private object cache;


/*
 | API functions
 */

public void reinit_garber()
{
  if(!QUERY(cache)) return;

  
  if(!sscanf(QUERY(cachedir), "%*s/roxen_cache"))
    QUERY(cachedir)+="roxen_cache/";
  
  mkdirhier(QUERY(cachedir)+"logs/oo");
  if(file_size(QUERY(cachedir)+"logs")>-2)
  {
    report_error("Cache directory ("+QUERY(cachedir)+") cannot be"
		 " accessed.\nCaching disabled.\n");
    QUERY(cache)=0;
    return;
  }
  if(cache)
    cache->reinit(QUERY(cachedir)+"logs/");
  else
    cache = Cache (QUERY(cachedir)+"logs/");
}

public void init_garber()
{
  reinit_garber();
}


void default_check_cache_file(object file);

object new_cache_stream(object fp, string fn)
{
  object res;
  if(!QUERY(cache)) return 0;
  res=CacheStream (fp, fn, 1);
#ifdef DEBUG
  mark_fd(fp->query_fd(), "Cache stream to "+fn+"\n");
#endif
  res->done_callback = default_check_cache_file;
  return res;
}

object cache_file(string cl, string entry)
{
  if(!QUERY(cache)) return 0;
  string name = cl+"/"+file_name( entry )+".done";
  if(file_size( QUERY(cachedir)+name ) > 0)
  {
    object cf;

    cf = open(QUERY(cachedir)+name, "rw");

    if(!cf)
    {
      perror("Cannot open old cachefile "+QUERY(cachedir)+name+"\n");
      rm(QUERY(cachedir)+name);
      return 0;
    }
    
    cf=new_cache_stream(cf, name);
    cf->new = 0;
    
    cf->load_headers();

//#define CACHE_DEBUG
    
    if(cf->headers->name != entry)
    {
#ifdef CACHE_DEBUG
      perror("CACHE DEBUG: Cache miss");
#endif
      cf->new = 1;
      destruct(cf);
      return 0;
    }

    if(cf->headers->expire)
      if(!is_modified(cf->headers->expire, time())) // Expired!
      {
#ifdef CACHE_DEBUG
	perror("CACHE DEBUG: Cache file expired");
#endif
	cf->new = 1;
	destruct(cf);
	return 0;
      }
	
#ifdef CACHE_DEBUG
    perror("CACHE DEBUG: Cache hit\n");
#endif
    cache->accessed( name,
		     (cf->file->stat()[1])/QUERY(bytes_per_second) );
    return cf;
  }  
  return 0;
}

void rmold(string name)
{
  int len;
   
  len = file_size(QUERY(cachedir)+name+".done");
  if(rm(QUERY(cachedir)+name+".done")&& (len > 0))
    cache->check(-len);
   
  len = file_size(QUERY(cachedir)+name+".head");
  if(rm(QUERY(cachedir)+name+".head")&& (len > 0))
    cache->check(-len);
}

object create_cache_file(string cl, string entry)
{
  if(!QUERY(cache)) return 0;
  string name = cl+"/"+file_name( entry );
  int len;
  object cf;

  // to reduce IO-load try open before making directories 14-Nov-96-wk
  if(!(cf = open(QUERY(cachedir)+name, "rwc")))
  {
    mkdirhier(QUERY(cachedir)+name);
    cf = open(QUERY(cachedir)+name, "rwc");
  }
  
  if(!cf)
  {
    perror("Cannot open new cachefile "+QUERY(cachedir)+name+"\n");
    return 0;
  }
  cache->accessed( name, time() ); // This file _will_ be removed first.
  cf=new_cache_stream(cf, name);
  cf->headers->name = entry;
  return cf;
}

void default_check_cache_file(object stream)
{
  string file = QUERY(cachedir)+stream->fname;
  if(QUERY(cache))
  {
    int s;
    s=file_size(file);
    stream->save_headers();
    mv(file, file+".done");
    cache->accessed( stream->fname+".done", s/QUERY(bytes_per_second) );
    cache->accessed( file+".head", 1024 );
    cache->check(s+1024);
  } else
    rm(file);
  destruct(stream);
}

string get_garb_info()
{
  return "<pre>"+cache->status()+"</pre>";
}



#define DELETE_AND_RETURN(){rmold(rfile);if(cachef){cachef->new=1;destruct(cachef);}return;}
#define RETURN() {if(cachef){destruct(cachef);}return;}

#include <stat.h>

void http_check_cache_file(object cachef)
{
  if(!cachef->file) RETURN();
  string rfile = QUERY(cachedir)+cachef->fname;
  array (int) stat = cachef->file->stat();
  int i;
  /*  soo..  Lets check if this is a file we want to keep. */
  /*  Initial screening is done in the proxy module. */
  if(stat[ST_SIZE] <= 0) DELETE_AND_RETURN();

  if((float)stat[ST_SIZE] >=
     (float)QUERY(cache_size)*1024.0*1024.0)
    DELETE_AND_RETURN();

  cachef->parse_headers();
// keep 404 also                                              4-Dec-96-wk
  if((cachef->headers[" returncode"]/100 != 2) &&
     (cachef->headers[" returncode"] != 404) &&
     (cachef->headers[" returncode"]/2 != 150))
    DELETE_AND_RETURN();
  
  if(!is_modified(cachef->headers["expire"], time()))
    DELETE_AND_RETURN();

  if(cachef->headers["pragma"] &&
     (search(cachef->headers["pragma"], "no-cache") != -1))
    DELETE_AND_RETURN();

  if(cachef->headers["set-cookie"])
    DELETE_AND_RETURN();

  if((int)cachef->headers["content-length"] > stat[ST_SIZE]) 
    DELETE_AND_RETURN();

  cachef->save_headers();

  mv(rfile, rfile+".done");

  cache->accessed( cachef->fname+".done", stat[1]/QUERY(bytes_per_second) );
  cache->accessed( cachef->fname+".head", stat[1]/QUERY(bytes_per_second) );
  cache->check( stat[ST_SIZE] );

  destruct(cachef);
}

