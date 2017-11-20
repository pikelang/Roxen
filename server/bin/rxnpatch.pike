
constant cvs_string = "$Id$";

import RoxenPatch;

int(0..1) stdin;
int main(int argc, array(string) argv)
{ 
  array switch_list = ({
    ({ "server_path",     Getopt.HAS_ARG,      ({ "-S", "--server"        }),
       "ROXEN_SERVER" /* Environment variable */ }),
    ({ "list_installed",  Getopt.NO_ARG,      ({ "-i", "--list-installed" }) }),
    ({ "list_imported",   Getopt.NO_ARG,       ({ "-u", "--list-imported" }) }),
    ({ "force",           Getopt.NO_ARG,       ({ "-f", "--force"         }) }),
    ({ "target_dir",      Getopt.HAS_ARG,      ({ "-t", "--target-dir"    }) }),
    ({ "metadata",        Getopt.HAS_ARG,      ({ "-m", "--metadata"      }) }),
    ({ "name",            Getopt.HAS_ARG,      ({ "-N", "--name"          }) }),
    ({ "originator",      Getopt.HAS_ARG,      ({ "-O", "--originator"    }), 
       "ROXEN_USER" /* Environment variable */ }),
    ({ "description",     Getopt.MAY_HAVE_ARG, ({ "-D", "--description"   }) }),
    ({ "platform",        Getopt.HAS_ARG,      ({ "-P", "--platform"      }) }),
    ({ "version",         Getopt.HAS_ARG,      ({ "-V", "--version"       }) }),
    ({ "udiff",           Getopt.MAY_HAVE_ARG, ({ "-p", "--patch"         }) }),
    ({ "new_file",        Getopt.HAS_ARG,      ({ "-n", "--new-file"      }) }),
    ({ "replace_file",    Getopt.HAS_ARG,      ({ "-R", "--replace"       }) }),
    ({ "delete_file",     Getopt.HAS_ARG,      ({ "-X", "--delete"        }) }),
    ({ "depends_on",      Getopt.HAS_ARG,      ({ "-d", "--depends"       }) }),
    ({ "flags",           Getopt.HAS_ARG,      ({ "-F", "--flag"          }) }),
    // Rewrite the helptext if -L is implemented
    ({ "reload",          Getopt.HAS_ARG,      ({ "-L", "--reload"        }) }),
    ({ "id",              Getopt.HAS_ARG,      ({ "-k", "--id"            }) }),
    ({ "dryrun",          Getopt.NO_ARG,       ({ "--dry-run", "--dryrun" }) }),
    ({ "nocolor",         Getopt.NO_ARG,       ({ "--no-color", "--no-colour",
                                                "--nocolor", "--nocolour" }) }),
    ({ "recursive",       Getopt.NO_ARG,       ({ "-r", "--recursive"     }) }),
    ({ "silent",	  Getopt.NO_ARG,       ({ "-s", "--silent"        }) }),
    /* ({ "http",	          Getopt.NO_ARG,       ({ "-e", "--http"          }) }), */
    ({ "help",	    	  Getopt.NO_ARG,       ({ "-h", "--help"	  }) }),
  });

  string current_user;
#ifndef __NT__
  current_user = sprintf("%s@localhost", getpwuid(getuid())[0]);
#endif

  string server_path	= 0;
#ifndef __NT__
  int(0..1) color	= 1;
#else
  int(0..1) color       = 0;
#endif
  int(0..1) dryrun	= 0;
  int(0..1) force	= 0;
  int(0..1) recursive	= 0;
  int(0..1) silent      = 0;

  int rxp_minor = 0;

  // If we have the command 'help' normal rules don't apply.
  int h = search(argv, "help");
  array(array) switches;
  array(string) cmd_n_files;
  if (h >= 0 && h < sizeof(argv))
  {
    cmd_n_files = ({ "dummy" }) + argv[h..];
    switches = Getopt.find_all_options(argv[0..h], switch_list);
  }
  else
  {
    switches = Getopt.find_all_options(argv, switch_list);
    cmd_n_files = Getopt.get_args(argv);
  }

  if (sizeof(switches))
  {

    foreach(switches; int n; array argument)
    {
      switch(argument[0])
      {
	case "nocolor":
	  color = 0;
	  switches[n] = 0;
	  break;
	case "dryrun":
	  dryrun = 1;
	  switches[n] = 0;
	  break;
	case "force":
	  force = 1;
	  switches[n] = 0;
	  break;
	case "recursive":
	  recursive = 1;
	  switches[n] = 0;
	  break;
	case "server_path":
	  server_path = argument[1];
	  switches[n] = 0;
	  break;
	case "silent":
	  silent = 1;
	  switches[n] = 0;
	  break;
	case "originator":
	  if (sscanf(argument[1], "%*s@%*s.%*s") == 3)
	    current_user = argument[1];
	  else
	    werror(err_email_not_valid);
	  switches[n] = 0;
	  break;
	default:
	  break;
      }
    }
    // Remove all arguments that we moved 
    switches = Array.filter(switches, lambda(array a) {return !!a;});
  }
   
  // Set output according to given switches
  function write_mess;
  function write_err;
  if (silent && h == -1) 
    // "silent" removes all output, not a good thing in combination with "help"
    // hence h == -1
  {
    write_mess = lambda(string s) { };
    write_err = lambda(string s) { };
  }
  else if(color)
  {
    write_mess = lambda(string s)
		 {
		   write(replace(s, ([ "<green>"	:"\e[92m",
				       "</green>"	:"\e[0m",
				       "<b>"		:"\e[1m",
				       "</b>"		:"\e[0m",
				       "<u>"		:"\e[4m",
				       "</u>"		:"\e[0m",
				    ])
				 ) + "\e[0m");
		 };
    write_err = lambda(string s)
		{
		  s = replace(s, ([ "<b>"		:"\e[1m",
				    "</b>"		:"\e[0;91m",
				    "<u>"		:"\e[4m",
				    "</u>"		:"\e[0;91m",
			          ])
			      );
		  werror("\e[1;91m%s\e[0m", s);
		};
  }
  else
  {
    write_mess = lambda(string s) { write(wash_output(s)); };
    write_err = lambda(string s) { werror(wash_output(s)); };
  }

  // Again treat "help" differently. We don't want to instantiate the Patcher
  // class if we're only going to show help
  if (sizeof(cmd_n_files) < 2)
  {
    if (sizeof(switches))
    {
      array topics = ({ });
      foreach (switches, array a)
      {
	if (a[0] == "help")
	  topics += ({ (string) a[1] });
      }
      display_help(write_mess, topics);
    }
    else
      display_help(write_mess);
    return 0;
  }
  else if (cmd_n_files[1] == "help")
  {
    if (sizeof(cmd_n_files) < 3)
    {
      display_help(write_mess);
      return 0;
    }

    display_help(write_mess, cmd_n_files[2..]);

    return 0;
  }

  // Check server path and current user before instantiating the Patcher class
  if (!server_path)
  {
    write_err(err_no_server_dir);
    return 0;
  }

  if (!current_user)
  {
    write_err(err_no_email);
    return 0;
  }    


  // Instantiate the Patcher class
  Patcher plib = Patcher(write_mess, write_err, server_path);
  plib->write_mess("Current user ... %s\n", current_user);

  // Handle the different commands.
  if (cmd_n_files[1] == "create")
  {
    PatchObject ptc_obj = PatchObject();
    string target_dir;
    int(0..1) metadata, cfcl, any_platform;
    string current_platform = UNDEFINED;
    foreach(switches, array argument)
    {
      switch (argument[0])
      {
	case "target_dir":
	  if (!target_dir)
	    target_dir = combine_and_check_path(argument[1]);
	  else
	  {
	    write_err("Too many arguments: -t\n");
	    return 0;
	  }
	  break;
	case "metadata":
	  if (metadata)
	  {
	    write_err("Too many arguments: -m\n");
	    return 0;
	  }
	  else if (cfcl) // == Create From Command Line.
	  {
	    write_err(err_arg_col);
	    return 0;
	  }
	  else
	  {
	    metadata = 1;
	    write_mess("Parsing metadata file...");
	    string md_file = Stdio.read_file(argument[1]);
	    if (!md_file || !sizeof(md_file))
	    {
	      write_err("Metadata file was empty or nonexistent\n");
	      return 0;
	    }
	    
	    if (ptc_obj->id)
	      ptc_obj = plib->parse_metadata(md_file,
					     ptc_obj->id);
	    else
	      ptc_obj = plib->parse_metadata(md_file,
					     plib->create_id());
	    if (ptc_obj)
	      write_mess("Done!\n");
	    else
	      return 0;
	  }
	  break;
	case "name":
	  if (metadata)
	  {
	    write_err(err_arg_col);
	    return 0;
	  }
	  
	  if (ptc_obj->name)
	  {
	    write_err("Too many arguments: -N\n");
	    return 0;
	  }
	  
	  cfcl = 1;
	  ptc_obj->name = argument[1];
	  break;
	case "originator":
	  ptc_obj->originator = current_user;
	  break;
	case "description":
	  if (metadata)
	  {
	    write_err(err_arg_col);
	    return 0;
	  }
	  
	  if (ptc_obj->description)
	  {
	    write_err("Too many arguments: -D\n");
	    return 0;
	  }
	  
	  cfcl = 1;

 	  // Check if we're going to read from standard in and if anyone else
 	  // wants to. Else read from file.
 	  if (argument[1] == 1 && !stdin)
 	  // Read from standard in.
 	  {
 	    write_mess("Reading description from stdin...");
 	    stdin = 1;
 	    ptc_obj->description = "";
 	    string s = Stdio.stdin->read();
 	    ptc_obj->description += s;
 	    write_mess("Done!\n");
 	  }
 	  else if (argument[1] == 1)
 	  // Somebody else wants to read from standard in.
 	  {
 	    write_err(err_stdin);
 	    return 0;
 	  }
 	  else
 	  // Assume file name.
 	  {
 	    string desc_file = Stdio.read_file(argument[1]);
 	    ptc_obj->description = desc_file;
	  }
	  break;
	case "platform":
	  array platform = plib->parse_platform(argument[1]);
	  if (platform && sizeof(platform)) {
	    current_platform = platform[0];
	    ptc_obj->platform += platform;
	  } else if ((argument[1] == "") ||
		     (lower_case(argument[1]) == "all")) {
	    current_platform = UNDEFINED;
	    any_platform = 1;
	  } else {
	    plib->write_err("Unkown platform: %s. Quitting.\n", argument[1]);
	    return 0;
	  }
	  break;
	case "version":
	  array version = plib->parse_version(argument[1]);
	  if (version && sizeof(version))
	    ptc_obj->version += version;
	  else
	  {
	    plib->write_err("Unkown version format: %s. Quitting.\n", 
			    argument[1]);
	    return 0;
	  }
	  break;
	case "udiff":
	  // Check if we're going to read from standard in and if anyone else
	  // wants to. Else read from file.
	  if (argument[1] == 1 && !stdin)
	  // Read from standard in.
	  {
	    write_mess("Reading patch data from stdin...");
	    stdin = 1;
	    string s = Stdio.stdin->read();
	    ptc_obj->udiff += ({ ([ "patch": s ]) });
	    if (current_platform) {
	      ptc_obj->udiff[-1]->platform = current_platform;
	    } else {
	      any_platform = 1;
	    }
	    write_mess("Done!\n");
	  }
	  else if (argument[1] == 1)
	  // Somebody else wants to read from standard in.
	  {
	    write_err(err_stdin);
	    return 0;
	  }
	  else
	  // Assume file name.
	  {
	    if (current_platform) {
	      ptc_obj->patch += ({ ([ "platform":current_platform,
				      "source": argument[1] ]) });
	    } else {
	      ptc_obj->patch += ({ ([ "source": argument[1] ]) });
	      any_platform = 1;
	    }
	  }
	  break;
	case "new_file":
	  array new_file = plib->parse_src_dest_path(argument[1]);
	  if (new_file && sizeof(new_file)) {
	    if (current_platform) {
	      new_file->platform = current_platform;
	    } else {
	      any_platform = 1;
	    }
	    ptc_obj->new += new_file;
	  } else
	    return 0;
	  break;
	case "replace_file":
	  array replace_file = plib->parse_src_dest_path(argument[1]); 
	  if (replace_file && sizeof(replace_file)) {
	    if (current_platform) {
	      replace_file->platform = current_platform;
	    } else {
	      any_platform = 1;
	    }
	    ptc_obj->replace += replace_file;
	  } else
	    return 0;
	  break;
	case "delete_file":
	  if (current_platform) {
	    ptc_obj->delete += ({ ([ "platform": current_platform,
				     "destination": argument[1] ]) });
	  } else {
	    ptc_obj->delete += ({ ([ "destination": argument[1] ]) });
	    any_platform = 1;
	  }
	  break;
	case "depends_on":
	  array(string) alternatives = argument[1]/"|";
	  if (sizeof(alternatives) > 1) {
	    rxp_minor = 1;
	  }
	  foreach(alternatives, string dep_id) {
	    if (!plib->verify_patch_id(dep_id, rxp_minor)) {
	      if (!rxp_minor && plib->verify_patch_id(dep_id, 1)) {
		rxp_minor = 1;
	      } else {
		write_err(err_patch_id);
		return 0;
	      }
	    }
	  }
	  ptc_obj->depends += ({ argument[1] });
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
	default:
	  plib->write_err("Unexpected argument: %O\n", argument[0]);
      }
    }

    ptc_obj->rxp_version = rxp_minor?"1.1":"1.0";
    ptc_obj->originator = current_user;
    if (any_platform) {
      ptc_obj->platform = UNDEFINED;
    }

    // If we don't have an id then create one.
    if(!ptc_obj->id)
      ptc_obj->id = plib->create_id();

    // If we don't have a description then launch the standard editor.
    if (!ptc_obj->description)
      ptc_obj->description = launch_external_editor(plib);

    plib->create_patch(ptc_obj, target_dir);

    return 0;
  }
  
  if (cmd_n_files[1] == "import")
  {  
    foreach(switches, array argument) {
      if (argument[0] == "http") {
	plib->import_file_http();
	return 0;
      }
    }

    if(sizeof(cmd_n_files) < 3)
    // Assume we're going to read from stdin.
    // This is not implemented so we'll write out a help message instead.
    {
      display_help(write_mess, "import");
      return 0;
    }

    array list = ({ });

    // Check if the argument contains globs and sort out unwanted arguments.
    for(int i = 2; i < sizeof(cmd_n_files); i++)
    {
      sscanf(cmd_n_files[i], "%*s%[*?]", string found_glob);
      if (found_glob && sizeof(found_glob))
	list += plib->find_files_with_globs(cmd_n_files[i], recursive);
      else
	list += cmd_n_files[i..i];
    }

    // Sort the list with the oldest first.
    list = Array.sort_array(list);
    foreach(list, string file) {
      plib->import_file(file);
    }

    return 0;
  }

  if (cmd_n_files[1] == "install")
  {
    if(sizeof(cmd_n_files) < 3)
    // Assume we're going to read from stdin.
    // This is not implemented so we'll write out a help message instead.
    {
      display_help(write_mess, "install");
      return 0;
    }

    array ins_list = ({ });
    array imp_list = ({ });
    for(int i = 2; i < sizeof(cmd_n_files); i++)
    {
      sscanf(cmd_n_files[i], "%*s%[*?]", string found_glob);

      // If we have "*" then install all imported patches otherwise import all
      // files that has that glob.
      if (cmd_n_files[i] == "*")
      {
	foreach(plib->file_list_imported(), mapping(string:PatchObject) po)
	{
	  ins_list += ({ po->metadata->id });
	}
      }
      else if (found_glob && sizeof(found_glob))
	imp_list += plib->find_files_with_globs(cmd_n_files[i], recursive);
      // Is the argument an id of an already installed patch?
      else if (plib->verify_patch_id(cmd_n_files[i]) && 
	       plib->is_imported(cmd_n_files[i]))
      {
	ins_list += ({ cmd_n_files[i] });
      }
      // Check if there's an imported patch with that name.
      else
      {
	string id = plib->extract_id_from_filename(cmd_n_files[i]);
	if (plib->is_imported(id))
	  ins_list += ({ id });
	else
	  imp_list += ({ cmd_n_files[i] });
      }
    }

    // If we have any files to import then now is the time to do it.
    imp_list = Array.sort_array(imp_list);
    foreach(imp_list, string file)
    {
      array(int|string) patch_ids = plib->import_file(file);
      foreach(patch_ids, int|string patch_id) {	
	if (patch_id && patch_id != -1) 
	  ins_list += ({ patch_id });
      }
    }
  
    // Install everything.
    multiset is_installed = (< >);
    ins_list = Array.sort_array(ins_list);
    foreach(ins_list, string id)
    {
      // Before installing the patch, check if there is an older patch
      // imported that is not installed.
      if(plib->got_dependers(id, is_installed) == 1)
      {
	plib->write_err("Couldn't install %s. "
			"This patch depends on other patches"
			"that are not installed yet. Please install them first "
			"or include them when installing the current patch.\n\n"
			"Quitting.\n", id);
	
	// Clean up if we're doing a dry run
	if (dryrun)
	{
	  foreach(imp_list, string id)
	  {
	    string dir = plib->id_to_filepath(id);
	    plib->clean_up(dir);
	  }
	}

	return 0;
      }

      if (plib->install_patch(id, current_user, dryrun, force))
      {
	if (dryrun)
	  is_installed[id] = 1;
	string success = sprintf("%s is successfully installed!\n", id);
	if (color)
	  write("\e[92m%s\e[0m", success);
	else
	  write(success);
      }
      else
      {
	plib->write_err("Couldn't install %s.\n", id);
	// Clean up if we're doing a dry run
	if (dryrun)
	{
	  foreach(imp_list, string source)
	  {
	    string id = plib->extract_id_from_filename(source);
	    string dir = plib->id_to_filepath(id | "", 1);
	    if (dir && sizeof(dir))
	      plib->clean_up(dir, 1);
	  }
	}
	return 0;
      }
    }

    // Clean up if we're doing a dry run
    if (dryrun)
    {
      foreach(imp_list, string id)
      {
	string dir = plib->id_to_filepath(id);
	plib->clean_up(dir);
      }
    }

    string need_restart = "You need to restart Roxen in order for "
			  "the changes to take effect.\n";
    if (color)
      write("\e[92m%s\e[0m", need_restart);
    else
      write(need_restart);
    return 0;
  }
  
  if (cmd_n_files[1] == "list")
  {
    int imp, ins;
    foreach(switches, array a)
    {
      switch (a[0])
      {
	case "list_imported":
	  imp = 1;
	  break;
	case "list_installed":
	  ins = 1;
	  break;
      }
    }
    if ((sizeof(cmd_n_files) == 2) && !imp && !ins) {
      imp = ins = 1;
    }
    if (imp)
      write_list(plib, plib->file_list_imported(),
		 "List of imported patches", 1, color);
    if (ins)
      write_list(plib, plib->file_list_installed(),
		 "list of installed patches", 1, color);
    if (sizeof(cmd_n_files) > 2) {
      array(mapping) patch_files =
	map(cmd_n_files[2..],
	    lambda(string path) {
	      string id = plib->extract_id_from_filename(path);
	      if (id) {
		mapping res = plib->describe_installed_patch(id) ||
		  plib->describe_imported_patch(id);
		if (res) return res;
	      }
	      return ([
		"status": "Not imported",
		"installed": 0,
		"user": 0,
		"metadata":
		plib->extract_patch(path, "/tmp/rxnpatch-" + getpid(), 1),
	      ]);
	    });
      write_list(plib, patch_files,
		 "list of patch files", 1, color);
    }
    return 0;
  }

  if (cmd_n_files[1] == "uninstall")
  {
    if(sizeof(cmd_n_files) < 3)
    {
      display_help (write_mess, "uninstall");
      return 0;
    }
    
    array list = ({ });

    foreach(cmd_n_files[2..], string id)
    {
      if (plib->verify_patch_id(id) &&
	  plib->is_installed(id))
	list += ({ id });
    }

    // Sort the list with the newest patch first.
    list = Array.sort_array(list, `<);
    
    if (dryrun)
      write_err("--dry-run is not supported when uninstalling a patch. "
		"It will be ignored.\n");
    foreach(list, string id)
    {
      // Check that the patch is installed
      plib->uninstall_patch(id, current_user);
    }

    return 0;
  }

  if (cmd_n_files[1] == "status")
  {
    if(sizeof(cmd_n_files) < 3)
    {
      display_help(write_mess, "status");
      return 0;
    }

    array(mapping) list = ({});
    foreach(cmd_n_files[2..], string id)
    {
      if (plib->verify_patch_id(id)) {
	mapping m = plib->patch_status(id);
	list += ({ m });
      } else {
	string rxp_path = id;
	if (!(id = plib->extract_id_from_filename(basename(rxp_path))) ||
	    !Stdio.is_file(rxp_path)) {
	  werror("\n%s is not a valid rxp filename.\n\n", rxp_path);
	  continue;
	}
	string mdblock =
	  Filesystem.Tar(rxp_path, UNDEFINED,
			 Gz.File(Stdio.File(rxp_path, "rb"), "rb"))->
	  open(id + "/metadata", "r")->read();
	PatchObject po = plib->parse_metadata(mdblock, id);
	list += ({
	  ([
	    "status": "Not imported",
	    "metadata": po,
	  ])
	});
      }
    }
    write_list(plib, list, UNDEFINED, UNDEFINED, color);
    return 0;
  }

  if (cmd_n_files[1] == "version")
  {
    sscanf(cvs_string, "$""Id: %s""$", string cvs_version);
    write("CVS Version ... %s\n"
	  "RXP Version ... %s\n"
	  "RXP File Format Version ... %s\n",
	  cvs_version || "n/a",
	  plib->current_version(),
	  rxp_version);
	  
    return 0;
  }

  display_help(write_mess);
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

array(array(string)) describe_metadata(Patcher po,
				       array(mapping(string:string)) md,
				       string singular, string plural,
				       void|int(0..1) color,
				       string|void patch_path)
{
  if (!md || !sizeof(md)) return ({});

  mapping(string:multiset(string)) files = ([]);
  foreach(md, mapping(string:string|array(string)) item) {
    array(string) file_list = ({});
    if (item->destination) {
      file_list = ({ item->destination });
    } else if (item->file_list) {
      file_list = item->file_list;
    } else if (item->source) {
      file_list = po->lsdiff(Stdio.read_file(combine_path(patch_path,
							  item->source)));
    }
    foreach(file_list, string file) {
      if (!files[file]) files[file] = (<>);
      files[file][item->platform] = 1;
    }
  }

  string res = "";
  foreach(sort(indices(files)), string file) {
    multiset(string) platforms = files[file];
    array(string) post = ({});
    if (!platforms[0] && !platforms[po->server_platform]) {
      res += "(" + file + ")";
    } else {
      res += file;
    }
    if ((sizeof(platforms) > 1) || !platforms[0]) {
      res += " [";
      if (platforms[0]) {
	if (color) {
	  res += "\e[1mALL\e[0m";
	} else {
	  res += "ALL";
	}
      }
      foreach(sort(indices(platforms)); int i; string platform) {
	if (!platform) continue;
	if (i || !platforms[0]) {
	  res += ", ";
	}
	if (platform == po->server_platform) {
	  if (color) {
	    res += "\e[1m" + platform + "\e[0m";
	  } else {
	    res += platform;
	  }
	} else {
	  res += platform;
	}
      }
      res += "]";
    }
    res += "\n";
  }
  if (sizeof(files) == 1) return ({ ({ singular, res }) });
  return ({ ({ plural, res }) });
}

protected string format_description(string desc)
{
  if (!has_value(desc, "\n")) return desc;

  // plain-text formatted description.
  //
  // Split into paragraphs, and format them to a max line length of 60.

  // Normalize empty lines.
  desc = map(desc/"\n",
	     lambda(string line) {
	       if (String.trim_all_whites(line) == "") return "";
	       return line;
	     }) * "\n";

  String.Buffer buf = String.Buffer();
  foreach(desc/"\n\n", string paragraph) {
    if (String.trim_all_whites(paragraph) == "") continue;
    string indent = "";
    string bullet = "";
    sscanf(paragraph, "%[ ]%[-*o+ ]%s", indent, bullet, paragraph);
    if (sizeof(bullet) && has_suffix(bullet, " ")) {
      // Looks like we have a bullet.
      indent += bullet;
    } else {
      // Not a bullet. Restore the prefix.
      paragraph = bullet + paragraph;
    }

    paragraph = map(paragraph/"\n", String.trim_all_whites) * " ";
    buf->add(sprintf("%/*s%-=*s\n\n",
		     sizeof(indent), indent, 59 - sizeof(indent), paragraph));
  }
  return buf->get();
}

private void write_list(Patcher plib,
			array(mapping) list,
			string|void list_heading,
			void|int(0..1) extended_info,
			void|int(0..1) color)
{
  string color_h1 = "";
  string color_th = "";
  string color_tr = "";
  string color_end = "";
  string color_bold_hr = "="*79 + "\n";
  string color_hr = "-"*79 + "\n";

  if (color) {
    color_h1 = "\e[1;30;43m";
    color_th = "\e[1;37;40m";
    color_tr = "\e[1m";
    color_end = "\e[0m";
    color_bold_hr = "";
    color_hr = "";
  }

  if (list_heading) {
    write("\n\n%s %|78s%s\n",
	  color_h1, list_heading, color_end);
  }
  write("%s %|16s %-61s%s\n"
	"%s",
	color_th, "ID", "NAME", color_end,
	color_bold_hr);

  if (sizeof(list))
  {
    list = Array.sort_array(list, lambda (mapping a, mapping b)
				  {
				    return a->metadata->id < b->metadata->id;
				  }
			    );
    foreach(list, mapping obj)
    {
      write("%s%-17s %-60s%s\n"
	    "%s",
	    color_tr, obj->metadata->id, obj->metadata->name || "", color_end,
	    color_hr);
      if(extended_info || obj->status)
      {
	array md = ({ });
	if (obj->status) {
	  md += ({ ({ "Status:"	, obj->status }) });
	  if (obj->status == "unknown") {
	    write("%s\n", color_bold_hr);
	    continue;
	  }
	}
	if (obj->installed)
	{
	  string date = sprintf("%4d-%02d-%02d %02d:%02d",
				(obj->installed->year < 1900) ?
				obj->installed->year + 1900 :
				obj->installed->year,
				obj->installed->mon,
				obj->installed->mday,
				obj->installed->hour,
				obj->installed->min);
	  md += ({
	    ({ "Installed:"	, date }),
	    ({ "Installed by:"	, obj->user || "Unknown" }),
	  });
	}

	if (obj->uninstalled)
	{
	  string date = sprintf("%4d-%02d-%02d %02d:%02d",
				(obj->uninstalled->year < 1900) ?
				obj->uninstalled->year + 1900 :
				obj->uninstalled->year,
				obj->uninstalled->mon,
				obj->uninstalled->mday,
				obj->uninstalled->hour,
				obj->uninstalled->min);
	  md += ({
	    ({ "Uninstalled:"	 , date }),
	    ({ "Uninstalled by:" , obj->uninstall_user || "Unknown" }),
	  });
	}

	md += ({
	  ({ "Description:"    ,
	     format_description(obj->metadata->description)
	  }),
	  ({ "Originator:"     , obj->metadata->originator  }),
	  ({ "RXP Version:"    , obj->metadata->rxp_version }),
	  ({ "Platform(s):"    , sizeof(obj->metadata->platform || ({})) ?
	                         sprintf("%{%s\n%}", obj->metadata->platform) :
	                         "All platforms" }),
	  ({ "Target version:" , sizeof(obj->metadata->version || ({})) ?
	                         sprintf("%{%s\n%}", obj->metadata->version) :
	                         "All versions" }),
	  ({ "Dependencies:"   , sizeof(obj->metadata->depends || ({})) ?
	                         sprintf("%{%s\n%}", obj->metadata->depends) :
	                         "(none)"
	  }),
	});

	if (obj->status != "Not imported") {
	  md += describe_metadata(plib, obj->metadata->new,
				  "New file:", "New files:", color);
	  md += describe_metadata(plib, obj->metadata->replace,
				  "Replaced file:", "Replaced files:", color);
	  md += describe_metadata(plib, obj->metadata->delete,
				  "Deleted file:", "Deleted files:", color);

	  md += describe_metadata(plib, obj->metadata->patch,
				  "Patched file:", "Patched files:", color,
				  plib->id_to_filepath(obj->metadata->id));
	}
	
	string active_flags = "";
	string yes = (color) ? (color_tr + "Yes" + color_end) : "YES";
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
	  write("%/17s %-=60s\n", mdfield[0], mdfield[1]);
	}
	write("%s\n", color_bold_hr);
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
#ifdef __NT__
  tempfile += ".txt";
  string editor = "notepad.exe";
#else
  string editor = "vi";
  
  // If the flag stdin is set then we need to set stdin to /dev/tty
  if (stdin)
    Stdio.stdin->open("/dev/tty");
#endif

  // Check if the EDITOR envvar is set.
  mapping env = getenv();
  if (env->EDITOR)
    editor = env->EDITOR;

  // Start the process.
  array args = ({ editor, tempfile });
  Process.Process p = Process.Process(args);

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
constant err_stdin = "Several flags cannot be set to read from standard input"
		     " at once!\n";
constant err_patch_id = "Patch id not correctly formatted";
constant err_no_server_dir = "Could not resolve server path. Quitting.\n";
constant err_no_email = "Name or email of the current user could not be "
			"resolved.\nTry setting the environment variable "
			"ROXEN_USER or use -O\n"; 
constant err_email_not_valid = "Not a valid e-mail address: -O\n";
// ****************************** Help texts ***********************************
private constant help_usage = ([
  "general"   : 
#"Usage: <b>rxnpatch</b> [rxnpatch-options] <command> [command-options-and-argument]

  where rxnpatch-options are --no-color, --dry-run etc.
  where command is <u>create</u>, <u>import</u>, <u>install</u>, <u>help</u>, <u>list</u>,
     <u>uninstall</u>, <u>status</u> or <u>version</u>.
  where command-options-and-arguments depends on the command.
",
  "create"    : "Usage:\n <b>rxnpatch</b> [-S <u>PATH</u>] [--no-colour]"
  		" [-sf] create -m <u>FILE</u>\n"
  		" [-k <u>ID</u>] [-t <u>DIRECTORY</u>]\n"
		"<b>rxnpatch</b> [-S <u>PATH</u>] [--no-colour] create"
  		" -N <u>NAME</u> [-O <u>EMAIL_ADDRESS</u>] [-D [<u>FILE</u>]]\n"
  		"[-P <u>PLATFORM</u>]... [-V <u>VERSION</u>]..."
		" [-p [<u>FILE</u>]]... [-n <u>FILE</u>]...\n" 
  		"[-R <u>FILE</u>]... [-X <u>FILE</u>]... [-d <u>ID</u>]..."
  		" [-F <u>FLAG</u>]... [-L <u>MODULE_NAME</u>]...\n"
		"[-k <u>ID</u>] [-t <u>DIRECTORY</u>]\n",
  "help"      : #"Usage: <b>rxnpatch</b> [--no-colour] help [command|switch]

Special cases:
  <b>rxnpatch help commands</b> - lists all available commands and what they do.
  <b>rxnpatch help options</b>  - lists all global options such as --silent,
			  --server etc.
",
  "import"    : 
#"Usage: <b>rxnpatch</b> [-S path] [--dry-run] [--no-colour] [-sf] import file...

Importing a does not alter any files in the server-x.x.xxx directory, it just
means that the patch will become available for installation and that you can
list information about the patch such as dependencies and which files will be affected upon installation.",
  "install"   : "Usage: <b>rxnpatch</b>  [-S path] [--dry-run] [--no-colour]"
                "  [-sf] install [id...|file...]\n",
  "list"      : "Usage: rxnpatch [--no-colour] list [-iu] \n",
  "uninstall" : "Usage: rxnpatch [-S path] [--dry-run] [--no-colour] [-sf]"
                " unintall [id...]\n",
  "status"    : "Usage: rxnpatch [-S path] [--no-colour] status id\n",
  "version"   : "Usage: rxnpatch version\n",
  // special cases
  "options"   : "The global options are:\n",
  "commands"  : #"Available commands are:
  <b>create</b>	Create a patch package.
  <b>help</b>		Get help with commands and options available.
  <b>import</b>	Import patch(es).
  <b>install</b>	Install patch(es).
  <b>list</b>		List imported and/or installed patches.
  <b>uninstall</b>	Uninstall patch(es).
  <b>status</b>	Shows the status for a patch, e.g. if it's installed or not.
  <b>version</b>	Shows version info for <b>rxnpatch</b>."
]);

private constant help_help = #"
Write <b>rxnpatch help</b> <<u>command|switch</u>> for detailed information 
about a given command or switch. I.e. <b>help -i</b> would give information 
about -i.

Special cases:
  <b>rxnpatch help commands</b> - lists all available commands and what they do.
  <b>rxnpatch help options</b>  - lists all global options such as --silent,
			  --server etc.
";
constant help_default = "\n<b>%s</b> is not a known switch or command\n\n";

constant help_stdin = "If more than one flags are set to  read from stdin then"
		      " an error will be thrown.\n";
constant help_flags = ([
  "S": ([ "syntax" : ({ "<b>-S</b> <u>PATH</u>",
			"<b>--server=</b><u>PATH</u>" }),
	  "hlptxt" : ({ "Path to Roxen's server directory. This flag is",
			"required if the environment variable ROXEN_SERVER",
			"isn't set." }),
	  "scope"  : ({ "global" }) ]),
  "i": ([ "syntax" : ({ "<b>-i</b>",
			"<b>--list-installed</b>" }),
	  "hlptxt" : ({ "List installed patches only." }),
	  "scope"  : ({ "list" }) ]),
  "u": ([ "syntax" : ({ "<b>-u</b>",
			"<b>--list-imported</b>" }),
	  "hlptxt" : ({	"List imported patches only." }),
	  "scope"  : ({ "list" }) ]),
  "f": ([ "syntax" : ({ "<b>-f</b>",
			"<b>--force</b>" }),
	  "hlptxt" : ({ "Force the patching tool to continue even if it runs",
			"into problems. Use with caution." }),
	  "scope"  : ({ "create", "import", "install", "uninstall" }) ]),
  "t": ([ "syntax" : ({ "<b>-t</b> <u>PATH</u>",
			"<b>--target-dir=</b><u>PATH</u>" }),
	  "hlptxt" : ({ "Target directory of the patch. If omitted the newly",
			"created patch will be written in the current working",
			"directory." }),
	  "scope"  : ({ "create" }) ]),
  "m": ([ "syntax" : ({ "<b>-m</b> <u>FILE</u>",
			"<b>--metadata=</b><u>FILE</u>" }),
	  "hlptxt" : ({	"Create a patch from the given metadata file.",
			"Additional <b>create</b> flags apart from <b>-t</b>",
			"are not allowed." }),
	  "scope"  : ({ "create" }) ]),
  "N": ([ "syntax" : ({ "<b>-N</b> <u>NAME</u>",
			"<b>--name=</b><u>NAME</u>" }),
	  "hlptxt" : ({ "The name of the patch. Should tell what the patch does,",
			"e.g. \"Search engine fix for deleted documents.\"" }),
	  "scope"  : ({ "create" }) ]),
  "O": ([ "syntax" : ({ "<b>-O<b> <u>EMAIL<u>",
			"<b>--originator=</b>" }),
	  "hlptxt" : ({ "The e-mail address of the creator of the patch. This",
			"is also used when installing or uninstalling a patch.",
			"If this flag is not present then the environment",
			"variable <b>ROXEN_USER</b> is used and if that is not",
			"present then the name of the current logged in user is",
			"fetched from the system." }),
	  "scope"  : ({ "create", "install", "uninstall" }) ]),
  "D": ([ "syntax" : ({ "<b>-D</b>[<u>FILE</u>]",
			"<b>--description</b>[<b>=</b><u>FILE</u>]" }),
	  "hlptxt" : ({ "Read patch description from <u>FILE</u>. If no filename",
			"is given then the description will be read from",
			"standard input. If more than one flags are set to read",
			"from stdin then an error will be thrown.",
			"",
			"If this flag is omitted then <b>rxnpatch</b> will try",
			"to launch the system editor set in the <u>EDITOR</u>",
			"environment variable" }),
	  "scope"  : ({ "create" }) ]),
  "P": ([ "syntax" : ({ "<b>-P</b> <u>PLATFORM</u>...",
			"<b>--platform=</b><u>PLATFORM</u>..." }),
	  "hlptxt" : ({ "Specifies which platforms the patch should work on.",
			"If omitted it is presumed that the patch is intended",
			"for all platforms. May not be used in combination with",
			"<b>-m</b>" }),
	  "scope"  : ({ "create" }) ]),
  "V": ([ "syntax" : ({ "<b>-V</b> <u>VERSION</u>...",
			"<b>--version=</b><u>VERSION</u>..." }),
	  "hlptxt" : ({ "Specifies which versions the patch should work on.",
			"If omitted it is presumed that the patch is intended",
			"for all versions. May not be used in combination with",
			"<b>-m</b>" }),
	  "scope"  : ({ "create" }) ]),
  "p": ([ "syntax" : ({ "<b>-p</b>[<u>FILE</u>]...",
			"<b>--patch</b>[<b>=</b><u>FILE</u>]..." }),
	  "hlptxt" : ({ "Read unified diff information from FILE. If no filename",
			"is given then the u-diff will be read from standard",
			"input. If more than one flags are set to read from",
			"stdin, then an error will be thrown." }),
	  "scope"  : ({ "create" }) ]),
  "n": ([ "syntax" : ({ "<b>-n</b> <u>FILE</u>|<u>GLOB</u>...",
		        "<b>--new-file=</b><u>FILE</u>|<u>GLOB</u>..." }),
	  "hlptxt" : ({ "<u>FILE</u> is a new file that is going to be placed in",
		        "Roxen CMS. Give the destination path relative to",
			"Roxen's server-x.x.xxx directory and <b>rxnpatch</b>",
		        "will automatically traverse the given directory",
			"structure upwards until it finds the source file to put",
			"in the patch package.",
			"",
			"If a glob is used then all matching files will be",
			"taken. In these cases it's important that the directory",
			"structure where the file(s) resides are the same as the",
			"destination.",
			"",
			"<b>NOTE!</b> Make sure that your command shell doesn't",
			"expand the glob on its own since that will leave to", 
			"faulty behaviour."}),
	  "scope"  : ({ "create" }) ]),
  "R": ([ "syntax" : ({ "<b>-R</b> <u>FILE</u>|<u>GLOB</u>...",
			"<b>--replace=</b><u>FILE</u>|<u>GLOB</u>..." }),
	  "hlptxt" : ({ "<u>FILE</u> is a file that is going to be replaced in",
			"Roxen CMS. Give the destination path relative to",
			"Roxen's server-x.x.xxx directory and <b>rxnpatch</b>",
			"will automatically traverse the given directory",
			"structure upwards until it finds the file.",
			"",
			"If a glob is used then all matching files will be",
			"taken. In these cases it's important that the directory",
			"structure where the file(s) resides are the same as the",
			"destination.",
			"",
			"<b>NOTE!</b> Make sure that your command shell doesn't",
			"expand the glob on its own since that will leave to", 
			"faulty behaviour." }),
	  "scope"  : ({ "create" }) ]),
  "X": ([ "syntax" : ({ "<b>-X</b> <u>FILE_PATH</u>...",
			"<b>--delete=</b><u>FILE_PATH</u>..." }),
	  "hlptxt" : ({ "FILE is a file that is going to be removed from",
		        "the Roxen CMS installation. Give the path to the file",
			"relative Roxen's server-x.x.xxx directory." }),
	  "scope"  : ({ "create" }) ]),
  "d": ([ "syntax" : ({ "<b>-d</b> <u>ID</u>...",
			"<b>--depends=</b><u>ID</u>..." }),
	  "hlptxt" : ({ "<u>ID</u> is the id of a patch which is required to be",
			"installed in order for this patch to be installed.",
			"",
			"It may also be a submodule with version, ",
			"eg \"sitebuilder/5.2.200\", in which case that ",
			"specific version of the submodule will be required.",
			"",
			"Multiple alternative <u>ID</u>'s may be listed ",
			"separated with \"|\" (vertical bar).",
			"",
			"Specifying either of the latter syntaxen ",
			"will force the version of the resulting ",
			"RXP-file to be at least 1.1." }),
	  "scope"  : ({ "create" }) ]),
  "F": ([ "syntax" : ({ "<b>-F</b> <u>FLAG</u>",
			"<b>--flag=</b><u>FLAG</u>" }),
	  "hlptxt" : ({ "Sets the flag <u>FLAG</u> to true. Flags that are",
			"omitted will default to FALSE.",
			"",
			"The following flags are supported:" }) +
	  	     // Nicely format the list of known flags
	             sprintf("%{%s: %s,%}", (array) known_flags) / ",",
	  "scope"  : ({ "create" }) ]),
  "L": ([ "syntax" : ({ "<b>-L</b> <u>MODULE</u>",
			"<b>--reload</b> <u>MODULE</u>" }),
	  "hlptxt" : ({ "Reloads <u>MODULE</u> after installing/uninstalling the",
			"patch. This is instead of restarting the whole server.",
			"<b>Not yet implemented.</b>" }),
	  "scope"  : ({ "create" }) ]),
  "k": ([ "syntax" : ({ "<b>-k</b> <u>ID</u>",
			"<b>--id=</b><u>ID</u>" }),
	  "hlptxt" : ({ "Set own id when creating a patch. If this is not used",
			"<b>rxnpatch</b> will create an id based on the current",
			"time and date. <u>ID</u> must follow the same pattern:",
			"<u>YYYY</u><b>-</b><u>MM</u><b>-</b><u>DD</u><b>T</b>"
			"<u>hhmm</u>." }),
	  "scope"  : ({ "create" }) ]),
  "dr":([ "syntax" : ({ "<b>--dry-run</b>",
			"<b>--dryrun</b>" }),
	  "hlptxt" : ({ "Simulate the operation of <u><command></u>. This may",
			"involve writing temporary files to the file system.",
			"<b>NOTE! --dry-run</b> does not work with"
			" <b>uninstall</b>." }),
	  "scope"  : ({ "global" }) ]),
  "nc":([ "syntax" : ({ "<b>--no-color</b>",
			"<b>--no-colour</b>",
			"<b>--nocolor</b>",
			"<b>--nocolour</b>" }),
	  "hlptxt" : ({ "Turns off 'Christmas light mode' making all output",
			"plain text without underlines, colors etc. This is",
			"useful if you're piping the output to a file or simply",
			"don't like colored output." }),
	  "scope"  : ({ "global" }) ]),
  "r": ([ "syntax" : ({ "<b>-r</b>", "<b>--recurse</b>" }),
	  "hlptxt" : ({ "When using globs this will traverse down the directory",
			"tree." }),
	  "scope"  : ({ "create", "install", "import" }) ]),
  "s": ([ "syntax" : ({ "<b>-s</b>",
			"<b>--silent</b>" }),
	  "hlptxt" : ({ "Silent mode. No messages will be printed out to",
			"stdout or stderr. This flag has no effect when used",
			"with commands whose sole purpose is to output data such",
			"as <b>help</b> and <b>list</b>. <b>NOTE!</b> No error"
			" messages will be", 
			"displayed if this flag is set." }),
	  "scope"  : ({ "global" }) ]),
  /*
  "e": ([ "syntax" : ({ "<b>-e</b>",
			"<b>--http</b>" }),
	  "hlptxt" : ({ "Import over HTTP. The latest patch cluster will be ",
			"fetched from www.roxen.com and imported. The correct ",
			"cluster file will be returned based on dist version, ",
			"platform and product type." }),
                        "scope"  : ({ "import" }) ]) */
]);

constant flag_map = ([
  "server"		: "S",
  "list-installed"	: "i",
  "list-imported"	: "u",
  "force"		: "f",
  "target_dir"		: "t",
  "metadata"		: "m",
  "name"		: "N",
  "originator"		: "O",
  "description"		: "D",
  "platform"		: "P",
  "version"		: "V",
  "patch"		: "p",
  "new-file"		: "n",
  "replace"		: "R",
  "delete"		: "X",
  "depends"		: "d",
  "flags"		: "f",
  "reload"		: "r",
  "id"			: "k",
  "recursive"		: "r",
  "silent"		: "s",
  "dry-run"		: "dr",
  "dryrun"		: "dr",
  "nocolor"             : "nc",
  "nocolour"		: "nc",
  "no-color"		: "nc",
  "no-colour"		: "nc",
  /* "http"                : "e" */
]);

void help_write_flag(function write_out, mapping flag_desc)
{
  if (!mappingp(flag_desc))
    return;

  // Make sure that we have a scrictly local copy of flag_desc
  flag_desc = flag_desc + ([ ]);

  if (flag_desc->scope)
  {
    string scope = "This flag is ";
    foreach(flag_desc->scope; int i; string s)
    {
      if (i > 0 && i == (sizeof(flag_desc->scope) - 1))
	scope += sprintf(" and <b>%s</b>", flag_desc->scope[i]);
      else if (i > 0)
	scope += sprintf(", <b>%s</b>", flag_desc->scope[i]);
      else if (flag_desc->scope[i] == "global")
	scope += "global";
      else
	scope += sprintf("intended for <b>%s</b>", flag_desc->scope[i]);
    }
    flag_desc->hlptxt += ({ scope + "." });
  }

  // Calculate the width of the string.
  // The reason we don't use the normal sprintf function is that it calculates
  // columns wrong when using escape characters.
  int no_of_rows = max(sizeof(flag_desc->syntax), 
		       sizeof(flag_desc->hlptxt));
  for (int row = 0; row <  no_of_rows; row++)
  {
    int col1 = 26; 
	
    if (row < sizeof(flag_desc->syntax))
    {
      col1 -= sizeof(wash_output(flag_desc->syntax[row]));
      if (col1 <= 0)
	col1 = 1;
      write_out(flag_desc->syntax[row]);
    }

    if (row < sizeof(flag_desc->hlptxt))
      write_out(" " * col1 + flag_desc->hlptxt[row] + "\n");
    else
      write_out("\n");
  }
  write_out("\n"); 
}

void display_help(function write_out, void|string|array(string) topics)
{
  Regexp is_flag = Regexp("^-[a-zA-Z]$");

  // write(help_usage["general"]);

  if (!(topics && sizeof(topics)))
    topics = ({ "general" });
  else if(stringp(topics))
    topics = ({ topics });
  
  foreach(topics, string t)
  {
    if (t == "1" || t == "general")
      write_out(help_usage["general"] + help_help);
    else if (stringp(t) && help_usage[t])
    {
      write_out(help_usage[t] + "\n");
      
      // Write out the flags for the command.
      mapping flags = map(help_flags, 
			  lambda(mapping m, string command)
			  {
			    // Special case
			    if (command == "options")
			      command = "global";

			    mapping res = ([ ]);
			    int i = -1;
			    if (arrayp(m->scope))
			      i = search(m->scope, command);
			    if (i >= 0)
			    {
			      res->syntax = m->syntax;
			      res->hlptxt = m->hlptxt;
			      return res;
			    }
			    else
			      return 0;
			  },
			  t);

      foreach(flags; string s; mapping m)
	if (m)
	  help_write_flag(write_out, m);
      write_out("\n");
    }
    else if(is_flag->match(t) && help_flags[t[1..1]])
    {
      help_write_flag(write_out, help_flags[t[1..1]]);
    }
    else if (t && flag_map[t])
    {
      help_write_flag(write_out, help_flags[flag_map[t]]);
    }
    else if (sizeof(t) > 2 && flag_map[t[2..]])
    {
      help_write_flag(write_out, help_flags[flag_map[t[2..]]]);
    }
    else if (stringp(t) && help_flags[t])
    {
      help_write_flag(write_out, help_flags[t]);
    }
    else
      write_out(sprintf(help_default, t));  
  }
}

