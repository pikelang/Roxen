//#include <stdio.h>
//#include <simulate.h>

/*
 * name = "Proxy Garbage Collector";
 * doc = "This is the proxy garbage collector";
 */

string cvs_version = "$Id$";

//#define DEBUG

string version = cvs_version;

#define MAX_LOG_SIZE 512
#define MAX_STAT_CACHE_SIZE 1000*MAX_LOG_SIZE


string lp;
int last_log, first_log=0x7fffffff;

mapping log = ([]);

#define LOGGER(x) if(gc_log) gc_log->write(x); else werror("          : %s", x)
Stdio.File gc_log;

string _order(int from)
{
  return sprintf("%08x", from);
}

int _num(string from)
{
  int c;
  sscanf(from[strlen(from)-8..], "%x", c);
  return c;
}


int rm_log(int num)
{
  rm(lp+"cachelog"+_order(num));
}

mapping parse_log(int num)
{
  string s;
  string file;
  mapping log;
  
  file = lp+"cachelog"+_order(num);
  if(!(s=Stdio.read_bytes(file)))
  {
    mkdir(lp);
    s=Stdio.read_bytes(file);
  }
  if(!s) {
    if(first_log == num)
      first_log++;
    if(last_log == num)
      last_log--;
    return 0;
  }

  if(catch(log = decode_value( s ))) {
#ifdef DEBUG
    LOGGER("Could not decode cachelog file ("+file+") - removed\n");
#endif
    rm_log(num);
    return 0;
  }
  if(sizeof(log)<=0) {
    rm_log(num);
    return 0;
  }

  return log;
}

void unparse_log(mapping log, int num)
{
  string file;
  file = lp+"cachelog"+_order(num);
  rm(file);
  if(sizeof(log)<=0)
    return;
  if(!Stdio.write_file(file, encode_value(log)))
    LOGGER("Could not write cachelog file ("+file+")\n");
}

#define BLOCK_SIZE 2048

#define FILE_SIZE_TO_BLOCK(X) (((X)+(BLOCK_SIZE-1))/BLOCK_SIZE)
// allow cache sizes of more than 2 GB                                1-Nov-96-wk
#define BLOCK_TO_KB(X)        ((((float)(X))*BLOCK_SIZE)/1024)

int max_cache_size;
int cache_normal_garb;
int cache_size;
int num_files, max_num_files;
int garbage_time;
int removed, removed_files, lastgc;
int disk_max, disk_used, disk_avail, disk_capacity,
  disk_i_max, disk_i_used, disk_i_avail, disk_i_capacity, disk_time;
string disk_name, disk_type;

string disk_info()
{
  return
    (disk_name?
     sprintf("Disk (%s):\n"
	     "%s%s\t%1dkb%s\n"
	     "\t%1dkb (%1d%%) used, %1dkb avail\n",
	     ctime(disk_time)-"\n",
	     strlen(disk_name)?"\tfilesystem name: "+disk_name+"\n":"",
	     strlen(disk_type)?"\tfilesystem type: "+disk_type+"\n":"",
	     disk_max, disk_i_max>0?" "+disk_i_max+" files":"",
	     disk_used, disk_capacity, disk_avail):"") + 
    (disk_i_used>0?
     sprintf("\t%1d (%1d%%) files used, %1d files available\n",
	     disk_i_used, disk_i_capacity, disk_i_avail):"");
}

void current_cache_message()
{
  if(!gc_log)
    return;
  string now = ctime(time(1))-"\n";
  
  LOGGER(sprintf("Cache(%s): %1.3f MB data (%1.2f%%)\n",
		 now,
		 (float)BLOCK_TO_KB(cache_size)/1024.0,
		 (float)cache_size*100/max_cache_size
		 ));
  if(max_num_files>0)
    LOGGER(sprintf("Cache(%s):\n"
		   "\t%1d files (%1.2f%%)\n",
		   now, num_files, (float)num_files*100/max_num_files));
  else
    LOGGER(sprintf("Cache(%s):\n"
		   "\t %1d files\n",
		   now, num_files));

  if(disk_name)
    LOGGER(disk_info());

  if(lastgc>0) {
    string gctime = ctime(lastgc)-"\n";
    LOGGER(sprintf("Gc(%s):\n"
		   "\t%1.3f MB (%d files) removed in last gc run\n"
		   "\tremoved files were last accessed %s\n",
		   gctime, (float)BLOCK_TO_KB(removed)/1024.0, removed_files,
		   ctime(garbage_time)-"\n"));
  }
}

int read_cache_status()
{
  mapping status = ([]);
  string file, s;
  file = lp+"cache_status";
  mkdir(lp);
  if(Stdio.file_size(file)<=0) {
    LOGGER("read_cache_status: "+file+" is missing\n");
    return 0;
  }
  if(!(s=Stdio.read_bytes(file))) {
    LOGGER("read_cache_status: "+file+" could not be read\n");
    rm(file);
    return 0;
  }
  if(catch(status = decode_value(s))) {
    LOGGER("read_cache_status: "+file+" could not be decoded\n");
    rm(file);
    return 0;
  }
  last_log = status->last_log;
  first_log = status->first_log;
  cache_size = status->cache_size;
  num_files = status->num_files;
  garbage_time = status->garbage_time;
  removed = status->removed;
  removed_files = status->removed_files;
  lastgc = status->lastgc;

  if((last_log < first_log) ||
     (max_cache_size>0&&cache_size <= 0)||
     (max_num_files>0&&num_files <= 0)||
     (first_log <= 0)) {
    LOGGER("read_cache_status: "+file+" contains rubbish\n");
    rm(file);
    return 0;
  }

  return 1;
}
		 
void create_cache(string logprefix)
{
  lp = logprefix;
  int li;
  string file;
  array (string) allfiles;
  cache_size = 0;

  mkdir(lp);

  allfiles = Array.map(get_dir(lp), lambda(string s) {
    if(search(s, "cachelog") != -1) return s;
    return 0;
  }) - ({ 0 });

  foreach(allfiles, file)
  {
    if((li=_num(file)) > last_log)
      last_log = li;
    if(li < first_log)
      first_log = li;
  }

  if(!last_log) {
    first_log = 0;
    return; // Ok, no old log.
  }

  if(read_cache_status()) {
    current_cache_message();
    return;
  }

  first_log = last_log = 0;

#if 0
  while(!((log=parse_log(last_log)) && last_log>=0))
    last_log--;
  if(!log)
    log = ([]);

  if(last_log < 0)
    LOGGER("CACHE: Failed to read existing logfile.\n");
#endif
}

void write_cache_status()
{
  mapping status = ([]);
  string file;

  file = lp+"cache_status";
  status->last_log = last_log;
  status->first_log = first_log;
  status->cache_size = cache_size;
  status->num_files = num_files;
  status->garbage_time = garbage_time;
  status->removed = removed;
  status->removed_files = removed_files;
  status->lastgc = lastgc;

  if(!Stdio.write_file(file+"+", encode_value(status)))
    LOGGER("write_cache_status: "+file+"+"+" could not be written\n");
  if(!mv(file+"+", file))
    LOGGER("write_cache_status: "+file+" could not be written\n");
}

void write_log()
{
  mapping status = ([]);	// This doesn't seem to be used
  string file;
  last_log++;
  mkdir(lp);
  file = lp+"cachelog"+_order(last_log);
  rm(file);
  if (!Stdio.write_file(file, encode_value(log)))
    LOGGER("Could not write cachelog file ("+file+")\n");
  log = ([]);
  write_cache_status();
}

void update(string file, int tim, int|void score)
{
//LOGGER(file+" "+(time(1)-tim)+" seconds old, "+score+" \"bonus\" seconds.\n");
  if((search(file, ".done")!=-1)&&log[file-".done"]) {
    m_delete(log, file-".done");
    num_files--;
  }
    
  log[file] = ({ tim, score });
  if(sizeof(log) > MAX_LOG_SIZE)
    write_log();
}

int check(int);

void accessed(string filename, int size)
{
  update(filename, time(), size);
  if(size!=0)
    check(size);
}

mapping stat_cache = ([]);

int collect_log(int amnt, function cb, mapping log)
{
  array a, b;
  
  a = values(log);
  b = indices(log);

  /* Sort logfile by accesstime
   * .head and .done files should be processed together
   * process until amnt is removed or greater garbage_time
   */

  //sort(map_array(a,lambda(array a){`-(@a);}), b);
  sort(column(a, 0), a, b);

  garbage_time = a[0][0];

  int i;
  for(i=0; (amnt>0)&&(i<sizeof(b)); i++)
  {
    amnt -= cb(b[i], a[i][0]);
    m_delete(log, b[i]);
  }

  if(sizeof(stat_cache) > MAX_STAT_CACHE_SIZE)
    stat_cache = ([]);

  return amnt;
}

void find_all_files_in(string dir, function|void cb)
{
  string path;
  foreach(get_dir(dir)||({}), path)
  {
    mixed st = file_stat(dir+path);
    if(st)
    {
      if(st[1] == -2)
      {
	if((path != "..") && (path!="."))
	  find_all_files_in(dir+path+"/", cb);
      } else {
	if(!cb)
	{
	  cache_size += FILE_SIZE_TO_BLOCK(st[1]);
	  num_files++;
	  update(dir+path, st[2], st[1]);
	} else
	  cb(dir+path);
      }
    }
  }
}

void find_all_files_and_log_it()
{
  array dirs = get_dir(".");
  string dir;
  
  LOGGER("Rechecking cache at "+ctime(time()));

  num_files = cache_size = 0;
  rm("size");
  find_all_files_in("logs/", rm); // Remove all logs
  log=([]);
  first_log = last_log = 0;   // Well, lets start again then.

  foreach(dirs, dir)
    if(Stdio.file_size(dir)<-1 && dir!="logs")
      find_all_files_in(dir+"/");

  last_log++;
  if((Stdio.file_size(lp+"cachelog"+_order(1))>0) &&
     !mv(lp+"cachelog"+_order(1), lp+"cachelog"+_order(last_log)))
    LOGGER("find_all_files_and_log_it - mv failed\n");
  
  write_cache_status();
  current_cache_message();

  remove_call_out(find_all_files_and_log_it);
  call_out(find_all_files_and_log_it, (BLOCK_TO_KB(cache_size)/5)+19200);
}


void collect(int amnt, function callback)
{
  int logsize;
  mixed r;

  write_log();

//  LOGGER("Collect. first_log="+first_log+"; last_log="+last_log+"\n");
  r = catch {
    while((amnt>0)&&(first_log <= last_log))
    {
      mapping rl;
//      LOGGER("Collecting log "+i+"\n");
//      LOGGER("Collect. first_log="+first_log+"; last_log="+last_log+"\n");
      if(rl = parse_log(first_log))
      {
	logsize = sizeof(rl);
	amnt = collect_log(amnt, callback, rl);
	if(logsize != sizeof(rl))
	  unparse_log(rl, first_log);
      }
    }
  }; 
  if(r)
  {
    LOGGER("Error while garbagecollecting: "+r[0]+"\n"
	   +describe_backtrace(r[1]));
    return;
  }
  
  if(amnt <= 0)
    return;

  find_all_files_and_log_it();
}


void gc(int);

// All sizes are in BLOCK_SIZE b blocks, except for
// howmuch, which is in bytes.
int check(int howmuch)
{
  howmuch = FILE_SIZE_TO_BLOCK(howmuch);
  cache_size += howmuch;

  if(howmuch >= 0)
    num_files++;
  else
    num_files--;

  //  len is in units of BLOCK_SIZE bytes. 
  if((max_cache_size>0) && ((int)((float)cache_size)) > max_cache_size)
    gc(cache_size);
  else if((max_num_files>0) && (num_files > max_num_files))
    gc(cache_normal_garb);

  return cache_size;
}

void cache_stream_closed()
{
  LOGGER("garbagecollector: cache command stream closed. Exiting\n");
#ifdef LPC_GARB
  write_log();
#endif
  exit(0);
}

protected mixed do_command(array what)
{
  mixed res;
  if(!arrayp(what))
  {
    LOGGER(sprintf("Got strange command (%O)\n", what));
    return 0;
  }

#ifdef DEBUG
//  LOGGER(sprintf("Got command %O\n", what));
#endif
  
  return this_object()[what[0]](@what[1..]);
}

private string _cache = "";
protected void got_command(object o, string cmd)
{
  cmd = _cache+cmd;

//  LOGGER("Got some data: '"+cmd+"'\n");
  
  while(strlen(cmd))
  {
    int l;
    
    if(strlen(cmd) < 8)  break; // More needed.

    sscanf(cmd[..7]-" ", "%x", l);

    if(strlen(cmd) < l+8) break; // More needed

    cmd=cmd[8..]; // Remove the 'length' field of this command.

    array err;
    if(err=catch(do_command( decode_value( cmd[..l-1] ) )))
      Stdio.stderr->write(describe_backtrace( err ));
    
    cmd=cmd[l..]; // Remove the 'command' field of this command
  }
//  LOGGER("data parsed ("+strlen(cmd)+" bytes in cache).\n");
  
  _cache=cmd;
}

#define MAX(x,y) ((x)<(y)?(y):(x))

int remove_one_file(string fname, int last_access)
{
  mixed s;
#ifdef DEBUG
//  LOGGER("remove one file? "+fname+" --- ");
#endif
  s=stat_cache[fname];
  if(!s)
    if(!(s = file_stat( fname )))
      s = stat_cache[fname] = ({0,-1,0,0,0,0});
    else
      stat_cache[fname]=s;
  
  if(s[1] != -1)
  {
    if(s[2]-10 > last_access) {
      update(fname, s[2], 0);
      return 0; /* See you next time */
    }
	
    int i;
    i=FILE_SIZE_TO_BLOCK(s[1]);
    cache_size-=i;
    num_files--;
    removed += i;
    removed_files++;
    s[1]=-1;
    rm(fname);
    return i; /* Ok, removed */
  }
  return 0; /* No such file */
}

/* Do _not_ call check() from this function. It might cause infinite
 * recursion
 */

void gc(int cs)
{
  int amnt;

  stat_cache = ([]);
  removed = removed_files = 0;
  lastgc = time();
  amnt = MAX(cache_normal_garb, cs-max_cache_size);

  catch {
#ifdef DEBUG
    // LOGGER("really_gc ("+(int)BLOCK_TO_KB(amnt)+" Kb)\n");
#endif
    collect(amnt, remove_one_file);
    write_cache_status();
    current_cache_message();
#ifdef DEBUG
    // LOGGER("--------- ("+(int)BLOCK_TO_KB(removed)+" Kb really removed)\n");
#endif
  };
  stat_cache = ([]);
}

string statistics()
{
  string gc_info;
  
  if(!removed)
    gc_info="";
  else
    gc_info=sprintf("GC(%s):\n"
		    "\t%2.2f Mb (%d files) removed\n"
		    "\tlast run was %d minutes ago\n"
		    "\tremoved files were last accessed %s\n",
		    ctime(lastgc)-"\n",
		    (float)removed/(1048576.0/BLOCK_SIZE),
		    removed_files,
		    (time()-lastgc)/60,
		    ctime(garbage_time)-"\n");

  rm("statistics");
  Stdio.write_file("statistics",
		   sprintf("Cache(%s):\n"
			   "\t%1d files%s\n"
			   "\t%1.3f MB (%1.2f%%)\n"
			   "\n"
			   "%s\n"
			   "%s",
			   ctime(time())-"\n", num_files,
			   max_num_files>0?
			   sprintf(" (%1.2f%%)",
				   (float)cache_size*100/max_cache_size):"",
			   ((float)BLOCK_TO_KB(cache_size))/(1024.0),
			   max_cache_size>0?
			   (float)cache_size*100/max_cache_size:0.0,
			   gc_info, disk_info()));
}

private string lf;

void do_write_log()
{
  write_log();
  exit(0);
}

void init_log_file(string lf)
{
  if(!lf || !strlen(lf))
    return;
  
  remove_call_out(init_log_file);
  
  if(gc_log)
    destruct(gc_log);

  gc_log = Stdio.File();
  if(!gc_log->open(lf, "rwac")) {
    werror("          : init_log_file("+lf+"): open failed\n");
    destruct(gc_log);
    return;
  }

  call_out(init_log_file, 300, lf);
}

void init_disk_check(string dir, int minfree)
{
  if(minfree<=0)
    return;

#if efun(filesystem_stat)
  remove_call_out(init_disk_check);

  mapping(string:int|string) st = filesystem_stat(dir);
  if (!st) {
    LOGGER("Minimum free disk check disabled\n");
    return;
  }
  
  disk_time = time();

  float i = ((float)(st->blocksize || 524288.0)) / 1024.0;
  disk_max = (int)(st->blocks * i);
  disk_used = (int)((st->blocks - st->bfree) * i);
  disk_avail = (int)(st->bavail * i);
  // disk_capacity = (disk_max - disk_avail) * 100 / disk_max;
  disk_capacity = disk_used * 100 / disk_max;
  disk_name = st->fsname||"";
  disk_type = st->fstype||"";

  disk_i_max = st->files;
  disk_i_used = st->files - st->ffree;
  disk_i_avail = st->favail;
  disk_i_capacity = (disk_i_max - disk_i_avail) * 100 / disk_i_max;

  if(((disk_used > 0) && ((100 - disk_capacity) <= minfree)) ||
     ((disk_i_used > 0) && ((100 - disk_i_capacity) <= minfree)))
    gc(cache_normal_garb);

  call_out(init_disk_check, 600, dir, minfree);
  
  statistics();
#endif
}

void create(string cdir, string logfiles, int cng, int mcs,
	    int mnf, int minfree, string gc_lf)
{
  if (!stringp(cdir)) return;	// Pike 7.6 calls create() with argv.

  int i;
  for(i = 1; i < 3; i++)
    signal(i,do_write_log);
  signal(signum("SIGINT"), 0);

  if(cdir)
  {
    init_log_file(gc_lf);

#ifdef DEBUG
    LOGGER("Initalizing cache, cache-dir is "+cdir+"\n");
#endif
    cd(cdir);
    cache_normal_garb = cng*(1048576/BLOCK_SIZE); 
    max_cache_size = mcs*(1048576/BLOCK_SIZE);
    if(mnf>0)
      max_num_files = mnf;
    if(lf != logfiles) // This function might be called more than once.
    {
      lf = logfiles;
      create_cache(logfiles);

      if(last_log < 10)
	find_all_files_and_log_it();
      
      if(Stdio.file_size(lp+"cachelog"+_order(1))>=0) {
	LOGGER("Found rechecking unfinished ...\n");
	find_all_files_and_log_it();
      }

      call_out(find_all_files_and_log_it, (BLOCK_TO_KB(cache_size)/5)+3600);
    }

    init_disk_check(cdir, minfree);
    
    LOGGER("Garbage collector ("+version+") on-line, waiting for commands.\n");

    check(0); // Open the 'size' file and, perhaps, do a garbage collect.
  }
}

int main() 
{
  object st = Stdio.File("stdin");
  st->set_id(Stdio.stdin);
  st->set_nonblocking( got_command, 0, cache_stream_closed );
  return -1;
}
