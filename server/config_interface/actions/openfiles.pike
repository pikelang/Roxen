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

array(mapping) collect_fds()
{
  mapping(string:string) types = ([
    "reg":"File",
    "dir":"Dir",
    "lnk":"Link",
    "chr":"Special",
    "blk":"Device",
    "fifo":"FIFO",
    "sock":"Socket",
    "unknown":"Unknown",
  ]);

  return Array.map(Stdio.get_all_active_fd(),
	  lambda(int fd)
	  {
	    object f = Stdio.File(fd);
	    object stat = f->stat();
	    if (!stat) {
	      return ([
	        "fd"      : (string) fd,
	        "type"    : "Unknown",
	        "mode"    : "?",
	        "details" : "(error " + f->errno() + ")"
	      ]);
	    }

	    string type = types[stat->type] || "Unknown";

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

	    return ([
              "fd"      : (string) fd,
              "type"    : type,
              "mode"    : stat->mode_string,
              "details" : details,
    	    ]);
	  });
}

string parse( RequestID id )
{
  mapping ctx = ([
    "headers" : ({
      ([ "fd"      : "Fd",
         "type"    : "Type",
         "mode"    : "Mode",
         "details" : "Details" ])
    }),
    "data" : collect_fds() || ({})
  ]);

  string tmpl = #"
    <table class='nice'>
      <thead class='sticky'>
        <tr>
        {{ #headers }}
          <th class='text-right'>{{ fd }}</th>
          <th>{{ type }}</th>
          <th>{{ mode }}</th>
          <th>{{ details }}</th>
        {{ /headers }}
        </tr>
      </thead>
      <tbody>
        {{ #data }}
        <tr>
          <td class='text-right'>{{ fd }}</td>
          <td>{{ type }}</td>
          <td><code>{{ mode }}</code></td>
          <td>{{ &details }}</td>
        </tr>
        {{ /data }}
      </tbody>
    </table>";

  Mustache stash = Mustache();
  string out =
    "<cf-title>" +LOCALE(23, "Active filedescriptors")+ "</cf-title>"
    "<hr class='section'>" +
    stash->render(tmpl, ctx);

  destruct(stash);

  return out;
}
