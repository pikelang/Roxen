/* This file is executed by pike */

string dir;
string log_dir;
string key;

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

  object fd = Stdio.File();
  if(fd->open(log_dir+"/status", "wct"))
  {
    if( roxen() )
    {
//       fd->write(roxen()->config_url()+"\r\n");
      foreach(roxen()->configurations, object c)
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
  int redirect = 0; // Default is not to redirect stdout with friends.

  add_constant ("getcwd", getcwd);

  if(argc > 1 && sizeof(argv[1]) && argv[1][0]=='+')
  {
    key = combine_path (getcwd(), argv[1][1..]);
    argv = argv[..0] + argv[2..];
    argc--;
  }

  if(argc > 1 && argv[1] == "-silent")
  {
    redirect = 1;
    argv = argv[..0] + argv[2..];
    argc--;
  }

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


  object fd = Stdio.File();

  mkdir(log_dir);

  if(redirect)
  {
    mkdir(log_dir+"/debug");

    rm(log_dir+"/debug/default.10");
    for(int i=9;i>0;i--)
      mv(log_dir+"/debug/default."+i, log_dir+"/debug/default."+(i+1));

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

  werror("Roxen base directory : "+dir+"\n"
	 "Roxen log directory  : "+log_dir+"\n"
	 "Roxen shutdown file  : "+(key || "None")+"\n"
	 "Roxen arguments      : "+(sizeof(argv)>1?argv[1..]*" ":"None")+"\n"
#if constant(_Crypto) && constant(Crypto.rsa)
	 "This version of Roxen has crypto algorithms available.\n"
#endif
	);

  call_out (write_status_file, 1);
  if(key) thread_create(read_from_stdin);
  argv[0] = dir+"/base_server/roxenloader.pike";
  return ((program)(argv[0]))()->main(argc, argv);
}
