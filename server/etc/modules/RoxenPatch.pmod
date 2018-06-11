
import Parser.XML.Tree;
import String;
import Stdio;

constant rxp_version = "1.1";
//! The latest supported version of the rxp fileformat.

constant known_flags = ([ "restart" : "Need to restart server" ]);
//! All flags that are supported by the rxp fileformat.

// NB: Platforms added here also need to be added to the test patch
//     etc/test/tests/patcher/2009-02-25T1124.rxp.
constant known_platforms = (< "macosx_ppc32", 
			      "macosx_x86",
			      "macosx_x86_64",
			      "rhel4_x86",
			      "rhel4_x86_64",
			      "rhel5_x86",
			      "rhel5_x86_64",
			      "rhel6_x86_64",
			      "rhel7_x86_64",
			      "ubuntu1604_x86_64",
			      "ubuntu1804_x86_64",
			      "sol10_x86_64",
			      "sol11_x86_64",
			      "win32_x86",
			      "win32_x86_64",
>);

//! All currently supported subfeatures.
constant features = (<
  "pike-support",		// Support patching master.pike.in and
				// removal of .o-files, etc.
  "file-modes",			// Support patching and restoring of
				// files with eg the exec bit set (broken).
  "file-modes-2",		// Support patching and restoring of
				// files with eg the exec bit set.
  "force-new",			// Support new for files that already exist.
>);

constant RXP_ACTION_URL = "https://extranet.roxen.com/rxp/action.html";
//! URL for fetching rxp clusters.

//! Contains the patchdata
//! 
class PatchObject(string|void id
		  //! Taken from filename.
		  )
{
  string name;
  //! "name" field in the metadata block

  string description;
  //! "description" field in the metadata block

  string originator;
  //! "originator" field in the metadata block

  string rxp_version;
  //! File format version.

  array(string) platform = ({});
  //! An array of all "platform" fields in the metadata block.

  array(string) version = ({});
  //! An array of all "version" fields in the metadata block.

  array(string) depends = ({});
  //! An array of all "depends" fields in the metadata block.

  multiset(string) flags = (<>);
  //! A multiset of active flags

  array(string) reload = ({});
  //! An array of all "reload" fields in the metadata block.

  array(mapping(string:string)) new = ({});
  //! An array of all "new" fields in the metadata block.
  //! @array
  //!   @elem mapping(string:string) 0..
  //!     @mapping
  //!       @member string "source"
  //!       @member string "destination"
  //!       @member string "platform"
  //!       @member string "file-mode"
  //!     @endmapping
  //! @endarray

  array(mapping(string:string)) replace = ({});
  //! An array of all "replace" fields in the metadata block.
  //! @array
  //!   @elem mapping(string:string) 0..
  //!     @mapping
  //!       @member string "source"
  //!       @member string "destination"
  //!       @member string "platform"
  //!       @member string "file-mode"
  //!     @endmapping
  //! @endarray

  array(mapping(string:string|array(string))) patch = ({});
  //! An array of all "patch" fields in the metadata block.
  //! @array
  //!   @elem mapping(string:string|array(string)) 0..
  //!     @mapping
  //!       @member string "source"
  //!         Filename containing the patch data.
  //!       @member string "platform"
  //!         Platform.
  //!       @member array(string) "file_list"
  //!         Affected files. Not always present.
  //!     @endmapping
  //! @endarray

  array(mapping(string:string)) udiff = ({});
  //! An array with literal udiff data.
  //! @array
  //!   @elem mapping(string:string) 0..
  //!     @mapping
  //!       @member string "patch"
  //!         A string of udiff data.
  //!       @member string "platform"
  //!     @endmapping
  //! @endarray

  array(mapping(string:string)) delete = ({});
  //! An array of all "delete" fields in the metadata block.
  //! @array
  //!   @elem mapping(string:string) 0..
  //!     @mapping
  //!       @member string "destination"
  //!       @member string "platform"
  //!     @endmapping
  //! @endarray
}

#if !constant(Privs)
protected class Privs(string reason, int|string|void uid, int|string|void gid)
{}
#endif

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
//! This is for utils of MSYS that need /c/ instead of c:\.
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

  private string dist_version = "";
  //! Dist version extracted from server/VERSION.DIST

  private string server_platform = "";
  //! The current platform. This should map to the platforms for which we build
  //! Roxen and is taken from [server_path]/OS.

  private string product_code = "";
  //! The roxen product: 'rep', 'cms' or 'webserver'.

  private string tar_bin = "tar";
  private string patch_bin = "patch";
  //! Command for the external executable.

  function(string, mixed...:void) write_mess;
  //! Callback function for status messages. Should take a string as argument
  //! and return void.

  function(string, mixed...:void) write_err;
  //! Callback function for error messages. Should take a string as argument
  //! and return void.

  private Regexp patchid_regexp = Regexp(
    "((19|20)[0-9][0-9]-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])T"
    "([01][0-9]|2[0-3])([0-6][0-9])*)");
  //! The format regexp for patch IDs.
  //! ie currently on the format @expr{YYYY-MM-DDThhmmss@}.
  //!
  //! @note
  //!   Old patchids were on the format @expr{YYYY-MM-DDThhmm@}.
  //!   Matching and extraction of these MUST still be supported.

  //! ETag for the latest fetched cluster.
  private string http_cluster_etag;

  //! Last modified header for the latest fetched cluster.
  private string http_cluster_last_modified;

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
      error("Cannot access server dir!\n");
    
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
	error("Can't access import dir!\n");
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
	error("Can't access installed dir!\n");
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
      error("Cannot access " + version_h + "\n");

    object err = catch
    {
      program ver = compile_file(version_h);
      server_version = ver->roxen_ver + "." + ver->roxen_build;
    };
    
    if (err)
      error("Can't fetch server version.\n");

    write_mess("Server version ... <green>%s</green>\n", server_version);

    // Set dist version
    dist_version = 
      (replace(Stdio.read_bytes("VERSION.DIST"), "\r", "\n") / "\n")[0];

    write_mess("Dist version ... <green>%s</green>\n", dist_version);

    // Set current platform
    string os_file = combine_path(server_path, "OS");
    if (is_file(os_file))
      server_platform = trim_all_whites(read_file(os_file));
    else
      server_platform = "unknown";
    write_mess("Platform ... <green>%s</green>\n", server_platform);

#if constant(roxen_product_code)
    // Added by roxenloader.pike when starting roxen
    product_code = roxen_product_code;
#else 
    // When invoked via the command line, we need to find the
    // product code ourselves.
    //
    // FIXME: is there a better way to do this? Currently this
    //        mimics roxenloader.pike.
    {
      string modules_path = combine_path(server_path, "modules");
      string packages_path = combine_path(server_path, "packages");

      int roxen_is_cms = !!file_stat(combine_path(modules_path, "sitebuilder")) ||
	!!file_stat(combine_path(packages_path, "sitebuilder"));
      
      if(roxen_is_cms) {
	if (file_stat(combine_path(modules_path, "print")) || 
	    file_stat(combine_path(packages_path, "print"))) {
	  product_code = "rep";
	} else {
	  product_code = "cms";
	}
      } else {
	product_code = "webserver";
      }
    }
#endif

    write_mess("Product code ... <green>%s</green>\n", product_code);
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

  array(int|string) import_file(string path, void|int(0..1) dry_run)
  //! Copies the file at @tt{path@} to the directory of imported patches.
  //! It will check if the file exists and that its name contains a valid
  //! patch id. 
  //! If the file at @tt{path@} is a tar file, the enclosed rxp files will
  //! be extracted first and each of them will be imported.
  //! @returns
  //!    Returns an array with one entry per patch containing:
  //!      - The imported patch id if the import was successful, or:
  //!      - 0 if the patch import failed, or:
  //!      - 1 if the patch was already installed.
  //!    TO DO: Check the id inside the file so it matches the id in the
  //!    file name.
  {
    // Check if the file exists
    if (!is_file(path))
    {
      write_err("<b>%s</b> could not be found!\n", path);
      return ({ 0 });
    }
    
    int is_tar, is_tar_gz;
    if (glob("*.tar", lower_case(path)))
      is_tar = 1;
    else if (glob("*.tar.gz", lower_case(path)) || 
	     glob("*.tgz", lower_case(path)))
      is_tar_gz = 1;

    array(string) rxp_paths = ({});
    string target_tmp_dir;

    if (is_tar || is_tar_gz) {
      // Assuming the tar/tar.gz file is not an rxp file but a
      // container of multiple rxp files

      target_tmp_dir = combine_path(get_temp_dir(), "rxps");
      mkdir(target_tmp_dir);
      extract_tar_archive(path, target_tmp_dir, is_tar ? 0 : 1);

      // Find rxp files recursively
      rxp_paths = lambda(string dirpath) {
		    array(string) rxps = ({});
		    foreach(get_dir(dirpath), string dp) {
		      string fullpath = combine_path(dirpath, dp);
		      if (Stdio.is_file(fullpath))
			rxps += ({ fullpath });
		      else
			rxps += this_function(fullpath);
		    }
		    return rxps;
		  } (target_tmp_dir);

      if (sizeof(rxp_paths) > 1)
	write_mess("Extracted multiple patch files from tar file.\n");

    } else {
      rxp_paths = ({ path });
    }

    array(int|string) patch_ids = ({});
    foreach(rxp_paths, string rxp_path) {
      string patch_id = extract_id_from_filename(basename(rxp_path));
      if (!patch_id) {
	write_err("<b>%s</b> is not a valid rxp package!\n", rxp_path);
	patch_ids += ({ 0 });
	continue;
      }
      
      // Check if it's installed already.
      if (is_installed(patch_id)) {
	write_mess("Patch %s is already installed.\n", patch_id);
	patch_ids += ({ -1 });
	continue;
      }
   
      PatchObject po = extract_patch(rxp_path, import_path, dry_run);
      if (po)
	patch_ids += ({ po->id });
      else
	patch_ids += ({ 0 });
    }

    if (target_tmp_dir)
      clean_up(target_tmp_dir, 1);

    return patch_ids;
  }

  array(int|string) import_file_http()
  //! Fetch the latest rxp cluster from www.roxen.com and import the patches.
  {
    mapping file;

    mixed err = catch {
	file = fetch_latest_rxp_cluster_file();
      };
    if (err) {
      write_err("HTTPS import failed: %s\n", describe_backtrace(err));
      write_mess("No patches were imported.\n");
      return 0;
    }
    if (!file) {
      // Already fetched and imported.
      return ({});
    }

    write_mess("Fetched rxp cluster file %s over HTTPS.\n", file->name);

    string temp_dir = Stdio.append_path(get_temp_dir(), file->name);

    Privs privs = Privs("RoxenPatch: Saving downloaded patch cluster...");
    // Extra directory level to get rid of the sticky bit normally
    // present on /tmp/ that would require Privs for clean_up to work.
    mkdir(temp_dir);
    string temp_file = Stdio.append_path(temp_dir, file->name);   
    write_file_to_disk(temp_file, file->data);
    privs = 0;

    array(int|string) patch_ids = import_file(temp_file);
    clean_up(temp_dir);

    return patch_ids;
  }

  int(0..1) install_patch(string patch_id, 
			  string user, 
			  void|int(0..1) dry_run,
			  void|int(0..1) force)
  //! Install a patch. Patch must be imported.
  //! @returns
  //!   Returns 1 if the patch was successfully installed, otherwise 0
  {
    Privs privs;
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
      Privs privs = Privs("RoxenPatch: Rollback");
      if(dry_run)
	rm(backup_file);
      else
      {
	if (sizeof(new_files))
	  foreach(new_files, string file)
	    rm(file);
	privs = 0;

	if (is_file(backup_file)) {
	  write_log(1, "Restoring backed up files ... ");
	  if (extract_tar_archive(backup_file, server_path))
	  {
	    write_log(0, "<green>ok</green>.\n");
	    Privs privs = Privs("RoxenPatch: Rollback");
	    rm(backup_file);
	    privs = 0;
	  }
	  else
	    write_log(1, "FAILED! Backup needs to be restored manually "
			 "from <u>%s</u>\n", backup_file);
	}

	privs = Privs("RoxenPatch: Write to logfile: " + log_path);
	write_file(log_path, log);
	privs = 0;

	write_err("Writing log to <u>%s</u>\n", log_path);
      }
    };

    int post_process_path(string path, mapping(string:string) file) {
      if (!has_prefix(path, server_path)) return 1;
      string dest = path[sizeof(server_path)..];
      if (has_prefix(dest, "/")) dest = dest[1..];
      if (has_prefix(dest, "pike/lib/")) {
	if (is_file(path + ".o")) {
	  write_log(0, "Removing file <u>%s</u> ... ", path + ".o");
	  write_log(0, "Backing up <u>%s</u> to <u>%s</u> ... ",
		    path + ".o",
		    basename(backup_file));

	  if (add_file_to_tar_archive(dest + ".o",
				      server_path,
				      backup_file))
	    write_log(0, "<green>ok.</green>\n");
	  else
	  {
	    write_err("FAILED: Could not append tar file!\n");
	    error_count++;
	    if (!force) return 0;
	  }
	  Privs privs = Privs("RoxenPatch: Remove file: " + path + ".o");
	  if (!dry_run) {
	    if (rm(path + ".o"))
	    {
	      write_log(0, "<green>ok.</green>\n");
	    } else {
	      write_err("FAILED: Could not remove file.\n");
	      error_count++;
	      if (!force) return 0;
	    }
	  }
	  privs = 0;
	}

	if (has_suffix(path, "/master.pike.in")) {
	  string master = path[..sizeof(path)-4];
	  write_log(0, "New Pike master file <u>%s</u> ... ", master);
	  if (is_file(master)) {
	    write_log(0, "Backing up <u>%s</u> to <u>%s</u> ... ",
		      master, basename(backup_file));

	    if (add_file_to_tar_archive(dest[..sizeof(dest)-4],
					server_path,
					backup_file))
	      write_log(0, "<green>ok.</green>\n");
	    else
	    {
	      write_err("FAILED: Could not append tar file!\n");
	      error_count++;
	      if (!force) return 0;
	    }
	  }
	  if (!dry_run) {
	    string data = Stdio.read_bytes(path);
	    string libdir = dirname(master);
	    string cflags = predef::master()->cflags||"#cflags#";
	    string ldflags = predef::master()->ldflags||"#ldflags#";
	    string incdir = append_path(dirname(libdir), "include");
	    string docdir = append_path(dirname(libdir), "doc");

	    string cppflags = " -I" + dirname(incdir);
	    if (has_suffix(cflags, cppflags)) {
	      // The default master appends this to cflags,
	      // so we need to remove it here.
	      cflags = cflags[..sizeof(cflags) - (sizeof(cppflags)+1)];
	    }

	    data = replace(data, ({
			     "#lib_prefix#",
			     "#share_prefix#",
			     "#cflags#",
			     "#ldflags#",
			     "#include_prefix#",
			     "#doc_prefix#",
			   }), ({
			     libdir,
			     "#share_prefix#",
			     cflags,
			     ldflags,
			     incdir,
			     docdir,
			   }));
	    Privs privs = Privs("RoxenPatch: Updating master " + master);
	    if (catch {
		Stdio.write_file(master, data);
	      }) {
	      privs = 0;
	      write_err("FAILED: Could not write file.\n");
	      error_count++;
	      if (!force) return 0;
	    }
	    privs = 0;
	    write_log(0, "<green>ok.</green>\n");

	    // NB: Clean the .o-file for the master.
	    return post_process_path(master, file);
	  }
	}
      }
      // Done.
      return 1;
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
    if (sizeof(ptchdata->platform || ({})))
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
    if (sizeof(ptchdata->version || ({})))
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
      foreach(ptchdata->depends, string patch_id_list)
      {
	array(string) patch_ids;
	if (ptchdata->rxp_version > "1.0") {
	  patch_ids = patch_id_list/"|";
	} else {
	  patch_ids = ({ patch_id_list });
	}
	int missing = 1;
	foreach(patch_ids, string patch_id) {
	  if (is_installed(patch_id, ptchdata->rxp_version > "1.0")) {
	    missing = 0;
	    break;
	  }
	}
	if (missing) {
	  if (sizeof(patch_ids) > 1) {
	    if (!error) {
	      write_log(1, "FAILED:\nNone of <b>%s</b> are installed!\n",
			patch_id_list);
	    } else {
	      write_log(1, "Neither are any of <b>%s</b> installed.\n",
			patch_id_list);
	    }
	  } else {
	    if (!error) {
	      write_log(1, "FAILED:\n<b>%s</b> is not installed!\n",
			patch_id_list);
	    } else {
	      write_log(1, "<b>%s</b> is not installed either!\n",
			patch_id_list);
	    }
	  }
	  error_count++;
	  error = 1;
	}
      }
      if (error && !force)
      {
	privs = Privs("RoxenPatch: Write to logfile: " + log_path);
	write_file(log_path, string_to_utf8(log));
	privs = 0;
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
	if ((file->platform || server_platform) != server_platform) {
	  continue;
	}
	string source = append_path(source_path, file->source);
	string dest = append_path(server_path, file->destination);
	write_log(0, "Writing new file <u>%s</u> ... ", dest);
	
	// Check if it already exists
	if(!file_stat(dest))
	{
	  // Check if the path exists or if we need to create it.
	  // Ignore if we are doing a dry run.
	  string path = dirname(dest);
	  if (!dry_run && !is_dir(path)) {
	    privs = Privs("RoxenPatch: Create target directory: " + path);
	    if(!mkdirhier(path))
	    {
	      privs = 0;
	      write_log(1, "FAILED: Could not create target directory.\n");
	      error_count++;
	      if (!force)
	      {
		undo_changes_and_dump_log_to_file();
		return 0;
	      }
	    }
	    privs = 0;
	  }
	}
	else
	{
	  if (file->force) {
	    write_log(0, "FORCE: File <b>%s</b> already exists.\n", dest);
	  } else {
	    write_log(1, "FAILED: File exists\n");
	    error_count++;
	  }
	  if (file->force || force)
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
	privs = Privs(sprintf("RoxenPatch: Copy file %O -> %O", source, dest));
	if (!dry_run && cp(source, dest))
	{
	  // Set correct mtime - if possible.
	  Stat fstat = file_stat(source);
	  
	  if(fstat) {
	    if (file["file-mode"]) {
	      chmod(dest, array_sscanf(file["file-mode"], "%O")[0] & 0777);
	    } else {
	      chmod(dest, fstat->mode & 0777);
	    }
	    System.utime(dest, fstat->atime, fstat->mtime);
	  }
	  privs = 0;
	  write_log(0, "<green>ok.</green>\n");
	  new_files += ({ dest });

	  if (!post_process_path(dest, file)) {
	    undo_changes_and_dump_log_to_file();
	    return 0;
	  }
	}
	else if (!dry_run)
	{
	  privs = 0;
	  write_log(1, "FAILED: Could not write file.\n");
	  error_count++;
	  if (!force)
	  {
	    undo_changes_and_dump_log_to_file();
	    return 0;
	  }
	}
	privs = 0;
      }
    }

    // Handle files to be replaced
    if (ptchdata->replace)
    {
      foreach (ptchdata->replace, mapping file)
      {
	if ((file->platform || server_platform) != server_platform) {
	  continue;
	}
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
	  privs = Privs("RoxenPatch: Replace file \"" + source + "\" -> \"" + dest + "\"");
	  if (!dry_run && cp(source, dest))
	  {
	    // Set correct mtime - if possible.
	    Stat fstat = file_stat(source);

	    if(fstat) {
	      if (file["file-mode"]) {
		chmod(dest, array_sscanf(file["file-mode"], "%O")[0] & 0777);
	      } else {
		chmod(dest, fstat->mode & 0777);
	      }
	      System.utime(dest, fstat->atime, fstat->mtime);
	    }
	    privs = 0;
	    write_log(0, "<green>ok.</green>\n");

	    if (!post_process_path(dest, file)) {
	      undo_changes_and_dump_log_to_file();
	      return 0;
	    }
	  }
	  else if (!dry_run)
	  {
	    privs = 0;
	    write_log(1, "FAILED: Could not write file.\n");
	    error_count++;
	    if (!force)
	    {
	      undo_changes_and_dump_log_to_file();
	      return 0;
	    }
	  }
	  else {
	    privs = 0;
	    write_log(0, "<green>ok.</green>\n");
	  }
	}
	else
	{
	  write_log(1, "FAILED: File to be overwritten doesn't exist.\n");
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
      foreach (ptchdata->delete, mapping(string:string) del_info)
      {
	if ((del_info->platform || server_platform) != server_platform) {
	  continue;
	}
	string dest = append_path(server_path, del_info->destination);
	write_log(0, "Removing file <u>%s</u> ... ", dest);
	
	// Make sure that the destination already exists
	if(is_file(dest))
	{
	  // Backup the original file to a tar_archive
	  write_log(0, "Backing up <u>%s</u> to <u>%s</u> ... ",
		    dest, 
		    basename(backup_file));

	  if (add_file_to_tar_archive(del_info->destination,
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
	  privs = Privs("RoxenPatch: Remove file: " + dest);
	  if (!dry_run && rm(dest))
	  {
	    write_log(0, "<green>ok.</green>\n");

	    if (!post_process_path(dest, del_info)) {
	      undo_changes_and_dump_log_to_file();
	      return 0;
	    }
	  }
	  else if (!dry_run)
	  {
	    write_log(1, "FAILED: Could not remove file.\n");
	    error_count++;
	    if (!force)
	    {
	      privs = 0;
	      undo_changes_and_dump_log_to_file();
	      return 0;
	    }
	  }
	  privs = 0;
	}
	else
	{
	  write_log(1, "FAILED: File to be removed doesn't exist.\n");
	  error_count++;
	  // This is not a fatal error so we'll just continue.
	}
      }
    }

    // Handle files to be patched
    if (ptchdata->patch)
    {
      int error = 0;
      
      foreach (ptchdata->patch, mapping(string:string) patch_info)
      {
	if ((patch_info->platform || server_platform) != server_platform) {
	  continue;
	}
	string file = patch_info->source;
	File udiff_data = File(append_path(source_path, file));
	string udiff = udiff_data->read();

	// Backup files
	foreach(lsdiff(udiff), string affected_file)
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
	privs = 0;
	
	// Patch file.
	write_log(0, "Applying patch ... ");
	udiff_data->seek(0); // Start from the beginning of the file again.

	array args = ({ patch_bin,
			"-p0",
#ifdef __NT__
			// Make sure that patch doesn't mess around
			// with EOL (cf [bug 7244]).
			"--binary",
#endif
			// Reject file
// 			"--global-reject-file=" +
// 			   append_path(source_path, "rejects"),
			"-d", combine_path(getcwd(), server_path) });
	
	if (dry_run) 
	  args += ({ "--dry-run" });

	Privs privs = Privs(sprintf("RoxenPatch: Spawning %O.", patch_bin));
	Process.Process p = 
	  Process.Process(args, 
			  ([ 
			    "cwd"   : server_path, 
			    "stdin" : udiff_data 
			  ]));
	privs = 0;

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

	if (!error) {
	  write_log(0, "<green>ok.</green>\n");

	  if (!dry_run) {
	    foreach(lsdiff(udiff), string affected_file) {
	      if (!post_process_path(append_path(server_path, affected_file),
				     patch_info)) {
		undo_changes_and_dump_log_to_file();
		return 0;
	      }
	    }
	  }
	}
      }
    }
    
    // Move dir
    if (!dry_run)
    {
      write_log(0, "Moving patch files ...");
      string dest_path = combine_path(installed_path,
				      basename(source_path));
      privs = Privs("RoxenPatch: Move patch files");
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
      privs = 0;

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
    privs = Privs("RoxenPatch: Cleanup");
    if (dry_run)
      rm(backup_file);
    else
    {
      write_mess("Writing log file to <u>%s</u>\n", log_path);
      write_file(log_path, string_to_utf8(log));
    }
    privs = 0;

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
    Privs privs;

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
      foreach(metadata->new, mapping(string:string) file)
      {
	if ((file->platform || server_platform) != server_platform) {
	  continue;
	}
	string filename = file->destination;
	write_mess("Removing %s ... ", append_path(server_path, filename));
	privs = Privs("RoxenPatch: Removing created files.");
	if(rm(append_path(server_path, filename)))
	  write_mess("<green>Done!</green>\n");
	else
	{
	  write_err("FAILED!\n");
	  errors++;
	}
	privs = 0;
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
    privs = Privs("RoxenPatch: Moving patch files.");
    if (Stdio.recursive_mv(append_path(installed_path, id), dest_path)) {
      privs = 0;
      write_mess("<green>Done!</green>\n");
    } else {
      privs = 0;
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
    privs = Privs("RoxenPatch: Creating installation.log file.");
    write_file(append_path(dest_path, "installation.log"), string_to_utf8(log));
    privs = 0;
    return 1;
  }

  int(0..1) remove_patch(string patch_id, string user) 
  //! Removes an imported patch from disk.
  //! @returns
  //!   Returns 1 if the patch was successfully removed, otherwise 0
  {
    string path = id_to_filepath(patch_id);
    if (!path) {
      return 0;
    }
    
    Privs privs = Privs("RoxenPatch: Remove patch " + patch_id + ", " + sprintf("%O", path));
    if (!Stdio.recursive_rm(path)) {
      privs = 0;
      write_err(sprintf("Failed to remove patch %s from disk. "
			"Not enough privileges?\n", patch_id));
      return 0;
    }
    privs = 0;

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
  //!     @member PatchObject "metadata"
  //!       Metadata block as returned from parse_metadata()
  //!   @endmapping
  {
    mapping res = ([ ]);
    string file_path = id_to_filepath(id);
    
    if (!(file_path && sizeof(file_path)))
      return ([
	"metadata" : PatchObject(id),
	"status" : "unknown",
      ]);

    // Get metadata
    if (is_file(append_path(file_path, "metadata")))
    {
      string md = read_file(append_path(file_path, "metadata"));
      res->metadata = parse_metadata(md, id);
    }
    else
      return ([
	"metadata" : PatchObject(id),
	"status" : "unknown"
      ]);

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
    PatchObject p = PatchObject(patchid);
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
      mapping(string:string) attrs = node->get_attributes();

      switch(name)
      {
      case "flag":
	// Check if we have a flag and if that flag is on or off.
	if (attrs->name && (tag_content != "false") && (tag_content != "0")) {
	  p->flags += (< attrs->name >);
	}
	break;
      case "patch":
	if (attrs->source) {
	  p->patch += ({ attrs });
	}
	break;
      case "name":
	p->name = tag_content;
	break;
      case "description":
	switch (attrs->type) {
	default:
	case "text/plain":
	  // Trim initial and trailing white space.
	  p->description = String.trim_all_whites(tag_content);
	  break;
	  case 0:
	  // Old-style.
	  // All formatting (if any) was destroyed when the patch was created.
	  p->description = trim_ALL_redundant_whites(tag_content);
	  break;
	}
	break;
      case "originator":
	p->originator = tag_content;
	break;
      case "delete":
      case "new":
      case "replace":
	if (sizeof(attrs)) {
	  if (!p[name]) p[name] = ({});
	  attrs->destination = attrs->destination || tag_content;
	  p[name] += ({ attrs });
	}
	break;
      default:
	if (sizeof(attrs)) {
	  if (!p[name]) p[name] = ({});
	  foreach(attrs; string i; string v) {
	    // FIXME: Why?
	    p[name] += ({ ([i:v]) });
	  }
	  break;
	}
	p[name] += ({ tag_content });
	break;
      }
    }
    
    if (!verify_patch_object(p, 1 /* Silent mode */))
      return 0;

    return p;  
  }

  mapping(string:string|mapping(string:mixed)) describe_installed_patch(string id)
  //! Describe a single installed patch given its patch id.
  //!
  //! @returns
  //!   Returns @expr{0@} (zero) for uninstalled or broken patches.
  //!   Otherwise a mapping with the following content:
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
  //!     @member PatchObject "metadata"
  //!       Metadata block as returned from parse_metadata()
  //!   @endmapping
  //!
  //!  Entries are sorted by patch ID in reverse alphabetical order, i.e.
  //!  newest patch first since IDs are by convention ISO timestamps.
  {
    if (!is_dir(combine_path(installed_path, id))) return 0;

    // Get installation log
    string install_log = append_path(installed_path,
				     id,
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
				id,
				"metadata");
    if (is_file(mdfile))
    {
      string mdblock = read_file(mdfile);
      po = parse_metadata(mdblock,
			  extract_id_from_filename(mdfile));

      return ([ "installed" : inst_date,
		"user"      : user,
		"metadata"  : po ]);
    }

    return 0;
  }

  mapping(string:string|mapping(string:mixed)) describe_imported_patch(string id)
  //! Describe a single imported patch given its patch id.
  //!
  //! @returns
  //!   Returns @expr{0@} (zero) for unimported or broken patches.
  //!   Otherwise a mapping with the following content:
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
  //!     @member mapping (string:int) "uninstalled"
  //!       Time of latest unistallation. This field is 0 unless the patch has
  //!       has been uninstalled.
  //!     @member string "uninstall_user"
  //!       User who uninstalled the patch. This field is usually 0.
  //!     @member PatchObject "metadata"
  //!       Metadata block as returned from parse_metadata()
  //!   @endmapping
  {
    if (!is_dir(combine_path(import_path, id))) return 0;

    // Get installation log
    string install_log = append_path(import_path,
				     id,
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
				id,
				"metadata");
    if (is_file(mdfile))
    {
      string mdblock = read_file(mdfile);
      po = parse_metadata(mdblock,
			  extract_id_from_filename(mdfile));

      return ([ "installed"		: inst_date,
		"user"		: inst_user,
		"uninstalled"	: uninst_date,
		"uninstall_user"	: uninst_user,
		"metadata"		: po ]);
    }

    return 0;
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
  //!     @member PatchObject "metadata"
  //!       Metadata block as returned from parse_metadata()
  //!   @endmapping
  {
    array(mapping(string:string|mapping(string:mixed))) res =
      filter(map(get_dir(installed_path) || ({ }), describe_installed_patch),
	     mappingp);

    //  Return in reverse chronological order, i.e. newest first
    return Array.sort_array(res, lambda (mapping a, mapping b)
				 {
				   return a->metadata->id < b->metadata->id;
				 }
			    );
  }

  array(mapping(string:string|mapping(string:int)|PatchObject)) file_list_imported()
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
  //!     @member mapping (string:int) "uninstalled"
  //!       Time of latest unistallation. This field is 0 unless the patch has
  //!       has been uninstalled.
  //!     @member string "uninstall_user"
  //!       User who uninstalled the patch. This field is usually 0.
  //!     @member PatchObject "metadata"
  //!       Metadata block as returned from parse_metadata()
  //!   @endmapping
  //!
  //!  Entries are sorted by patch ID in alphabetical order, i.e. oldest
  //!  patch first since IDs are by convention ISO timestamps.
  {
    array(mapping(string:string|mapping(string:mixed))) res =
      filter(map(get_dir(import_path) || ({ }),  describe_imported_patch),
	     mappingp);

    //  Return in chronological order, i.e. oldest first
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
      error("Couldn't set %s as path for installed patches.\n", installed_path);
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
    if (!is_dir(import_path))
      error("Couldn't set %s as path for imported patches.\n", import_path);
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
      error("Couldn't set a standard temp dir.\n");
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
    
    string desc = String.trim_all_whites(metadata->description);
    xml += sprintf("  <description type='text/plain'>\n%s\n  </description>\n",
		   html_encode(desc));
    
    xml += sprintf("  <originator>%s</originator>\n",
		   html_encode(metadata->originator));

    // Add feature dependency on file-modes-2 if used.
    foreach((metadata->new || ({})) +
	    (metadata->replace || ({})), mapping(string:string) f) {
      if (f["file-mode"]) {
	if (!has_value(metadata->depends, "roxenpatch/file-modes-2")) {
	  metadata->depends += ({ "roxenpatch/file-modes-2" });
	}
	break;
      }
    }

    array valid_tags = ({ "version", "platform", "depends", "flags", "reload",
			  "patch", "new", "replace", "delete" });

    foreach(valid_tags, string tag_name)
    {
      if(metadata[tag_name] && sizeof(metadata[tag_name]))
      {
	if (tag_name == "flags")
	{
	  foreach(indices(known_flags), string s)
	    xml += sprintf("  <flag name=\"%s\">%s</flag>\n",
			   s, (metadata->flags[s]) ? "true" : "false");
	}
	else if (tag_name == "patch")
	{
	  foreach(metadata->patch, mapping(string:string) patch_info)
	    xml += sprintf("  <patch source=\"%s\" />\n", patch_info->source);
	}
	else if (mappingp(metadata[tag_name][0]))
	{
	  // array(mapping) -- eg new, replace & delete.
	  foreach(metadata[tag_name], mapping m) {
	    if (m->source) {
	      xml += sprintf("  <%s source=\"%s\"%s>%s</%s>\n",
			     tag_name,
			     m->source,
			     m["file-mode"]?
			     (" file-mode=\"" + m["file-mode"] + "\""):"",
			     m->destination,
			     tag_name);
	    } else {
	      xml += sprintf("  <%s%s>%s</%s>\n",
			     tag_name,
			     m["file-mode"]?
			     (" file-mode=\"" + m["file-mode"] + "\""):"",
			     m->destination,
			     tag_name);
	    }
	  }
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
				   lambda (string id, string rxp_version)
				   {
				     array(string) ids;
				     if (rxp_version > "1.0") {
				       ids = id/"|";
				     } else {
				       ids = ({ id });
				     }
				     foreach(ids, id) {
				       if (is_installed(id,
							rxp_version > "1.0") ||
					   pretend_installed[id]) {
					 return 0;
				       }
				     }
				     return 1;
				   },
				   po->rxp_version
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

    if (!destination_path) destination_path = getcwd();
    string dest =
      unixify_path(combine_path(destination_path || getcwd(), id + ".rxp"));
    write_mess("Creating rxp file %s ... ", dest);
    Stdio.File rxpfile = Stdio.File();
    if (!rxpfile->open(dest, "wbct")) {
      write_err("FAILED: Could not create %s: %s\n",
		dest, strerror(rxpfile->errno()));
      return 0;
    }
    write_mess("<green>Done!</green>\n");

    int mtime = dwim_time(id);
    Gz.File gzfile = Gz.File(rxpfile, "wb");
    mapping(string:string) tared_files = ([]);

    if (!add_dir_to_rxp(gzfile, id, mtime)) {
      return 0;
    }

    // Copy the files to the temp dir:
    if (metadata->patch)
      foreach(metadata->patch, mapping m)
      {
	if ((m->platform || server_platform) != server_platform) {
	  continue;
	}
	// Package the string nicely:
	if (!add_file_to_rxp(gzfile, m, id, tared_files))
	{
	  return 0;
	}
      }

    if (metadata->replace)
      foreach(metadata->replace, mapping m) {
	if ((m->platform || server_platform) != server_platform) {
	  continue;
	}
	if (!add_file_to_rxp(gzfile, m, id, tared_files))
	{
	  return 0;
	}
      }

    if (metadata->new)
      foreach(metadata->new, mapping m) {
	if ((m->platform || server_platform) != server_platform) {
	  continue;
	}
	if (!add_file_to_rxp(gzfile, m, id, tared_files))
	{
	  return 0;
	}
      }

    // If we for some reason have any unified diffs then we need to write them
    // down to a file as well.
    if (metadata->udiff)
    {
      foreach(metadata->udiff; int i; mapping(string:string) udiff) {
	string out_filename = sprintf("patchdata-%04d.patch", i);

	if (!add_blob_to_rxp(gzfile, udiff->patch, id + "/" + out_filename,
			     mtime)) {
	  return 0;
	}

	// Update the patch object with a pointer to the file and discard the
	// udiff block; it's not needed anymore.
	metadata->patch += ({ ([ "source": out_filename ]) });
	if (udiff->platform) {
	  metadata->patch[-1]->platform = udiff->platform;
	}
      }
      metadata->udiff = 0;
    }

    string mdxml = build_metadata_block(metadata);

    if (!add_blob_to_rxp(gzfile, mdxml, id + "/metadata", mtime)) {
      return 0;
    }

    if (!finish_rxp(gzfile)) {
      return 0;
    }

    write_mess("Patch created successfully!\n");

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
    if (res && dry_run) {
      // We need to populate the list of affected files here,
      // since we're about to delete the relevant information.
      foreach(res->patch, mapping(string:string|array(string)) item) {
	item->file_list = lsdiff(Stdio.read_file(combine_path(target_dir,
							      patchid,
							      item->source)));
      }
    }
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

  int(0..1) is_installed(string id, int|void allow_versioned)
  //! Check if a patch is installed.
  //! @returns
  //!   Returns 1 if a patch is installed, 0 otherwise
  {
    if(!patchid_regexp->match(id))
    {
      array(string) path = id/"/";
      if ((sizeof(path) == 2) && allow_versioned) {
	// Package/VERSION
	string installed;
	if (path[0] == "roxen") {
	  installed = Stdio.read_bytes(combine_path(server_path, "VERSION"));
	} else if (path[0] == "pike") {
	  string headerfile =
	    Stdio.read_bytes(combine_path(server_path,
					  "pike/include/version.h")) ||
	    Stdio.read_bytes(combine_path(server_path,
					  "pike/include/pike/version.h"));
	  if (headerfile) {
	    /* Filter everything but cpp-directives. */
	    headerfile = filter(headerfile/"\n", has_prefix, "#")*"\n" + "\n";
	    catch {
	      installed =
		compile_string(headerfile +
			       "constant ver = PIKE_MAJOR_VERSION + \".\" +\n"
			       "               PIKE_MINOR_VERSION + \".\" +\n"
			       "               PIKE_BUILD_VERSION;\n")->ver;
	    };
	  }
	} else if (path[0] == "roxenpatch") {
	  /* RoxenPatch feature dependency.
	   *
	   * These are used to force a too old RoxenPatch to fail,
	   * but still allow the patch to be imported. This is to
	   * ensure that implicit side effects (like eg patching
	   * master.pike) will be performed when the patch is applied.
	   */
	  return features[path[1]];
	} else {
	  installed =
	    Stdio.read_bytes(combine_path(server_path, "packages",
					  path[0], "VERSION")) ||
	    Stdio.read_bytes(combine_path(server_path, "modules",
					  path[0], "VERSION"));
	}
	if (!installed) return 0;
	installed -= "\n";
	installed -= "\r";
	return installed == path[1];
      }
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
    if (!silent)
      write_err("Not found on disk.\n");

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
  //! If the source path is known, it may be specified explicitly
  //! by prefixing the destination path with the source path and
  //! a colon: @expr{"path/to/source:destination/path"@}.
  //!
  //! If the raw path contains a glob then it will try to find all source files
  //! matching that glob.
  {
    array(string) a = raw_path/":";
    if ((sizeof(a) > 1) && Stdio.exist(a[0])) {
      return ({ ([ "source" : a[0],
		   "destination" : a[1..] * ":",
		]) });
    }

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

  int(0..1) verify_patch_id(string patch_id, int|void allow_versioned)
  //! Takes a string and verifies that it is a correctly formated patch id.
  {
    if (extract_id_from_filename(patch_id) == patch_id) return 1;
    if (!allow_versioned) return 0;
    return sizeof(patch_id/"/") == 2;
  }

  int(0..1) verify_patch_object(PatchObject ptc_obj, void|int(0..1) silent)
  //! Returns 1 if ok, otherwise 0;
  {
    if (!silent)
      write_mess("Verifying metadata ... ");
    if (ptc_obj->rxp_version > rxp_version)
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
      foreach(ptc_obj->depends, string patch_id_list) {
	if (ptc_obj->rxp_version > "1.0") {
	  foreach(patch_id_list/"|", string patch_id)
	    if (!verify_patch_id(patch_id, 1))
	    {
	      if (!silent)
		write_err("FAILED: Dependency %s is not a valid patch id\n",
			patch_id);
	      return 0;
	    }
	} else {
	  if (!verify_patch_id(patch_id_list))
	  {
	    if (!silent)
	      write_err("FAILED: Dependency %s is not a valid patch id\n",
			patch_id_list);
	    return 0;
	  }
	}
      }

    if (ptc_obj->replace)
    {
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

    if (ptc_obj->delete)
    {
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

    Stat st = file_stat(full_path);
    if (st) {
      chmod(dest, st->mode & 0777);
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

    if(out_file->write(data) != sizeof(data))
    {
      write_err("FAILED: %s\n", strerror(errno()));
      return 0;
    }

    out_file->close();

    write_mess("<green>Done!</green>\n");
    return 1;
  }

  string create_id(void|object time)
  //! Create a string on the format @expr{YYYY-MM-DDThhmmss@}
  //! based on the current time.
  //!
  //! @note
  //!   Old patchids were on the format @expr{YYYY-MM-DDThhmm@}.
  {
    if (!time)
      time = Calendar.ISO->now();

    return time->format_ymd() + "T" + time->format_tod_short();
  }

  int dwim_time(string patchid)
  //! Get the number of seconds since the epoch for a patchid.
  {
    return Calendar.ISO.parse("%Y-%M-%DT%t", patchid)->unix_time();
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

  protected int(0..1) add_header_to_rxp(Gz.File rxp, string path,
					int mode, int uid, int gid, int sz,
					int mtime, int|void header_type)
  {
    string path_pad = "\0" * (100 - sizeof(path));
    string header = sprintf("%100s%06o \0%06o \0%06o \0%011o %011o ",
			    path + path_pad, mode, uid, gid, sz, mtime);
    int csum = `+(@((array(int))header), ' '*8);
    string check = sprintf("%06o\0 %c", csum + header_type, header_type);
    string pad = "\0" * (512 - (sizeof(header) + sizeof(check)));

    int bytes;
    bytes += rxp->write(header) - sizeof(header);
    bytes += rxp->write(check) - sizeof(check);
    bytes += rxp->write(pad) - sizeof(pad);
    return !bytes;
  }

  protected int(0..1) add_dir_to_rxp(Gz.File rxp, string path, int mtime)
  {
    if (!has_suffix(path, "/")) path += "/";
    write_mess("Archiving directory %s ... ", path);
    if (!add_header_to_rxp(rxp, path, 0755, 0, 0, 0, mtime, '5')) {
      write_err("FAILED: Failed to write tar header to rxp.\n");
      return 0;
    }
    write_mess("<green>Done!</green>\n");
    return 1;
  }

  protected int(0..1) add_blob_to_rxp(Gz.File rxp, string blob,
				      string path, int mtime, int|void mode)
  {
    write_mess("Archiving %s ... ", path);
    if (mode & 0111) {
      mode = 0755;
    } else {
      mode = 0644;
    }
    if (!add_header_to_rxp(rxp, path, mode, 0, 0, sizeof(blob), mtime)) {
      write_err("FAILED: Failed to write tar header to rxp.\n");
      return 0;
    }

    int bytes = rxp->write(blob) - sizeof(blob);
    if (sizeof(blob) & 511) {
      bytes += rxp->write("\0" * (512 - (sizeof(blob) & 511))) -
	(512 - (sizeof(blob) & 511));
    }
    if (bytes) {
      write_err("FAILED: Failed to write %d bytes.\n", -bytes);
      return 0;
    }
    write_mess("<green>Done!</green>\n");
    return 1;
  }

  protected int(0..1) add_file_to_rxp(Gz.File rxp, mapping m, string id,
				      mapping(string:string) tared_files)
  {
    string filename = basename(m->source);
    string full_path = combine_path(getcwd(), m->source);
    if (!sizeof(filename||"")) return 0;
    string dest = id + "/" + filename;
    if (tared_files[dest]) {
      // We need to search for a suitable destination filename.
      int n;
      for (n = 0; tared_files[dest + n]; n++)
	;
      dest += n;
      filename += n;
    }
    tared_files[dest] = full_path;
    m->source = filename;

    write_mess("Reading %s ... ", full_path);
    string data = Stdio.read_bytes(full_path);
    if (!data) {
      write_err("FAILED: Could not read file %s: %s\n",
		full_path, strerror(errno()));
      return 0;
    }
    write_mess("<green>Done!</green>\n");
    Stat st = file_stat(full_path);
    int mtime = st && st->mtime;
    int mode = st ? st->mode : 0644;
    if (mode & 0111) {
      // Propagate the file-mode to the meta data file.
      m["file-mode"] = "0755";
    }
    return add_blob_to_rxp(rxp, data, dest, mtime, mode);
  }

  protected int finish_rxp(Gz.File rxp)
  {
    write_mess("Finishing rxp ... ");
    int bytes = rxp->write("\0" * (512 * 2)) - 512 * 2;
    if (bytes) {
      write_err("FAILED: %d bytes remaining.\n", -bytes);
      return 0;
    }
    if (!rxp->close()) {
      write_err("FAILED: Close failed.\n");
      return 0;
    }
    write_mess("<green>Done!</green>\n");
    return 1;
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
  
    Privs privs =
      Privs(sprintf("RoxenPatch: Creating tar file %O.", dest));
    Process.Process p = Process.Process(args, ([ "cwd" : temp_path ]));
    privs = 0;
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

    string tar_path = combine_path(base_path, tar_archive);
    Privs privs;
    if (!Stdio.exist(tar_path)) {
      // Some versions of tar (eg Solaris) don't like creating new tar
      // files with "rf"...
      args[1] = "cf";
      privs = Privs(sprintf("RoxenPatch: Creating tar file %O.", tar_archive));
    } else {
      privs = Privs(sprintf("RoxenPatch: Appending to tar file %O.", tar_archive));
    }
    Process.Process p = Process.Process(args, ([ "cwd" : base_path ]));
    privs = 0;
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
	Privs privs =
	  Privs(sprintf("RoxenPatch: Extracting tar archive %O.", file_name));
	tarfs->tar->extract("", path, UNDEFINED,
			    Filesystem.Tar.EXTRACT_SKIP_EXT_MODE|
			    Filesystem.Tar.EXTRACT_SKIP_MTIME);
	privs = 0;
      }) {
      write_err("Extraction failed: %s\n", describe_backtrace(err));
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
      // Normalize line breaks.
      patch_data = replace(patch_data, "\r\n", "\n");
      // Split on "\n@@" to find the chunk headers.
      // Note that GIT-diff appends context information
      // after the second "@@" on the "@@"-line.
      foreach(patch_data / "\n@@", string chunk)
      {
	array(string) lines = chunk / "\n";
	// Look at the last line before the "@@"-line to find the filename.
	// Note that CVS-diff appends a tab and a timestamp after the filename.
	if (sizeof(lines) > 1 &&
	    sscanf(lines[-1], "+++ %[^\t]", string fname))
	{
	  res += ({ fname });
	}
      }
    }
    return res;
  }

  mapping(string:string) fetch_latest_rxp_cluster_file() {
    string get_url(Standards.URI uri, int|void use_etag)
    {
      string etag = use_etag && http_cluster_etag;
      string last_modified = use_etag && http_cluster_last_modified;
      string expected_sha1;

      if (use_etag) {
	// We use the query part of the URL to receive metadata information
	// about the patch from the server.
	mapping(string:string) variables = uri->get_query_variables();
	expected_sha1 = variables->sha1;

	// There's no need to send back the variables to the server.
	uri->set_query_variables(([]));
      }

      Protocols.HTTP.Query query = try_get_url(uri, 20, etag, last_modified);
      if ((query->status == 304) || (query->status == 412)) {
	return 0;
      }
      if (query->status != 200) {
	error("HTTPS request for URL %s failed with status %d: %s.\n",
	      (string)uri || "", query->status, query->status_desc || "");
      }
      if (use_etag) {
	http_cluster_etag = query->headers->etag;
	if ((http_cluster_last_modified = query->headers["last-modified"]) &&
	    query->headers["content-length"]) {
	  http_cluster_last_modified +=
	    "; length=" + query->headers["content-length"];
	}
      }
      string data = query->data();
      if (expected_sha1 &&
	  (Crypto.SHA1.hash(data) != String.hex2string(expected_sha1))) {
	error("SHA1 checksum mismatch for URL %s. Got: %s, expected: %s\n",
	      (string)uri,
	      String.string2hex(Crypto.SHA1.hash(data)), expected_sha1);
      }
      return data;
    };

    // If not running in a dist we can't fetch patches
    if (dist_version == "")
      error("Not running a proper distribution.\n");

    // Get rxp action url
    Standards.URI uri = Standards.URI(RXP_ACTION_URL);
    uri->add_query_variables(([ "product"  : product_code,
				"version"  : dist_version,
				"platform" : server_platform,
				"checksum" : "sha1",
				"action"   : "get-latest-rxp-cluster-url" ]));
    string res = get_url(uri);

    // Get rxp cluster url
    if (!res || !sizeof(res))
      error("No rxp cluster URL was found.\n");

    Standards.URI uri2 = Standards.URI(String.trim_all_whites(res), uri);
    if (uri2->scheme != "https")
      error("Fetch: Not HTTPS: %s\n", (string)uri2);
    string res2 = get_url(uri2, 1);

    if (!res2) {
      // Already fetched.
      return 0;
    }

    return ([ "data" : res2,
	      "name" : basename(uri2->path) ]);
  }

  Protocols.HTTP.Query try_get_url(Standards.URI uri, int timeout,
				   string|void etag, string|void last_modified)
  {
    write_mess("Preparing to fetch %s.\n", (string)uri);

    mapping(string:string) request_headers = ([]);

    if (etag) {
      request_headers["If-None-Match"] = etag;
    }
    if (last_modified) {
      request_headers["If-Modified-Since"] = last_modified;
    }
#if constant(roxenp)
    // NB: Use roxenp to access the roxen object since roxen hasn't
    //     been loaded when we are compiled.
    object roxen = roxenp();
    if (roxen && (this_thread() != roxen.backend_thread)) {
      // The backend thread is probably running and we are not it.
      Thread.Queue queue = Thread.Queue();
      object con = Protocols.HTTP.Query();
      con->timeout = timeout;

      // Hack to force do_async_method to not reset the timeout value
      con->headers = ([ "connection" : "keep-alive" ]);

      function cb = lambda() { queue->write("@"); };
      con->set_callbacks(lambda() { con->async_fetch(cb, cb); }, cb);

      if (uri->scheme == "https") {
	// Enable verification of the certificate chain.
	SSL.Context ctx = con->context = SSL.Context();
	ctx->trusted_issuers_cache = Standards.X509.load_authorities();
	if (sizeof(ctx->trusted_issuers_cache)) {
	  ctx->verify_certificates = 1;
	  ctx->require_trust = 1;
	  ctx->auth_level = SSL.Constants.AUTHLEVEL_require;
	} else {
	  write_err("Failed to find set of root certificate authorities.\n"
		    "Proceeding with certificate validation turned off.\n");
	  ctx->verify_certificates = 0;
	  ctx->require_trust = 0;
	  ctx->auth_level = SSL.Constants.AUTHLEVEL_none;
	}
      }

#ifdef ENABLE_OUTGOING_PROXY
      if (roxen.query("use_proxy")) {
	Protocols.HTTP.do_async_proxied_method(roxen.query("proxy_url"),
					       roxen.query("proxy_username"),
					       roxen.query("proxy_password"),
					       "GET", uri, 0,
					       request_headers, con);
      } else {
	Protocols.HTTP.do_async_method("GET", uri, 0, request_headers, con);
      }
#else
      Protocols.HTTP.do_async_method("GET", uri, 0, request_headers, con);
#endif
  
      queue->read();
  
      return con;
    }

    // FALLBACK to synchronous fetch.
#endif /* roxen */
    return Protocols.HTTP.get_url(uri, UNDEFINED, request_headers);
  }
}
