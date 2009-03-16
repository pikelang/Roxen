inherit "../pike_test_common.pike";

void run_tests(Configuration c)
{
  // Replace this with global var later.
  string ptfm_str = String.trim_all_whites(
    test_true(Stdio.read_file, combine_path(getcwd(), "OS")));
  RoxenPatch.Patcher po = test(RoxenPatch.Patcher, 
			       lambda(string s)
			       {
				 write(RoxenPatch.wash_output(s));
			       },
			       lambda(string s)
			       {
				 werror(RoxenPatch.wash_output(s));
			       },
			       getcwd(),
			       getenv("LOCALDIR"));
  
  // Set temporary paths.
  string test_path = test_true(po->combine_and_check_path,
			       combine_path("etc", "test","tests", "patcher"));
  string temp_path = combine_path(test_true(po->get_temp_dir), 
				  "roxen_self_test");
  test_true(mkdir, temp_path);
  
  // Try importing and installing a patch directly through the lib. 
  string patch_id = test_true(po->import_file, 
			      combine_path(test_path, "2009-02-25T1124.rxp"), 
			      0);
  test_true(po->install_patch, patch_id, "self_test@localhost");

  // Create a patch using the lib.
  
  test_true(po->create_patch, 
	      ([ "id" 		: "2009-02-25T1628",
		 "name"		: "Test Patch 2: replace",
		 "description"	: "This is test 2.",
		 "originator"	: "self_test@localhost",
		 "rxp_version"  : RoxenPatch.rxp_version,
		 "version"      : ({ roxen_dist_version }),
		 "depends"	: ({ "2009-02-25T1124" }),
		 "replace"      : ({ 
		                    ([ "source" : combine_path(test_path,
							       "testfile.txt"),
				       "destination" : "test/testfile.txt" ]) 
	                          }),
	      ]),
	    temp_path);

  // Install it using the command line tool
  string clt_path = test_true(combine_path, getcwd(), "bin", "rxnpatch"); 
  Process.create_process p = test(Process.create_process,
				  ({ clt_path, 
				     "install", 
				     combine_path(temp_path, 
						  "2009-02-25T1628.rxp") }) );
  test_false(p->wait);

  // Create a patch using the command line tool and then install it.
  array clt_args = ({ clt_path, "create", 
		      "-k", "2009-02-25T1728",
		      "-N", "Test Patch 3: patching",
		      "-D", 
		      "-O", "self_test@roxen.com", 
		      "--platform=" + ptfm_str,
		      "--patch=" + combine_path(test_path, "testfile.patch"),
		      "-t", temp_path });
  Stdio.File desc = Stdio.File();
  p = test(Process.create_process, clt_args, ([ "stdin" : desc.pipe() ]) );
  
  desc.write("Created by self_test.");
  desc.close();
  test_false(p->wait);
  
  patch_id = test_true(po->import_file,
		       combine_path(temp_path, "2009-02-25T1728.rxp"),
		       0);

  test_true(po->install_patch, patch_id, "self_test@localhost");

  test_false(po->uninstall_patch, "2009-02-25T1124", "self_test@localhost");

  // Uninstall all patches
  test_true(po->uninstall_patch, "2009-02-25T1728", "self_test@localhost");
  test_true(po->uninstall_patch, "2009-02-25T1628", "self_test@localhost");
  test_true(po->uninstall_patch, "2009-02-25T1124", "self_test@localhost");
  
  // Clean up.
  test_true(po->clean_up, 
	    combine_path(po->get_import_dir(), "2009-02-25T1728"));
  test_true(po->clean_up, 
	    combine_path(po->get_import_dir(), "2009-02-25T1628"));
  test_true(po->clean_up, 
	    combine_path(po->get_import_dir(), "2009-02-25T1124"));
  test_false(po->clean_up, 
	     combine_path(po->get_installed_dir(), "2009-02-25T1728"), 1);
  test_false(po->clean_up, 
	     combine_path(po->get_installed_dir(), "2009-02-25T1628"), 1);
  test_false(po->clean_up, 
	     combine_path(po->get_installed_dir(), "2009-02-25T1124"), 1);
  test_true(po->clean_up, temp_path, 0);
  test_true(po->clean_up, combine_path(getcwd(), "test"));
}
