inherit "functions.pike";

void main(int argc, array argv)
{
  string self_test_dir = argv[1];
  string var_dir = argv[2];
  
  recursive_cp(combine_path(self_test_dir, "config"),
	       combine_path(var_dir, "test_config"));
	    
  copy_file(combine_path(self_test_dir, "filesystem/test_rxml_package"),
	    "rxml_packages/test_rxml_package");
}
