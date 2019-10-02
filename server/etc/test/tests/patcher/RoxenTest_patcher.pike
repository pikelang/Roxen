inherit "../pike_test_common.pike";

void run_tests(Configuration c)
{
  // Replace this with global var later.
  string ptfm_str = test_true(Stdio.read_file, combine_path(getcwd(), "OS"));
  if (!ptfm_str) return;
  ptfm_str = String.trim_all_whites(ptfm_str);

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
#ifdef __NT__
  test_path = replace(test_path, "/", "\\");
  temp_path = replace(temp_path, "/", "\\");
#endif
  if(!mkdir(temp_path))
  {
    if (test_true(Stdio.is_dir, temp_path)) {
      werror("The temporary directory %O already exists.\n"
	     "This is most likely due to a previous self-test run "
	     "having failed.\n"
	     "Trying to clear the directory.\n",
	     temp_path);
      test(po->clean_up, temp_path, 1);
      test_true(mkdir, temp_path);
    } else {
      werror("Creation of the test directory failed: %s\n\n",
	     strerror(errno()));
      return;
    }
  }
  
  // Place all temporary files in the same directory
  test(po->set_temp_dir, temp_path);

  // Add temp path to environment (to be passed on to external processes)
  mapping env = getenv() || ([ ]);
  env->TEMP = temp_path;

  // Try importing and installing a patch directly through the lib. 
  array(int|string) patch_ids = test_true(po->import_file, 
					  combine_path(test_path, "2009-02-25T1124.rxp"), 
					  0);
  string patch_id = patch_ids[0];
  test_true(po->install_patch, patch_id, "self_test@localhost");

  // Create a patch using the lib.
  
  test_true(po->create_patch, 
	      ([ "id" 		: "2009-02-25T1628",
		 "name"		: "Test Patch 2: replace",
		 "description"	: "This is test 2.",
		 "originator"	: "self_test@localhost",
		 "rxp_version"  : RoxenPatch.rxp_version,
		 "version"      : po->parse_version(po->get_server_version()),
		 "depends"	: ({ "2009-02-25T1124" }),
		 "replace"      : ({ 
		                    ([ "source" : combine_path(test_path,
							       "testfile.txt"),
				       "destination" : "test/testfile.txt" ]) 
	                          }),
	      ]),
	    temp_path);

  // Install it using the command line tool
  string clt_path = test_true(combine_path, getcwd(), "bin", 
#ifdef __NT__
"rxnpatch.bat"
#else
"rxnpatch"
#endif
);
  Process.Process p = test(Process.Process,
			   ({ clt_path, 
			      "-O", "self_test@roxen.com",
			      "--no-colour",
			      "install", 
			      combine_path(temp_path, 
					   "2009-02-25T1628.rxp") }),
			   ([ "env" : env ]) );
  test_false(p && p->wait);

  // Create a patch using the command line tool and then install it.
  array clt_args = ({ clt_path, "create", 
		      "--no-colour",
		      "-k", "2009-02-25T1728",
		      "-N", "Test Patch 3: patching",
		      "-D", 
		      "-O", "self_test@roxen.com", 
		      "--platform=" + ptfm_str,
		      "--patch=" + combine_path(test_path, "testfile.patch"),
		      "-t", temp_path });
  Stdio.File desc = Stdio.File();
  p = test(Process.Process, clt_args, ([ "stdin" : desc.pipe(),
					 "env"	: env ]) );
  
  test(desc.write, "Created by self_test.");
  test(desc.close);
  test_false(p && p->wait);
  
  patch_ids = test_true(po->import_file,
			combine_path(temp_path, "2009-02-25T1728.rxp"),
			0);
  patch_id = patch_ids[0];

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
