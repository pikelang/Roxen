/*
 * $Id: proxystatus.pike,v 1.2 1999/03/05 02:07:50 grubba Exp $
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
	      int rq_detail, int rc_stats, int cc_stats)
{
  string res_retcodes = "";
  if(rc_stats&&catch(sizeof(mc->retcodes->cache)))
    res_retcodes = "<b>For HTTP returncode stats proxy and disk_cache "
      "module versions of April 1999 or later are needed.</b><br><br>";
  else if(rc_stats){
    array title = ({ "HTTP returncode", "Cache", "%", "New", "%", "Sum", "%" });
    array rows = ({});
    int sum_cache = `+(0, @values(mc->retcodes->cache));
    int sum_new = `+(0, @values(mc->retcodes->new));
    int sum_sum = sum_cache + sum_new;
#define PER(X,Y) (X)==(Y)?"100":(X)==0?"":sprintf("%.2f",(float)(X)*100.0/(float)(Y))
    if(!sum_sum)
      res_retcodes = "<b>No HTTP returncodes since restart.</b><br>";
    else {
      foreach(indices(mc->retcodes->cache)|indices(mc->retcodes->new),
	      object foo){
        int cache = mc->retcodes->cache[foo];
        int new = mc->retcodes->new[foo];
        rows += ({ ({ foo, cache||"", PER(cache,cache+new), new||"",
		      PER(new,cache+new),
		      cache+new||"", PER(cache+new,sum_sum) }) });
      }
      sort(rows);
      rows += ({ ({ "Sum", sum_cache||"", PER(sum_cache,sum_sum), sum_new||"",
		    PER(sum_new,sum_sum), sum_sum, "" }) });
      res_retcodes = html_table(title, rows);
    }
  }
  if(!cc_stats)
    return res_retcodes;
  array rows = ({});
  array times = ({});
  array title = ({ "Since", "Bytes", "Mode" });
  if(cf_detail)
    title += ({ "Cache file", "bytes", "idle" });
  title += ({ "Browser" });
  if(bc_detail)
    title += ({ "connection" });
  title += ({ "Server" });
  if(sc_detail)
    title += ({ "connection" });
  title += ({ "Request" });

  foreach(indices(mc->requests), object foo){
    string res = "";
    if(!objectp(foo))
      continue;
    string request = "";
    catch{request = foo->name;};
    if(request&&sizeof(request)){
      request = "\<a href=\"http://"+request+"\">"+
		(rq_detail||sizeof(request)<40?request:request[..37]+"...");
    }
    string server;
    if(catch(server = roxen->quick_ip_to_host((foo->from->query_address()/" ")[0]))||!server)
      server = "-" + (sc_detail?"\t":"");
    else if(sc_detail){
      string r;
      if(!catch(r=foo->from->query_fd())&&r)
        server += "\t"+r+":";
      if(!catch(r=replace(foo->from->query_address(1), " ", ":"))&&r)
        server += r;
      server += "->";
      if(!catch(r=replace(foo->from->query_address(), " ", ":"))&&r)
        server += r;
    }
    string cache;
    if(catch(cache = foo->new?(foo->cache?"caching":"new"):"cached"))
      cache = "-";
    if(cf_detail){
      cache += "\t";
      string r;
      if(!catch(r=foo->cache->file->query_fd())&&r)
        cache += r+":";
      if(!catch(r=(foo->cache->rfile/"roxen_cache/http/")[1])&&r)
        cache += r;
      cache += "\t";
      object stat;
      if(catch(stat=foo->cache->file->stat()))
        cache += "\t";
      else {
        int size;
        catch{size = stat[ST_SIZE]-foo->cache->headers->head_size;};
        cache += (size<=0?0:size) + "\t";
        int idle = time()-stat[ST_MTIME];
        if(idle>5)
          cache += idle + "s";
      }
    }
    string bytes;
    if(catch(bytes=foo->pipe->bytes_sent()/(sizeof(foo->ids)||1))||!bytes)
      bytes = "-";
    int done = 0;
    foreach(foo->ids, object id){
      if(!objectp(id))
	continue;
      int id_time;
      if(catch(id_time=id->time))
	continue;
      string since = (time()-id_time)+"s";
      string browser;
      if(catch(browser=id->my_fd->query_fd())||!browser){
	if(catch(browser="["+roxen->quick_ip_to_host(id->remoteaddr)+"]"+
			 (bc_detail?"\t":""))||
	   !browser)
	browser = "-" + (bc_detail?"\t":"");
      } else {
	browser = roxen->quick_ip_to_host(id->remoteaddr);
	if(bc_detail){
          string r;
          if(!catch(r=id->my_fd->query_fd())&&r)
	    browser += "\t"+r+":";
          if(!catch(r=replace(id->my_fd->query_address(), " ", ":"))&&r)
	    browser += r;
          browser += "->";
          if(!catch(r=replace(id->my_fd->query_address(1), " ", ":"))&&r)
	    browser += r;
	}
      }
      string res = since + "\t" + bytes + "\t" + cache + "\t" +
		   browser + "\t" + server + "\t" + request;
      times += ({ id_time });
      rows += ({ res/"\t" });
      done = 1;
    }
    if(!done){
      string res = "\t" + bytes + "\t" + cache +
		   (bc_detail?"\t-\t\t":"\t-\t") + server + "\t" + request;
      times += ({ time() });
      rows += ({ res/"\t" });
    }
  }

  if(sizeof(mc->requests)&&sizeof(rows)){
    times = sort(times, rows);
    return res_retcodes + html_table(title, rows);
  } else
    return res_retcodes + "<b>No current proxy connections.</b>";
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
      id->variables["first"]=1;
    }
    foreach(indices(o->modules->proxy->copies), int i){
      object out = o->modules->proxy->copies[i];
      gc();
#define ON(X) id->variables[X]!="0"&&id->variables[X]
      res+=status(out, 
		  ON("cf_detail"), ON("bc_detail"), ON("sc_detail"),
		  ON("rq_detail"), ON("rc_stats"), ON("cc_stats"));
    }
  }
  if(!strlen(res))
    return "<b>There are no active virtual servers.</b>";
  res += "<table>"
    "<tr>"
    "<td><var type=checkbox name=cf_detail></td><td>Cachefile details\n</td>"
    "<td><var type=checkbox name=sc_detail></td><td>Server connection details\n</td>"
    "<td><var type=checkbox name=rc_stats></td><td>HTTP returncode stats\n</td>"
    "</tr><tr>"
    "<td><var type=checkbox name=bc_detail></td><td>Browser connection details\n</td>"
    "<td><var type=checkbox name=rq_detail></td><td>Full request string\n</td>"
    "<td><var type=checkbox name=cc_stats default=on></td><td>Current connections\n</td>"
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

mixed handle(object id) { return wizard_for(id,0); }

