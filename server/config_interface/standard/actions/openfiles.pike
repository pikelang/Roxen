/*
 * $Id: openfiles.pike,v 1.2 2000/02/20 05:33:29 mast Exp $
 */

inherit "wizard";
constant action="debug_info";

constant name= "Open files";

constant doc = "Show a list of all open files and network connections.";

#include <stat.h>

// Debug functions.  List _all_ open filedescriptors
array checkfd_fix_line(string l)
{
  array(string) s;
  s=l/",";
  if (sizeof(s) > 1) {
    s[0]=decode_mode((int)("0"+s[0]));
    if((int)s[1])
      s[1]=sizetostring((int)s[1]);
    else
      s[1]="-";
    // mode size inode ? ?
    s[2]=(int)s[3]?s[3]:"-";
    int m = (int)("0"+s[0]);
    if(!(S_ISLNK(m)||S_ISREG(m)||S_ISDIR(m)||S_ISCHR(m)||S_ISBLK(m)))
      s[2]="-";
    return s[0..2];//*",";
  }
  return l/",";
}

string parse(object id)
{
  return
    ("<h1>Active filedescriptors</h1>\n"+
     sprintf("<pre><b>%-5s  %-9s  %-10s   %-10s   %s</b>\n\n",
	     "fd", "type", "mode", "size", "inode")+

     (Array.map(get_all_active_fd(),
	  lambda(int fd)
	  {
	    string fdc =
#ifdef FD_DEBUG
	      mark_fd(fd)||"?";
#else
	    "";

#endif
	    catch {
	      array args = checkfd_fix_line(fd_info(fd));
	      args = (args[0] / ", ") + args[1..];
	      args[-2] = ( args[-2] / " " - ({""})) * " ";
	      args[1] = (args[1] - "<tt>") - "</tt>";
	      //	    werror("%O\n", args);
	      return sprintf("%-5s  %-9s  %-10s   %-12s  %s",
			   (string)fd,
			   @args,
			   fdc);
	    };
	    return "Error when making info list...\n";

	  })*"\n")+
     "</pre><cf-ok>");
}
