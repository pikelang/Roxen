/*
 * $Id: requeststatus.pike,v 1.5 2000/08/25 15:57:27 lange Exp $
 */

inherit "../statusinfo.pike";
#include <roxen.h>
//<locale-token project="admin_tasks" > LOCALE </locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("admin_tasks",X,Y)

constant action = "status";

string name= LOCALE(45, "Access / request status");
string doc = LOCALE(46, "Shows the amount of data handled since last restart.");


string status_total() {
  mapping total = ([]);

  foreach(roxen->configurations, object conf)
  {
    if(!conf->sent || !conf->received || !conf->hsent)
      continue;
    total->sent += conf->sent;
    total->hsent += conf->hsent;
    total->received += conf->received;
    total->requests += conf->requests;
    if (conf->misc && !zero_type(conf->misc->ftp_users)) {
      if(!total->misc) total->misc = ([]);
      total->misc->ftp_users +=  conf->misc->ftp_users;
      total->misc->ftp_users_now +=  conf->misc->ftp_users_now;
    }
  }

  int uptime = time(1)-roxen->start_time;
  int days = uptime/(24*60*60);
  int hrs = uptime/(60*60);
  int min = uptime/60 - hrs*60;
  hrs -= days*24;

  return 
    "<table>"
    "<tr><th>"+ LOCALE(40,"Version:") +"</th>"
    "<td colspan='2'>"+ roxen->real_version +"</td></tr>\n"
    "<tr><th>"+ LOCALE(41,"Booted:") +"</th>"
    "<td colspan='2'>"+
    roxen->language(roxen->locale->get(), "date")(roxen->start_time)+
    "</td></tr>\n"
    "<tr><th>"+ LOCALE(42,"Uptime:") +"</th>"
    "<td colspan='2'>"+
    (days? days+" "+((days<2)?LOCALE(47,"day"):LOCALE(48,"days"))+", " : "")+
    sprintf("%02d:%02d:%02d",hrs,min,uptime%60) +"</td></tr>\n"
    "<tr><td colspan='3'>&nbsp;</td></tr>\n"
    "</table>"+    
    status(total);
}

string status_configurations()
{
  string res="";
  foreach(Array.sort_array(roxen->configurations,
			   lambda(object a, object b) {
			     return a->requests < b->requests;
			   }), object o)
  {
    if(!o->requests)
      continue;
    res += sprintf("<h3>%s</h3><blockquote>%s</blockquote>\n",
		   o->query_name(), status(o) );
  }
  return
    "<b>" + 
    LOCALE(43,"These are all active virtual servers. They are sorted "
	   "by the number of requests they have received - the most active "
	   "being first. Servers which haven't recieved any requests are not "
	   "listed.") + 
    "</b>" + res + "<p><cf-ok/></p>";
}

mixed parse( RequestID id )
{
  return 
    "<h2>"+ LOCALE(44, "Server Overview") +"</h2>"+
    status_total()+
    "<p>"+
    status_configurations() +
    "</p>";
}


