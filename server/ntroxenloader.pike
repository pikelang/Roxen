/* This file is executed by Pike to bootstrap Roxen on NT.
 *
 * $Id$
 */

string dir;
string log_dir;
string key;

class Options
{
  int redirect = 0; // Default is not to redirect stdout with friends.
  int verbose = 1;
  array(string) script;
  string wd;
}

function werror = predef::werror;

object _roxen;
object roxen()
{
  if(!_roxen)
    _roxen =  all_constants()["roxen"];
  return _roxen;
}

int write_status_file()
{
  call_out(write_status_file, 30);

  Stdio.File fd = Stdio.File();
  if(fd->open(log_dir+"/status", "wct"))
  {
    if( roxen() )
    {
      foreach(roxen()->configurations, object c)
	// Configuration not usable here
	fd->write(c->query_name()+"\r\n"+
		  c->query("MyWorldLocation")+"\r\n");
      fd->close();
    }
  } else {
    werror("Failed to open status file %s.\n", log_dir + "/status");
    return 0;
  }
  return 1;
}

function mw;
void my_werror(string fmt, mixed ... args)
{
  if(sizeof(args))
    mw(sprintf(fmt, @args));
  else
    mw(fmt);
}

void read_from_stdin()
{
  while(!file_stat(key)) sleep(2);
  rm(key);

  //  Ask for orderly shutdown. The signal has potentially already been
  //  delivered but it doesn't hurt to make sure.
  if (object rxn = roxen()) {
    if (!rxn->is_shutting_down())
      rxn->exit_when_done();
  }
  sleep(60);
  werror("Roxen not shutting down nicely... forcing termination\n");
  exit(0);
}

string pathcnv (string path)
// Convert a path to use '/' as dir separator. Roxen always uses '/'
// for that (even on NT).
{
  return path && replace (path, "\\", "/");
}

string getcwd()
{
  return pathcnv (predef::getcwd());
}

int main(int argc, array (string) argv)
{
  add_constant ("getcwd", getcwd);

  Options opt = Options();
  
  if(argc > 1 && sizeof(argv[1]) && argv[1][0]=='+')
  {
    key = combine_path (getcwd(), argv[1][1..]);
    argv = argv[..0] + argv[2..];
    argc--;
  }

  if(argc > 1 && argv[1] == "-silent")
  {
    opt->redirect = 1;
    argv = argv[..0] + argv[2..];
    argc--;
  }
  
  int i = search (argv, "--program");
  if (i >= 0) {
    opt->script = argv[i+1..];
    argv = argv[..i-1];
  }

  foreach(Getopt.find_all_options(argv, ({
    ({ "cd", Getopt.HAS_ARG, ({ "--cd" }) }),
    ({ "quiet", Getopt.NO_ARG, ({ "-q", "--quiet" }) })
  })), array arg)
    switch(arg[0])
    {
      case "cd":
	opt->wd = arg[1];
	break;
	
      case "quiet":
	opt->verbose = 0;
	break;
    }
  // Don't complain about unknown options but
  // remove NULL entries left behind by find_all_options
  argv -= ({ 0 });

  dir = pathcnv (combine_path(getcwd(),__FILE__ + "/.."));
  log_dir = combine_path (dir, "../logs");

  if(!cd(dir))
  {
    werror("Failed to cd to "+dir+"\n");
    exit(0);
  }
  add_module_path( dir+"/etc/modules" );
  add_include_path( dir+"/etc/include" );

  add_include_path( dir+"/base_server" );
  add_program_path( dir+"/base_server" );

  add_include_path( dir );
  add_program_path( dir );


  Stdio.File fd = Stdio.File();

  mkdir(log_dir);

  if(opt->redirect)
  {
    mkdir(log_dir+"/debug");

    if (!opt->script) {
      rm(log_dir+"/debug/default.10");
      for(int i=9;i>0;i--)
	mv(log_dir+"/debug/default."+i, log_dir+"/debug/default."+(i+1));
    }

    if(fd->open(log_dir+"/debug/default.1", "wct"))
    {
      fd->dup2( Stdio.stderr );
      fd->dup2( Stdio.stdout );
      mw = fd->write;
      add_constant("werror", my_werror);
      add_constant("write", my_werror);
      werror = my_werror;
    } else {
      werror("Failed to do redirection to %s.\n", log_dir+"/debug/default.1");
    }
  }

  if(opt->verbose)
    werror("Roxen base directory : "+dir+"\n"
	   "Roxen log directory  : "+log_dir+"\n"
	   "Roxen shutdown file  : "+(key || "None")+"\n"
	   "Roxen arguments      : "+(sizeof(argv)>1?argv[1..]*" ":"None")+"\n"
#if constant (Nettle)
	   "This version of Roxen has crypto algorithms available.\n"
#endif
	   );

  call_out (write_status_file, 1);
  
  if(key) thread_create(read_from_stdin);
 
  if(opt->wd)
    cd(opt->wd);

  if(opt->script)
    argv = opt->script;
  else
    argv[0] = dir+"/base_server/roxenloader.pike";

  return ((program)(argv[0]))()->main(argc, argv);
}
