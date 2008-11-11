inherit "functions.pike";

void main(int argc, array argv)
{
  string self_test_dir = argv[1];
  string var_dir = argv[2];
  
  recursive_cp(combine_path(self_test_dir, "config"),
	       combine_path(var_dir, "test_config"));
	    
  copy_file(combine_path(self_test_dir, "filesystem/test_rxml_package"),
	    "rxml_packages/test_rxml_package");

  // Pull in any testsuites from packages.
  // NB: The search of the modules directory is for compat.
  foreach(sort(long_get_dir("modules") + long_get_dir("packages")),
	  string package) {
    string pkg_test_dir = package + "/test";
    string pkg_setup =
      combine_path(getcwd(), pkg_test_dir, "scripts/setup.pike");
    if (file_stat(pkg_setup)) {
      ((program)pkg_setup)()->main(2, ({ pkg_setup, pkg_test_dir, var_dir }));
    }
  }
}
