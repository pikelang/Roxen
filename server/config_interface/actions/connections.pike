#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("admin_tasks",X,Y)

constant action = "status";
string name = LOCALE(0, "Active connection" );
string doc = LOCALE(0,"All currently active connection");

string parse( RequestID id )
{
  string res = "";
  foreach( roxen->configurations, Configuration c )
  {
    mapping q = c->connection_get();
    if( sizeof( q ) )
    {
      res += "<h2>"+c->query_name();
      array rows = ({});
      foreach( indices( q ), RequestID i )
      {
	if( i && q[i] )
	{
	  rows += ({
	    ([
	      "start":(q[i]->start || i->time),
	      "written":(int)q[i]->written,
	      "host":i->remoteaddr,
	      "file":i->not_query || "?",
	      "len":q[i]->len,
	      "stat":(i->file && i->file->stat) || (i->misc && i->misc->stat),
	      ])
	  });
	}
      }
      sort( rows );
      res += "<table cellspacing=0 border=0 cellpadding=2 width=100% >";
      res += "<tr bgcolor='&usr.fade2;'>"
	"<td><b>Host</b></td>"
	"<td><b>File</b></td>"
	"<td align=right><b>Time</b></td>"
	"<td align=right><b>Sent</b></td>"
	"<td align=right><b>Bandwidth</b></td>"
	"</tr>";
      float total_bw = 0.0;
      foreach( rows, mapping r )
      {
//  	res += sprintf( "%O", r );
	res += sprintf(
	  "<tr><td>%s</td>" // host
	  "<td>%s</td>"      // file
	  "<td align=right>%2dm %02ds</td>"     // time (min)
	  "<td align=right>%.1f / %s Mb</td>" // sent
	  "<td align=right>%.1fKbit/sec</td>" // bw
          "</tr>"
	  ,
          roxen.quick_ip_to_host( r->host ),
	  r->file,
	  (time(1)-r->start)/60, (time(1)-r->start)%60,
          (r->written/1024.0/1024.0),
	  (r->len&&sprintf("%.1f", r->len/1024.0/1024.0 )) ||
	  (r->stat?sprintf("%.1f",r->stat[ST_SIZE]/1024.0/1024.0):" - "),
	  ((r->written*8)/(time(r->start)+0.1))/1024.0);
	total_bw += ((r->written*8)/(time(r->start)+0.1))/1024.0;
      }
      res +=
	sprintf("<tr bgcolor='&usr.fade2;'><td colspan=4>Total bandwidth</td><td>%.1fKbit/sec</td></tr>",
		total_bw );
      res += "</table>";
    }
  }
  return res;
}
