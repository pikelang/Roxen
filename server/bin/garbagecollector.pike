/* There is some bug in this I haven't had time to find. */

//#define DEBUG

string version = "$Id: garbagecollector.pike,v 1.2 1996/11/15 04:26:43 per Exp $";

#define MAX_LOG_SIZE 512

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
  
  mkdir(lp);
  file = lp+"cachelog"+_order(num);
  if(!(s=read_bytes(file)))
  {
    log = ([]);
    return 0;
  } else {
    if(catch(log = decode_value( s )))
      return 0;
    return log;
  }
}

void create_cache(string logprefix)
{
  lp = logprefix;
  int i;
  string file;
  array (string) files;

  mkdir(lp);
#if 0
  files = map_array(get_dir(lp), lambda(string s) {
    if(!search(s, "cachelog")) return s;
    return 0;
  }) - ({ 0 });

  foreach(files, file)
  {
    if((i=_num(file)) > last_log)
      last_log = i;
    if(i < first_log)
      first_log = i;
  }

  if(!last_log) {
    first_log = 0;
    return; // Ok, no old log.
  }

  while(!((log=parse_log(last_log)) && last_log>=0))
    last_log--;
  if(!log)
    log = ([]);

  if(last_log < 0)
    perror("CACHE: Failed to read existing logfile.\n");
#endif
}

void write_log()
{
  string file;
  last_log++;
  mkdir(lp);
  file = lp+"cachelog"+_order(last_log);
  rm(file);
  write_bytes(file, encode_value(log));
  log = ([]);
}

void update(string file, int tim, int|void score)
{
//perror(file+" "+(time(1)-tim)+" seconds old, "+score+" \"bonus\" seconds.\n");
  log[file] = ({ tim, score });
  if(sizeof(log) > MAX_LOG_SIZE)
    write_log();
}

void accessed(string filename, int extra)
{
  update(filename, time(), extra);
}

int do_collect(int amnt, function cb, mapping log)
{
  array a, b;
  
  a = values(log);
  b = indices(log);
  sort(map_array(a,lambda(array a){`-(@a);}), b);

  int i;
  for(i=0; i<sizeof(b); i++)
  {
    m_delete(log, b[i]);
    amnt -= cb(b[i], a[i][0]);
    if(amnt <= 0) throw("Done");
  }
  return amnt;
}

#define BLOCK_SIZE 2048

#define FILE_SIZE_TO_BLOCK(X) (((X)+(BLOCK_SIZE-1))/BLOCK_SIZE)
#define BLOCK_TO_KB(X)        (((X)*BLOCK_SIZE)/1024)

int max_cache_size;
int cache_normal_garb;
int cache_size;
int num_files; // Only used for informative output

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
	  update(dir+path, st[2], st[1]/20);
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
  
  perror("Rechecking cache ... ");

  num_files = cache_size = 0;
  rm("size");
  find_all_files_in("logs/", rm); // Remove all logs
  log=([]);
  first_log = last_log = 0;   // Well, lets start again then.

  foreach(dirs, dir)
    if(file_size(dir)<-1 && dir!="logs")
      find_all_files_in(dir+"/");

  perror(sprintf("Found %d files, in total %.2fMb data\n",
		 num_files, (float)BLOCK_TO_KB(cache_size)/1024.0));
  remove_call_out(find_all_files_and_log_it);
  call_out(find_all_files_and_log_it, (BLOCK_TO_KB(cache_size)/5)+7200);
}


void collect(int amnt, function callback, int|void norec)
{
  int i, t_last_log = last_log+(last_log-first_log);
  mixed r;
  write_log();
//  perror("Collect. first_log="+first_log+"; last_log="+last_log+"\n");
  r = catch {
    for(i=first_log; i<=t_last_log; i++)
    {
      mapping rl;
//      perror("Collecting log "+i+"\n");
//      perror("Collect. first_log="+first_log+"; last_log="+last_log+"\n");
      if(rl = parse_log(i))
      {
	rm_log(i);
	if(i != last_log)
	  first_log = i+1;
	amnt = do_collect(amnt, callback, rl);
      }
    }
  }; 
  if(!r)
  {
#ifdef DEBUG
    perror("All files removed?\n");
#endif
    if(norec)
    {
      perror("All files removed, but still data to collect.\n");
      return;
    }
    find_all_files_and_log_it();
    if(amnt >= 0)
      return collect(amnt, callback, 1);
  }
  if(r && (r!= "Done"))
    perror("Error while garbagecollecting: "+r[0]+"\n"
           +describe_backtrace(r[1]));
}

void gc(int);

// All sizes are in BLOCK_SIZE b blocks, except for
// howmuch, which is in bytes.
int check(int howmuch)
{
  howmuch = FILE_SIZE_TO_BLOCK(howmuch);
  cache_size += howmuch;

  //  len is in units of BLOCK_SIZE bytes. 
  if(((int)((float)cache_size)) > max_cache_size)
    gc(cache_size);
  
#ifdef DEBUG
  perror(sprintf("data in cache: %d Kb\n",
		 (int)((float)BLOCK_TO_KB(cache_size))));
#endif
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

int removed, lastgc;

#define MAX(x,y) ((x)<(y)?(y):(x))

mapping stat_cache = ([]);



void cleandirs()  // Not really needed when using the 'hash' method.
{
//  object null = new(File);
//  null->open("/dev/null", "rw");
//  spawn("find . -type d | xargs rmdir", null, null, null);
//  remove_call_out(cleandirs);
//  call_out(cleandirs, (cache_size+3)*3600);
}


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
    int i;

    if((search(fname, ".done")!=-1) && (s[2]-10 > last_access))
    {
#ifdef DEBUG
//      perror("Nope.\n");
#endif
      update(fname, s[2],  s[1]/20);
      return 0; /* File has been accessed since the cache checked */
    }
    i=FILE_SIZE_TO_BLOCK(s[1]);
#ifdef DEBUG
//    perror("Yep. "+(int)BLOCK_TO_KB(i)+"Kb removed\n");
#endif
    s[1]=-1;
    removed += i;
    cache_size-=i;
    rm( fname );
    return i; /* Ok, removed */
  }
#ifdef DEBUG
//  perror("Already.\n");
#endif
  return 0; /* No such file */
}

/* Do _not_ call check() from this function. It might cause infinite
 * recursion
 */

void gc(int cs)
{
  int amnt;

  stat_cache = ([]);
  removed = 0;
  lastgc = time();
  amnt = MAX(cache_normal_garb, cs-max_cache_size);

  catch {
#ifdef DEBUG
    perror("really_gc ("+(int)BLOCK_TO_KB(amnt)+" Kb)\n");
#endif
    collect(amnt, remove_one_file);
#ifdef DEBUG
    perror("--------- ("+(int)BLOCK_TO_KB(removed)+" Kb really removed)\n");
#endif
  };
//  cleandirs();
  stat_cache = ([]);
}

string statistics()
{
  string last_garb;
  
  if(!removed)
    last_garb="";
  else
    last_garb=sprintf("%2.2f Mb was removed in the last garbage collection "
		      "%d minutes ago",
		      (float)removed/(1048576.0/BLOCK_SIZE),
		      (time()-lastgc)/60);
  rm("statistics");
  write_file("statistics",
	     sprintf("%2.2f Mb data in the cache\n%s",
		     ((float)BLOCK_TO_KB(cache_size))/(1024.0),
		     last_garb));
}


private string lf;

void do_write_log()
{
  write_log();
  exit(0);
}

void create(string cdir, string logfiles, int cng, int mcs)
{
  int i;
  for(i = 1; i < 3; i++)
    signal(i,do_write_log);
  signal(signum("SIGINT"), 0);

  if(cdir)
  {
#ifdef DEBUG
    perror("Initalizing cache, cache-dir is "+cdir+"\n");
#endif
    cd(cdir);
    cache_normal_garb = cng*(1048576/BLOCK_SIZE); 
    max_cache_size = mcs*(1048576/BLOCK_SIZE);
    if(lf != logfiles) // This function might be called more than once.
    {
      lf = logfiles;
      cleandirs();
      create_cache(logfiles);
//    find_all_files_and_log_it();
    }
    check(0); // Open the 'size' file and, perhaps, do a garbage collect.
    perror("Garbage collector ("+version+") on-line, waiting for commands.\n");
    perror("Current cache size: "
           +((float)BLOCK_TO_KB(cache_size)/(1024.0))+" MB\n");
  }
}

int main() 
{
  stdin->set_nonblocking( got_command, 0, cache_stream_closed );
  stdin->set_id(stdin);
  return -1;
}
