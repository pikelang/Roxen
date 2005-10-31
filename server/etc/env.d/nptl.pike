// $Id: nptl.pike,v 1.2 2005/10/31 17:28:01 grubba Exp $
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
    env->set("LD_ASSUME_KERNEL", "2.4.1");
  } else {
    write("no\n");
  }
#endif
}
