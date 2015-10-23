
import Parser.XML.Tree;
import String;
import Stdio;

constant rxp_version = "1.0";
//! The latest supported version of the rxp fileformat.

constant known_flags = ([ "restart" : "Need to restart server" ]);
//! All flags that are supported by the rxp fileformat.

constant known_platforms = (< "macosx_ppc32", 
			      "macosx_x86",
			      "macosx_x86_64",
			      "rhel4_x86",
			      "rhel4_x86_64",
			      "rhel5_x86",
			      "rhel5_x86_64",
			      "sol10_x86_64",
			      "win32_x86" >);

typedef mapping(string:string |
		  multiset(string) |
		  array(string | mapping(string:string))) PatchObject;          
//! Contains the patchdata
//! 
//! @mapping
//!   @member string "id"
//!     Taken from filename.
//!   @member string "name"
//!     "name" field in the metadata block
//!   @member string "description"
//!     "description" field in the metadata block
//!   @member string "originator"
//!     "originitor" field in the metadata block
//!   @member string "rxp_version"
//!     File format version.
//!   @member array(string) "platform"
//!     An array of all "platform" fields in the metadata block.
//!   @member array(string) "version"
//!     An array of all "version" fields in the metadata block.
//!   @member array(string) "depends"
//!     An array of all "depends" fields in the metadata block.
//!   @member multiset(string) "flags"
//!     A multiset of active flags
//!   @member array(string) "reload"
//!     An array of all "reload" fields in the metadata block.
//!   @member array(mapping(string:string)) "new"
//!     An array of all "new" fields in the metadata block.
//!     @mapping
//!       @member string "source"
//!       @member string "destination"
//!     @endmapping
//!   @member array(mapping(string:string)) "replace"
//!     An array of all "replace" fields in the metadata block.
//!     @mapping
//!       @member string "source"
//!       @member string "destination"
//!     @endmapping
//!   @member array(string) "patch"
//!     An array of all "patch" fields in the metadata block.
//!   @member string "udiff"
//!     A string of udiff data.
//!   @member array(string) "delete"
//!     An array of all "delete" fields in the metadata block.
//! @endmapping

string wash_output(string s)
{
  return replace(s, ([ "<green>":"",
		       "</green>":"",
		       "<b>":"",
		       "</b>":"",
		       "<u>":"",
		       "</u>":"" ])
		 );
}

// Encode <, > and & of our own since this must be able to work outside Roxen.
string html_encode(string s)
{
  s = replace(s, (["&":"&amp;", "<":"&lt;", ">":"&gt;"]));
  return replace(s, (["&amp;amp;":"&amp;",
		      "&amp;lt;" :"&lt;", 
		      "&amp;gt;" :"&gt;"]));
}

string unixify_path(string s)
//! This is for utils of MSYS that needs /c/ instead of c:\
{
  if (s[0] == '/' || s[0] == '\\' || s[1] == ':')
    return append_path_nt("/", s);

  return s;
}

//!
class Patcher
{
  private constant lib_version = "$Id$";

  //! Should be relative the server dir.
  private constant default_local_dir     = "../local/";
  private constant default_installed_dir = "patches/";

  //! Should be relative the local dir.
  private constant default_import_dir    = "patches/";

  private string import_path = "";
  //! Path to the directory of imported patches.

  private string installed_path = "";
  //! Path to the directory of installed_patches.

  private string temp_path = "";
  //! Path to temp directory.

  private string server_path = "";
  //! Path to roxen/server-x.x.xxx/

  private string server_version = "";
  //! Server version extracted from server/etc/include/version.h

  private string server_platform = "";
  //! The current platform. This should map to the platforms for which we build
  //! Roxen and is taken from [server_path]/OS.

  private string tar_bin = "tar";
  private string patch_bin = "patch";
  //! Command for the external executable.

  function write_mess;
  //! Callback function for status messages. Should take a string as argument
  //! and return void.

  function write_err;
  //! Callback function for error messages. Should take a string as argument
  //! and return void.

  private Regexp patchid_regexp = Regexp(
    "((19|20)[0-9][0-9]-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])T"
    "([01][0-9]|2[0-3])[0-5][0-9])");
  //! The format regexp for patch IDs.


  void create(function      message_callback,
	      function      error_callback,
              string        server_dir,
	      void | string local_dir, 
	      void | string temp_dir)
  //! Instantiate the Patcher class.
  //! @param message_callback
  //!   A callback function which is used for status callback.
  //! @param error_callback
  //!   A callback function which is used for status callback.
  //! @param server_dir
  //!   Path to the the roxen server directory 
  //!   Eg @tt{/usr/local/roxen/server-x.x.xxx/@}
  //! @param local_dir
  //!   Path to the the roxen local directory 
  //!   Defaults to @expr{"../local/"@} relative the server path.
  //! @param temp_dir
  //!   Path to the the system temp dir. Depending on operating system it
  //!   will either default to @expr{"/tmp/"@} or the path set in the
  //!   environment variable @tt{TEMP@}
  {
    // Set callback functions
    write_mess = lambda(mixed ... arg) 
		 { 
		   message_callback(sprintf(@arg)); 
		 };

    write_err  = lambda(mixed ... arg) 
		 { 
		   error_callback(sprintf(@arg)); 
		 };

    // Verify server dir
    server_path = combine_and_check_path(server_dir);
    if (!server_path)
      throw(({ "Cannot access server dir!" }));
    
//     write_mess("Server path set to %s\n", server_path);
 
    // Set default import directory
    if (!local_dir)
      local_dir = default_local_dir;
    import_path = combine_path(server_path, local_dir, default_import_dir);
    if(!is_dir(import_path))
    {
      if(!mkdirhier(import_path))
      {
	// If the dir does not exist and we failed to create it.
	throw(({ "Can't access import dir!" }));
      }
    }
//     write_mess("Import dir set to %s\n", import_path);

    // Set default installed directory
    installed_path = combine_path(server_path, default_installed_dir);
    if(!is_dir(installed_path))
    {
      if(!mkdirhier(installed_path))
      {
	// If the dir does not exist and we failed to create it.
	throw(({"Can't access installed dir!"}));
      }
    }
//     write_mess("Installed dir set to %s\n", installed_path);

    // Set temp dir
    set_temp_dir(temp_dir);

    // Set external process environment and path to exectuables
    master()->putenv("PATH",
#ifdef __NT__
		     combine_path(server_path, "bin/msys/bin") + ";"
#else
		     combine_path(server_path, "bin/gnu") + ":"
#endif
		     + getenv("PATH"));

    // Set server version
    string version_h = combine_path(server_path, "etc/include/version.h");
    if (!is_file(version_h))
      throw( ({ "Cannot access " + version_h  }) );

    object err = catch
    {
      program ver = compile_file(version_h);
      server_version = ver->roxen_ver + "." + ver->roxen_build;
    };
    
    if (err)
      throw(({"Can't fetch server version"}));

    write_mess("Server version ... <green>%s</green>\n", server_version);

    // Set current platform
    string os_file = combine_path(server_path, "OS");
    if (is_file(os_file))
      server_platform = trim_all_whites(read_file(os_file));
    else
      server_platform = "unknown";
    write_mess("Platform ... <green>%s</green>\n", server_platform);
  }
  
  string extract_id_from_filename(string filename)
  //! Takes a filename and returns the patch id.
  {
    // Check if the file has a valid id
    if(!patchid_regexp->match(filename))
      return 0;
    
    return patchid_regexp->split(filename)[0];
  }

  multiset get_flags(string id)
  //! Returns the flags for a given patch. Returns 0 if no patch with
  //! that id is available. NOT IMPLEMENTED!
  {
    
  }

  array(string) get_dependencies(string id)
  //! Returns the dependencies for a given patch. Returns 0 if no patch with
  //! that id is available.
  {
    PatchObject md = get_metadata(id);

    if (!md)
      return 0; 

    return md->depends || ({ });
  }

  string import_file(string path, void|int(0..1) dry_run)
  //! Copies the file at @tt{path@} to the directory of imported patches.
  //! It will check if the file exists and that its name contains a valid
  //! patch id. 
  //! @returns
  //!    Returns the patch id of the imported patch. 
  //!    TO DO: Check the id inside the file so it matches the id in the
  //!    file name.
  {
    // Check if the file exists
    if (!is_file(path))
    {
      write_err("<b>%s</b> could not be found!\n", path);
      return 0;
    }

    string patch_id = extract_id_from_filename(basename(path));
    if (!patch_id)
    {
      write_err("<b>%s</b> is not a valid rxp package!\n", path);
      return 0;
    }

    // Check if it's installed or already imported.
    if (is_imported(patch_id) || is_installed(patch_id))
    {
      write_err("Patch already installed or imported!\n");
      return 0;
    }
   
    PatchObject res = extract_patch(path, import_path, dry_run);
    
    return (res) ? res->id : 0;
  }


  int(0..1) install_patch(string patch_id, 
			  string user, 
			  void|int(0..1) dry_run,
			  void|int(0..1) force)
  //! Install a patch. Patch must be imported.
  //! @returns
  //!   Returns 1 if the patch was successfully installed, otherwise 0
  {
    string log = "";
    int error_count = 0;
    object current_time = Calendar.ISO->now();

    string source_path = id_to_filepath(patch_id);

    // Keep track of new files written in case the patch fails and we need to
    // remove them again.
    array(string) new_files = ({ });

    // Create a tar ball for backed up files.
    string backup_file = combine_path(source_path,
				      sprintf("backup_%s.tar", 
					      create_id(current_time)));

    // We set log path by default to the source directory.
    // When the installation succeeds it's re-set to the installation dir.
    string log_path = combine_path(source_path,
				   sprintf("failed_install_%s.log", 
					   create_id(current_time)));

    void write_log(int(0..1) error, mixed ... s)
    {
      log += wash_output(sprintf(@s));
      
      if(error)
	write_err(@s);
      else
	write_mess(@s);
    };
    
    void undo_changes_and_dump_log_to_file()
    {
      if(dry_run)
	rm(backup_file);
      else
      {
	if (sizeof(new_files))
	  foreach(new_files, string file)
	    rm(file);

	if (is_file(backup_file)) {
	  write_log(1, "Restoring backed up files ... ");
	  if (extract_tar_archive(backup_file, server_path))
	  {
	    write_log(0, "<green>ok</green>.\n");
	    rm(backup_file);
	  }
	  else
	    write_log(1, "FAILED! Backup needs to be restored manually "
			 "from <u>%s</u>\n", backup_file);
	}
	write_file(log_path, log);
	write_err("Writing log to <u>%s</u>\n", log_path);
      }
    };

    // Check if the patch is already installed
    if (is_installed(patch_id))
    {
      write_err("Patch <b>%s</b> is already installed!\n", patch_id); 
      return 0;
    }

    // Read metadata
    
    if (!source_path || sizeof(source_path) == 0)
    {
      write_err("Patch <b>%s</b> is not imported!\n", patch_id);
      return 0;
    }
    
    string mdfile = combine_path(source_path, "metadata");
    if (!is_file(mdfile))
    {
      write_err("Couldn't find metadata file!\n");
      return 0;
    }

    PatchObject ptchdata = parse_metadata(read_file(mdfile), patch_id);

    // Create a log file
    log = sprintf("Name:\t\t%s\nInstalled:\t%s\nUser:\t\t%s\n\n\n", 
		  ptchdata->name,
		  current_time->format_mtime(),
		  user);

    // Check platform
    write_log(0, "Checking platform ... ");
    if (ptchdata->platform)
    {
      if (!sizeof(filter(ptchdata->platform, check_platform)))
      {
	write_log(1, "FAILED: current platform not supported by this patch.\n");
	
	// TO DO: Ask if the user wants to abort or continue
	if (!force)
	{
	  
	  return 0;
	}
	else
	  error_count++;
      }
      else
	write_log(0, "<green>ok.</green>\n");
    }
    else
      write_log(0, "<green>ok.</green>\n");

    // Check version
    write_log(0, "Checking server version ... ");
    if (ptchdata->version)
    {
      if (!sizeof(filter(ptchdata->version, check_server_version)))
      {
	write_log(1, "FAILED: server version not supported by this patch.\n");
	
	// TO DO: Ask if the user wants to abort or continue
	if (!force)
	{
	  
	  return 0;
	}
	else
	  error_count++;
      }
      else
	write_log(0, "<green>ok.</green>\n");
    }   
    else
      write_log(0, "<green>ok.</green>\n");

    // Check dependencies
    write_log(0, "Checking dependencies ... ");
    if (ptchdata->depends)
    {
      int error = 0;
      foreach(ptchdata->depends, string patch_id)
      {
	if (!is_installed(patch_id) && !error)
	{
	  write_log(1, "FAILED:\n<b>%s</b> is not installed!\n", patch_id);
	  error_count++;
	  error = 1;
	}
	else if (!is_installed(patch_id))
	{
	  write_log(1, "<b>%s</b> is not installed either!\n", patch_id);
	  error_count++;
	}
      }
      if (error && !force)
      {
	write_file(log_path, log);
	write_err("Writing log to <u>%s</u>\n", log_path);
	return 0;
      }
    }
    else
      write_log(0, "<green>ok.</green>\n");   

    // Handle new files
    if (ptchdata->new)
    {
      foreach (ptchdata->new, mapping file)
      {
	string source = append_path(source_path, file->source);
	string dest = append_path(server_path, file->destination);
	write_log(0, "Writing new file <u>%s</u> ... ", dest);
	
	// Check if it already exists
	if(!file_stat(dest))
	{
	  // Check if the path exists or if we need to create it.
	  // Ignore if we are doing a dry run.
	  string path = dirname(dest);
	  if (!dry_run && !is_dir(path))
	    if(!mkdirhier(path))
	    {
	      write_log(1, "FAILED: Could not create target directory.\n");
	      error_count++;
	      if (!force)
	      {
		undo_changes_and_dump_log_to_file();
		return 0;
	      }
	    }
	}
	else
	{
	  write_log(1, "FAILED: File exists\n");
	  error_count++;
	  if (force)
	  // Since the file exists we better make a backup!
	  {
	    write_log(0, "Backing up <b>%s</b> to <u>%s</u> ... ", dest, 
		                                     basename(backup_file));
	    if (add_file_to_tar_archive(file->destination,
					server_path,
					backup_file))
	      write_log(0, "<green>ok.</green>\n");
	    else
	      // Since we will only come here if the force flag is set
	      // it's no use trying to bail out now.
	      write_log(1, "FAILED: No backup could be made. "
			   "File will be overwritten anyway.\n");
	  }
	  else
	  {
	    undo_changes_and_dump_log_to_file();
	    return 0;
	  }
	}

	// Copy the file from the archive to it's destination in the system.
	if (!dry_run && cp(source, dest))
	{
	  // Set correct mtime - if possible.
	  Stat fstat = file_stat(source);
	  
	  if(fstat)
	    System.utime(dest, fstat->atime, fstat->mtime);
	  write_log(0, "<green>ok.</green>\n");
	  new_files += ({ dest });
	}
	else if (!dry_run)
	{
	  write_log(1, "FAILED: Could not write file.\n");
	  error_count++;
	  if (!force)
	  {
	    undo_changes_and_dump_log_to_file();
	    return 0;
	  }
	}
      }
    }

    // Handle files to be replaced
    if (ptchdata->replace)
    {
      foreach (ptchdata->replace, mapping file)
      {
	string source = append_path(source_path, file->source);
	string dest = append_path(server_path, file->destination);
	
	// Make sure that the destination already exists
	if(is_file(dest))
	{
	  // Backup the original file to a tar_archive
	  write_log(0, "Backing up <b>%s</b> to <u>%s</u> ... ", 
		    dest, 
		    basename(backup_file));
	  if (add_file_to_tar_archive(file->destination,
				      server_path,
				      backup_file))
	    write_log(0, "<green>ok.</green>\n");
	  else
	  {
	    write_err("FAILED: Could not append tar file!\n");
	    
	    if (!force)
	    {
	      undo_changes_and_dump_log_to_file();
	      return 0;
	    }
	  }
  
	  // copy the file from the archive to it's destination in the system.
	  write_log(0, "Replacing file <u>%s</u> ... ", dest);
	  if (!dry_run && cp(source, dest))
	  {
	    // Set correct mtime - if possible.
	    Stat fstat = file_stat(source);

	    if(fstat)
	      System.utime(dest, fstat->atime, fstat->mtime);
	    write_log(0, "<green>ok.</green>\n");
	  }
	  else if (!dry_run)
	  {
	    write_log(1, "FAILED: Could not write file.\n");
	    error_count++;
	    if (!force)
	    {
	      undo_changes_and_dump_log_to_file();
	      return 0;
	    }
	  }
	  else
	    write_log(0, "<green>ok.</green>\n");
	}
	else
	{
	  write_log(1, "FAILED: File to be overwritten doesn't exists.\n");
	  error_count++;
	  if (!force)
	  {
	    undo_changes_and_dump_log_to_file();
	    return 0;
	  }
	}
      }
    }

    // Handle files to be deleted
    if (ptchdata->delete)
    {
      foreach (ptchdata->delete, string file)
      {
	string dest = append_path(server_path, file);
	write_log(0, "Removing file <u>%s</u> ... ", dest);
	
	// Make sure that the destination already exists
	if(is_file(dest))
	{
	  // Backup the original file to a tar_archive
	  write_log(0, "Backing up <u>%s</u> to </u>%s</u> ... ", 
		    dest, 
		    basename(backup_file));
	  if (add_file_to_tar_archive(file,
				      server_path,
				      backup_file))
	    write_log(0, "<green>ok.</green>\n");       
	  else
	  {
	    write_err("FAILED: Could not append tar file!\n");
	    
	    if (!force)
	    {
	      undo_changes_and_dump_log_to_file();
	      return 0;
	    }
	  }
	  
	  // Remove the file
	  if (!dry_run && rm(dest))
	  {
	    write_log(0, "<green>ok.</green>\n");
	  }
	  else if (!dry_run)
	  {
	    write_log(1, "FAILED: Could not remove file.\n");
	    error_count++;
	    if (!force)
	    {
	      undo_changes_and_dump_log_to_file();
	      return 0;
	    }
	  }
	}
	else
	{
	  write_log(1, "FAILED: File to be removed doesn't exists.\n");
	  error_count++;
	  // This is not a fatal error so we'll just continue.
	}
      }
    }

    // Handle files to be patched
    if (ptchdata->patch)
    {
      int error = 0;
      
      foreach (ptchdata->patch, string file)
      {
	File udiff_data = File(append_path(source_path, file));

	// Backup files
	foreach(lsdiff(udiff_data->read()), string affected_file)
	{
	  // Check that the affected file exists
	  write_log(0, "Checking %s ... ", affected_file);
	  if (is_file(append_path(server_path, affected_file)))
	  {
	    write_log(0, "<green>ok.</green>\nBacking up %s to %s ... ", 
		      affected_file,
		      basename(backup_file));
	    if (add_file_to_tar_archive(affected_file,
					server_path,
					backup_file))
	      write_log(0, "<green>ok.</green>\n");       
	    else
	    {
	      write_log(1, "FAILED: Could not append tar file!\n");
	      error_count++;
	      
	      if (!force)
	      {
		undo_changes_and_dump_log_to_file();
		return 0;
	      }
	    }
	  }
	  else
	  {
	    write_log(1, "FAILED: File does not exist.\n");
	    error_count++;
	    if (!force)
	    {
	      undo_changes_and_dump_log_to_file();
	      return 0;
	    }
	  }
	}
	
	// Patch file.
	write_log(0, "Applying patch ... ");
	udiff_data->seek(0); // Start from the beginning of the file again.

	array args = ({ patch_bin,
			"-p0",
			// Reject file
// 			"--global-reject-file=" +
// 			   append_path(source_path, "rejects"),
			"-d", combine_path(getcwd(), server_path) });
	
	if (dry_run) 
	  args += ({ "--dry-run" });

	Process.create_process p = 
	  Process.create_process(args, 
				 ([ 
				   "cwd"   : server_path, 
				   "stdin" : udiff_data 
				 ]));

	if (!p || p->wait())
	{
	  error_count++;
	  error = 1;
	  switch (p->wait())
	  {
	    case 1:
	      if (!force)
		write_log(1, "FAILED: Some hunks could not be patched.\n"
			     "If you want to patch anyway run rxnpatch from "
			     "the prompt with --force\n");
	      break;
	    case 2:
	      write_log(1, "FAILED: Permission denied.\n");
	      break;
	    default:
	      write_log(1, "FAILED!\n");
	  }
	  if (!force)
	  {
	    udiff_data->close();
	    undo_changes_and_dump_log_to_file();
	    return 0;
	  }
	}
	
	// Close file object again
	udiff_data->close();
      }
      if (!error)
	write_log(0, "<green>ok.</green>\n");
      
    }
    
    // Move dir
    if (!dry_run)
    {
      write_log(0, "Moving patch files ...");
      string dest_path = combine_path(installed_path,
				      basename(source_path));
      // This is because the file locks in Windows are evil and don't let go as
      // soon as one would wish. That's why a time out before reporting
      // permission denied is needed. 
      int i = 8; // Two seconds
      int mv_status = Stdio.recursive_mv(source_path, dest_path);
      while (!mv_status && errno() == 13 && i > 0)
      {
	sleep(0.25);
	Stdio.recursive_rm (dest_path); // To clean up a half-finished copy.
	mv_status = Stdio.recursive_mv(source_path, dest_path);
	i--;
      }
      if (mv_status)
      {
	write_log(0, "<green>ok.</green>\n");
	// Set a new destination for the log file
	log_path = combine_path(dest_path, "installation.log");
      }
      else
      {
	write_log(1, "Failed to move patch files: %O\n", strerror(errno()));
	error_count++;
	if (!force)
	{
	  undo_changes_and_dump_log_to_file();
	  return 0;
	}
      }
    }

    if (error_count == 1)
      write_log(1, "One (1) error occurred during installation.\n");
    else if (error_count > 1)
      write_log(1, "%d errors occcurred during installation.\n", error_count);

    // If we're doing a dry run then delete the backup file so we don't create
    // any footprints. If this is not a dry run then write log file to disk.
    if (dry_run)
      rm(backup_file);
    else
    {
      write_mess("Writing log file to <u>%s</u>\n", log_path);
      write_file(log_path, log);
    }

    return 1;
  }

  int(0..1) uninstall_patch(string id, string user)
  //! Uninstalls a patch by simply deleting all new files created and then
  //! unrolling the tarball containing the backuped files. 
  //! @param user
  //!   
  //! @returns 
  //!   true (1) upon success and false (0) if it
  //!   fails including if patch is not installed or got dependers.
  {
    int errors;

    write_mess("Checking if the patch is installed ... ");
    if (!is_installed(id))
    {
      write_err("FAILED: Patch is not installed!\n");
      return 0;
    }
    write_mess("<green>Done!</green>\n");

    write_mess("Checking if the patch got dependers ... ");
    if (got_dependers(id))
    {
      write_err("FAILED: Other patches depend on this patch!\n");
      return 0;
    }
    write_mess("<green>Done!</green>\n");

    write_mess("Reading installation log ... ");
    string log = read_file(combine_path(installed_path, 
					id, 
					"installation.log"));
    if (!(log && sizeof(log)))
    {
      write_err("FAILED!\n");
      return 0;
    }
    write_mess("<green>Done!</green>\n");

    write_mess("Checking metadata ... ");
    string mdxml = read_file(combine_path(installed_path, 
					  id, 
					  "metadata"));
    if (!(mdxml && sizeof(mdxml)))
    {
      write_err("FAILED: No metadata!\n");
      return 0;
    }
    PatchObject metadata = parse_metadata(mdxml, id);
    if (!metadata)
    {
      write_err("FAILED: Invalid metadata!\n");
      return 0;
    }
    write_mess("<green>Done!</green>\n");
      
    // We only need to check for backups if we have replaced, deleted or 
    // patched an old file. If the RXP only put new files in the system then
    // there should be no backup file unless the user forced an install.
    write_mess("Checking for backups ... ");
    string backup_file;
    if (sscanf(log, "%*sBacking up %*s to %s ... ok.\n", 
	       backup_file) == 3)
    { 
      if ( !(backup_file && sizeof(backup_file)) )
      {
	write_err("FAILED: No known backups!\n");
	return 0;
      }
      backup_file = combine_path(installed_path, id, basename(backup_file));
      if (!is_file(backup_file))
      {
	write_err("FAILED: Backup file %s not found!\n", backup_file);
	return 0;
      }
    }
    write_mess("<green>Done!</green>\n");

    // Delete new files that were created and thus are not part of the backups.
    if (metadata->new)
    {
      foreach(metadata->new->destination, string filename)
      {
	write_mess("Removing %s ... ", append_path(server_path, filename));
	if(rm(append_path(server_path, filename)))
	  write_mess("<green>Done!</green>\n");
	else
	{
	  write_err("FAILED!\n");
	  errors++;
	}
      }
    }

    // Unroll tarball.
    if (backup_file)
    {
      write_mess("Restoring backed up files from %O... ", backup_file);
      if (extract_tar_archive(backup_file, server_path))
	write_mess("<green>Done!</green>\n");
      else
      {
	write_err("FAILED!\n");
	errors++;
      }
    }
    
    // Move patch dir to Imported Patches
    write_mess("Moving patch files ...");
    string dest_path = combine_path(import_path, id);
    if (Stdio.recursive_mv(append_path(installed_path, id), dest_path))
      write_mess("<green>Done!</green>\n");
    else
    {
      write_err("FAILED to move patch files (%d: %s)\n"
		"%O ==> %O\n",
		errno(), strerror(errno()),
		append_path(installed_path, id), dest_path);
      errors++;
    }

    if (errors)
    {
      write_err("Some problems occurred when uninstalling patch!\n");
      return 0;
    }

    // Write to the installation log when the patch was uninstalled:
    log += sprintf("\nUninstalled:\t%s\nUser:\t\t%s\n", 
		   Calendar.ISO->now()->format_mtime(),
		   user);
    write_file(append_path(dest_path, "installation.log"), log);
    return 1;
  }

  mapping patch_status(string id)
  //! Returns the status of a patch.
  //! @returns
  //!   @mapping
  //!     @member string "status"
  //!       The current status of the patch. Is either "unknown", "imported",
  //!       "installed" or "uninstalled".
  //!     @member mapping "installed"
  //!       Date the patch was installed last time. Only available if the
  //!       @tt{status@} is "installed" or "uninstalled".
  //!     @member mapping "uninstalled"
  //!       Date the patch was installed last time. Only available if the
  //!       @tt{status@} is "uninstalled".
  //!     @member string "user"
  //!       Name of the user that installed the patch the last time. Only 
  //!       available if the @tt{status@} is "installed" or "uninstalled".
  //!     @member string "uninstall_user"
  //!       Name of the user that installed the patch the last time. Only 
  //!       available if the @tt{status@} is "installed" or "uninstalled".
  //!     @member mapping "metadata"
  //!   @endmapping
  {
    mapping res = ([ ]);
    string file_path = id_to_filepath(id);
    
    if (!(file_path && sizeof(file_path)))
      return ([ "status" : "unknown" ]);

    // Get metadata
    if (is_file(append_path(file_path, "metadata")))
    {
      string md = read_file(append_path(file_path, "metadata"));
      res->metadata = parse_metadata(md, id);
    }
    else
      return ([ "status" : "unknown" ]);

    string inst_user, uninst_user;
    mapping(string:int) inst_date, uninst_date;
    if (is_file(append_path(file_path, "installation.log")))
    {
      string install_log = read_file(append_path(file_path, 
						 "installation.log"));
      sscanf(install_log, 
	     "%*sInstalled:\t%4d-%2d-%2d %2d:%2d\nUser:\t\t%s\n",
	     int year,
	     int month,
	     int day,
	     int hour,
	     int minute,
	     inst_user);
	
      inst_date = ([ "year" : (year > 1900) ? year - 1900 : year,
		     "mon"  : month,
		     "mday" : day,
		     "hour" : hour,
		     "min"  : minute ]);
	
      res->installed	= inst_date;
      res->user	= inst_user || "Unknown";

      if (sscanf(install_log, 
		 "%*sUninstalled:\t%4d-%2d-%2d %2d:%2d\nUser:\t\t%s\n",
		 year,
		 month,
		 day,
		 hour,
		 minute,
		 uninst_user) == 7)
      {	   
	uninst_date = ([ "year" : (year > 1900) ? year - 1900 : year,
			 "mon"  : month,
			 "mday" : day,
			 "hour" : hour,
			 "min"  : minute ]);
	res->status		= "uninstalled";
	res->uninstalled	= uninst_date;
	res->uninstall_user	= uninst_user;
	return res;
      }
	
      // Assume the patch is installed.
      res->status = "installed";
    }
    else if (is_installed(id))
    {
      res->inst_date = "Information not available.";
      res->inst_user = "Unknown";
    }
    else
      res->status		= "imported";
  
    return res;
  }


  PatchObject parse_metadata(string metadata_block, string patchid)
  //! Parses a string containing the metadata block.
  //! @returns
  //!   Returns a mapping if successful, 0 otherwise.
  {
    PatchObject p = ([ "id" : patchid ]);
    SimpleNode md = simple_parse_input(metadata_block, 0,
				       PARSE_CHECK_ALL_ERRORS);
    //				       PARSE_FORCE_LOWERCASE |
    //				       PARSE_WANT_ERROR_CONTEXT);

    md = md->get_first_element();
    p->rxp_version = md->get_attributes()->version;

    foreach(md->get_elements(0,1), SimpleNode node)
    {
      string name = node->get_full_name();
      string tag_content = (node[0]) ? node[0]->get_text() : "";
      if (sizeof(node->get_attributes()))
      {
	foreach(node->get_attributes(); string i; string v)
	{
	  // Check if we have a flag and if that flag is on or off.
	  if(name == "flag")
	  { 
	    if((i == "name") && 
	       !(tag_content == "false" ||
		 tag_content == "0"))
	    {
	      p->flags += (< v >);
	    }
	  }
	  else if(name == "patch")
	  {
	    p->patch += ({ v });
	  }
	  else
	  {
	    if(!p[name])
	      p += ([ name:({ }) ]);
	    p[name] += ({ ([i:v]) });
	  }
	}
	if(arrayp(p[name]) && 
	   mappingp(p[name][-1]) &&
	   p[name][-1]->source)
	  p[name][-1]->destination = tag_content;
      }
      else
      {
	switch(name)
	{
	  case "name":
	    p->name = tag_content;
	    break;
	  case "description":
	    p->description = trim_ALL_redundant_whites(tag_content);
	    break;
	  case "originator":
	    p->originator = tag_content;
	    break;
	  default:
	    p[name] += ({ tag_content });
	    break;
	}
      }
    }
    
    if (!verify_patch_object(p, 1 /* Silent mode */))
      return 0;

    return p;  
  }

  array(mapping(string:string|mapping(string:mixed))) file_list_installed()
  //! This function returns a list of installed patches.
  //!
  //! @returns
  //!   Returns an array of mapping with the following content:
  //!   @mapping
  //!     @member mapping(string:int) "installed"
  //!       Time of installation. Same kind of mapping as localtime() returns.
  //!       Taken from the patch's installation log. If there is no log,
  //!       i.e if it has been deleted by a user, then the value of this field
  //!       will be 0.
  //!     @member string "user"
  //!       User who installed the patch. Taken from the patch's 
  //!       installation log. If there is no log,
  //!       i.e if it has been deleted by a user, then the value of this field
  //!       will be 0.
  //!     @member mapping(string:mixed) "metadata"
  //!       metadata block as returned from parse_metadata()
  //!   @endmapping
  {
    array patch_list = filter(get_dir(installed_path) || ({ }), 
			      lambda(string s)
			      {
				return is_dir(combine_path(installed_path, s));
			      }
			     );

    array res = ({ });
    
    foreach(patch_list, string patch_path)
    {
      // Get installation log
      string install_log = append_path(installed_path,
				       patch_path,
				       "installation.log");
      string user;
      mapping(string:int) inst_date;
      PatchObject po;

      if (is_file(install_log))
      {
	string log_data = read_file(install_log);
	sscanf(log_data, 
	       "%*sInstalled:\t%4d-%2d-%2d %2d:%2d\nUser:\t\t%s\n",
	       int year,
	       int month,
	       int day,
	       int hour,
	       int minute,
	       user);

	inst_date = ([ "year" : (year > 1900) ? year - 1900 : year,
		       "mon"  : month,
		       "mday" : day,
		       "hour" : hour,
		       "min"  : minute ]);
      }

      // Get metadata
      string mdfile = append_path(installed_path, 
				  patch_path, 
				  "metadata");
      if (is_file(mdfile))
      {
	string mdblock = read_file(mdfile);
	po = parse_metadata(mdblock, 
			    extract_id_from_filename(mdfile));

      
	res += ({ ([ "installed" : inst_date,
		     "user"      : user,
		     "metadata"  : po ]) });
      }
    }

    return Array.sort_array(res, lambda (mapping a, mapping b)
				 {
				   return a->metadata->id < b->metadata->id;
				 }
			    );
  }
  
  array(mapping(string:string|mapping(string:mixed))) file_list_imported()
  //! This function returns a list of all imported patches.
  //!
  //! @returns
  //!   Returns an array of mapping with the following content:
  //!   @mapping
  //!     @member mapping(string:int) "installed"
  //!       Time of latest installation. Same kind of mapping as localtime()
  //!       returns. Taken from the patch's installation log. If there is no
  //!       log, e.g. if the patch has never been installed, then the value of
  //!       this field will be 0.
  //!     @member string "user"
  //!       User who installed the patch. Taken from the patch's 
  //!       installation log. If there is no log, e.g. if the patch has never
  //!       been installed, then the value of this field will be 0.
  //!    then the value of this field
  //!       will be 0.
  //!     @member mapping (string:int) "uninstalled"
  //!       Time of latest unistallation. This field is 0 unless the patch has
  //!       has been uninstalled.
  //!     @member string "uninstall_user"
  //!       User who uninstalled the patch. This field is usually 0.
  //!     @member mapping(string:mixed) "metadata"
  //!       metadata block as returned from parse_metadata()
  //!   @endmapping
  {
    array patch_list = filter(get_dir(import_path) || ({ }), 
			      lambda(string s)
			      {
				return is_dir(append_path(import_path, s));
			      }
			     );

    array res = ({ });
    
    foreach(patch_list, string patch_path)
    {
      // Get installation log
      string install_log = append_path(import_path,
				       patch_path,
				       "installation.log");
      string inst_user, uninst_user;
      mapping(string:int) inst_date, uninst_date;
      PatchObject po;

      if (is_file(install_log))
      {
	string log_data = read_file(install_log);
	sscanf(log_data, 
	       "%*sInstalled:\t%4d-%2d-%2d %2d:%2d\nUser:\t\t%s\n",
	       int year,
	       int month,
	       int day,
	       int hour,
	       int minute,
	       inst_user);

	inst_date = ([ "year" : (year > 1900) ? year - 1900 : year,
		       "mon"  : month,
		       "mday" : day,
		       "hour" : hour,
		       "min"  : minute ]);
	sscanf(log_data, 
	       "%*sUninstalled:\t%4d-%2d-%2d %2d:%2d\nUser:\t\t%s\n",
	       year,
	       month,
	       day,
	       hour,
	       minute,
	       uninst_user);

	uninst_date = ([ "year" : (year > 1900) ? year - 1900 : year,
			 "mon"  : month,
			 "mday" : day,
			 "hour" : hour,
			 "min"  : minute ]);
      }

      // Get metadata
      string mdfile = append_path(import_path, 
				  patch_path, 
				  "metadata");
      if (is_file(mdfile))
      {
	string mdblock = read_file(mdfile);
	po = parse_metadata(mdblock, 
			    extract_id_from_filename(mdfile));

	res += ({ ([ "installed"		: inst_date,
		     "user"		: inst_user,
		     "uninstalled"	: uninst_date,
		     "uninstall_user"	: uninst_user,
		     "metadata"		: po ]) });
      }
    }

    return Array.sort_array(res, lambda (mapping a, mapping b)
				 {
				   return a->metadata->id > b->metadata->id;
				 }
			    );
  }
  
  string current_version()
  //! @returns
  //!   current version of the patch file lib.
  {
    sscanf(lib_version, "$""Id: %s""$", string ver);
    return ver || "n/a";
  }
  
  void set_installed_path(string path) 
  //! Sets the new path to the installed patches directory. If the path is
  //! relative then it is assumed that it is relative the server dir.
  //!
  //! Raises an exception if the directory does not exist or if it lacks write
  //! permissions.
  {
    installed_path = combine_path(server_path, path);
    if (!is_dir(installed_path))
      throw( ({ sprintf("Couldn't set %s as path for installed patches", 
			installed_path) }) );
  }  
  
  void set_imported_path(string path) 
  //! Sets the new path to the imported patches directory. If the path is
  //! relative then it is assumed that it is relative the current working 
  //! directory.
  //!
  //! Raises an exception if the directory does not exist or if it lacks write
  //! permissions.
  {
    import_path = combine_path(getcwd(), path);
    if (!is_dir(installed_path))
      throw( ({ sprintf("Couldn't set %s as path for installed patches", 
			import_path) }) );
  }
  
  void set_temp_dir(void | string path)
  //! Sets the new path to the temp directory
  //!
  //! If no argument is given then the function will check for environment
  //! variables specifing the systems temp dir and none is present /tmp/ will
  //! be used.
  //!
  //! Raises an exception if the directory does not exist or if it lacks write
  //! permissions.
  {
    mapping env = getenv();
    if (path)
      temp_path = path;
    else if (env->TEMP && is_dir(env->TEMP))
      temp_path = env->TEMP;
    else if (env->TMPDIR && is_dir(env->TMPDIR))
      temp_path = env->TMPDIR;
    else if (env->TMP && is_dir(env->TMP))
      temp_path = env->TMP;
    else if (is_dir("/tmp/"))
      temp_path = "/tmp/";
    else
      throw(({"Couldn't set a standard temp dir."}));
  }

  string get_temp_dir() { return temp_path; }
  //! Return the current temp directory.

  string get_import_dir() { return import_path; }
  //! Return the current import directory.

  string get_installed_dir() { return installed_path; }
  //! Return the current installed patches directory.

  string get_server_version() { return server_version; }
  //! Return the current server version

  string get_server_platform() { return server_platform; }
  // Return the current server platform 

  string build_metadata_block(PatchObject metadata)
  //! Builds an XML metadatablock from the mapping provided.
  //! Throws an exception if the PatchObject is not complete.
  {
    string xml = "<?xml version=\"1.0\"?>\n";
    xml += sprintf("<rxp version=\"%s\">\n", rxp_version);
    
    xml += sprintf("  <name>%s</name>\n", 
		   html_encode(metadata->name));
    
    // Reformat the description
    string desc = "   ";
    int col_count = 3;
    foreach(trim_ALL_redundant_whites(metadata->description) / " ", string s)
    {
      s = html_encode(s);
      if((col_count + sizeof(s) + 1) < 80)
      {
	  desc += " " + s;
	  col_count += sizeof(s) + 1;
      }
      else
      {
	desc += sprintf("\n    %s", s);
	col_count = 4 + sizeof(s);
      }
    }
    xml += sprintf("  <description>\n%s\n  </description>\n", desc);
    
    xml += sprintf("  <originator>%s</originator>\n", metadata->originator);

    array valid_tags = ({ "version", "platform", "depends", "flags", "reload",
			  "patch", "new", "replace", "delete" });

    foreach(valid_tags, string tag_name)
    {
      if(metadata[tag_name])
      {
	if (tag_name == "flags")
	{
	  foreach(indices(known_flags), string s)
	    xml += sprintf("  <flag name=\"%s\">%s</flag>\n",
			   s, (metadata->flags[s]) ? "true" : "false");
	}
	else if (mappingp(metadata[tag_name][0]))
	{
	  foreach(metadata[tag_name], mapping m)
	    xml += sprintf("  <%s source=\"%s\">%s</%s>\n",
			   tag_name,
			   m->source,
			   m->destination,
			   tag_name);
	}
	else if (tag_name == "patch")
	{
	  foreach(metadata->patch, string s)
	    xml += sprintf("  <patch source=\"%s\" />\n", s);
	}
	else
	{
	  foreach(metadata[tag_name], string s)
	    xml += sprintf("  <%s>%s</%s>\n", tag_name, s, tag_name);
	}
      }
    }

    return xml += "</rxp>";  
  }
  
  int(-1..1) got_dependers(string id, void|multiset(string) pretend_installed)
  //! Checks if there are patches installed after this one. If the patch given
  //! isn't installed instead return true if it depends on patches that are not
  //! installed.
  //! @param pretend_installed
  //!   Pretend that the given ids are installed patches. Useful when batch
  //!   processing files in "dry run" mode.
  //! @returns
  //!   Returns 0 if there are no dependers, 1 if there are and -1 if the patch
  //!   is neither installed nor imported.
  {
    if (!pretend_installed)
      pretend_installed = (< >);
    if (is_installed(id))
    {
      array file_list = file_list_installed();
    
      array filtered_list = filter(file_list, 
				   lambda (mapping m)
				   {
				     return m->metadata->id > id &&
				       !pretend_installed[m->metadata->id];
				   } );
      return !!sizeof(filtered_list);
    }
    
    if (is_imported(id))
    {
      PatchObject po = get_metadata(id);

      if (!po)
	return -1;

      if (!po->depends)
	return 0;
      
      array filtered_list = filter(po->depends, 
				   lambda (string id)
				   {
				     return !(is_installed(id) ||
					      pretend_installed[id]);
				   }
				   );
      return !!sizeof(filtered_list);
    }

    // If the patch is neither imported nor installed then return -1
    return -1;
  }
  
  int(0..1) create_patch(PatchObject metadata, string|void destination_path)
  //! Creates a patch archive from the given PatchObject
  {
    // Verify patch object
    if (!verify_patch_object(metadata))
      return 0;

    // Copy all files to a temp dir.
    string id = metadata->id;
    string temp_data_path = combine_path(temp_path, id);
    write_mess("Creating temp dir for %s ... ", id);
    if(mkdirhier(temp_data_path))
      write_mess("<green>Done!</green>\n");
    else
    {
      write_err("FAILED: Could not create %s\n", temp_data_path);
      return 0;
    }

    // Copy the files to the temp dir:
    if (metadata->patch)
      foreach(metadata->patch; int i; string s)
      {
	// Package the string nicely:
	mapping m = ([ "source" : s ]);
	if (!copy_file_to_temp_dir(m, temp_data_path))
	{
	  clean_up(temp_data_path);
	  return 0;
	}

	// Update with the new file name
	metadata->patch[i] = basename(s);
      }

    if (metadata->replace)
      foreach(metadata->replace, mapping m)
	if (!copy_file_to_temp_dir(m, temp_data_path))
	{
	  clean_up(temp_data_path);
	  return 0;
	}

    if (metadata->new)
      foreach(metadata->new, mapping m)
	if (!copy_file_to_temp_dir(m, temp_data_path)) 
	{
	  clean_up(temp_data_path);
	  return 0;
	}

    // If we for some reason have any unified diffs then we need to write them
    // down to a file as well.
    if (metadata->udiff)
    {
      constant out_filename = "patchdata.patch";
      string out_file_path = combine_path(temp_data_path, out_filename);
      
      if(!write_file_to_disk(out_file_path, metadata->udiff))
      {
	clean_up(temp_data_path);
	return 0;
      }

      // Update the patch object with a pointer to the file and discard the
      // udiff block; it's not needed anymore.
      metadata->patch += ({ out_filename });
      metadata->udiff = 0;
    }

    string mdxml = build_metadata_block(metadata);
    string out_file_path = combine_path(temp_data_path, "metadata");
    
    if(!write_file_to_disk(out_file_path, mdxml))
      return 0;

    if(!create_rxp_file(id, destination_path))
      return 0;

    write_mess("Patch created successfully!\n");

    clean_up(temp_data_path);
    
    return 1;
  }

  PatchObject extract_patch(string file, 
			    string target_dir,
			    void|int(0..1) dry_run)
  //! Creates a directory in target_dir named after the patch's id and 
  //! extracts the patch there. Then returns the parsed metadata.
  {
    string source_file = combine_path(getcwd(), file);
    write_mess("Extracting %s to %s ... ", source_file, target_dir);

    if (!extract_tar_archive(source_file, target_dir, 1))
    {
      write_err("FAILED: Could not extract file.\n");
      return 0;
    }

    write_mess("<green>Done!</green>\n");
    
    // Read metadata
    string patchid = extract_id_from_filename(file);
    string mdfile = combine_path(target_dir, patchid, "metadata");
    write_mess("Extracting %s ... ", mdfile);
    string md = read_file(mdfile);
    
    if (md && sizeof(md))
      write_mess("<green>Done!</green>\n");
    else
    {
      write_err("FAILED: Could not read metadata file.\n");
      rm(combine_path(target_dir, patchid));
      return 0;
    }

    PatchObject res = parse_metadata(md, patchid);
    if (!res || dry_run)
      recursive_rm(combine_path(target_dir, patchid));

    return res;
  }

  int(0..1) is_imported(string id)
  //! Check if a patch is imported. Note that it will return false (0) if the
  //! patch is installed.
  //! @returns
  //!   Returns 1 if a patch is imported, 0 otherwise
  {
    if(!patchid_regexp->match(id))
    {
      write_err("Not a proper id\n");
      return 0;
    }

    // Make an array of the paths where we want to check for the dir
    array inst_ptchs = filter(get_dir(import_path) || ({ }), 
			      lambda(string s)
			      {
				return is_dir(combine_path(import_path, s));
			      }
			     );

    foreach(inst_ptchs, string dir_name)
    {
      if(sscanf(dir_name, "%*s"+id+"%*s"))
	return 1;
    }
      
    // Not found.
    return 0;
  }

  int(0..1) is_installed(string id)
  //! Check if a patch is installed.
  //! @returns
  //!   Returns 1 if a patch is installed, 0 otherwise
  {
    if(!patchid_regexp->match(id))
    {
      write_err("Not a proper id\n");
      return 0;
    }

    // Make an array of the paths where we want to check for the dir
    array inst_ptchs = filter(get_dir(installed_path) || ({ }), 
			      lambda(string s)
			      {
				return is_dir(combine_path(installed_path, s));
			      }
			     );

    foreach(inst_ptchs, string dir_name)
    {
      if(sscanf(dir_name, "%*s"+id+"%*s"))
	  return 1;
    }

    // Not found.
    return 0;
  }

  string id_to_filepath(string id, void|int(0..1) silent)
  //! Returns the path to a give patch id.
  //! @returns
  //!   Returns a file path if successful and 0 if the file is neither imported
  //!   nor installed.
  {
    if(!patchid_regexp->match(id))
    {
      if (!silent)
	write_err("Not a proper id.\n");
      return 0;
    }

    // Make an array of the paths where we want to check for the dir
    array all_paths = ({ installed_path, import_path });

    foreach(all_paths, string path)
    {
      array inst_ptchs = filter(get_dir(path) || ({ }), 
				lambda(string s)
				{
				  return is_dir(combine_path(path, s));
				}
			       );

      foreach(inst_ptchs, string dir_name)
      {
	if(sscanf(dir_name, "%*s"+id+"%*s"))
	  return combine_path(path, dir_name);
      }
    }

    // Apparently we didn't find anything
    return 0;
  }

  PatchObject get_metadata(string id)
  //! Returns the PatchObject of a given installed or imported patch
  //! @returns
  //!   Returns a PatchObject if successful and 0 if the patch is neither
  //!   installed nor imported.
  {
    string patch_path = id_to_filepath(id);

    string mdfile = combine_path(patch_path, "metadata");

    if (!is_file(mdfile))
      return 0;
    
    string mdblock = read_file(mdfile);
    return parse_metadata(mdblock, id);
  }

  array(string) parse_platform(string raw_string)
  //! Takes a raw string and checks if it's a correctly formatted platform id.
  {
    if (known_platforms[raw_string])
      return ({ raw_string });

    return 0;
  }

  array(string) parse_version(string raw_string)
  //! Takes a raw string and checks if it's a correctly formatted server 
  //! version and returns a list of versions parsed.
  {
    if (sscanf(raw_string, "%1d.%d.%d", int major, int minor, int build) == 3)
    {
      string version = major + "." + minor + "." + build;
      return ({ version });
    }

    return 0;
  }

  array(mapping(string:string)) parse_src_dest_path(string raw_path)
  //! Uses the raw path as destination and then tries to find the source file
  //! by checking each directory from the given path up to root.
  //!
  //! If the raw path contains a glob then it will try to find all source files
  //! matching that glob.
  {
    array(mapping(string:string)) res;

    // Check if there are globs in the raw_path. In that case we can assume that
    // the source and destination are the same.
    sscanf(raw_path, "%*s%[*?]", string found_glob);
    if (found_glob && sizeof(found_glob))
    {
      array(string) all_files = find_files_with_globs(raw_path, 1);
      res = map(all_files, lambda (string path)
			   {
			     return ([ "source" : path,
				       "destination" : path ]);
			   } 
		);
    }
    else
    {
      string parsed_src = find_file(raw_path), parsed_dest = raw_path;
      if (parsed_src)
	res = ({ (["source":parsed_src, "destination":parsed_dest ]) });
    }
    return res;
  }

  int(0..1) verify_patch_id(string patch_id)
  //! Takes a string and verifies that it is a correctly formated patch id.
  {
    return patchid_regexp->match(patch_id);
  }

  int(0..1) verify_patch_object(PatchObject ptc_obj, void|int(0..1) silent)
  //! Returns 1 if ok, otherwise 0;
  {
    if (!silent)
      write_mess("Verifying metadata ... ");
    if (ptc_obj->rxp_version != rxp_version)
    {
      if (!silent)
	write_err("FAILED: This rxp version is not supported!\n");
      return 0;
    }

    if(!ptc_obj->id)
    {
      if (!silent)
	write_err("FAILED: No ID in metadata!\n");
      return 0;
    }
    
    if(!verify_patch_id(ptc_obj->id))
    {
      if (!silent)
	write_err("FAILED: ID is not valid!\n");
      return 0;
    }
    
    if (!(ptc_obj->name && sizeof(ptc_obj->name)))
    {
      if (!silent)
	write_err("FAILED: No patch name given in metadata!\n");
      return 0;
    }
    
    if (!(ptc_obj->description && sizeof(ptc_obj->description)))
    {
      if (!silent)
	write_err("FAILED: No description given in metadata!\n");
      return 0;
    }
    
    if (!sizeof(ptc_obj->originator))
    {
      if (!silent)
	write_err("FAILED: No originator given in metadata!\n");
      return 0;
    }
    
    if (ptc_obj->depends)
      foreach(ptc_obj->depends, string patch_id)
	if (!verify_patch_id(patch_id))
	{
	  if (!silent)
	    write_err("FAILED: Dependency %s is not a valid patch id\n",
		      patch_id);
	  return 0;
	}
    
    if (ptc_obj->replace)
    {
      if (!sizeof(ptc_obj->replace))
      {
	if (!silent)
	  write_err("FAILED: List of files to be replaced exists but is "
		    "empty.\n");
	return 0;
      }
//       foreach(ptc_obj->replace, mapping(string:string) m)
//       {
// 	werror("REPLACE: %s\n", m->source);
// 	Stat stat = file_stat(m->source);
// 	if (!(stat && stat->isreg))
// 	{
// 	  write_err("FAILED: Could not find %s!\n", m->source);
// 	  return 0;
// 	}
//       }
    }

    if (ptc_obj->new)
    {
      if (!sizeof(ptc_obj->new))
      {
	write_err("FAILED: List of new files to be created exists but is "
		  "empty.\n");
	return 0;
      }
//       foreach(ptc_obj->new, mapping(string:string) m)
//       {
// 	Stat stat = file_stat(m->source);
// 	if (!(stat && stat->isreg))
// 	{
// 	  write_err("FAILED: Could not find %s!\n", m->source);
// 	  return 0;
// 	}
//       }
    }

    if (ptc_obj->delete && !sizeof(ptc_obj->delete))
    {
      if (!silent)
	write_err("FAILED: List of files to be deleted exists but is "
		  "empty.\n");
      return 0;
    }
    
    // We have passed all the above tests.
    if (!silent)
      write_mess("<green>Done!</green>\n");
    return 1;
  }

  /***************************************************************************
   *                         PRIVATE FUNCTIONS                               *
   ***************************************************************************/

  string combine_and_check_path(string path)
  //! Set path relative to server path and validate
  //!
  //! @param path
  //!   Absolute path or relative the server directory.
  {
    string combined = combine_path(getcwd(), server_path, path);
    Stat stat = file_stat(combined);
    if(!stat || !stat->isdir)
    {
      write_err("%s is not a directory!\n", combined);
      return 0;
    }
    return combined;
  }

  string find_file(string raw_path)
  //! Search for a file by checking each directory from the given path up to 
  //! root
  {
    string res = "";

    // Use '/' as directory delimiter even on Windows systems.
    raw_path = normalize_path(raw_path);

    // Extract the file name
    string filename = basename(raw_path);
    
    // do an iterative search for the source file.
    // But first check the current working dir before checking any paths
    // parallel dirs.
    if (raw_path[0..1] == "..")
    {
      string s = combine_path(getcwd(), filename);
      
      write_mess("Fetching %s ... ", s);

      if(is_file(s))
      {
	write_mess("<green>Done!</green>\n");
	return s;
      }
      else
	write_mess("Not Found!\n");
    }
    
    // Create a full path and reverse it for easier traversion
    string path_rev = reverse(combine_path(getcwd(), raw_path));
    
    // Remove file name from path
    sscanf(path_rev, "%*s/%s", path_rev);

    for (int i = sizeof(path_rev / "/"); i >= 0; i--)
    {
      string test_path = combine_path(reverse(path_rev), filename);
      test_path = combine_path(getcwd(), test_path);
      
      write_mess("Fetching %s ... ", test_path);
      
      if(is_file(test_path))
      {
	write_mess("<green>Done!</green>\n");
	return test_path;
      }
      else
	write_mess("Not Found!\n");
      //      write_mess("\n%d: %s\n\n", i, path_rev);
      // If we can't find any '/' then we only have one directory left
      // and that needs to be removed too.
      if(sscanf(path_rev, "%*s/%s", path_rev) < 2)
	path_rev = ""; 
    }
    
    write_err("FAILED!\n");
    return 0;
  }

  array(string) recursive_find_all_files(void|string path)
  //! Find all files in directory and its subdirectories.
  //! @returns
  //!   Returns an array of file paths.
  {
    array res = ({ });
    array current_dir = (path && sizeof(path)) ? get_dir(path) 
                                               : get_dir(getcwd());

    foreach(current_dir, string file_name)
    {
      string current_file = (path) ? append_path(path, file_name) : file_name;
      if (is_dir(current_file))
	res += recursive_find_all_files(current_file);
      else if (is_file(current_file))
	res += ({ current_file });
    }
    
    return res;
  }

  array find_files_with_globs(string glob_pattern, void|int(0..1) recursive)
  //! Find files using a glob pattern.
  //! @param recursive
  //!   If this is set then this function will start by building a list of all
  //!   files in the specified directory and then apply the glob to each and
  //!   every one of them by using glob.
  //! @returns
  //!   An array of matching files.
  {
    // First of all extract the path that is not a glob and use that as base
    // directory.
    array(string) all_files;
    if (sscanf(glob_pattern, "%s%*[*?]", string base) == 2)
    {
      if (recursive)
	all_files = recursive_find_all_files(dirname(base));
      else
      {
	all_files = get_dir(dirname(base)) || get_dir(getcwd());
	all_files = filter(all_files, lambda (string filename)
				      {
					return is_file(filename);
				      }
			   );
      }
    }
    else 
      return 0;
    
    return glob(glob_pattern, all_files);
  }

  int(0..1) copy_file_to_temp_dir(mapping m, string temp_data_path)
  //! Copy the file in @[m] to a temporary directory while
  //! preserving the original path.
  {
    string filename = basename(m->source);
    string full_path = combine_path(getcwd(), m->source);
    if(!sizeof(filename))
      return 0;
    
    string dest = combine_path(temp_data_path, filename);

    write_mess("Copying %s to %s ... ", full_path, dest);

    // Check if another file exists already in the temp dir. 
    // If so, rename the new one.
    if (is_file(dest))
    {
      int n;
      for(n = 0; is_file(dest + n); n++);

      dest += n;
      write_mess("file exists.\n Trying %s ... ", dest);
    }

    if(!cp(full_path, dest))
    {
      write_err("FAILED: %s!\n", strerror(errno()));
      return 0;
    }

    // Since the filename may have been changed we'll extract it again from
    // dest.
    m->source = basename(dest);
    write_mess("<green>Done!</green>\n");
    return 1;
  }

  int write_file_to_disk(string path, string data)
  //! Write data to file in temp dir.
  {
    write_mess("Writing patch data to %s ... ", path);

    File out_file = File();
    
    if(!out_file->open(path, "cxw"))
    {
      write_err("FAILED: %s\n", strerror(errno()));
      return 0;
    }
    
    if(out_file->write(data) < 1)
    {
      write_err("FAILED: %s\n", strerror(errno()));
      return 0;
    }
    
    out_file->close();
    
    write_mess("<green>Done!</green>\n");
    return 1;
  }

  string create_id(void|object time)
  //! Create a string on the format YYYY-MM-DDThhmm based on the current time.
  {
    if (!time)
      time = Calendar.ISO->now();

    sscanf(time->format_mtime(), "%s %s:%s", string id1, string id2, string id3);
    return sprintf("%sT%s%s", id1, id2, id3);
  }


  string trim_ALL_redundant_whites(string s)
  //! Trim away all whites including newlines, double space a tabs.
  {
    string res = "";
    int i = 0;
    s = trim_all_whites(s);
    while(i < sizeof(s))
    {
      if (s[i] == ' '  ||
	  s[i] == '\n' ||
	  s[i] == '\r' ||
	  s[i] == '\t')
      {
	
	// This is safe since we know that the last char is not a blank:
	int j = i + 1;
	if (s[j] != ' '  &&
	    s[j] != '\n' &&
	    s[j] != '\r' &&
	    s[j] != '\t')
	  res += " ";
      }
      else
	res += s[i..i];
      i++;    
    }
    return res;
  }

  int create_rxp_file(string id, void|string dest_path)
  //! Call tar as an external process and create a file with the given id
  //! in the given destination directory.
  {
    string dest;
    if (dest_path)
      dest = combine_path(dest_path, id + ".rxp");
    else
      dest = combine_path(getcwd(), id + ".rxp");
    dest = unixify_path(dest);
    write_mess("Creating tar file %s ... ", dest);
    array args = ({ tar_bin, "czf", dest, id });
  
    Process.create_process p = Process.create_process(args, 
						      ([ "cwd" : temp_path ]));
    if (!p || p->wait())
    {
      write_err("FAILED: Could not create tar file!\n");
      return 0;
    }
  
    write_mess("<green>Done!</green>\n");
    return 1;
  }

  
  int(0..1) add_file_to_tar_archive(string file_name,
				    string base_path,
				    string tar_archive)
  //! Add a file to @[tar_archive]. If the archive doesn't exist it will be 
  //! created automagically by tar. @[file_name] cannot be a relative path
  //! higher than base_path.
  {
    array args = ({ tar_bin, "rf", 
		    unixify_path(tar_archive), 
		    simplify_path(unixify_path(file_name)) });
  
    Process.create_process p = Process.create_process(args,
						      ([ "cwd" : base_path ]));
    if (!p || p->wait())
      return 0;
  
    return 1; 
  }


  int(0..1) extract_tar_archive(string file_name, string path, int|void gzip) 
  //! Extract a tar archive to @[path].
  {
    Stdio.File file = Stdio.File(file_name, "rb");

    if (gzip) {
      file = Gz.File(file, "rb");
    }

    // NB: We use Filesystem.Tar here so that we don't need
    //     to rely on tar binary options that are known not
    //     to be compatible across operating systems.
    Filesystem.Tar tarfs = Filesystem.Tar(file_name, UNDEFINED, file);

    if (mixed err = catch {
	tarfs->tar->extract("", path, UNDEFINED,
			    Filesystem.Tar.EXTRACT_SKIP_MODE|
			    Filesystem.Tar.EXTRACT_SKIP_MTIME);
      }) {
      werror("%s\n", describe_backtrace(err));
      file->close();
      return 0;
    }
    
    file->close();
    return 1; 
  }


  int(0..1) clean_up(string temp_path, void|int(0..1) silent)
  //! Deletes temporary data when we're done with it.
  {
    if (!silent)
      write_mess("Cleaning up ... ");
    
    if (recursive_rm(temp_path))
    {
      if (!silent) 
	write_mess("<green>Done!</green>\n");
      return 1;
    }
    if (!silent)
      write_err("FAILED: Could not delete %s\n", temp_path);
    return 0;
  }

  int(0..1) check_server_version(string version)
  //! Checks if the incoming version string matches the current server version.
  //!
  //! The current serverversion is taken from @expr{roxen_ver@} and
  //! @expr{roxen_build@} in etc/include/version.h.
  //! @param version
  //!   String to compare with the current server version
  { return version == server_version; }

  int(0..1) check_platform(string platform)
  //! Checks if the incoming platform string matches the current platform.
  { return platform == server_platform; }

  array(string) lsdiff(string patch_data)
  //! Takes a string containing u-diff data and finds which files are affected
  //! by it.
  //! @returns
  //!   Returns an array of file names.
  {
    array(string) res = ({ });
    
    if (patch_data)
    {
      // Check for Windows line breaks.
      patch_data = replace(patch_data, "\r\n", "\n");
      // Split on "@@" and then on newline to find file name.
      foreach(patch_data / "@@\n", string chunk)
      {
	array(string) line = chunk / "\n";
	if (sizeof(line) > 1 &&
	    sscanf(line[-2], "+++ %s\t", string fname))
	{
	  res += ({ fname });
	}
      }
    }
    return res;
  }
}
