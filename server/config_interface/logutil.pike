#include <config.h>
#include <roxen.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)
#define CALL(X,Y)	_LOCALE_FUN("roxen_config",X,Y)

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
    return capitalize(roxen->language(roxen.locale->get(),"date")(t));
  else
    return sprintf("%02d:%02d",localtime(t)->hour,localtime(t)->min);
}

string _units(string unit, int num)
{
  if(num==1) return "one "+unit;
  return num+" "+unit+"s";
}

string describe_interval(int i)
{
  switch(i) {
  case 0..50:
    return CALL("units", _units)("second", i);
  case 51..3560:
    return CALL("units", _units)("minute", ((i+20)/60));
  default:
    return CALL("units", _units)("hour", ((i+300)/3600));
  }
}

string describe_times(array (int) times)
{
  __lt=0;
  if(sizeof(times) < 6)
    return String.implode_nicely(map(times, describe_time),
				 LOCALE("cw", "and"));

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
    return (LOCALE(207, "every") +" "
	    +describe_interval(d)+" "+LOCALE(208, "since")+" "+
	    describe_time(times[0]));
  return String.implode_nicely(map(times[..4], describe_time)+({"..."})+
			map(times[sizeof(times)-3..], describe_time),
			LOCALE("cw", "and"));
}

string fix_err(string s)
{
  sscanf(reverse(s), "%*[ \t\n]%s", s);
  s=reverse(s);
  if(s=="")
    return s;
  if(!(<'.','!','?'>)[s[-1]]) s+=".";
  return Roxen.html_encode_string(capitalize(s));
}

int last_time;
string describe_error(string err, array (int) times,
		      string lang, int|void no_links)
{
  int code, nt;
  string links = "", reference, server;
  array(string) codetext=({ LOCALE(209, "Notice"),
			    LOCALE(210, "Warning"),
			    LOCALE(211, "Error") });

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
      if(module = Roxen.get_module( reference ))
	links += sprintf("<a href=\"%s\">%s</a> : ",
			 @get_conf_url_to_module( module, lang ));
  }

  return "<table class='logitems'><tr><td><img src=&usr.err-"+code+"; \n"
	 "alt=\"" + codetext[code-1] + "\" />"
	  "</td><td>" + links + (nt?"":describe_times(times)+"<br />") +
	  replace(fix_err(err), "\n", "<br />\n") + "</table>";
}


// Returns ({ URL to module config page, human-readable (full) module name })
array(string) get_conf_url_to_module(string|RoxenModule m, string|void lang)
{
  // module is either a RoxenModule object or a string as returned by
  // get_modname(some RoxenModule), eg "ConfigInterface/piketag#0"
  RoxenModule module = stringp(m) ? Roxen.get_module(m) : m;
  Configuration conf = module->my_configuration();
  string url_modname = replace(conf->otomod[module], "#", "!"),
	url_confname = conf->name;

  return ({ sprintf("/sites/site.html/%s/-!-/%s/?section=Information",
		   Roxen.http_encode_url(url_confname),
		   Roxen.http_encode_url(url_modname)),
	    Roxen.html_encode_string(Roxen.get_modfullname(module)) });
}

// Returns ({ URL to virtual server config page, virtual server name })
array(string) get_conf_url_to_virtual_server(string|Configuration conf,
					     string|void lang)
{
  // conf is either a conf object or the configuration's real name,
  // eg "ConfigInterface"
  string url_confname;
  if(stringp(conf))
    conf = roxen->find_configuration(url_confname = conf);
  else
    url_confname = conf->name;

  return ({ sprintf("/sites/site.html/%s/", 
		    Roxen.http_encode_url(url_confname)),
	    Roxen.html_encode_string(conf->query_name()) });
}


