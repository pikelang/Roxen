/* This file is executed by pike */

string dir;
string log_dir;


string get_regvalue(string value)
{
  string ret;
  foreach( ({ HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE, }), int w)
    if(ret = RegGetValue(w, "SOFTWARE\\Idonex\\Roxen\\1.3", value))
      return ret;
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
  call_out(write_status_file, 10);

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
  while(1)
    switch(Stdio.stdin.read(3))
    {
     case 0: case "": case "die":
       roxen()->stop_all_modules();
       _exit(0);
       break;

     case "rst":
       roxen()->stop_all_modules();
       _exit(0);
       break;
       
     case "inf":
       remove_call_out(write_status_file);
       write_status_file();
       break;
    }
  roxen()->kill_me();
}

int main(int argc, array (string) argv)
{
  /* Syntax: ntroxenloader.pike <roxen-directory> <roxen loader options> */
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

  
  object fd = Stdio.File();

  mkdir(log_dir);
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

  werror("Compiling "+dir+"base_server\\roxenloader.pike\n");
  call_out(write_status_file, 1);
  thread_create(read_from_stdin);
  return ((program)(dir+"base_server\\roxenloader.pike"))()
    ->main(argc,argv);
}
