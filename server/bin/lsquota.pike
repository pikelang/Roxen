/*
 * $Id$
 *
 * List the keys of a quotadb.
 *
 * Henrik Grubbström 1999-06-20
 */

int main(int argc, array(string) argv)
{
  Stdio.File cat = Stdio.File();

  array args = Getopt.find_all_options(argv, ({
    ({ "version", Getopt.NO_ARG, ({ "-v", "--version" }) }),
    ({ "help", Getopt.NO_ARG, ({ "-h", "--help" }) }),
  }), 1);

  foreach(args, array arg) {
    switch(arg[0]) {
    case "help":
      write(sprintf("Usage:\n"
		    "\t%s [options] quotafile\n"
		    "Options:\n"
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

  if (!cat->open(argv[1] + ".cat", "r")) {
    werror(sprintf("Failed to open file %O\n", argv[1] + ".cat"));
    exit(1);
  }

  string buf = "";

  while(1) {
    int len;
    string data = cat->read(8192);

    if (data == "") {
      // EOF
      if (buf != "") {
	werror(sprintf("File truncated. Expected %d bytes more data.\n",
		       len - sizeof(buf)));
	exit(1);
      }
      exit(0);
    }
    buf += data;

    while(1) {
      sscanf(buf[..3], "%4c", len);

      if (len < 8) {
	werror(sprintf("Bad entry length:%d\n", len));
	exit(1);
      }
      if (len > sizeof(buf)) {
	// Need more data.
	break;
      }
      // %4c len, %4c offset, %s key
      data = buf[8..len-1];
      buf = buf[len..];

      write(data+"\n");
    }
  }
}
