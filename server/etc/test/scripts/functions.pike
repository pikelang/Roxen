#define ERROR(x,y) throw(({ sprintf(x, y), backtrace() }))
void copy_file(string src_name, string dest_name)
{
  Stdio.File src = Stdio.File(src_name, "r");
  if(!src)
    ERROR("Can't open source file: %O\n", src);
  
  Stdio.File dest = Stdio.File(dest_name, "cwt");
  if(!dest)
    ERROR("Can't open destination file: %O\n", dest);
  
  dest->write(src->read());
  dest->close();
  src->close();
}

void recursive_cp(string src, string dest)
{
  if(!Stdio.is_dir(src))
    ERROR("Source file is not a directory: %O\n", src);

  if(!Stdio.is_dir(dest) && !mkdir(dest))
    ERROR("Can not create destination directory: %O\n", dest);
  
  foreach(get_dir(src), string item)
  {
    string src_path = combine_path(src, item);
    string dest_path = combine_path(dest, item);
    if(Stdio.is_dir(src_path))
      recursive_cp(src_path, dest_path);
    else
      copy_file(src_path, dest_path);
  }
}

void extract_tarfile(Filesystem.Tar tarfile, string dest_dir)
{
  tarfile->tar->extract ("/", dest_dir);
}

array(string) long_get_dir(string dir)
{
  return map(get_dir(dir)||({}),
	     lambda(string f, string dir) {
	       return dir + "/" + f;
	     }, dir);
}
