//#include <stdio.h>
#include <simulate.h>

string cvs_version = "$Id: garbagecollector.pike,v 1.6 1997/04/05 01:25:48 per Exp $";

//#define DEBUG

string version = cvs_version;

#define MAX_LOG_SIZE 512
#define MAX_STAT_CACHE_SIZE 1000*MAX_LOG_SIZE


string lp;
int last_log, first_log=0x7fffffff;

mapping log = ([]);

string _order(int from)
{
  return sprintf("%08x", from);
}

int _num(string from)
{
  return (int)("0x"+from[strlen(from)-8..]);
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
  if(!(s=read_bytes(file)))
  {
    mkdir(lp);
    s=read_bytes(file);
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
    perror("Could not decode cachelog file ("+file+") - removed\n");
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
  if(!write_file(file, encode_value(log)))
    perror("Could not write cachelog file ("+file+")\n");
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
  disk_i_used, disk_i_avail, disk_i_capacity, disk_time;
string disk_name;

#define LOGGER(x) if(gc_log)gc_log->write(x);else perror(x)
object gc_log;

string disk_info()
{
  return
    (disk_name?
     sprintf("Disk(%s): %1dkb (%s)\n"
	     "Disk(%s): %1dkb (%1d%%) used, %1dkb avail\n",
	     ctime(disk_time)-"\n", disk_max, disk_name,
	     ctime(disk_time)-"\n",
	     disk_used, disk_capacity, disk_avail):"") + 
    (disk_i_used>0?
     sprintf("Disk(%s): %1d (%1d%%) files used, %1d files avail\n",
	     ctime(disk_time)-"\n",
	     disk_i_used, disk_i_capacity, disk_i_avail):"");
}

void current_cache_message()
{
  if(!gc_log)
    return;
  string now = ctime(time())-"\n";
  
  LOGGER(sprintf("Cache(%s): %1.3f MB data (%1.2f%%)\n",
		 now,
		 (float)BLOCK_TO_KB(cache_size)/1024.0,
		 (float)cache_size*100/max_cache_size
		 ));
  if(max_num_files>0)
    LOGGER(sprintf("Cache(%s): %1d files (%1.2f%%)\n",
		   now, num_files, (float)num_files*100/max_num_files));
  else
    LOGGER(sprintf("Cache(%s): %1d files\n",
		   now, num_files));

  if(disk_name)
    LOGGER(disk_info());

  if(lastgc>0) {
    string gctime = ctime(lastgc)-"\n";
    LOGGER(sprintf("Gc(%s): %1.3f MB (%d files) removed in last gc run\n"
		   "Gc(%s): removed files were last accessed %s\n",
		   gctime, (float)BLOCK_TO_KB(removed)/1024.0, removed_files,
		   gctime, ctime(garbage_time)-"\n"));
  }
}

int read_cache_status()
{
  mapping status = ([]);
  string file, s;
  file = lp+"cache_status";
  mkdir(lp);
  if(file_size(file)<=0) {
    perror("read_cache_status: "+file+" is missing\n");
    return 0;
  }
  if(!(s=read_bytes(file))) {
    perror("read_cache_status: "+file+" could not be read\n");
    rm(file);
    return 0;
  }
  if(catch(status = decode_value(s))) {
    perror("read_cache_status: "+file+" could not be decoded\n");
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
     (cache_size <= 0)||
     (num_files <= 0)||
     (first_log <= 0)) {
    perror("read_cache_status: "+file+" contains rubbish\n");
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

  allfiles = map_array(get_dir(lp), lambda(string s) {
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
    perror("CACHE: Failed to read existing logfile.\n");
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

  if(!write_file(file+"+", encode_value(status)))
    perror("write_cache_status: "+file+"+"+" could not be written\n");
  if(!mv(file+"+", file))
    perror("write_cache_status: "+file+" could not be written\n");
}

void write_log()
{
  mapping status = ([]);	// This doesn't seem to be used
  string file;
  last_log++;
  mkdir(lp);
  file = lp+"cachelog"+_order(last_log);
  rm(file);
  if (!write_file(file, encode_value(log)))
    perror("Could not write cachelog file ("+file+")\n");
  log = ([]);
  write_cache_status();
}

void update(string file, int tim, int|void score)
{
//perror(file+" "+(time(1)-tim)+" seconds old, "+score+" \"bonus\" seconds.\n");
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
    array st = file_stat(dir+path);
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
    if(file_size(dir)<-1 && dir!="logs")
      find_all_files_in(dir+"/");

  last_log++;
  if((file_size(lp+"cachelog"+_order(1))>0) &&
     !mv(lp+"cachelog"+_order(1), lp+"cachelog"+_order(last_log)))
    perror("find_all_files_and_log_it - mv failed\n");
  
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

//  perror("Collect. first_log="+first_log+"; last_log="+last_log+"\n");
  r = catch {
    while((amnt>0)&&(first_log <= last_log))
    {
      mapping rl;
//      perror("Collecting log "+i+"\n");
//      perror("Collect. first_log="+first_log+"; last_log="+last_log+"\n");
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
    perror("Error while garbagecollecting: "+r[0]+"\n"
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
  if(((int)((float)cache_size)) > max_cache_size)
    gc(cache_size);
  else if((max_num_files>0) && (num_files > max_num_files))
    gc(cache_normal_garb);

  return cache_size;
}

void cache_stream_closed()
{
  perror("garbagecollector: cache command stream closed. Exiting\n");
#ifdef LPC_GARB
  write_log();
#endif
  exit(0);
}

static mixed do_command(array what)
{
  mixed res;
  if(!arrayp(what))
  {
    perror(sprintf("Got strange command (%O)\n", what));
    return 0;
  }

#ifdef DEBUG
//  perror(sprintf("Got command %O\n", what));
#endif
  
  return this_object()[what[0]](@what[1..]);
}

private string _cache = "";
static void got_command(object o, string cmd)
{
  cmd = _cache+cmd;

//  perror("Got some data: '"+cmd+"'\n");
  
  while(strlen(cmd))
  {
    int l;
    
    if(strlen(cmd) < 8)  break; // More needed.

    l = (int)("0x"+(cmd[..7]-" "));
    
    if(strlen(cmd) < l+8) break; // More needed

    cmd=cmd[8..]; // Remove the 'length' field of this command.

    array err;
    if(err=catch(do_command( decode_value( cmd[..l-1] ) )))
      stderr->write(describe_backtrace( err ));
    
    cmd=cmd[l..]; // Remove the 'command' field of this command
  }
//  perror("data parsed ("+strlen(cmd)+" bytes in cache).\n");
  
  _cache=cmd;
}

#define MAX(x,y) ((x)<(y)?(y):(x))

int remove_one_file(string fname, int last_access)
{
  array s;
#ifdef DEBUG
//  perror("remove one file? "+fname+" --- ");
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
    // perror("really_gc ("+(int)BLOCK_TO_KB(amnt)+" Kb)\n");
#endif
    collect(amnt, remove_one_file);
    write_cache_status();
    current_cache_message();
#ifdef DEBUG
    // perror("--------- ("+(int)BLOCK_TO_KB(removed)+" Kb really removed)\n");
#endif
  };
  stat_cache = ([]);
}

string statistics()
{
  string last_garb;
  
  if(!removed)
    last_garb="";
  else
    last_garb=sprintf("GC(%s): %2.2f Mb (%d files) removed\n"
		      "GC: last run was %d minutes ago\n"
		      "GC: removed files were last accessed %s\n",
		      ctime(lastgc)-"\n",
                      (float)removed/(1048576.0/BLOCK_SIZE),
		      removed_files,
		      (time()-lastgc)/60,
		      ctime(garbage_time)-"\n");

  rm("statistics");
  write_file("statistics",
	     sprintf("Cache(%s): %1d files%s, %1.3f MB (%1.2f%%)\n%s\n%s",
                    ctime(time())-"\n",
                    num_files,
                    max_num_files>0?
		     sprintf(" (%1.2f%%)",
			     (float)cache_size*100/max_cache_size):"",
                     ((float)BLOCK_TO_KB(cache_size))/(1024.0),
                    (float)cache_size*100/max_cache_size,
                    last_garb, disk_info()));
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

  gc_log = files.file();
  if(!gc_log->open(lf, "rwac")) {
    perror("init_log_file("+lf+"): open failed\n");
    destruct(gc_log);
    return;
  }

  call_out(init_log_file, 300, lf);
}

void init_disk_check(int minfree)
{
  if(minfree<=0)
    return;

  remove_call_out(init_disk_check);
  
  string res;
  string comm = "/usr/ucb/df";
  string rf = "df_output";
  
  if(mixed err = catch {
    spawn(comm + " . > "+rf+" 2>&1;"+comm+" -i . >> "+rf+" 2>&1");
    res = read_bytes(rf);
  } ) {
    LOGGER("Command ("+comm+") failed:" + err[0]+"\n");
    LOGGER("Minimum free disk check disabled\n");
    return;
  }

  if(!stringp(res)|| !strlen(res)) {
    call_out(init_disk_check, 60, minfree);
    return;
  }

  int no;
  if((no = sscanf(res,
		  "%*s%*[\n]%*s%*[ \t]%d%*[ \t]%d%*[ \t]%d%*[ \t]%d%*[%]%*[ \t]%s%*[\n]" +
		  "%*s%*[\n]%*s%*[ \t]%d%*[ \t]%d%*[ \t]%d%*[%]%*s",
		  disk_max, disk_used, disk_avail, disk_capacity, disk_name,
		  disk_i_used, disk_i_avail, disk_i_capacity)) < 12) {
    LOGGER("Minimum free disk check disabled\n");
    return;
  }
  disk_time = time();

#ifdef DEBUGX
  if(no < 24)
    LOGGER("Minimum free inodes check disabled - no no of inode info available\n");
  LOGGER("init_disk_check - disk_max="+disk_max+
	 ", disk_used="+disk_used+
	 ", disk_avail="+disk_avail+
	 ", disk_capacity="+disk_capacity+
	 ", disk_name="+disk_name+"\n");
  LOGGER("init_disk_check - disk_i_used="+disk_i_used+
	 ", disk_i_avail="+disk_i_avail+
	 ", disk_i_capacity="+disk_i_capacity+"\n");
#endif

  if(((disk_used > 0) && ((100 - disk_capacity) < minfree)) ||
     ((disk_i_used > 0) && ((100 - disk_i_capacity) < minfree)))
    gc(cache_normal_garb);
  
  call_out(init_disk_check, 600, minfree);
}

void create(string cdir, string logfiles, int cng, int mcs,
	    int mnf, int minfree, string gc_lf)
{
  int i;
  for(i = 1; i < 3; i++)
    signal(i,do_write_log);
  signal(signum("SIGINT"), 0);

  if(cdir)
  {
    init_log_file(gc_lf);

#ifdef DEBUG
    perror("Initalizing cache, cache-dir is "+cdir+"\n");
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
      
      if(file_size(lp+"cachelog"+_order(1))>=0) {
	LOGGER("Found rechecking unfinished ...\n");
	find_all_files_and_log_it();
      }

      call_out(find_all_files_and_log_it, (BLOCK_TO_KB(cache_size)/5)+3600);
    }

    init_disk_check(minfree);
    
    LOGGER("Garbage collector ("+version+") on-line, waiting for commands.\n");

    check(0); // Open the 'size' file and, perhaps, do a garbage collect.
  }
}

int main() 
{
  object st = File("stdin");
  st->set_nonblocking( got_command, 0, cache_stream_closed );
  st->set_id(stdin);
  return -1;
}
