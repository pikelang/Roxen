//
// Status exporter for Prometheus.
//

inherit "module";

constant cvs_version = "$Id$";

#include <module.h>

constant thread_safe = 1;

//<locale-token project="mod_prometheus">_</locale-token>
#define _(X, Y)	_DEF_LOCALE("mod_prometheus", X, Y)
// end of the locale related stuff

constant module_type = MODULE_LOCATION;
constant module_unique = 0;

LocaleString module_name = _(0, "Prometheus exporter");
LocaleString module_doc =
  _(0, "<p>Make server SNMP data available to Prometheus.</p>\n"
    "<p>Note: You may need a snmp port configured in the site to "
    "make this module work.</p>\n");

Configuration conf;

protected void create()
{
  defvar("location", "/prometheus/", _(0, "Mount point"),
	 TYPE_LOCATION|VAR_INITIAL|VAR_NO_DEFAULT,
	 _(0, "Where the module will be mounted in the site's virtual "
	   "file system."));
}

void start(int when, Configuration conf)
{
  this::conf = conf;
}

int|object|mapping find_file(string f, RequestID id)
{
  if (f != "") return 0;

  Stdio.Buffer buf = Stdio.Buffer();

  foreach(get_snmp_rows(), mapping row) {
    fmt_snmp_value(buf, row);
  }

  return Roxen.http_string_answer((string)buf, "text/plain");
}

void fmt_snmp_value(Stdio.Buffer buf, mapping entry)
{
  string name = sprintf("%s-%s-%s",
			entry->plugin, entry->plugin_instance,
			entry->type_instance);
  buf->sprintf("# HELP %s %s\n", name, entry->doc || "");
  buf->sprintf("# TYPE %s %s\n", name, entry->type);
#if 0
  if (entry->oid) {
    buf->sprintf("%O\n", entry);
  }
#endif

  if (floatp(entry->value)) {
    buf->sprintf("%s %g\n", name, entry->value);
  } else if (arrayp(entry->value)) {
    foreach(entry->value; int i; mapping subval) {
      if (!subval) continue;
      if (entry->aspects) {
	entry->aspects -= ({ "suffix" });
      }
      array(string) aspects = entry->aspects;
      foreach (aspects || ({}), string aspect) {
	if (undefinedp(subval[aspect])) {
	  aspects -= ({ aspect });
	}
      }
      if (!aspects || sizeof(aspects)) {
	if (subval->suffix || entry->suffix) {
	  buf->sprintf("%s_%s{", name, subval->suffix || entry->suffix);
	} else {
	  buf->sprintf("%s{", name);
	}
	if (sizeof(aspects || ({}))) {
	  foreach(aspects; int j; string aspect) {
	    int|float|string a_value = subval[aspect];
	    if (j) {
	      buf->sprintf(",%s=", aspect);
	    } else {
	      buf->sprintf("%s=", aspect);
	    }
	    if (intp(a_value)) {
	      buf->sprintf("%d", a_value);
	    } else if (floatp(a_value)) {
	      buf->sprintf("%g", a_value);
	    } else {
	      buf->sprintf("%q", a_value);
	    }
	  }
	} else {
	  buf->sprintf("index=%d", i);
	}
	buf->add("} ");
      } else {
	if (subval->suffix || entry->suffix) {
	  buf->sprintf("%s_%s ", name, subval->suffix || entry->suffix);
	} else {
	  buf->sprintf("%s ", name);
	}
      }
      if (floatp(subval->value)) {
	buf->sprintf("%g\n", subval->value);
      } else if (intp(subval->value)) {
	buf->sprintf("%d\n", subval->value);
      } else {
	buf->sprintf("0\n# ERROR %O\n", entry);
      }
    }
  } else {
    if (entry->suffix) {
      buf->sprintf("%s_%s %d\n", name, entry->suffix, entry->value);
    } else {
      buf->sprintf("%s %d\n", name, entry->value);
    }
  }
  // buf->sprintf("%O\n", entry);
}

protected string histogram_suffix(mapping entry)
{
  string oid = entry->oid;
  while(has_suffix(oid, ".0")) {
    oid = oid[..sizeof(oid)-3];
  }
  if (has_suffix(oid, ".1")) return "sum";
  return "bucket";
}

array(mapping) get_snmp_rows()
{
  array(mapping) res =
    get_global_snmp()+
    get_cache_snmp()+
    get_site_snmp()+
    get_module_snmp(conf->find_module("print-clients#0"), 0)+
    get_module_snmp(conf->find_module("print-backup#0"), 1)+
    get_module_snmp(conf->find_module("feed-import#0"), 2)+
    get_module_snmp(conf->find_module("image#0"), 3)+
    get_module_snmp(conf->find_module("print-indesign-server#0"), 4)+
    get_module_snmp(conf->find_module("print-db#0"), 5);

  RoxenModule memory_logger_module = conf->find_module("memory_logger#0");
  if(memory_logger_module && sizeof(memory_logger_module->pmem))
    res += get_module_snmp(memory_logger_module, 6);

  foreach(({ ([ "oid_prefix": "1.3.6.1.4.1.8614.1.1.1.7.1.3",
		"aspects": ({ "ge", "suffix" }),
		"type": "histogram",
		"suffix": histogram_suffix,
		"ge":
		lambda(mapping entry) {
		  string suffix =
		    entry->type_instance[sizeof("handlerNumRuns")..];
		  if (sizeof(suffix)) return suffix;
		  return UNDEFINED;
		},
	     ]),
	     ([ "oid_prefix": "1.3.6.1.4.1.8614.1.1.1.7.2.3",
		"aspects": ({ "ge", "suffix" }),
		"type": "histogram",
		"suffix": histogram_suffix,
		"ge":
		lambda(mapping entry) {
		  string suffix =
		    entry->type_instance[sizeof("bgNumRuns")..];
		  if (sizeof(suffix)) return suffix;
		  return UNDEFINED;
		},
	     ]),
	     ([ "oid_prefix": "1.3.6.1.4.1.8614.1.1.1.7.3.3",
		"aspects": ({ "ge", "suffix" }),
		"type": "histogram",
		"suffix": histogram_suffix,
		"ge":
		lambda(mapping entry) {
		  string suffix =
		    entry->type_instance[sizeof("coNumRuns")..];
		  if (sizeof(suffix)) return suffix;
		  return UNDEFINED;
		},
	     ]),
	     ([ "oid_prefix": "1.3.6.1.4.1.8614.1.1.2.9.1.2",
		"aspects": ({ "ge", "suffix" }),
		"type": "histogram",
		"suffix": histogram_suffix,
		"ge":
		lambda(mapping entry) {
		  string suffix =
		    entry->type_instance[sizeof("requestNumRuns")..];
		  if (sizeof(suffix)) return suffix;
		  return UNDEFINED;
		},
	     ]),
	     ([ "oid_prefix": "1.3.6.1.4.1.8614.1.1.2.9.2.2",
		"aspects": ({ "ge", "suffix" }),
		"type": "histogram",
		"suffix": histogram_suffix,
		"ge":
		lambda(mapping entry) {
		  string suffix =
		    entry->type_instance[sizeof("handleNumRuns")..];
		  if (sizeof(suffix)) return suffix;
		  return UNDEFINED;
		},
	     ]),
	     ([ "oid_prefix": "1.3.6.1.4.1.8614.1.1.2.9.3.2",
		"aspects": ({ "ge", "suffix" }),
		"type": "histogram",
		"suffix": histogram_suffix,
		"ge":
		lambda(mapping entry) {
		  string suffix =
		    entry->type_instance[sizeof("queueNumRuns")..];
		  if (sizeof(suffix)) return suffix;
		  return UNDEFINED;
		},
	     ]),
	     /* Start (fake) module oids. */
	     ([ "oid_prefix": "-1.0.2",
		"aspects": ({ "interval" }),
		"interval":
		lambda(mapping entry) {
		  string suffix =
		    entry->type_instance[sizeof("activeBrowserUsers")..];
		  if (sizeof(suffix)) return suffix;
		  return "since start";
		},
	     ]),
	     ([ "oid_prefix": "-1.0.3",
		"aspects": ({ "interval" }),
		"interval":
		lambda(mapping entry) {
		  string suffix =
		    entry->type_instance[sizeof("activeAppLauncherUsers")..];
		  if (sizeof(suffix)) return suffix;
		  return "since start";
		},
	     ]),
	     ([ "oid_prefix": "-1.0.4",
		"aspects": ({ "interval" }),
		"interval":
		lambda(mapping entry) {
		  string suffix =
		    entry->type_instance[sizeof("activePlannerUsers")..];
		  if (sizeof(suffix)) return suffix;
		  return "since start";
		},
	     ]),
	     ([ "oid_prefix": "-1.0.5",
		"aspects": ({ "interval" }),
		"interval":
		lambda(mapping entry) {
		  string suffix =
		    entry->type_instance[sizeof("activeBadBrowserUsers")..];
		  if (sizeof(suffix)) return suffix;
		  return "since start";
		},
	     ]),
	     ([ "oid_prefix": "-1.0.6",
		"aspects": ({ "interval" }),
		"interval":
		lambda(mapping entry) {
		  string suffix =
		    entry->type_instance[sizeof("activeBadAppLauncherUsers")..];
		  if (sizeof(suffix)) return suffix;
		  return "since start";
		},
	     ]),
	     ([ "oid_prefix": "-1.0.7",
		"aspects": ({ "interval" }),
		"interval":
		lambda(mapping entry) {
		  string suffix =
		    entry->type_instance[sizeof("activeBadPlannerUsers")..];
		  if (sizeof(suffix)) return suffix;
		  return "since start";
		},
	     ]),
	     ([ "oid_prefix": "-1.5.15",
		"type": "histogram",
		"aspects": ({ "suffix" }),
		"suffix": "sum",
	     ]),
	     ([ "oid_prefix": "-1.5.19",
		"aspects": ({ "ge", "suffix" }),
		"type": "histogram",
		"suffix": "bucket",
		"ge":
		lambda(mapping entry) {
		  string suffix =
		    entry->type_instance[sizeof("numActions")..];
		  if (sizeof(suffix)) return suffix;
		  return "since start";
		},
		"type_instance": "numActions",
	     ]),
	  }), mapping consolidator) {
    mapping new_entry;
    foreach(res; int i; mapping entry) {
      if (!has_prefix(entry->oid, consolidator->oid_prefix + ".")) {
	continue;
      }
      if (!new_entry) {
	res[i] = new_entry = ([]);
	new_entry->value = ({ entry });
	new_entry->oid = consolidator->oid_prefix;
	foreach(({ "aspects", "doc", "plugin", "plugin_instance",
		   "type", "type_instance" }), string field) {
	  new_entry[field] = consolidator[field] || entry[field];
	}
      } else {
	res[i] = 0;
	new_entry->value += ({ entry });
      }
      foreach(consolidator->aspects || ({}), string aspect) {
	string aspect_val = callablep(consolidator[aspect])?
	  consolidator[aspect](entry):consolidator[aspect];
	if (undefinedp(aspect_val)) continue;
	entry[aspect] = aspect_val;
      }
    }

    res -= ({ 0 });
  }

  // Convert ge-histograms into le-histograms to make
  // Prometheus happy.
  mapping(string:int|float) sums = ([]);
  for(int j = 0; j < 2; j++) {	// NB: Loop in case sum comes after buckets.
    int misses;
    foreach(res; int i; mapping entry) {
      if (entry->type != "histogram") continue;
      string key = sprintf("%s-%s-%s",
			   entry->plugin, entry->plugin_instance,
			   entry->type_instance);
      foreach(arrayp(entry->value)?entry->value:({ entry }), mapping subval) {
	if (subval->suffix == "sum") {
	  sums[key] = subval->value;
	} else if ((subval->suffix == "bucket") && subval->ge) {
	  int|float val = sums[key];
	  if (undefinedp(val)) {
	    if (j) {
	      werror("PROMETHEUS (%O): No sum for histogram %O!\n", conf, key);
	    }
	    misses++;
	    continue;
	  }
	  subval->value = val - subval->value;
	  subval->le = m_delete(subval, "ge");
	  if (subval->aspects) {
	    subval->aspects = replace(subval->aspects, "ge", "le");
	  }
	}
      }
      if (!misses && entry->aspects) {
	entry->aspects = replace(entry->aspects, "ge", "le");
      }
    }
    if (!misses) break;
  }

  return res;
}

Protocol get_snmp_prot()
{
  foreach(conf->registered_urls, string url) {
    mapping(string:string|Configuration|Protocol|array(Protocol)) port_info =
      roxen.urls[url];

    foreach((port_info && port_info->ports) || ({}), Protocol prot) {
      if ((prot->prot_name == "snmp") && (prot->mib))
	return prot;
    }
  }
}

array(mapping) get_global_snmp()
{
  Protocol prot = get_snmp_prot();
  if(!prot)
    return ({});

  return get_snmp_values(prot->mib, SNMP.RIS_OID_WEBSERVER + ({ 1 }), "global",
			 ({
			   SNMP.RIS_OID_WEBSERVER + ({ 1, 3 }),     // DBManager
   			   SNMP.RIS_OID_WEBSERVER + ({ 1, 8 }),     // Pike memory
			 }),
			 ({
			   "activeFDCount",
			   "virtualMemory",
			   "residentMemory",
			 }) );
}

array(mapping) get_cache_snmp()
{
  Protocol prot = get_snmp_prot();
  if(!prot)
    return ({});

  return get_snmp_values(prot->mib, SNMP.RIS_OID_WEBSERVER + ({ 3 }), "cache",
			 ({
			 }),
			 ({
			   "cache-*-name",
			   "cache-*-numEntries",
			   "cache-*-numBytes",
			   "cache-*-numHits",
			   "cache-*-costHits",
			   "cache-*-byteHits",
			   "cache-*-numMisses",
			   "cache-*-costMisses",
			   "cache-*-byteMisses",
			 }) );
}

array(mapping) get_site_snmp()
{
  Protocol prot = get_snmp_prot();
  if(!prot)
    return ({});

  return get_snmp_values(prot->mib, conf->query_oid(), "site",
			 ({ conf->query_oid() + ({ 8 }),
			    SNMP.RIS_OID_WEBSERVER + ({ 3 })        // Cache
			 }) );
}

array(mapping) get_module_snmp(RoxenModule o, int mod_no)
{
  if (!o || !o->query_snmp_mib) return ({});

  // Use fake oid:s below, since we are only interested in the values not the actual address.
  ADT.Trie mib = o->query_snmp_mib(({ -1, mod_no }), ({}));
  return get_snmp_values(mib, ({}), (o->sname()/"#")[0], 0,
			 ({ "backupDiskCapacity",
			    "backupDiskUsed",
			    "backupDiskFree",

			    "minFeedDiskCapacity",
			    "minFeedDiskUsed",
			    "minFeedDiskFree",

			    "databaseDiskCapacity",
			    "databaseDiskUsed",
			    "databaseDiskFree",
			    "numPublications",
			    "numEditions",
			    "numPages",
			    "numPageVersions",
			    "numStories",
			    "numStoryItems",
			    "numStoryItemVersions",
			    "numFeedItems",
			    "numPageSlots",
			    "numPageGroups"
			 }) );
}

mapping type_mapping = ([ "STRING": 0,
			  "GAUGE": "gauge",
			  "COUNTER": "counter",
			  "COUNTER64": "counter",
			  "TICK": "gauge",
			  "INTEGER": "gauge" ]);

string mangle_snmp_label(string label)
{
  return replace(label,
		 ({ "GDS(1)", "GDS(cpu time)", "GDS(real time)", "(", ")", "<", ">"," " }),
		 ({ "0", "1", "2", "_", "_", "_", "_", "_" }));
}

array(mapping) get_snmp_values(ADT.Trie mib,
			      array(int) oid_start,
			      string plugin_instance,
			      void|array(array(int)) oid_ignores,
			      void|array(string) name_ignores)
{
  //  werror("get_snmp_values(mib, %O, %O, %O)\n",
  //	 (array(string))oid_start*".", plugin_instance_suffix,
  //	 oid_ignores?(array(string))oid_ignores*".":0);
  array(mapping) res = ({});

 outer:
  for (array(int) oid = oid_start; oid; oid = mib->next(oid)) {
    if (!has_prefix((string)oid, (string)oid_start)) {
      // Reached end of the oid subtree.
      break;
    }
    if(oid_ignores)
      foreach(oid_ignores, array(int) oid_ignore)
	if (oid_ignore && has_prefix((string)oid, (string)oid_ignore)) continue outer;
    string name = "";
    mixed val = "";
    string snmp_type = "";
    string doc = "";
    float update;
    mixed err = catch {
	val = mib->lookup(oid);
	if (zero_type(val)) continue;
	if (objectp(val)) {
	  name = val->name || "";
	  snmp_type = val->type_name;
	  doc = val->doc || "";
	  if(name_ignores && glob(name_ignores, name))
	    continue;
	  if (val->update_value) {
	    update = gauge {
		val->update_value();
	      };
	  }
	  val = val->value;
	}
	val = (string)val;
      };
    if (err) {
      name = "Error";
      val = "";
    }

    val = (int)val;
    if (snmp_type == "TICK") {
      // Convert centiseconds to seconds.
      val /= 100.0;
      doc = replace(doc, "centisecond", "second");
    }

    string type = type_mapping[snmp_type];
    if(type) {
      res += ({ ([ "plugin":          "roxen",
		   "plugin_instance": plugin_instance,
		   "type":            type,
		   "snmp_type":       snmp_type,
		   "type_instance":   mangle_snmp_label(name),
		   "timestamp":       time(),
		   "value":           val,
		   "update_time":     update,
		   "oid":             (array(string))oid*".",
		   "doc":             doc
		]) });
    }
  }
  return res;
}
