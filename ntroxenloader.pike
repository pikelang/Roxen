/* This file is executed by pike */

string dir;
void write_status_file()
{
  call_out(write_status_file, 10);

  object fd = Stdio.File();
  if(fd->open(dir+"..\\logs\\debug\\status", "wct"))
  {
    object roxen = all_constants()["roxen"];
    fd->write(roxen->config_url()+"\r\n");
    foreach(roxen->configurations, object c)
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

int main(int argc, array (string) argv)
{
  /* Syntax: ntroxenloader.pike <roxen-directory> <roxen loader options> */
  dir = argv[1]+"\\server\\";
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

  mkdir(dir+"..\\logs");
  mkdir(dir+"..\\logs\\debug");
  
  for(int i=10;i>0;i--)
    mv(dir+"..\\logs\\debug\\default."+i, dir+"..\\logs\\debug\\default."+(i+1));

  if(fd->open(dir+"..\\logs\\debug\\default.1", "wct"))
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
  return ((program)(dir+"base_server\\roxenloader.pike"))()
    ->main(argc-1,argv[1..]);
}
