
void copy_file(string src_name, string dest_name)
{
  Stdio.File src = Stdio.File(src_name, "r");
  if(!src)
    error("Can't open source file: %O\n", src);
  
  Stdio.File dest = Stdio.File(dest_name, "cwt");
  if(!dest)
    error("Can't open destination file: %O\n", dest);
  
  dest->write(src->read());
  dest->close();
  src->close();
}

void recursive_cp(string src, string dest)
{
  if(!Stdio.is_dir(src))
    error("Source file is not a directory: %O\n", src);

  if(!Stdio.is_dir(dest) && !mkdir(dest))
    error("Can not create destination directory: %O\n", dest);
  
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
  void extract_path(string base)
  {
    foreach(tarfile->get_dir(base), string entry)
    {
      string abs_entry = combine_path(dest_dir, (entry[0..0]=="/"? entry[1..]: entry));
      if(tarfile->stat(entry)->isdir())
      {
	mkdir(abs_entry);
	extract_path(entry);
      }
      else
      {
	Stdio.File file = Stdio.File(abs_entry, "cwt");
	
	file->write(tarfile->stat(entry)->size?tarfile->open(entry, "r")->read():"");
	file->close();
      }
    }
  };
  
  mkdir(dest_dir);
  extract_path("/");
}
