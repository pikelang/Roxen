//
// Prettyprint status information
//

string status(object|mapping conf)
{
  float tmp, dt = (float)(time(1) - core->start_time + 1);

#define NBSP(X)  replace(X, " ", "&nbsp;")

  string res = "<table>"
    "<tr align='left'><td><b>Sent data:</b></td>"
    "<td align='right'>"
     +replace(String.int2size(conf->sent)," ","</td><td>")+"</td>"
    "<td>"+ sprintf(" (%.2f",
		    (((float)conf->sent)/(1024.0*1024.0)/dt) * 8192.0)+
    "&nbsp;kbit/sec) </td>"
    "</tr><tr align='left'><td><b>Sent headers:</b></td>"
    "<td align='right'>"
     +replace(String.int2size(conf->hsent)," ","</td><td>")+"</td>"
    "<tr align='left'><td><b>Requests:</b></td>"
    "<td align='right'>"+ conf->requests +"</td><td>requests</td>"
    "<td align='left'>"+ sprintf(" (%.2f ", 
				  ((float)conf->requests*60.0)/dt)+
    "hits/min) </td>"
    "</tr><tr align='left'><td><b>Received data:</b></td>"
    "<td align='right'>"
     +replace(String.int2size(conf->received)," ","</td><td>")+"</td></tr>\n";

  res += "</table>\n\n";

  if (conf->extra_statistics && conf->extra_statistics->ftp && 
      conf->extra_statistics->ftp->commands) {
    // FTP statistics.
    res += "<table><tr><td><b>FTP statistics:"
      " </b></td><td>&nbsp;</td><td>&nbsp;</td></tr>\n";

    foreach(sort(indices(conf->extra_statistics->ftp->commands)), string cmd) {
      res += "<tr align='right'><td>&nbsp;</td>"
	"<td><b> "+ upper_case(cmd) +"</b></td><td align='right'>"+ 
	conf->extra_statistics->ftp->commands[cmd] +
	"</td></tr>\n";
    }
    res += "</table>\n";
  }

  return res;
}

