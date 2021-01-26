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

  NOCACHE(); // Disable protocol cache

  Stdio.Buffer buf = Stdio.Buffer();

  foreach(get_snmp_rows(), PrometheusValue val) {
     val->fmt(buf);
  }

  return Roxen.http_string_answer((string)buf, "text/plain");
}

class PrometheusValue(string name)
{
  // Mapping (suffix|zero: mapping(aspects|zero: array(value, aspects)))
  mapping(string:mapping(string:array(mixed))) values = ([]);
  string type;
  string doc;

  string render_aspects(mapping aspects)
  {
    if (!aspects || !sizeof(aspects)) return UNDEFINED;
    Stdio.Buffer buf = Stdio.Buffer();
    foreach(sort(indices(aspects)); int i; string a) {
      if (i) buf->add(", ");
      buf->add(a, "=");
      mixed v = aspects[a];
      if (floatp(v)) {
	buf->sprintf("%g", v);
      } else if (intp(v)) {
	buf->sprintf("%d", v);
      } else {
	buf->add(v);
      }
    }
    return (string)buf;
  }

  void add_value(mixed val, string|void suffix, mapping|void aspects,
		 string|void oid)
  {
    mapping suffix_values = values[suffix];
    if (!suffix_values) {
      suffix_values = values[suffix] = ([]);
    }
    suffix_values[render_aspects(aspects)] = ({ val, aspects, oid });
  }

  void fmt_one_value(Stdio.Buffer buf, mixed val, string|void suffix,
		     string|mapping|void aspects, string|void oid)
  {
#if 0
    if (oid) {
      buf->add("## OID ", oid, "\n");
    }
#endif

    buf->add(name);

    if (suffix) {
      buf->add("_", suffix);
    }

    if (aspects) {
      if (mappingp(aspects)) {
	aspects = render_aspects(aspects);
      }

      buf->add("{", aspects, "}");
    }

    buf->add(" ");

    if (floatp(val)) {
      buf->sprintf("%g\n", val);
    } else {
      buf->sprintf("%d\n", val);
    }
  }

  void fmt_value(Stdio.Buffer buf)
  {
    foreach(sort(indices(values)), string suffix) {
      mapping suffix_values = values[suffix];
      foreach(sort(indices(suffix_values)), string aspects) {
	fmt_one_value(buf, suffix_values[aspects][0], suffix, aspects,
		      suffix_values[aspects][2]);
      }
    }
  }

  void fmt(Stdio.Buffer buf)
  {
    if (doc) {
      buf->sprintf("# HELP %s %s\n", name, doc);
    }
    if (type) {
      buf->sprintf("# TYPE %s %s\n", name, type);
    }

    fmt_value(buf);
  }
}

class Histogram
{
  inherit PrometheusValue;

  string type = "histogram";

  void fmt(Stdio.Buffer buf)
  {
    int count;
    if (!values->count) {
      // Paranoia.
      add_value(100, "count");
    }
    count = values->count[0][0];

    if (!values->bucket || !values->bucket["le=+Inf"]) {
      add_value(count, "bucket", ([ "le": "+Inf" ]), values->count[0][2]);
    }

    // Convert ge-histograms into le-histograms to make
    // Prometheus happy.
    foreach(values->bucket; string aspects; array val) {
      if (val[1]->ge) {
	add_value(count - val[0], "bucket", ([ "le": val[1]->ge ]), val[2]);
	m_delete(values->bucket, aspects);
      }
    }

    ::fmt(buf);
  }
}

protected string histogram_label(mapping entry, string name)
{
  string label = entry->type_instance[sizeof(name)..];
  if (!sizeof(label)) return UNDEFINED;
  if (has_suffix(label, "s")) {
    label = label[..sizeof(label)-2];
  }
  if (has_prefix(label, "0") && !has_value(label, ".")) {
    label = "0." + label[1..];
  }
  return label;
}

protected string histogram_suffix(mapping entry)
{
  string oid = entry->oid;
  while(has_suffix(oid, ".0")) {
    oid = oid[..sizeof(oid)-3];
  }
  if (has_suffix(oid, ".1")) return "count";
  return "bucket";
}

array(PrometheusValue) get_snmp_rows()
{
  array(mapping) snmp_res =
    get_global_snmp()+
    get_cache_snmp()+
    get_site_snmp();

  // NB: Order below is relevant. Only add new modules to the end.
  //     Replace obsolete/removed modules with 0 or UNDEFINED.
  foreach(({ "print-clients", "print-backup", "feed-import",
	     "image", "print-indesign-server", "print-db",
	     "memory_logger" }); int i; string modname) {
    if (!modname) continue;
    RoxenModule mod = conf->find_module(modname + "#0");
    if(mod) {
      if ((modname == "memory_logger") && !sizeof(mod->pmem)) {
	// Not initialized yet.
	continue;
      }
      snmp_res += get_module_snmp(mod, i);
    }
  }

  mapping(string:PrometheusValue) vals = ([]);

  void add_entry(mapping entry)
  {
    string name = sprintf("%s_%s_%s",
			  entry->plugin,
			  replace(entry->plugin_instance, "-", "_"),
			  replace(entry->type_instance, "-", "_"));

    PrometheusValue val = vals[name];
    if (!val) {
      program(PrometheusValue) prog = ([
	"histogram": Histogram,
      ])[entry->type] || PrometheusValue;
      val = vals[name] = prog(name);
      val->type = entry->type;
    }
    if (!val->doc) val->doc = entry->doc;

    mapping aspects = ([]);
    foreach(entry->aspects || ({}), string a) {
      if (a == "suffix") continue;
      if (undefinedp(entry[a])) continue;
      aspects[a] = entry[a];
    }

    val->add_value(entry->value, entry->suffix, aspects, entry->oid);
  };

  foreach(snmp_res; int i; mapping entry) {
    foreach(({ ([ "oid_prefix": "1.3.6.1.4.1.8614.1.1.1.5",
		  "type_instance": "cpuTime",
		  "aspects": ({ "mode" }),
		  "mode":
		  lambda(mapping entry) {
		    return entry->type_instance == "userTime" ? "user" :
		      "system";
		  },
		  "doc": "Total cpu time expressed in centiseconds."
	       ]),
	       ([ "oid_prefix": "1.3.6.1.4.1.8614.1.1.1.7.1.2",
		  "type_instance": "handlerTime",
		  "aspects": ({ "mode" }),
		  "mode":
		  lambda(mapping entry) {
		    if (entry->type_instance == "handlerTime") {
		      add_entry(entry + ([
				  "aspects": ({ "suffix" }),
				  "suffix":"sum",
				  "type":"histogram",
				  "type_instance": "handlerNumRuns",
				]));
		      return "user";
		    }
		    return "system";
		  },
	       ]),
	       ([ "oid_prefix": "1.3.6.1.4.1.8614.1.1.1.7.1.3",
		  "type_instance": "handlerNumRuns",
		  "aspects": ({ "ge", "suffix" }),
		  "type": "histogram",
		  "suffix": histogram_suffix,
		  "ge":
		  lambda(mapping entry) {
		    return histogram_label(entry, "handlerNumRuns");
		  },
	       ]),
	       ([ "oid_prefix": "1.3.6.1.4.1.8614.1.1.1.7.2.2",
		  "type_instance": "bgTime",
		  "aspects": ({ "mode" }),
		  "mode":
		  lambda(mapping entry) {
		    if (entry->type_instance == "bgTime") {
		      add_entry(entry + ([
				  "aspects": ({ "suffix" }),
				  "suffix":"sum",
				  "type":"histogram",
				  "type_instance": "bgNumRuns",
				]));
		      return "user";
		    }
		    return "system";
		  },
	       ]),
	       ([ "oid_prefix": "1.3.6.1.4.1.8614.1.1.1.7.2.3",
		  "type_instance": "bgNumRuns",
		  "aspects": ({ "ge", "suffix" }),
		  "type": "histogram",
		  "suffix": histogram_suffix,
		  "ge":
		  lambda(mapping entry) {
		    return histogram_label(entry, "bgNumRuns");
		  },
	       ]),
	       ([ "oid_prefix": "1.3.6.1.4.1.8614.1.1.1.7.3.2",
		  "type_instance": "coTime",
		  "aspects": ({ "mode" }),
		  "mode":
		  lambda(mapping entry) {
		    if (entry->type_instance == "coTime") {
		      add_entry(entry + ([
				  "aspects": ({ "suffix" }),
				  "suffix":"sum",
				  "type":"histogram",
				  "type_instance": "coNumRuns",
				]));
		      return "user";
		    }
		    return "system";
		  },
	       ]),
	       ([ "oid_prefix": "1.3.6.1.4.1.8614.1.1.1.7.3.3",
		  "type_instance": "coNumRuns",
		  "aspects": ({ "ge", "suffix" }),
		  "type": "histogram",
		  "suffix": histogram_suffix,
		  "ge":
		  lambda(mapping entry) {
		    return histogram_label(entry, "coNumRuns");
		  },
	       ]),
	       ([ "oid_prefix": "1.3.6.1.4.1.8614.1.1.2.9.1.1",
		  "type_instance": "requestTime",
		  "aspects": ({ "mode" }),
		  "mode":
		  lambda(mapping entry) {
		    if (entry->type_instance == "requestTime") {
		      add_entry(entry + ([
				  "aspects": ({ "suffix" }),
				  "suffix":"sum",
				  "type":"histogram",
				  "type_instance": "requestNumRuns",
				]));
		      return "user";
		    }
		    return "system";
		  },
	       ]),
	       ([ "oid_prefix": "1.3.6.1.4.1.8614.1.1.2.9.1.2",
		  "type_instance": "requestNumRuns",
		  "aspects": ({ "ge", "suffix" }),
		  "type": "histogram",
		  "suffix": histogram_suffix,
		  "ge":
		  lambda(mapping entry) {
		    return histogram_label(entry, "requestNumRuns");
		  },
	       ]),
	       ([ "oid_prefix": "1.3.6.1.4.1.8614.1.1.2.9.2.1",
		  "type_instance": "handleTime",
		  "aspects": ({ "mode" }),
		  "mode":
		  lambda(mapping entry) {
		    if (entry->type_instance == "handleTime") {
		      add_entry(entry + ([
				  "aspects": ({ "suffix" }),
				  "suffix":"sum",
				  "type":"histogram",
				  "type_instance": "handleNumRuns",
				]));
		      return "user";
		    }
		    return "system";
		  },
	       ]),
	       ([ "oid_prefix": "1.3.6.1.4.1.8614.1.1.2.9.2.2",
		  "type_instance": "handleNumRuns",
		  "aspects": ({ "ge", "suffix" }),
		  "type": "histogram",
		  "suffix": histogram_suffix,
		  "ge":
		  lambda(mapping entry) {
		    return histogram_label(entry, "handleNumRuns");
		  },
	       ]),
	       ([ "oid_prefix": "1.3.6.1.4.1.8614.1.1.2.9.3.1",
		  "type_instance": "queueTime",
		  "aspects": ({ "mode" }),
		  "mode":
		  lambda(mapping entry) {
		    if (entry->type_instance == "queueTime") {
		      add_entry(entry + ([
				  "aspects": ({ "suffix" }),
				  "suffix":"sum",
				  "type":"histogram",
				  "type_instance": "queueNumRuns",
				]));
		      return "user";
		    }
		    return "system";
		  },
	       ]),
	       ([ "oid_prefix": "1.3.6.1.4.1.8614.1.1.2.9.3.2",
		  "type_instance": "queueNumRuns",
		  "aspects": ({ "ge", "suffix" }),
		  "type": "histogram",
		  "suffix": histogram_suffix,
		  "ge":
		  lambda(mapping entry) {
		    return histogram_label(entry, "queueNumRuns");
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
		  "type_instance": "activeBrowserUsers",
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
		  "type_instance": "activeAppLauncherUsers",
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
		  "type_instance": "activePlannerUsers",
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
		  "type_instance": "activeBadBrowserUsers",
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
		  "type_instance": "activeBadAppLauncherUsers",
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
		  "type_instance": "activeBadPlannerUsers",
	       ]),
	       ([ "oid_prefix": "-1.5.15",
		  "type": "histogram",
		  "aspects": ({ "suffix" }),
		  "suffix": "count",
	       ]),
	       ([ "oid_prefix": "-1.5.18",
		  "type_instance": "actionTime",
		  "aspects": ({ "mode" }),
		  "mode":
		  lambda(mapping entry) {
		    if (entry->type_instance == "actionUserTime") {
		      add_entry(entry + ([
				  "aspects": ({ "suffix" }),
				  "suffix":"sum",
				  "type":"histogram",
				  "type_instance": "numActions",
				]));
		      return "user";
		    }
		    return "system";
		  },
	       ]),
	       ([ "oid_prefix": "-1.5.19",
		  "type_instance": "numActions",
		  "aspects": ({ "ge", "suffix" }),
		  "type": "histogram",
		  "suffix": "bucket",
		  "ge":
		  lambda(mapping entry) {
		    return histogram_label(entry, "numActions");
		  },
	       ]),
	    }), mapping consolidator) {
      if (!has_prefix(entry->oid, consolidator->oid_prefix + ".")) {
	continue;
      }

      foreach(consolidator->aspects || ({}), string aspect) {
	string aspect_val = callablep(consolidator[aspect])?
	  consolidator[aspect](entry):consolidator[aspect];
	if (undefinedp(aspect_val)) continue;
	entry[aspect] = aspect_val;
      }
      foreach(({ "aspects", "doc", "plugin", "plugin_instance",
		 "type", "type_instance" }), string field) {
	entry[field] = consolidator[field] || entry[field];
      }
      break;
    }

    add_entry(entry);
  }

  array(PrometheusValue) res = values(vals);
  sort(indices(vals), res);

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
			  "TICK": "counter",
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
