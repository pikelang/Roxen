#!
import RoxenPatch;

int main(int argc, array(string) argv)
{  
  array(array) switches = Getopt.find_all_options(
    argv, 
    ({
      ({ "help",            Getopt.MAY_HAVE_ARG, ({ "-h", "--help"      }) }),
      ({ "import",          Getopt.MAY_HAVE_ARG, ({ "-I", "--import"    }) }),
      ({ "install",         Getopt.MAY_HAVE_ARG, ({ "-i", "--install"   }) }),
      ({ "uninstall",       Getopt.HAS_ARG,      ({ "-u", "--uninstall" }) }),
      ({ "status",          Getopt.HAS_ARG,      ({ "-s", "--status"    }) }),
      ({ "server_path",     Getopt.HAS_ARG,      ({ "-S", "--server"    }) }),
      ({ "list",            Getopt.NO_ARG,       ({ "-l", "--list"      }) }),
      ({ "list_installed",  Getopt.NO_ARG,  ({ "-T", "--list-installed" }) }),
      ({ "list_imported",   Getopt.NO_ARG,   ({ "-U", "--list-imported" }) }),
      ({ "rxp_version",     Getopt.NO_ARG,       ({ "-v", "--version"   }) }),
      ({ "force",           Getopt.NO_ARG,       ({ "-f", "--force"     }) }),
      ({ "create",          Getopt.NO_ARG,       ({ "-c", "--create"    }) }),
      ({ "target_dir",      Getopt.HAS_ARG,      ({ "-t"                }) }),
      ({ "metadata",        Getopt.HAS_ARG,      ({ "-m"                }) }),
      ({ "name",            Getopt.HAS_ARG,      ({ "-N"                }) }),
      ({ "originator",      Getopt.HAS_ARG,      ({ "-O"                }) }),
      ({ "description",     Getopt.MAY_HAVE_ARG, ({ "-D"                }) }),
      ({ "platform",        Getopt.HAS_ARG,      ({ "-P"                }) }),
      ({ "version",         Getopt.HAS_ARG,      ({ "-V"                }) }),
      ({ "udiff",           Getopt.MAY_HAVE_ARG, ({ "-p"                }) }),
      ({ "new_file",        Getopt.HAS_ARG,      ({ "-n"                }) }),
      ({ "replace_file",    Getopt.HAS_ARG,      ({ "-R"                }) }),
      ({ "delete_file",     Getopt.HAS_ARG,      ({ "-X"                }) }),
      ({ "depends_on",      Getopt.HAS_ARG,      ({ "-d"                }) }),
      ({ "flags",           Getopt.HAS_ARG,      ({ "-F"                }) }),
      ({ "reload",          Getopt.HAS_ARG,      ({ "-L"                }) }),
      ({ "id",              Getopt.HAS_ARG,      ({ "-k", "--id"        }) }),
      ({ "dryrun",          Getopt.NO_ARG,       ({ "--dry-run"         }) }),
      ({ "nocolor",         Getopt.NO_ARG,       ({ "--no-color",
                                                    "--no-colour"       }) }),
      ({ "recursive",       Getopt.NO_ARG,       ({ "-r", "--recursive" }) }),
    }));

  if (sizeof(switches) || 1)
  {
    string current_user = getenv("ROXEN_USER") || 
                          sprintf("%s@localhost", getpwuid(getuid())[0]);
   
    string server_path = "";
  
    // We NEED to find the server flag first and instantiate the Patcher class
    int color = (Array.search_array(switches,
				    lambda(array a)
				    { return a[0] == "nocolor"; }
				    ) == -1);

    int recursive = (Array.search_array(switches,
					lambda(array a)
					{ return a[0] == "recursive"; }
					) != -1);

    int i = Array.search_array(switches, 
			       lambda(array a)
			       { return a[0] == "server_path"; }
			       );
    if (i == -1)
    {
      server_path = getenv("ROXEN_SERVER");
      if (!server_path)
      {
	if (color)
	  werror("\e[1;91mCould not resolve server path. Quitting.\e[0m\n");
	else
	  werror("Could not resolve server path. Quitting.\n");
	return 0;
      }
    }
    else
      server_path = switches[i][1];

    Patcher plib = Patcher((color) ? lambda(string s)
				     {
				       string a, b;
				       if (sscanf(s, "%sDone!\n%s", a, b))
					 write("%s\e[92mDone!\n\e[0m%s", a, b);
				       else if (sscanf(s, "%sok.\n%s", a, b))
					 write("%s\e[92mok.\n\e[0m%s", a, b);
				       else
					 write(s);
				     } : write,
                           (color) ? lambda(string s) 
				     { werror("\e[1;91m%s\e[0m", s); } : write, 
                           server_path
			   );

    mapping(string:array(string)) args = ([ ]);
    PatchObject ptc_obj = ([ ]);
    foreach(switches, array argument)
    {
      switch(argument[0])
      {
	case "help":
	  args->help += ({ (string)argument[1] });
	  break;
	case "create":
	  args->create = ({ });
	  break;
	case "uninstall":
	  if (plib->verify_patch_id(argument[1]) &&
	      plib->is_installed(argument[1]))
	    args->uninstall += ({ argument[1] });
	  break;
	case "import":
	  if (argument[1] == 1 && !args->stdin)
	  // Read from standard in.
	  {
	    plib->write_err("Sorry, reading patch from stdin is not " 
			    "implemented\n");
	    args->stdin = ({ });
// 	    string s = Stdio.stdin->read();
// 	    args->import_data = ({ s });
// 	    plib->write_mess("Done!\n");
	  }
	  else if (argument[1] == 1)
	  // Somebody else wants to read from standard in.
	  {
	    plib->write_err(err_stdin);
	    return 0;
	  }
	  else
	  {
	    // Check if the argument contains globs
	    sscanf(argument[1], "%*s%[*?]", string found_glob);
	    if (found_glob && sizeof(found_glob))
	      args->import = plib->find_files_with_globs(argument[1], 
							 recursive);
	    else
	      args->import += ({ argument[1] });
	  }
	  break;
	case "install":
	  if (argument[1] == 1 && !args->stdin)
	  // Read from standard in.
	  {
	    plib->write_err("Sorry, reading patch from stdin is not " 
			    "implemented\n");
	    args->stdin = ({ });
// 	    string s = Stdio.stdin->read();
// 	    args->install_data = ({ s });
// 	    plib->write_mess("Done!\n");
	  }
	  else if (argument[1] == 1)
	  // Somebody else wants to read from standard in.
	  {
	    plib->write_err(err_stdin);
	    return 0;
	  }
	  // Are we going to install ALL imported patches?
	  else if (argument[1] == "*")
	  {
	    // Get a list of all imported patches
	    foreach(plib->file_list_imported(), PatchObject po)
	    {
	      args->install += ({ po->id });
	    }
	  }
	  // Is the argument an id of an already installed patch?
	  else if (plib->verify_patch_id(argument[1]) && 
		   plib->is_imported(argument[1]))
	  {
	    args->install += ({ argument[1] });
	  }
	  // Check if there's an imported patch with that name.
	  else
	  {
	    string id = plib->extract_id_from_filename(argument[1]);
	    if (plib->is_imported(id))
	      args->install += ({ id });
	    else
	      args->install_file += ({ argument[1] });
	  }
	  break;
	case "list":
	  args->list += ({ });
	  break; 
	case "list_installed":
	  args->list += ({ "list_installed" });
	  break;
	case "list_imported":
	  args->list += ({ "list_imported" });
	  break;
	case "status":
	  args->status += ({ argument[1] });
	  break;
	case "rxp_version":
	  args->rxp_version = ({ });
	  break;
	case "force":
	  args->force = ({ });
	  break;
	case "target_dir":
	  if (!args->target_dir)
	    args->target_dir = ({ combine_and_check_path(argument[1]) });
	  else
	  {
	    plib->write_err("Too many arguments: -t\n");
	    return 0;
	  }
	  break;
	case "metadata":
	  if (args->metadata)
	  {
	    plib->write_err("Too many arguments: -m\n");
	    return 0;
	  }
	  else if (args->cfcl) // == Create From Command Line.
	  {
	    plib->write_err(err_arg_col);
	    return 0;
	  }
	  else
	  {
	    plib->write_mess("Parsing metadata file...");
	    Stdio.File md_file = Stdio.File();
	    md_file->open(argument[1], "r");
	    args->metadata = ({ md_file->read() });
	    ptc_obj = plib->parse_metadata(args->metadata[0],
					   plib->create_id());
	    plib->write_mess("Done!\n");
	  }
	  break;
	case "name":
	  if (args->metadata)
	  {
	    plib->write_err(err_arg_col);
	    return 0;
	  }
	  else if (ptc_obj->name)
	  {
	    plib->write_err("Too many arguments: -N\n");
	    return 0;
	  }
	  else
	  {
	    ptc_obj->name = argument[1];
	  }
	  break;
	case "originator":
	  // TODO: Maybe some emailadress verification here?
	  if (sscanf(argument[1], "%*s@%*s.%*s") == 3)
	    current_user = argument[1];
	  else
	    plib->write_err("Not a valid e-mail address: -O\n");
	  break;
	case "description":
	  if (args->metadata)
	  {
	    plib->write_err(err_arg_col);
	    return 0;
	  }
	  else if (ptc_obj->description)
	  {
	    plib->write_err("Too many arguments: -D\n");
	    return 0;
	  }
	  else 
	  {
	    // Check if we're going to read from standard in and if anyone else
	    // wants to. Else read from file.
	    if (argument[1] == 1 && !args->stdin)
	    // Read from standard in.
	    {
	      plib->write_mess("Reading description from stdin...");
	      args->stdin = ({ });
	      ptc_obj->description = "";
	      string s = Stdio.stdin->read();
	      ptc_obj->description += s;
	      plib->write_mess("Done!\n");
	    }
	    else if (argument[1] == 1)
	    // Somebody else wants to read from standard in.
	    {
	      plib->write_err(err_stdin);
	      return 0;
	    }
	    else
	    // Assume file name.
	    {
	      Stdio.File desc_file = Stdio.File();
	      desc_file->open(argument[1], "r");
	      ptc_obj->description = desc_file->read();
	    }
	  }
	  break;
	case "platform":
	  ptc_obj->platform += plib->parse_platform(argument[1]);
	  break;
	case "version":
	  ptc_obj->version += plib->parse_version(argument[1]);
	  break;
	case "udiff":
	  // Check if we're going to read from standard in and if anyone else
	  // wants to. Else read from file.
	  if (argument[1] == 1 && !args->stdin)
	  // Read from standard in.
	  {
	    plib->write_mess("Reading patch data from stdin...");
	    args->stdin = ({ });
	    string s = Stdio.stdin->read();
	    ptc_obj->udiff = s;
	    plib->write_mess("Done!\n");
	  }
	  else if (argument[1] == 1)
	  // Somebody else wants to read from standard in.
	  {
	    plib->write_err(err_stdin);
	    return 0;
	  }
	  else
	  // Assume file name.
	  {
	    ptc_obj->patch += ({ argument[1] });
	  }
	  break;
	case "new_file":
	  ptc_obj->new += plib->parse_src_dest_path(argument[1]);
	  break;
	case "replace_file":
	  ptc_obj->replace += plib->parse_src_dest_path(argument[1]);
	  break;
	case "delete_file":
	  ptc_obj->delete += ({ argument[1] });
	  break;
	case "depends_on":
	  plib->write_mess("%s: %O\n",
			      argument[1], 
			      plib->verify_patch_id(argument[1]));
	  if (plib->verify_patch_id(argument[1]))
	    ptc_obj->depends += ({ argument[1] });
	  else
	  {
	    plib->write_err(err_patch_id);
	    return 0;
	  }
	  break;
	case "flags":
	  ptc_obj->flags += (< argument[1] >);
	  break;
	case "reload":
	  ptc_obj->reload += ({ argument[1] });
	  break;
	case "id":
	  ptc_obj->id = argument[1];
	  break;
	case "dryrun":
	  args->dryrun = ({ });
	  break;
	default:
      } 
    }

    // Choose which command to perform by testing their presence according
    // to weight. I.e. if the user tries to both run help and create then
    // the program will display the help and then exit without executing create.
    if (args->help)
    {
      display_help(args->help);
      return 0;
    }
    
    if (args->uninstall)
    {
      // Start by sorting the list with the newest first.
      array list = Array.sort_array(args->uninstall, `<);
      
      if (args->dryrun)
	plib->write_err("--dry-run is not supported when uninstalling a patch. "
			"It will be ignored.\n");
      foreach(list, string id)
      {
	// Check that the patch is installed
	plib->uninstall_patch(id);
      }
    }

    if (args->create)
    {
      ptc_obj->rxp_version = rxp_version;
      ptc_obj->originator = current_user;

      // If we don't have an id then create one.
      if(!ptc_obj->id)
	ptc_obj->id = plib->create_id();

      // If we don't have a description then launch the standard editor.
      if (!ptc_obj->description)
	ptc_obj->description = launch_external_editor(plib);

      if (args->target_dir)
      {
 	plib->create_patch(ptc_obj, args->target_dir[0]);
      }
      else
 	plib->create_patch(ptc_obj);
      return 0;
    }
    
    if (args->import)
    {
      // Start by sorting the list with the oldest first.
      array list = Array.sort_array(args->import);
      foreach(list, string file)
      {
	string id = plib->import_file(file);
	if(id)
	{
	  string success = sprintf("%s is successfully imported!\n", id);
	  if (color)
	    write("\e[92m%s\e[0m", success);
	  else
	    write(success);
	}
	else
	  throw( ({ sprintf("Couldn't import %s.", file) }) );
      }
    }
    
    // Install already imported files
    if (args->install)
    {
      // Start by sorting the list with the oldest first.
      array list = Array.sort_array(args->install);
      foreach (list, string patch)
      {
	// Before installing the patch, check if there is an older patch
	// imported that is not installed.
	if(plib->got_dependers(patch) == 1)
	{
	  plib->write_err("There are older patches imported that are not "
			  "installed yet. Please install them first or "
			  "include them when installing the current patch.\n\n"
			  "Quitting.\n");
	  return 0;
	}

	if (plib->install_patch(patch, 
				current_user, 
				!!args->dryrun,
				!!args->force))
	{
	  string success = sprintf("%s is successfully installed!\n"
				   "You need to restart Roxen in order for "
				   "the changes to take effect.\n", patch);
	  if (color)
	    write("\e[92m%s\e[0m", success);
	  else
	    write(success);
	}
	else
	  throw( ({ sprintf("Couldn't install %s.", patch) }) );
      }
    }

    // Import and install files.
    if (args->install_file)
    {
      // Start by sorting the list with the oldest first.
      array list = Array.sort_array(args->install_file);
      foreach (list, string file)
      {
	string id = plib->import_file(file);

	// Before installing the patch, check if there is an older patch
	// imported that is not installed.
	if(id && (plib->got_dependers(id) == 1))
	{
	  plib->write_err("There are older patches imported that are not "
			  "installed yet. Please install them first or "
			  "include them when installing the current patch.\n\n"
			  "Quitting.\n");
	  return 0;
	}

	if(id && plib->install_patch(id, current_user, !!args->dryrun))
	{
	  string success = sprintf("%s is successfully installed!\n"
				   "You need to restart Roxen in order for "
				   "the changes to take effect.\n", id);
	  if (color)
	    write("\e[92m%s\e[0m", success);
	  else
	    write(success);
	}
	else
	  throw( ({ sprintf("Couldn't install %s.", file) }) );
      }
    }
    
    // List files
    if (args->list)
    {
      if (!sizeof(args->list) ||
	  (search(args->list, "list_imported") > -1))
      {
	write_list(plib, "imported", 1, color);
      }
      if (!sizeof(args->list) ||
	  (search(args->list, "list_installed") > -1))
      {
	write_list(plib, "installed", 1, color);
      }
      return 0;
    }
  }
  // display_help();

  return 0;
}


private string combine_and_check_path(string path)
{
  string combined = combine_path(getcwd(), path);
  Stdio.Stat stat = file_stat(combined);
  if(!stat->isdir)
    throw(({combined + " is not a directory!"}));
  return combined;
}

private void write_list(Patcher plib,
			string  list_name,
			void|int(0..1) extended_info,
			void|int(0..1) color)
{

  array(mapping) list;

  if (list_name == "installed")
  {
    list = plib->file_list_installed();
    if (color)
    {
      write("\n\n\e[1;30;43m %|80s\e[0m\n", "List of installed patches");
      write("\e[1;37;40m %|15s %|64s\e[0m\n", "ID", "NAME");
    }
    else if (list_name == "installed")
    {
      write("\n\nList of installed patches:\n\n");
      write(" %|15s %|64s\n%s\n", "ID", "NAME", "=" * 80);
    }
  }
  else if (list_name == "imported")
  {
    list = map(plib->file_list_imported(), lambda(mapping m)
					 {
					   return ([ "metadata" : m ]);
					 }
	       );
    if (color)
    {
      write("\n\n\e[1;30;43m %|80s\e[0m\n", "List of imported patches");
      write("\e[1;37;40m %|15s %|64s\e[0m\n", "ID", "NAME");
    }
    else
    {
      write("\n\nList of imported patches:\n\n");
      write(" %|15s %|64s\n%s\n", "ID", "NAME", "=" * 80);
    }
  }

  if (sizeof(list))
  {
    list = Array.sort_array(list, lambda (mapping a, mapping b)
				  {
				    return a->metadata->id < b->metadata->id;
				  }
			    );
    foreach(list, mapping obj)
    {
      if (color)
	write("\e[1m%-15s %-64s\e[0m\n", 
	      obj->metadata->id, 
	      obj->metadata->name);
      else
	write("%-15s %-64s\n%s\n", 
	      obj->metadata->id, 
	      obj->metadata->name, "-" * 80);
      if(extended_info)
      {
	array md;
	if (list_name == "installed")
	{
	  string inst_date;
	  if (obj->installed)
	  {
	    inst_date = sprintf("%4d-%02d-%02d %02d:%02d",
				(obj->year < 1900) ? 
				obj->installed->year + 1900 : 
				obj->installed->year,
				obj->installed->mon,
				obj->installed->mday,
				obj->installed->hour,
				obj->installed->min);
	  }
	  else
	    inst_date = "Information not available.";

	  md = ({
	    ({ "Installed:"      , inst_date }),
	    ({ "Installed by:"   , (obj->user) ? obj->user : "Unknown" }),
	  });
	}
	else
	  md = ({ });

	md += ({
	  
	  ({ "Description:"    , obj->metadata->description }),
	  ({ "Originator:"     , obj->metadata->originator  }),
	  ({ "Platform(s):"    , (obj->metadata->platform) ? 
	                         sprintf("%{%s\n%}", obj->metadata->platform) :
	                         "All platforms" }),
	  ({ "Target version:" , (obj->metadata->version) ? 
	                         sprintf("%{%s\n%}", obj->metadata->version) :
	                         "All versions" }),
	  ({ "Dependencies:"   , (obj->metadata->depends) ? 
	                         sprintf("%{%s\n%}", obj->metadata->depends) :
	                         "(none)"
	  }),
	});

	if (obj->metadata->new && sizeof(obj->metadata->new) == 1)
	  md += ({ 
	    ({ "New file:", sprintf("%s", 
				    obj->metadata->new[0]->destination) }) 
	  });
	else if (obj->metadata->new)
	  md += ({ 
	    ({ "New files:", sprintf("%{%s\n%}", 
				     obj->metadata->new->destination) })
	  });
	
	if (obj->metadata->replace && sizeof(obj->metadata->replace) == 1)
	{
	  md += ({ 
	    ({ "Replaced file:",  
	       sprintf("%s", obj->metadata->replace[0]->destination) })
	  });
	}
	else if (obj->metadata->replace)
	  md += ({ 
	    ({ "Replaced files:", 
	       sprintf("%{%s\n%}", obj->metadata->replace->destination) })
	  });
	
	if (obj->delete && sizeof(obj->metadata->delete) == 1)
	  md += ({ 
	    ({ "Deleted file:", 
	       sprintf("%s", obj->metadata->delete[0]) })
	  });
	else if (obj->metadata->delete)
	  md += ({
	    ({ "Deleted files:", 
	       sprintf("%{%s\n%}", obj->metadata->delete) })
	  });
	
	if (obj->metadata->patch)
	{
	  string patch_data = "";
	  string patch_path = combine_path(plib->get_installed_dir(),
					   obj->metadata->id);
	  foreach(obj->metadata->patch, string patch_file)
	  {
	    werror("Patch_file: %s\n", patch_file);
	    patch_data += Stdio.read_file(combine_path(patch_path,
						       patch_file));
	  }
	  
	  array(string) patched_files_list = plib->lsdiff(patch_data);
	  if (sizeof(patched_files_list) == 1)
	    md += ({
	      ({ "Patched file:",
		 sprintf("%s\n", patched_files_list[0]) })
	    });
	  else
	    md += ({
	      ({ "Patched files:",
		 sprintf("%{%s\n%}", patched_files_list) })
	    });
	}
	
	string active_flags = "";
	string yes = (color) ? "\e[1mYes\e[0m" : "YES";
	foreach(known_flags; string index; string long_reading)
	{
	  active_flags += sprintf("%-40s %3s\n",
				  long_reading + ":",
				  (obj->metadata->flags && 
				   obj->metadata->flags[index]) ?
				  yes : "No");
	}
	md += ({ ({ "Flags:", active_flags }) });

	foreach(md, array mdfield)
	{
	  write("%/15s %-=64s\n", mdfield[0], mdfield[1]);
	}
	if (color)
	  write("\n");
	else
	  write("=" * 80 + "\n");
      }
    }
  }
  else
    write("\n%|76s\n\n", "No patches found.");
}

private string launch_external_editor(Patcher aux)
// Launches an external editor.
// @param aux
//   Used because we need some functionality that is embedded in the Patcher
//   object.
{
  // Start by creating a tempfile
  string tempfile = combine_path(aux->get_temp_dir(), 
				 "description_" + aux->create_id());
  werror("Tempfile: %s\n", tempfile);
  string editor = "vi";

  // Check if the EDITOR envvar is set.
  mapping env = getenv();
  if (env->EDITOR)
    editor = env->EDITOR;

  // Start the process.
  array args = ({ editor, tempfile });
  Process.create_process p = Process.create_process(args);

  if (p->wait())
     return 0;

  string res = Stdio.read_file(tempfile);
  
  rm(tempfile);
  
  return res;
}

// ******************************** Errors *************************************

constant err_too_many_args = "Too many arguments: %s";
constant err_arg_col = "Argument collision! It's not possible to both specify "
  "to create from a metadata file and from command line arguments!\n";
constant err_stdin = "Several flags cannot read from standard input at once!\n";
constant err_patch_id = "Patch id not correctly formatted";  

// ******************************* Help texts **********************************

private constant help_usage = "\nUsage: \n"
  "rxnpatch [-u[id]|[file]]... [-I[file]]... [-i[[id]|[file]]... [--dry-run]]\n"
  "         [-s[id]|[file]]... [-h[topic]] [-S path] [-flTUv] [--no-colour]\n" 
  "rxnpatch -c -m file [-t directory] [-S path] [-k id] [--no-colour]\n"
  "rxnpatch -c -N name -O email-address [-D [file]] [-P platform]...\n"
  "         [-V version]... [-p [file]]... [-n file]... [-R file]...\n" 
  "         [-X file]... [-d id]... [-F flag]... [-L module-name]\n"
  "         [-k id] [-t directory] [-S path] [--no-colour]\n\n";

private constant help_help = "Write --help=<switch> for a detailed information"
  " about a given\nswitch. I.e. --help=-i would give information about -i.\n\n";
constant help_default = "\n%s is not implemented.\n\n";
constant help_create_flag = "               Must be used together with -c"
  " and may not be used\n               together with -m\n\n";
constant help_stdin = "                  If more than one flags are set to"
  " read from stdin then\n               an error will be thrown.\n";
constant help_flags = ([
  "h":"-h [topic]     Show help about a specific command line\n"
      "--help=[topic] switch or instruction.\n\n",

  "N":"-N NAME        The name of the patch. Should tell what the patch does.\n"
      "               I.e. \"Search engine fix for deleted documents.\"\n" +
      help_create_flag,

  "O":"-O EMAIL       The e-mail address of the creator of the patch. This\n"
      "               flag needs to be used when creating a patch if the\n"
      "               environment variable RXNPATCHER_ORIGIN is not present.\n"+
      help_create_flag,

  "D":"-D[FILE]       Read patch description from FILE. If no filename is\n"
      "               given then the description will be read from standard\n"
      "               input.\n" +
      help_stdin +
      help_create_flag,

  "p":"-p[FILE]       Read unified diff information from FILE. If no filename\n"
      "               is given then the u-diff will be read from standard\n"
      "               input.\n" +
      help_stdin +
      help_create_flag,

  "n":"-n{FILE}       FILE is a new file that is going to be placed in the\n"
      "               in Roxen CMS. Give the full destination path and\n"
      "               rxnpatch will automatically traverse the given directory\n"
      "               structure upwards until it finds the file.\n\n" +
      help_create_flag,
  "R":"-R{FILE|GLOB}  FILE is a file that is going to be replaced in the\n"
      "               in Roxen CMS. Give the full destination path and\n"
      "               rxnpatch will automatically traverse the given directory\n"
      "               structure upwards until it finds the file.\n\n"
      "               If a glob is used then all matching files will be taken.\n"
      "               In these cases it's important that the directory structure\n"
      "               where the file(s) resides are the same as the destination.\n\n"
      "               NOTE! Make sure that your command shell doesn't expand\n"
      "               the glob on its own since that will leave to faulty\n"
      "               behaviour.\n\n" +
      help_create_flag,

  "I":"-I{FILE|GLOB}          Takes FILE and unpacks it to the imported\n"
      "--import={FILE|GLOB}   patches directory. This is usually\n"
      "                       roxen/local/patches.\n\n",
  "i":"-i{FILE|ID|'*'}           Installs a patch. If a filename is given as\n"
      "--install={FILE|ID|'*'}   argument then that file will be first imported\n"
      "                          and then installed. If an ID is given then the\n"
      "               patch with a corresponding ID will be installed if\n"
      "               there is such a patch imported.\n\n"
      "               If an asterisk (*) is given as argument then all\n"
      "               imported files will be installed. For this reason using\n"
      "               globs to install a number of directly doesn't work.\n\n",
  "t":"-t{PATH}       Target directory of the patch. If omitted the newly"
      "               created patch will be written in the current working"
      "               directory.\n\n"
      "               Must be used together with -c.\n\n",

  "k":"-k id          Set own id when creating a patch.\n\n"
      "               Must be used together with -c.\n\n",
  "r":"-r   --recurse When using globs this will traverse down the directory\n"
      "               tree.\n",
]);

void display_help(void|string|array(string) topics)
{
  Regexp is_flag = Regexp("^-[a-zA-Z]$");

  write(help_usage);

  if (!topics)
    return;

  if(stringp(topics))
    topics = ({ topics });
  
  foreach(topics, string t)
  {
    if(is_flag->match(t))
    {
      write(help_flags[t[1..1]]);
    }
    else if (t)
    {
      switch(t)
      {
	case "1":  
	  write(help_help);
	  break;
	case "help":
	case "--help":
	  write(help_flags->h);
	  write(help_help);
	  break;
	case "dry-run":
	case "--dry-run":
	  write(
      "--dry-run      Runs the patch process without actually modifying any\n" 
      "               files.\n\n" );
	  break;
	case "no-color":
	case "--no-color":
	case "no-colour":
	case "--no-colour":
	  write(
      "--no-color     Turns off colouring in output to standard out.\n"
      "--no-colour\n\n");
	  break;
	default:
	  write(help_default, t);
      }
    }
  }
}

