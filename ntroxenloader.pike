/* This file is executed by pike */

string dir;
string log_dir;
string key;

string get_regvalue(string value)
{
  string ret;
  foreach( ({ HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE, }), int w)
    catch {
      if(ret = RegGetValue(w, "SOFTWARE\\Idonex\\Roxen\\1.3", value))
	return ret;
    };
}

object _roxen;
object roxen()
{
  if(!_roxen)
    _roxen =  all_constants()["roxen"];
  return _roxen;
}

void write_status_file()
{
  call_out(write_status_file, 30);

  object fd = Stdio.File();
  if(fd->open(log_dir+"\\status", "wct"))
  {
    fd->write(roxen()->config_url()+"\r\n");
    foreach(roxen()->configurations, object c)
      fd->write(c->query_name()+"\r\n"+
		c->query("MyWorldLocation")+"\r\n");
    fd->close();
  } else
    werror("Failed to open status file.\n");
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
  while(!file_stat(log_dir + "\\" + key)) sleep(2);
  rm(log_dir + "\\" + key);
  exit(0);
}

int main(int argc, array (string) argv)
{
  int redirect = 1; // Default is to redirect stdout with friends.
  /* Syntax: ntroxenloader.pike <roxen-directory> <roxen loader options> */
  if(argc > 1 && argv[1][0]=='+')
  {
    key = argv[1][1..];
    argv = argv[1..];
    argc--;
  }

  if(argc > 1 && argv[1] == "-verbose")
  {
    redirect = 0;
    argv = argv[1..];
    argc--;
  }

  dir = replace(combine_path(getcwd(),__FILE__), "/", "\\");
  dir = dir[..sizeof(dir)-search(reverse(dir), "\\")-2];
  if(sizeof(dir)<2 || dir[1]!=':' || !file_stat(dir+"\\server"))
    dir = get_regvalue("installation_directory");
  if(!dir)
  {
    werror("Failed to get registry entry for installation directory.\n"
	   "Aborting.\n");
    exit(0);
  }

  log_dir = get_regvalue("log_directory");
  if(!log_dir)  log_dir = dir + "\\logs";

  
  dir += "\\server\\";
  dir = replace(dir, "\\\\", "\\");

  if(!cd(dir))
  {
    werror("Failed to cd to "+dir+"\n");
    exit(0);
  }
  add_module_path( dir+"etc\\modules" );
  add_include_path( dir+"etc\\include" );

  add_include_path( dir+"base_server" );
  add_program_path( dir+"base_server" );

  add_include_path( dir );
  add_program_path( dir );
  putenv("CLASSPATH",(getenv("CLASSPATH")? getenv("CLASSPATH")+";":"")+
	 dir+"etc\\classes\\jsdk.jar;"+dir+"etc\\classes\\roxen_servlet.jar;"+
	 dir+"etc\\classes");

  
  object fd = Stdio.File();

  mkdir(log_dir);

  if(redirect)
  {
    werror("Using configuration from "+dir+"configurations\\, "
	   "storing the debug log in "+log_dir+"\\debug\\default.1\r\n"
	   "You can use the configuration interface in the server to "
	   "get debug info.\r\n");

    mkdir(log_dir+"\\debug");
  
    for(int i=10;i>0;i--)
      mv(log_dir+"\\debug\\default."+i, log_dir+"\\debug\\default."+(i+1));

    if(fd->open(log_dir+"\\debug\\default.1", "wct"))
    {
      fd->dup2( Stdio.stderr );
      fd->dup2( Stdio.stdout );
      mw = fd->write;
      add_constant("werror", my_werror);
      add_constant("write", my_werror);
    } else {
      werror("Failed to do redirection\n");
    }
  }

  function rget=
    lambda(string ent) {
      string res ;
      catch(res=RegGetValue(HKEY_CURRENT_USER,"SOFTWARE\\Idonex\\Pike\\0.6",ent));
      if(res) return res;
      catch(res=RegGetValue(HKEY_LOCAL_MACHINE,"SOFTWARE\\Idonex\\Pike\\0.6",ent));
      if(res) return res;
      return "<undefined>";
    };
  werror("Primary bootstrap complete.\n"
 "   Pike master file     : "+rget("PIKE_MASTER")+"\n"
 "   Pike share directory : "+rget("share_prefix")+"\n"
 "   Pike arch directory  : "+rget("lib_prefix")+"\n"
 "   Roxen base directory : "+dir+"\n"
 "   Roxen configurations : "+dir+"configurations\n"
 "   Roxen status file    : "+log_dir+"\\status\n"
 "   Roxen shutdown file  : "+(key?log_dir+"\\"+key:"None")+"\n"
 "   Roxen log directory  : "+log_dir+"\n"
 "   Roxen arguments      : "+(sizeof(argv)>1?argv[1..]*" ":"None")+"\n"
#if constant(_Crypto) && constant(Crypto)
 "   This version of roxen has crypto algorithms available\n"
#endif
 "\n");
 
  werror("Compiling second level bootstrap ["
	 +dir+"base_server\\roxenloader.pike]\n");
  call_out(write_status_file, 1);
  if(key) thread_create(read_from_stdin);
  return ((program)(dir+"base_server\\roxenloader.pike"))()
    ->main(argc, argv);
}
