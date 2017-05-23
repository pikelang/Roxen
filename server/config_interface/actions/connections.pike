#include <config_interface.h>
#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)     _STR_LOCALE("admin_tasks",X,Y)

constant action = "status";
string name = LOCALE(156, "Active connections" );
string doc = LOCALE(157,"All currently active connections");

string parse( RequestID id )
{
  string res = "<h2>Active Connections</h2>";

/*
  string tmpl = #"
    <h2 class='no-margin-top'>Active Connections</h2>
    {{ #sites }}
      <h3 class='section'>{{ name }}</h3>
    {{ /sites }}
  ";

  mapping mctx = ([
    "file_label" : LOCALE(18,"File"),
    "time_label" : LOCALE(158,"Time"),
    "sent_label" : LOCALE(159,"Sent (Mib)"),
    "kb_label"   : LOCALE(160,"Kibyte/s"),
    "sites" : ({})
  ]);
*/
  foreach( roxen->configurations, Configuration c )
  {
    mapping q = c->connection_get();
    if( sizeof( q ) )
    {
      res += "<h3 class='section'>"+c->query_name()+"</h3>";

      float total_bw = 0.0, host_bw;
      string oh;
      array rows = ({});

      foreach( indices( q ), RequestID i )
      {
        if( i && q[i] )
        {
          mapping r = ([
            "start"     : (q[i]->start || i->time),
            "written"   : (int)q[i]->written,
            "host"      : i->remoteaddr,
            "closed"    : ((!i->my_fd&&2) || !!catch(i->my_fd->query_address())),
            "cc"        : q[i]->closed,
            "file"      : i->not_query || "?",
            "len"       : q[i]->len,
            "stat"      : (i->file && i->file->stat) || (i->misc && i->misc->stat),
            "hoststart" : i->remoteaddr +
                          sprintf("%010d",(time()-(q[i]->start || i->time))),
          ]);

          // r->out_time_min = (time(1)-r->start)/60;
          // r->out_time_sec = (time(1)-r->start)%60;
          // r->out_sent_1   = (r->written/1024.0/1024.0);
          // r->out_sent_2   = (r->len&&sprintf("%.1f", r->len/1024.0/1024.0 ))
          //                   || (r->stat
          //                         ? sprintf("%.1f",r->stat[ST_SIZE]/1024.0/1024.0)
          //                         : " - ");
          // r->out_bw       = ((r->written)/(time(r->start)+0.1))/1024.0;

          rows += ({ r });
        }
      }
      sort( column(rows,"hoststart"), rows );

      // msite->files = rows;

      res +=
        "<table class='nice'>\n"
        "<thead>"
        "<tr>"
        "<th>"+LOCALE(18,"File")+"</th>"
        "<th class='text-right'>"+LOCALE(158,"Time")+"</th>"
        "<th class='text-right'>"+LOCALE(159,"Sent (Mib)")+"</th>"
        "<th class='text-right'>"+LOCALE(160,"Kibyte/s")+"</th>"
        "</tr>"
        "</thead>"
        "<tbody>";

      foreach( rows, mapping r )
      {
        if( r->host != oh )
        {
          if( oh )
            res += sprintf("<tr class='sum'><td colspan='3'>"
                           + roxen.quick_ip_to_host(oh)+
                           "</td><td class='text-right'>%.1f</td>"
                           "</tr>", host_bw);
          oh = r->host;
          host_bw = 0.0;
        }
        res += sprintf(
          "<tr>"
          "<td>%s</td>"      // file
          "<td class='text-right'>%2dm %02ds</td>"     // time (min)
          "<td class='text-right'>%.1f / %s</td>" // sent
          "<td class='text-right'>%.1f</td>" // bw
          "</tr>\n",
          r->file,
          (time(1)-r->start)/60, (time(1)-r->start)%60,
          (r->written/1024.0/1024.0),
          (r->len&&sprintf("%.1f", r->len/1024.0/1024.0 )) ||
          (r->stat?sprintf("%.1f",r->stat[ST_SIZE]/1024.0/1024.0):" - "),
          ((r->written)/(time(r->start)+0.1))/1024.0);

        if( !r->closed )
        {
          host_bw +=  ((r->written)/(time(r->start)+0.1))/1024.0;
          total_bw += ((r->written)/(time(r->start)+0.1))/1024.0;
        }
      }
      if( oh )
        res += sprintf("<tr class='sum'><td colspan=3>"
                       + roxen.quick_ip_to_host(oh)+
                       "</td><td class='text-right'>%.1f</td></tr>",
                       host_bw);
      res +=
        "</tbody><tfoot>" +
        sprintf("<tr><td>"
                +LOCALE(161,"Total bandwidth")+"</td>"
                "<td class='text-right' colspan='3'>%.1f</td></tr>\n",
                total_bw );
      res += "</tfoot></table>";
    }
  }
  res += "<input type=hidden name=action value='connections.pike' />"
    "<br />"
    "<cf-ok-button href='./'/> <cf-refresh/>";
  return res;
}
