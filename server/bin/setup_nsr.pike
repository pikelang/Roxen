// $Id$
//
// Setup .nsr (Networker) files for logfile directories if appropriate.
// NOTE: We must be paranoid; we must not alter files that the user
//       has entered or changed!
//
// 2003-09-24 Henrik Grubbström

int verbose;

#define vwerror(ARGS ...) do { \
    if (verbose) werror(ARGS); \
  } while(0)

void update_nsr_file(string directory)
{
  vwerror("Checking for directory %O\n", directory);
  Stdio.Stat st = file_stat(directory);
  if (!st) {
    vwerror("Not found\n");
    return;
  }

  int this_rev = -1;
  if (sscanf("$Revision: 1.5 $", "$""Revision: 1.%d $", this_rev) != 1) {
    vwerror("Failed to parse own revision $Rev$\n");
    return;
  }

  string nsr_file = directory + "/.nsr";
  st = file_stat(nsr_file);
  if (st) {
    vwerror("nsr file %O exists.\n", nsr_file);
    // File exists. Check if it's an old unmodified file.
    string old_content = Stdio.read_file(nsr_file);
    if (!has_prefix(old_content, "# Roxen nsr-checksum:")) {
      vwerror("Bad prefix.\n");
      return;
    }
    array(string) lines = old_content/"\n";
    string csum;
    if (sscanf(old_content, "# Roxen nsr-checksum: %s\n%s",
	       csum, old_content) != 2) {
      vwerror("No checksum.\n");
      return;
    }
    if (String.string2hex(Crypto.MD5.hash(old_content)) != csum) {
      vwerror("Bad checksum.\n");
      return;
    }
    int rev = -1;
    if (sscanf(old_content, "# Roxen nsr-revision: 1.%d\n%s",
	       rev, old_content) != 2) {
      vwerror("Bad revision.\n");
      return;
    }
    if (this_rev <= rev) {
      vwerror("Already up to date.\n");
      return;
    }
    // The file seems to be an old version that we've generated.
  }
  // Generate the new nsrfile.
  vwerror("Generating new file %O\n", nsr_file);

  string new_content = sprintf(
#"# Roxen nsr-revision: 1.%d

# The output from the restart loop is named start_default.output.
+logasm: start_*.output

# Active debug log files are named default.1 or configurationdir.1
+logasm: *.1

# The default name for site logs is Log
+logasm: Log
", this_rev);
  Stdio.write_file(nsr_file,
		   sprintf("# Roxen nsr-checksum: %s\n"
			   "%s",
			   String.string2hex(Crypto.MD5.hash(new_content)),
			   new_content));
  write("Updated nsr file %O\n", nsr_file);
}

int main(int argc, array(string) argv)
{
  array(array(string)) opts = Getopt.find_all_options(argv, ({
    ({"logdir", Getopt.HAS_ARG, ({"--logdir"}) }),
    ({"debugdir", Getopt.HAS_ARG, ({"--debugdir"}) }),
    ({"verbose", Getopt.NO_ARG, ({"-v", "--verbose"}) }),
    ({"version", Getopt.NO_ARG, ({"-V", "--version"}) }),
  }), 1);

  foreach(opts, [string opt, string value]) {
    switch(opt) {
    case "logdir":
      update_nsr_file(value);
      break;
    case "debugdir":
      update_nsr_file(value);
      break;
    case "verbose":
      verbose++;
      break;
    case "version":
      write("$Id$\n");
      break;
    }
  }
}
