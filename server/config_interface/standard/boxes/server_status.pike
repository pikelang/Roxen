/*
 * Locale stuff.
 * <locale-token project="roxen_config"> _ </locale-token>
 */
#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)

constant box      = "large";
constant box_initial = 0;

String box_name = _(0,"Server status");
String box_doc  = _(0,"Various global server statistics");

string add_row( string item, string value ) {
  return "<tr><td>" + item + ":</td><td>" + value + "</td></tr>";
}

string parse( RequestID id )
{
  int dt = (time() - roxen->start_time+1);
  string contents = "";
  contents += add_row( _(0, "Server started"),
		       Roxen.strftime( "%Y-%m-%d %H:%M:%S", roxen->start_time) );
  contents += add_row( _(0, "Server uptime"),
		      Roxen.msectos( dt*1000 ));
  array ru;
  if(!catch(ru=rusage())) {
    int tmp;
    if(ru[0])
      tmp = ru[0]/(time() - roxen->start_time+1);
    contents += add_row( _(0, "CPU-time used"),
			 Roxen.msectos(ru[0]+ru[1]) +
			 (tmp?(" ("+tmp/10+"."+tmp%10+"%)"):""));
  }

  mapping total = ([]);
  foreach(roxen->configurations, Configuration conf) {
    if(!conf->sent || !conf->received || !conf->hsent)
      continue;
    total->sent += conf->sent;
    total->hsent += conf->hsent;
    total->received += conf->received;
    total->requests += conf->requests;
  }
  contents += add_row( _(0,"Sent data"), Roxen.sizetostring(total->sent) +
		      sprintf(" (%.2f kbit/%s)",
			      ((((float)total->sent)/(1024.0*1024.0)/dt) * 8192.0),
			      _(3,"sec")) );
  contents += add_row( _(0,"Sent headers"), Roxen.sizetostring(total->hsent));
  contents += add_row( _(0,"Requests"), total->requests +
		       sprintf(" (%.2f/%s)",
			       (((float)total->requests*60.0)/dt),
			       _(6,"min")) );
  contents += add_row( _(0,"Received data"), Roxen.sizetostring(total->sent));

  return ("<box type='"+box+"' title='"+box_name+"'><table>"+contents+"</table></box>");
}
