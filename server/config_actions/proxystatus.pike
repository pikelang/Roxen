/*
 * $Id: proxystatus.pike,v 1.3 1999/04/02 16:55:58 grubba Exp $
 *
 * proxystatus was contributed by Wilhelm Köhler (wk@cs.tu-berlin.de)
 *
 * based on code from requeststatus.pike
 *
 */

#include <stat.h>

inherit "wizard";
constant name= "Status//Proxy connections";

constant doc = ("Shows current proxy connections.");

constant more=0;

constant ok_label = " Refresh ";
constant cancel_label = " Done ";

string status(object mc, int cf_detail, int bc_detail, int sc_detail,
	      int rq_detail, int http_stats, int cc_stats, int length_stats,
	      int clear_stats)
{
  string res_stats = "";
  if((length_stats||http_stats)&&catch(sizeof(mc->stats->http->cache))){
    res_stats = "<b>For HTTP stats proxy and disk_cache "
      "module versions of April 1999 or later are needed.</b><br><br>";
    length_stats = http_stats = clear_stats = 0;
  }

  if(clear_stats){
    mc->stats = ([ "http": ([ "cache":([]), "new":([]) ]),
                   "length": ([ "cache":([]), "new":([]) ]) ]);
    res_stats = "<b>Online Statistics Cleared</b><br><br>";
  }

  if(http_stats){
    array title = ({ "HTTP code", "Sum", "%", "New", "%", "Cache", "%" });
    array rows = ({});
    int sum_cache = `+(0, @values(mc->stats->http->cache));
    int sum_new = `+(0, @values(mc->stats->http->new));
    int sum_sum = sum_cache + sum_new;
#define PER(X,Y) (X)==(Y)?"100":(X)==0?"":sprintf("%.2f",\
		                                  (float)(X)*100.0/(float)(Y))
    if(!sum_sum)
      res_stats += "<b>No HTTP codes since reset.</b><br>";
    else {
      foreach(indices(mc->stats->http->cache)|indices(mc->stats->http->new),
	      object foo){
        int cache = mc->stats->http->cache[foo];
        int new = mc->stats->http->new[foo];
        rows += ({ ({ foo, cache+new||"", PER(cache+new,sum_sum),
		      new||"", PER(new,sum_sum), cache||"",
		      PER(cache,sum_sum) }) });
      }
      sort(rows);
      rows += ({ ({ "Sum", sum_sum, "100",
		    sum_new||"", PER(sum_new,sum_sum), sum_cache||"",
		    PER(sum_cache,sum_sum) }) });
      res_stats += html_table(title, rows);
    }
  }

  if(length_stats){
    array title = ({ "Bytes (<=)", "Sum", "%", "New", "%", "Cache", "%" });
    array rows = ({});
    array s_rows = ({});
    int sum_cache = `+(0, @values(mc->stats->length->cache));
    int sum_new = `+(0, @values(mc->stats->length->new));
    int sum_sum = sum_cache + sum_new;
#define PER(X,Y) (X)==(Y)?"100":(X)==0?"":sprintf("%.2f",\
		                                  (float)(X)*100.0/(float)(Y))
    if(!sum_sum)
      res_stats += "<b>No Requests since reset.</b><br>";
    else {
      foreach(indices(mc->stats->length->cache)|indices(mc->stats->length->new),
	      object foo){
        int cache = mc->stats->length->cache[foo];
        int new = mc->stats->length->new[foo];
        rows += ({ ({ !foo?256:foo == 1?512:(int)pow(2.0,(float)(foo-2))+"k",
		      cache+new||"", PER(cache+new,sum_sum),
		      new||"", PER(new,sum_sum),
		      cache||"", PER(cache,sum_sum) }) });
	s_rows += ({ foo });
      }
      sort(s_rows, rows);
      rows += ({ ({ "Sum", sum_sum, "100",
		    sum_new||"", PER(sum_new,sum_sum), sum_cache||"",
		    PER(sum_cache,sum_sum) }) });
      res_stats += html_table(title, rows);
    }
  }

  if(!cc_stats)
    return res_stats;
  array rows = ({});
  array times = ({});
  array title = ({ "Since", "Bytes", "Idle", "Mode", "Http" });
  if(cf_detail)
    title += ({ "Cache file", "bytes", "idle" });
  title += ({ "Browser" });
  if(bc_detail)
    title += ({ "connection" });
  title += ({ "Server" });
  if(sc_detail)
    title += ({ "connection" });
  title += ({ "Requested" });

  foreach(indices(mc->requests), object request){
    if(!request){
      report_debug("PROXY_STATUS: no request\n");
      continue;
    }
    string res = "";
    string since = "", bytes = "", idle = "", mode = "", http = "", cache = "";
    string browser = "", server = "", requested = "";
    int idle_time;

    if(catch(http = request->http_code()||""))
      http = "-";

    if(cf_detail)
    {
      if(request->from_disk)
      {
        if(catch(cache = "\t" + request->cache_file_info + "\t"))
          cache = "\t\t\t";
      } else if(!request->to_disk)
        cache = "\t\t\t";
      else
      {
        if(catch(cache = "\t" + request->to_disk->file->query_fd() + ":" +
                   ((request->to_disk->rfile/"roxen_cache/http/")[1]) + "\t"))
          cache = "\t\t";
        object stat;
        if(catch(stat = request->to_disk->file->stat()))
          cache += "\t";
        else {
          int size = stat[ST_SIZE];
          catch{size -= request->to_disk->headers->head_size;};
          cache += (size<=0?0:size) + "\t";
#define MY_TIME(X) sprintf("%s%d:%d", (X)>(60*60)?(X)/(60*60)+":":"",\
                             (X)%(60*60)/60, (X)%60)
          idle_time = time()-stat[ST_MTIME];
          if(idle_time)
            cache += MY_TIME(idle_time);
        }
      }
    }
    object r_s;
    if(catch((r_s = request->server->from_server)&&
	     (server = roxen->quick_ip_to_host((r_s->query_address()/" ")[0]))))
      server = "-" + (sc_detail?"\t":"");
    else if(sc_detail){
    //if(request->server)request->server->_got(0,"");
    request->write("");
      string r;
      if(!catch(r=r_s->query_fd())&&r)
        server += "\t"+r+":";
      if(!catch(r=replace(r_s->query_address(1), " ", ":"))&&r)
        server += r;
      server += "->";
      if(!catch(r=replace(r_s->query_address(), " ", ":"))&&r)
        server += r;
    }

    if(catch(requested = request->name) || !sizeof(requested))
      requested = "-";
    else {
      requested = "\<a href=\"http://"+requested+"\">"+
        (rq_detail||sizeof(requested)<40?requested:requested[..37]+"...");
    }
      
    object id;
    int id_time;
    if(catch((id = request->id) && (id_time = id->time)))
      id_time = time();

    since = MY_TIME(idle_time = time()-id_time);

    if(catch(bytes = request->bytes_sent()||""))
      bytes = "n/a";

    if(catch(idle = (idle_time = request->idle()) > 5?MY_TIME(idle_time):""))
      idle = "n/a";

    if(catch(mode = request->mode()))
      mode = "-";

    if(catch((browser=id->my_fd->query_address()||("["+roxen->quick_ip_to_host(request->_remoteaddr)+"]")) &&
             (browser = roxen->quick_ip_to_host(request->_remoteaddr)||request->_remoteaddr)) &&
       catch(browser="["+(roxen->quick_ip_to_host(request->_remoteaddr)||request->_remoteaddr)+"]"))
      browser = "-" + (bc_detail?"\t":"");
    else if(bc_detail){
      browser += "\t";
      if(catch(browser += id->my_fd->query_fd() + ":"))
        browser += "[n/a]:";
      if(catch(browser += replace(id->my_fd->query_address(), " ", ":") + "->"))
        browser += "[n/a]->";
      if(catch(browser += replace(id->my_fd->query_address(1), " ", ":")))
        browser += "[n/a]";
    }

    string res = since + "\t" + bytes + "\t" + idle + "\t" + mode + "\t" +
		   http + cache +  "\t" + browser + "\t" + server +
		   "\t" + requested;
    times += ({ id_time });
    rows += ({ res/"\t" });
  }

  if(sizeof(mc->requests)&&sizeof(rows)){
    sort(times, rows);
    return res_stats + html_table(title, rows);
  } else
    return res_stats + "<b>No current proxy connections.</b>";
}

mixed page_0(object id, object mc)
{
  string res="";
  foreach(Array.sort_array(roxen->configurations,
			   lambda(object a, object b) {
			     return a->requests < b->requests;
			   }), object o) {
    if(!o->requests || !o->modules || !o->modules->proxy ||
       !o->modules->proxy->copies)
      continue;
    res += sprintf("<h3><a href=%s>%s</a><br>%s</h3>\n",
		   o->query("MyWorldLocation"),
		   o->name,
		   replace(o->status(), "<table>", "<table cellpadding=4>"));

    if(!id->variables["first"]){
      id->variables["cc_stats"]="on";
      id->variables["first"]="1";
    }

    foreach(indices(o->modules->proxy->copies), int i){
      object out = o->modules->proxy->copies[i];
      gc();
#define ON(X) id->variables[X]!="0"&&id->variables[X]
      res+=status(out, 
		  ON("cf_detail"), ON("bc_detail"), ON("sc_detail"),
		  ON("rq_detail"), ON("http_stats"), ON("cc_stats"),
		  ON("length_stats"), ON("clear_stats"));
    }
    if(ON("clear_stats"))
      id->variables["clear_stats"]=0;
  }
  if(!strlen(res))
    return "<b>There are no active virtual servers.</b>";
  res += "<table>"
    "<tr>"
    "<td><var type=checkbox name=cf_detail></td><td>Cachefile details\n</td>"
    "<td><var type=checkbox name=sc_detail></td><td>Server connection details\n</td>"
    "<td><var type=checkbox name=bc_detail></td><td>Browser connection details\n</td>"
    "</tr><tr>"
    "<td><var type=checkbox name=rq_detail></td><td>Full request string\n</td>"
    "<td></td><td></td>"
    "<td><var type=checkbox name=clear_stats></td><td>Clear Online Statistics\n</td>"
    "</tr><tr>"
    "<td><var type=checkbox name=cc_stats default=on></td><td>Current connections\n</td>"
    "<td><var type=checkbox name=http_stats></td><td>Http code stats\n</td>"
    "<td><var type=checkbox name=length_stats></td><td>Length stats\n</td>"
    "</tr></table>";
  return
    "<b>These are all virtual servers with proxy modules. They are sorted by the "
    "number of requests they have received - the most active being first. "
    "Servers which haven't recevied any requests are not listed.</b>" + res;

}

int verify_0(object id)
{
  return 1;
}

mixed handle(object id)
{
  return wizard_for(id,0);
}
