int copy_file(string src_name, string dest_name)
{
  Stdio.File src = Stdio.File(src_name, "r");
  if(!src)
  {
    werror("Can't open source file: %O\n", src);
    return 1;
  }
  
  Stdio.File dest = Stdio.File(dest_name, "cwt");
  if(!dest)
  {
    werror("Can't open destination file: %O\n", dest);
    return 1;
  }
  
  dest->write(src->read());
  dest->close();
  src->close();
}

void main(int argc, array argv)
{
  string self_test_dir = argv[1];
  string var_dir = argv[2];
  
  copy_file(combine_path(self_test_dir, "filesystem/test_rxml_package"),
	    "rxml_packages/test_rxml_package");
}
