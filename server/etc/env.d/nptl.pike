// $Id: nptl.pike,v 1.1 2003/09/23 12:02:48 grubba Exp $
//
// Detection and workaround for Redhat 9's New Posix Thread Library.
//
// 2003-09-23 Henrik Grubbström

void run(object env)
{
  write("   Checking for NPTL... ");
  if (search(Process.popen("/usr/bin/getconf GNU_LIBPTHREAD_VERSION 2>/dev/null"),
	     "NPTL") >= 0) {
    write("yes (%s)\n");
    env->set("LD_ASSUME_KERNEL", "2.4.1");
  } else {
    write("no\n");
  }
}
