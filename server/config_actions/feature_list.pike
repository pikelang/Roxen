/*
 * $Id: feature_list.pike,v 1.2 1997/11/30 16:08:58 grubba Exp $
 */

inherit "wizard";

import Array;

constant name = "Development//Pike feature-list";

constant doc = "Shows which Pike-modules which are enabled.";

constant more = 1;

mapping(string:int) modules = ([]);

void find_modules()
{
  object m = master();

  modules = ([]);

  if(!_static_modules["Regexp"]) {
    modules["dynamic_modules"] = 1;
  } else {
    modules["dynamic_modules"] = -1;
  }

#if efun(thread_create)
  modules["threads"] = 1;
#else
  modules["threads"] = -1;
#endif /* thread_create */

  foreach(m->pike_module_path, string p) {
    array files;
    catch { files = get_dir(p); };
    if (files) {
      foreach(glob("*.so", files), string f) {
	string s = (f/".so")[0];

	catch {
	  mixed val = m->resolv(s);
	  if (objectp(val)) {
	    if (sizeof(indices(val))) {
	      modules[s] = 1;
	    } else {
	      modules[s] = -1;
	    }
	  } else if (val) {
	    modules[s] = 1;
	  }
	};
      }
      foreach(glob("*.pmod", files), string f) {
	string s = (f/".pmod")[0];

	if (!modules[s]) {
	  catch {
	    mixed val = m->resolv(s);
	    if (objectp(val)) {
	      if (sizeof(indices(val))) {
		modules[s] = 1;
	      } else {
		modules[s] = -1;
	      }
	    } else if (val) {
	      modules[s] = 1;
	    }
	  };
	}
      }
    }
  }
  // These modules only add efuns.
  foreach(({ "call_out", "math", "sprintf", "system" }), string s) {
    if (modules[s]) {
      modules[s] = 1;
    }
  }
}

mixed page_0(object id, object mc)
{
  if (!sizeof(modules)) {
    find_modules();
  }
  string res = "<b>Features:</b><ul>\n";
  foreach(({ "dynamic_modules", "threads", "_Crypto", "CommonLog",
	     "Dbm", "Gdbm", "Gmp", "Gz", "MIME",
	     "Msql", "Mysql", "Odbc", "Oracle", "Postgres", "Ssleay",
	     "WideValues", "X", "Yp" }), string s) {
    if (modules[s] == 1) {
      res += " "+s;
    }
  }
  res += "</ul><br>\n";
  array disabled = sort(filter(indices(modules),
			       lambda(string s, mapping m) {
				 return(m[s] != 1);
			       }, modules));
  if (sizeof(disabled)) {
    res += "<b>Disabled modules:</b><ul>\n";
    res += disabled * " ";
    res += "</ul><br>\n";
  }
  return(res);
}

mixed page_1(object id, object mc)
{
  if (!sizeof(modules)) {
    find_modules();
  }
  return("<b>All modules:</b><ul>\n" +
	 html_table(({ "Module name", "State" }),
		    map(sort(indices(modules)),
			lambda(string s, mapping r) {
			  return ({
			    s,
			    ({
			      "<font color='#ff0000'><b>Disabled</b></font>",
			      "N/A", "Enabled" })[ r[s] + 1]
			  });
			}, modules)) +
	 "</ul>\n");
}

mixed handle(object id)
{
  return wizard_for(id, 0);
}
