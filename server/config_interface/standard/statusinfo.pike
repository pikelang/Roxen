//
// Prettyprint status information
//

#include <roxen.h>
//<locale-token project="roxen_config"> LOCALE </locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)


string status(object|mapping conf)
{
  float tmp, dt = (float)(time(1) - roxen->start_time + 1);

#define NBSP(X)  replace(X, " ", "&nbsp;")

  string res = "<table>"
    "<tr align='left'><th>"+ LOCALE(2,"Sent data:") +"</th>"
    "<td>"+ NBSP(Roxen.sizetostring(conf->sent)) +"</td>"
    "<td>"+ sprintf(" (%.2f",
		    (((float)conf->sent)/(1024.0*1024.0)/dt) * 8192.0)+
    "&nbsp;kbit/"+ LOCALE(3,"sec") +") </td>"
    "<th>"+ LOCALE(4,"Sent headers:")+"</th>"
    "<td>"+ NBSP(Roxen.sizetostring(conf->hsent)) +"</td></tr>\n"
    "<tr align='left'><th>"+ LOCALE(5,"Number of requests:") +"</th>"
    "<td align='right'>"+ conf->requests +"</td>"
    "<td align='right'>"+ sprintf(" (%.2f", 
				  ((float)conf->requests*60.0)/dt)+
    "/"+ LOCALE(6,"min") +") </td>"
    "<th>"+ LOCALE(7,"Received data:") +"</th>"
    "<td>"+ NBSP(Roxen.sizetostring(conf->received)) +"</td></tr>\n";

  if (conf->misc && !zero_type(conf->misc->ftp_users)) {
    res += sprintf("<tr align='left'><th>%s</th><td>%8d</td>"
		   "<td align='right'> (%.2f/%s) </td>"
		   "<th>%s</th><td>%d</td></tr>\n",
		   LOCALE(8,"FTP users (total):"), conf->misc->ftp_users,
		   (((float)conf->misc->ftp_users*60.0)/dt), 
		   LOCALE(6,"min"), LOCALE(9,"FTP users (now):"), 
		   conf->misc->ftp_users_now);
  }
  res += "</table>\n\n";

  if (conf->extra_statistics && conf->extra_statistics->ftp && 
      conf->extra_statistics->ftp->commands) {
    // FTP statistics.
    res += "<table><tr><th>" + LOCALE(10, "FTP statistics:") + 
      " </th><td>&nbsp;</td><td>&nbsp;</td></tr>\n";

    foreach(sort(indices(conf->extra_statistics->ftp->commands)), string cmd) {
      res += "<tr align='right'><td>&nbsp;</td>"
	"<th> "+ upper_case(cmd) +"</th><td align='right'>"+ 
	conf->extra_statistics->ftp->commands[cmd] +
	"</td></tr>\n";
    }
    res += "</table>\n";
  }

  return res;
}

