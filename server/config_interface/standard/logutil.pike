inherit "roxenlib";
#include <config.h>
#include <roxen.h>
#define LOCALE	LOW_LOCALE->config_interface
int __lt;
string describe_time(int t)
{
  int full;
  if(localtime(__lt)->yday != localtime(t)->yday)
  {
    __lt = t;
    full=1;
  }

  if(full)
    return capitalize(roxen->language(LOW_LOCALE->name,"date")(t));
  else
    return sprintf("%02d:%02d",localtime(t)->hour,localtime(t)->min);
}

string describe_interval(int i)
{
  switch(i)
  {
   case 0..50:       return LOW_LOCALE->seconds(i);
   case 51..3560:    return LOW_LOCALE->minutes(((i+20)/60));
   default:          return LOW_LOCALE->hours(((i+300)/3600));
  }
}

string describe_times(array (int) times)
{
  __lt=0;
  if(sizeof(times) < 6)
    return String.implode_nicely(map(times, describe_time), LOW_LOCALE->and);

  int d, every=1;
  int ot = times[0];
  foreach(times[1..], int t)
    if(d)
    {
      if(abs(t-ot-d)>(d/4))
      {
	every=0;
	break;
      }
      ot=t;
    } else
      d = t-ot;
  if(every && (times[-1]+d) >= time(1)-10)
    return (LOW_LOCALE->every +" "
	    +describe_interval(d)+" "+LOW_LOCALE->since+" "+
	    describe_time(times[0]));
  return String.implode_nicely(map(times[..4], describe_time)+({"..."})+
			map(times[sizeof(times)-3..], describe_time),
			LOCALE->and);
}

string fix_err(string s)
{
  sscanf(reverse(s), "%*[ \t\n]%s", s);
  s=reverse(s);
  if(s=="")
    return s;
  if(!(<'.','!','?'>)[s[-1]]) s+=".";
  return html_encode_string(capitalize(s));
}

int last_time;
string describe_error(string err, array (int) times,
		      string lang, int|void no_links)
{
  int code, nt;
  string links = "", reference, server;
  array(string) codetext=({ LOCALE->notice,
			    LOCALE->warning,
			    LOCALE->error });

  if(sizeof(times)==1 && times[0]/60==last_time) nt=1;
  last_time=times[0]/60;
  sscanf(err, "%d,%[^,],%s", code, reference, err);
  switch(no_links)
  {
    Configuration conf;
    RoxenModule module;
    case 2:
      sscanf(reference, "%[^/]", server);
      if(conf = roxen->find_configuration( server ))
	links += sprintf("<a href=\"%s\">%s</a> : ",
			 @get_conf_url_to_virtual_server( conf, lang ));
    case 1: // find_configuration(configinterface)->query_name() == realname
      if(module = get_module( reference ))
	links += sprintf("<a href=\"%s\">%s</a> : ",
			 @get_conf_url_to_module( module, lang ));
  }

  return "<table><tr><td valign=\"top\"><img src=&usr.err-"+code+"; \n"
	 "alt=\"" + codetext[code-1] + "\" />"
	  "</td><td>" + links + (nt?"":describe_times(times)+"<br />") +
	  replace(fix_err(err), "\n", "<br />\n") + "</table>";
}


// Returns ({ URL to module config page, human-readable (full) module name })
array(string) get_conf_url_to_module(string|object(RoxenModule) m, string|void lang)
{ // module is either a RoxenModule object or a string as returned by
  // get_modname(some RoxenModule), eg "ConfigInterface/piketag#0"
  RoxenModule module = stringp(m) ? get_module(m) : m;
  Configuration conf = module->my_configuration();
  string url_modname = replace(conf->otomod[module], "#", "!"),
	url_confname = conf->name;

  return ({ sprintf("/%s/sites/site.html/%s/modules/%s/",
		    lang || "standard", url_confname, url_modname),
	    get_modfullname(module) });
}

// Returns ({ URL to virtual server config page, virtual server name })
array(string) get_conf_url_to_virtual_server(string|object(Configuration) conf,
					     string lang)
{ // conf is either a conf object or the configuration's real name, eg "ConfigInterface"
  string url_confname;
  if(stringp(conf))
    conf = roxen->find_configuration(url_confname = conf);
  else
    url_confname = conf->name;

  return ({ sprintf("/%s/sites/site.html/%s/", lang || "standard", url_confname),
            conf->query_name() });
}
