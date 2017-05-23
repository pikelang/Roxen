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

  string res = "<table class='auto'>"
    "<tr align='left'><td><b>"+ LOCALE(2,"Sent data") +":</b></td>"
    "<td align='right'>"+(Roxen.sizetostring(conf->sent)/" ")[0]+"</td>"
    "<td>"+(Roxen.sizetostring(conf->sent)/" ")[1]+"</td>"
    "<td>"+ sprintf(" (%.2f",
		    (((float)conf->sent)/(1024.0*1024.0)/dt) * 8192.0)+
    "&nbsp;kbit/"+ LOCALE(3,"sec") +") </td>"
    "</tr><tr align='left'><td><b>"+ LOCALE(4,"Sent headers")+":</b></td>"
    "<td align='right'>"+(Roxen.sizetostring(conf->hsent)/" ")[0]+"</td>"
    "<td>"+(Roxen.sizetostring(conf->hsent)/" ")[1]+"</td></tr>\n"
    "<tr align='left'><td><b>"+ LOCALE(234,"Requests") +":</b></td>"
    "<td align='right'>"+ conf->requests +"</td><td>"+LOCALE(526, "requests")+"</td>"
    "<td align='left'>"+ sprintf(" (%.2f ",
				  ((float)conf->requests*60.0)/dt)+
    LOCALE(527,"hits")+"/"+ LOCALE(6,"min") +") </td>"
    "</tr><tr align='left'><td><b>"+ LOCALE(7,"Received data") +":</b></td>"
    "<td align='right'>"+(Roxen.sizetostring(conf->received)/" ")[0]+"</td>"
    "<td>"+(Roxen.sizetostring(conf->received)/" ")[1]+"</td></tr>\n";

  res += "</table>\n\n";

  if (conf->extra_statistics && conf->extra_statistics->ftp &&
      conf->extra_statistics->ftp->commands) {
    // FTP statistics.
    res += "<table class='auto'><tr><td><b>" + LOCALE(10, "FTP statistics:") +
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

