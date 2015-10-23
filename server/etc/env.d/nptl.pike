// $Id$
//
// Detection and workaround for Redhat 9's New Posix Thread Library.
//
// 2003-09-23 Henrik Grubbström

void run(object env)
{
#if !constant(Mysql.mysql)
  // The Mysql module when compiled on RedHat 7.3 contains the symbol
  // "errno@@GLIBC_2.0", which is not available in modern GLIBCs.
  write("   Broken Mysql -- Checking for NPTL... ");
  if (search(Process.popen("/usr/bin/getconf GNU_LIBPTHREAD_VERSION 2>/dev/null"),
	     "NPTL") >= 0) {
    write("yes (%s)\n");
    write("   Checking if LD_ASSUME_KERNEL might work... ");
    // On recent releases of Linux, binaries often fail with
    //   error while loading shared libraries: libc.so.6: cannot
    //   open shared object file: No such file or directory
    // when LD_ASSUME_KERNEL is set. We test with a binary that
    // the start-script will attempt to use: sed.
    object in = Stdio.File();
    object out = Stdio.File();
    object err = Stdio.File();
    Process.Process p =
      Process.create_process(({ "sed", "-ed" }), ([
			       "stdin": in->pipe(Stdio.PROP_REVERSE),
			       "stdout": out->pipe(),
			       "stderr": err->pipe(),
			       "env":getenv() + ([
				 "LD_ASSUME_KERNEL":"2.4.1",
			       ])
			     ]));
    in->close();
    out->close();
    err->read();
    err->close();
    if (!p->wait()) {
      write("yes\n");
      env->set("LD_ASSUME_KERNEL", "2.4.1");
      return;
    }
  }
  write("no\n");
#endif
}
