/*
 * $Id: openfiles.pike,v 1.12 2002/06/13 00:28:52 nilsson Exp $
 */
inherit "wizard";

// This file uses stuff from spider...
import spider;

#include <stat.h>

constant task = "debug_info";
constant name = "Open files";
constant doc  = "Show a list of all open files and network connections.";

// Debug functions.  List _all_ open filedescriptors

string fix_port(string p)
{
  array(string) a = p/" ";
  if (a[0] == "0.0.0.0") {
    a[0] = "*";
  }
  if (a[1] == "0") {
    a[1] = "ANY";
  }
  return a * ":";
}

string parse( RequestID id )
{
  return
    ("<h1>Active filedescriptors</h1>\n"+
     sprintf("<pre><b>%-5s  %-9s  %-10s   %-10s</b>\n\n",
	     "fd", "type", "mode", "details")+

     (Array.map(get_all_active_fd(),
	  lambda(int fd)
	  {
	    object f = Stdio.File(fd);
	    object stat = f->stat();

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
	      string remote_port = f->query_address();
	      string local_port = f->query_address(1);
	      if (!remote_port) {
		if (local_port && (local_port != "0.0.0.0 0")) {
		  type = "Port";
		  details = fix_port(local_port);
		}
	      } else {
		details = sprintf("%s &lt;=&gt; %s",
				  local_port?fix_port(local_port):"-",
				  fix_port(remote_port));
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
