string cvs_version = "$Id: hosts.pike,v 1.8.2.1 1997/03/02 19:15:14 grubba Exp $";
#include <roxen.h>
#include <module.h> // For VAR_VALUE define.
#if DEBUG_LEVEL > 7
#ifndef HOST_NAME_DEBUG
# define HOST_NAME_DEBUG
#endif
#endif

inherit "module_support";

import files;
import Stdio;

#if 0
inline nomask private static 
string|int|array(string|int|array(int)) query(string varname) 
{
  return module_support::query(varname);
}
#endif
object *out = ({ });
int curr;


void died(object o) { if(objectp(o)) { out -= ({ o }); destruct(o);  } }

int lookup(int mode, string name)
{
  string to_send;
  int tmp;
  int sent;

  to_send=sprintf("%o%c%s", strlen(name), mode, name);
#ifdef HOST_NAME_DEBUG
  report_debug(sprintf("Hostnames: Lookup %c <%s>  (%s)\n", 
		       mode, name, to_send));
#endif
  if(!sizeof(out))
  {
    /*
    report_error("Hostnames: Fatal host name lookup failure: "+
		 "No processes left (killed of?).\n");
    */
    return 0;
  }

  curr=(curr+1)%sizeof(out);
  while(sent <  strlen(to_send))
  {
    curr=(curr)%sizeof(out);
    if((tmp=out[curr]->write(to_send[sent..strlen(to_send)-1])) < 0)
    {
//      report_error("Hostnames: Write failed.\n");
      if(sizeof(out)-1 >= curr)
      {
	died(out[curr]);
	return lookup(mode, name);
      }
      return 0;
    }
    sent += tmp;
  }
  return 1;
}

mapping (string:mixed *) do_when_found=([]);

void notify(mixed *callbacks, string res)
{
  mixed *c;
  if(!arrayp(callbacks))
    return 0;
  foreach(callbacks, c)
    c[0](res, @c[1]);
}

void got_one_result(object o, string res)
{
  int lenf, lent;
  string from, to;
  int dir;
    
#ifdef HOST_NAME_DEBUG
  report_debug("Hostnames: Got one result <"+res+">\n");
#endif

  if(!(res && strlen(res))) return 0;

  while(strlen(res))
  {
    if(strlen(res) < 5)
      res+=o->read(5-strlen(res));
  
    lenf=(int)("1"+res[1..4])-10000;
    if(strlen(res) < (8+lenf))
      res+=o->read((8+lenf)-strlen(res));

    lent=(int)("1"+res[(5+lenf)..(8+lenf)])-10000;

    if(lent  && strlen(res) < 9+lenf+lent)
      res+=o->read(9+lenf+lent-strlen(res));

    dir=res[0];
    from=res[5..lenf+4];

    if(lent)
      to=res[9+lenf..8+lenf+lent];
    else
      to=0;
#ifdef HOST_NAME_DEBUG
    report_debug("Hostnames:   ---- <"+from+"> == <"+to+"> ----\n");
#endif
    if(do_when_found[from]) 
      notify(do_when_found[from], to);
    m_delete(do_when_found, from);

    if(strlen(from))
    /* Save them in the cache for a while, to speed things up a bit... */
      cache_set("hosts", from, ({ to, time(1)+(to?3600:10) }));
    if(to && strlen(to))
      cache_set("hosts", to , ({ from, time(1)+3600 }));
    res=res[9+lenf+lent..100000];
  }
}


string blocking_ip_to_host(string ip)
{
  array addr;
  if(!(int)ip) return ip;
  addr = gethostbyaddr( ip );
  if(do_when_found[ip]) 
    notify(do_when_found[ip], addr&&addr[0][random(sizeof(addr[0]))]);
  m_delete(do_when_found, ip);
  return addr?addr[0]:ip;
}

string blocking_host_to_ip(string host)
{
  array addr;
  if((int)host) return host;
  addr = gethostbyname( host );
  if(do_when_found[host]) 
    notify(do_when_found[host], addr[0][random(sizeof(addr[0]))]);
  m_delete(do_when_found, host);
  return addr?addr[0][random(sizeof(addr[0]))]:host;
}

string quick_ip_to_host(string ipnumber)
{
#ifdef NO_REVERSE_LOOKUP
  return ipnumber;
#else
  mixed foo;

  if(stringp(ipnumber) && strlen(ipnumber))
    ipnumber=(ipnumber/" ")[0];
  else
    return ipnumber;
  
  if(!(int)ipnumber) return ipnumber;

  if(foo=cache_lookup("hosts", ipnumber))
  {
    return foo[0] || ipnumber;
  } else if(!do_when_found[ipnumber]) {
    do_when_found[ipnumber] = ({ }); // No callback, but the request is on...
    lookup(IP_TO_HOST, ipnumber);
    return ipnumber;
  }
  return ipnumber;
#endif
}

string quick_host_to_ip(string h)
{
  mixed entry = h / "." - ({""});
  int isip;
  string s;
  if(sizeof(entry) == 4) 
  { // Could be an ip number
    foreach(entry, s)
      if((string)((int)s) != s) {
	isip = 0;
	break;
      } else
	isip = 1;
  }
  if(isip) 
    return h;
  if(h[-1] == '.')
    h=h[0..strlen(h)-2];
  return cache_lookup("hosts", h) || h;
}

varargs void ip_to_host(string ipnumber, function callback, mixed ... args)
{
#ifdef NO_REVERSE_LOOKUP
  return callback(ipnumber, @args);
#else
  mixed *entry;

  if(!((int)ipnumber))
    return callback(ipnumber, @args);

  if(entry=cache_lookup("hosts", ipnumber))
    if((entry[1] > time(1)) && entry[0]) // No negative caching.
      return callback(entry[0], @args);
  if(!sizeof(out))
    return callback(ipnumber, @args);

  if(!do_when_found[ipnumber])
  {
    if(lookup(IP_TO_HOST, ipnumber))
      do_when_found[ipnumber] = ({ ({ callback, args }) });
    else
      return callback(ipnumber, @args);
  } else {
    do_when_found[ipnumber] += ({ ({ callback, args }) });
  }
#endif
}

varargs void host_to_ip(string host, function callback, mixed ... args)
{
  mixed *entry;
  string s;
  int isip;
  if(!stringp(host) || !strlen(host))
    return callback(0, @args);
  if(host[-1] == '.')
    host=host[0..strlen(host)-2];
  entry = host / "." - ({""});
  if(sizeof(entry) == 4) 
  { // Could be an ip number
    foreach(entry, s)
      if((string)((int)s) != s) {
	isip = 0;
	break;
      } else
	isip = 1;
  }
  if(isip) 
    return callback(host,  @args);

  if(entry=cache_lookup("hosts", host))
    if((entry[1] > time(1)) && entry[0])
      return callback(entry[0], @args);

  if(!sizeof(out))
    return callback(host, @args);

  if(!do_when_found[ host ])
  {
    if(lookup(HOST_TO_IP, host))
      do_when_found[host] = ({ ({ callback, args }) });
    else
      return callback(host, @args);
  } else {
    do_when_found[host] += ({ ({ callback, args }) });
  }
}

void nil(){}

void create_host_name_lookup_processes()
{
  object out2;
  int i, j;

  j=this_object()->variables->NumHostnameLookup[VAR_VALUE];

  if(!j) j=1;

  out=allocate(j);
  for(i=0; i<j; i++)
  {
    out[i]=file();
    if (!(out2=out[i]->pipe())) {
      error("Couldn't create pipe! Out of fd's?\n");
    }
    mark_fd(out[i]->query_fd(), "Host name lookup local end of pipe.\n");
    spawne("bin/roxen_hostname", ({}),0, out2, out2, stderr);
    destruct(out2);
    out[i]->set_nonblocking(got_one_result, nil, died);
  }
}
 

