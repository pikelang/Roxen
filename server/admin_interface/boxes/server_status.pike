
constant box      = "large";
constant box_initial = 1;

constant box_name = "Server status";
constant box_doc  = "Various global server statistics";

string add_row( string item, string value ) {
  return "<tr><td>" + item + ":</td><td>" + value + "</td></tr>";
}

string parse( RequestID id )
{
  int dt = (time() - roxen->start_time+1);
  string contents = "";
  contents += add_row( "Server started",
		       Roxen.strftime( "%Y-%m-%d %H:%M:%S", roxen->start_time) );
  contents += add_row( "Server uptime",
		      Roxen.msectos( dt*1000 ));
  mapping ru;
  if(!catch(ru=System.getrusage())) {
    int tmp;
    if(ru->utime)
      tmp = ru->utime/(time() - roxen->start_time+1);
    contents += add_row( "CPU-time used",
			 Roxen.msectos(ru->utime+ru->stime) +
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
  contents += add_row( "Sent data", String.int2size(total->sent) +
		      sprintf(" (%.2f kbit/sec)",
			      ((((float)total->sent)/(1024.0*1024.0)/dt) * 8192.0)) );
  contents += add_row( "Sent headers", String.int2size(total->hsent));
  contents += add_row( "Requests", total->requests +
		       sprintf(" (%.2f/min)",
			       (((float)total->requests*60.0)/dt)) );
  contents += add_row( "Received data", String.int2size(total->received));

  return ("<box type='"+box+"' title='"+box_name+"'><table cellpadding='0'>"+
	  contents+"</table></box>");
}
