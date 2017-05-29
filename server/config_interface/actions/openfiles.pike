/*
 * $Id$
 */
inherit "wizard";

// This file uses stuff from spider...
import spider;

#include <stat.h>
#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("admin_tasks",X,Y)


constant action="debug_info";


string name= LOCALE(21, "Open files");
string doc = LOCALE(22,
		    "Show a list of all open files and network connections.");

// Debug functions.  List _all_ open filedescriptors

string fix_port(string p)
{
  array(string) a = p/" ";
  if (a[0] == "0.0.0.0") {
    a[0] = "*";
  }
  if (has_value (a[0], ":"))
    a[0] = "[" + a[0] + "]";
  if (a[1] == "0") {
    a[1] = "ANY";
  }
  return a * ":";
}

string parse( RequestID id )
{
  return
    ("<cf-title>" +LOCALE(23, "Active filedescriptors")+ "</cf-title>"
     "<hr class='section'>"+
     sprintf("<pre><b>%-5s  %-9s  %-10s   %-10s</b>\n\n",
	     "fd", "type", "mode", "details")+

     (Array.map(Stdio.get_all_active_fd(),
	  lambda(int fd)
	  {
	    object f = Stdio.File(fd);
	    object stat = f->stat();
	    if (!stat)
	      return sprintf("%-5s  %-9s  %-10s   %-12s",
			     (string) fd, "Unknown", "?", "(error " + f->errno() + ")");

	    string type = ([
	      "reg":"File",
	      "dir":"Dir",
	      "lnk":"Link",
	      "chr":"Special",
	      "blk":"Device",
	      "fifo":"FIFO",
	      "sock":"Socket",
	      "unknown":"Unknown",
	    ])[stat->type] || "Unknown";

	    // Doors aren't standardized yet...
	    if ((type == "Unknown") &&
		((stat->mode & 0xf000) == 0xd000))
	      type = "Door";

	    string details = "-";

	  format_details:
	    if (stat->isreg) {
	      if (stat->size == 1) {
		details = "1 byte";
	      } else {
		details = sprintf("%d bytes", stat->size);
	      }
	      if (stat->ino) {
		details += sprintf(", inode: %d", stat->ino);
	      }
	    } else if (stat->issock) {


	      string local_port = f->query_address(1);
	      if (local_port)
		local_port = fix_port (local_port);
	      else {
		if ((<System.EBADF, System.ENOTCONN,
#if constant (System.EAFNOSUPPORT)
		      System.EAFNOSUPPORT,
#endif
		      System.EINVAL>)[f->errno()]) {
		  // A socket that getsockname(2) doesn't like. Assume
		  // it's a unix socket if we get these errors. Don't
		  // know how portable it is - only tested on Linux.
		  // /mast
		  type = "Unix";
		  break format_details;
		}

		local_port =
		  "(Cannot get local port: "+ strerror (f->errno()) + ")";
	      }

	      string remote_port = f->query_address();
	      if (remote_port)
		remote_port = fix_port (remote_port);
	      else if (f->errno() != System.ENOTCONN)
		remote_port =
		  "(Cannot get remote port: "+ strerror (f->errno()) + ")";

	      if (!remote_port) {
		type = "Port";
		details = local_port + " (listen)";
	      } else {
		details = sprintf("%s &lt;=&gt; %s",
				  local_port, remote_port);
	      }
	    }

	    return sprintf("%-5s  %-9s  %-10s   %-12s",
			   (string)fd,
			   type,
			   stat->mode_string,
			   details);
	  })*"\n")+
     "</pre><p><cf-ok/></p>");
}
