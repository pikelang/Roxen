/*
 * $Id: openfiles.pike,v 1.5 1998/07/24 09:41:22 neotron Exp $
 */

inherit "wizard";
constant name= "Status//Open files";

constant doc = ("Show a list of all open files.");

constant more=1;


#include <stat.h>

// Debug functions.  List _all_ open filedescriptors
inline static private array checkfd_fix_line(string l)
{
  string *s;
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

string page_0()
{
  return
    ("<h1>Active filedescriptors</h1>\n"+
     //     "<br clear=left><hr>\n"+
     //     "<table width=100% cellspacing=0 cellpadding=3>\n"+
     //     "<tr align=right><td>fd</td><td>type</td><td>mode</td>"+
     //     "<td>size</td><td>inode</td></tr>\n"+
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
     "</pre>");
}

int wizard_done(){ return -1; }

mixed handle(object id) { return wizard_for(id,0); }

