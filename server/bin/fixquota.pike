#!/usr/local/bin/pike

object(Roxen.QuotaDB) quota_db;

int du(string dir)
{
  array(string) files = get_dir(dir);
  int total;

  foreach((files || ({})) - ({ ".", ".." }), string file) {
    string path = dir + "/" + file;

    mixed st = file_stat(path);
    if (st) {
      if (st[1] == -2) {
	// Recurse
	total += du(path);
      } else if (st[1] >= 0) {
	// Ordinary file
	total += st[1];
      } else {
	werror(sprintf("%O is not an ordinary file!\n", path));
      }
    } else {
      // Probably not reached.
    }
  }

  werror(sprintf("du(%O) => %d\n", dir, total));

  return(total);
}

void fixdir(string dir)
{
  int usage = du(dir);

  object q = quota_db->lookup(dir);
  q->set_usage(dir, usage);
}

int main(int argc, array(string) argv)
{
  int create_new = 0;

  array args = Getopt.find_all_options(argv, ({
    ({ "version", Getopt.NO_ARG, ({ "-v", "--version" }) }),
    ({ "help", Getopt.NO_ARG, ({ "-h", "--help" }) }),
    ({ "create", Getopt.NO_ARG, ({ "-c", "--create" }) }),
  }), 1);

  foreach(args, array arg) {
    switch(arg[0]) {
    case "create":
      create_new = 1;
      break;
    case "help":
      write(sprintf("Usage:\n"
		    "\t%s [options] quotafile\n"
		    "Options:\n"
		    "\t-c, --create   Create database.\n"
		    "\t-h, --help     Show usage information.\n"
		    "\t-v, --version  Show version information.\n",
		    argv[0]));
      exit(0);
      break;
    case "version":
      werror("$Id$\n");
      exit(0);
      break;
    }
  }

  argv = Getopt.get_args(argv, 1);

  if (sizeof(argv) < 2) {
    werror(sprintf("Too few arguments to %s\n", argv[0]));
    exit(1);
  } else if (sizeof(argv) > 2) {
    werror(sprintf("Too many arguments to %s\n", argv[0]));
    exit(1);
  }

  quota_db = Roxen.QuotaDB(argv[1], create_new);

  string input = "";
  string in;

  do {
    in = Stdio.stdin->read(1024);

    if (!sizeof(in)) {
      if (sizeof(input) && (input[-1] != '\n')) {
	input += "\n";
      }
    } else {
      input += in;
      if (search(in, "\n") == -1) {
	continue;
      }
    }

    array a = input/"\n";

    input = a[-1];
    foreach(a[..sizeof(a)-2], string dir) {
      fixdir(dir);
    }
  } while(sizeof(in));

  werror("Done. Rebuilding index...\n");

  werror(sprintf("Before:\n"
		 "index:%O\n"
		 "index_acc:%O\n",
		 quota_db->index,
		 quota_db->index_acc));

  quota_db->rebuild_index();

  werror(sprintf("After:\n"
		 "index:%O\n",
		 quota_db->index));

  exit(0);
}
