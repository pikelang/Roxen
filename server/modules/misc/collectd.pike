// Collectd module

#include <module.h>

inherit "module";

constant thread_safe=1;
constant module_type = MODULE_PROVIDER;
LocaleString module_name = "Collectd";
LocaleString module_doc = #"
<p>This modules periodically collects snmp data and 
sends it to the collectd statistics server.</p>
<p>Note: You need a snmp port configured in the site to make this module work.</p>";

constant cvs_version = "$Id$";

#ifdef COLLECTD_DEBUG
protected void collectd_werror(sprintf_format fmt, sprintf_args ... args)
{
  Configuration conf = my_configuration();
  werror("COLLECTD: %s: " + fmt, conf->name, @args);
}
#define COLLECTD_WERR collectd_werror
#else
#define COLLECTD_WERR(X ...)
#endif

Thread.Thread sender_thread;
Thread.Condition sender_cond = Thread.Condition();
Thread.Mutex sender_mutex = Thread.Mutex();

int sender_enabled;

Configuration conf;
string socket_path;
int interval;
string hostname;
string plugin_instance;

void create()
{
  defvar("socket_path", "/var/run/collectd-unixsock", "Socket path", TYPE_FILE,
	 "The path to the socket file opened by collectd. Use the "
	 "<a href=\"https://collectd.org/wiki/index.php/Plugin:UnixSock\">UnixSock</a> "
	 "plugin in collectd to enable the socket.");

  defvar("hostname", "localhost", "Hostname", TYPE_STRING,
	 "The name of the machine that reports statistics. "
	 "First part of the collectd identifier.");

  defvar("plugin_instance", "0", "Plugin instance", TYPE_STRING,
	 "The instance number for the roxen plugin used when reporting statistics. "
	 "Sufix of the second part of the collectd identifier, e.g roxen-0.");

  defvar("interval", 0, "Interval",
	 TYPE_INT, "Interval in seconds between updates (0 = disabled).");
}

void start(int when, Configuration _conf)
{
  COLLECTD_WERR("::: start(%O, %O)\n", when, _conf);

  if(_conf) {
    conf = _conf;
    socket_path = query("socket_path");
    interval = query("interval");
    hostname = query("hostname");
    plugin_instance = query("plugin_instance");
  }

  if(when == 2) {
    if(interval)
      start_sender_thread();
    else
      stop_sender_thread();
  }
}

void ready_to_receive_requests()
{
  COLLECTD_WERR("::: ready_to_receive_requests() interval=%O\n", interval);
  if(interval)
    start_sender_thread();
}

void stop()
{
  COLLECTD_WERR("::: stop()\n");
  stop_sender_thread();
}

void start_sender_thread()
{
  COLLECTD_WERR("::: start_sender_thread()\n");
  if(!sender_thread) {
    sender_enabled = 1;
    sender_thread = Thread.Thread(sender_loop);
  }
}

void stop_sender_thread()
{
  COLLECTD_WERR("::: stop_sender_thread()\n");
  if(sender_thread) {
    sender_enabled = 0;
    sender_cond->signal();
    sender_thread->wait();
    sender_thread = 0;
  }
}

void sender_loop()
{
  COLLECTD_WERR("::: sender_loop()\n");
  Roxen.name_thread(this_thread(), "Collectd Sender");
  while(sender_enabled)
  {
    if (mixed err = catch {
	do_send();
      })
      master()->handle_error (err);
    int time_to_next_run = interval - (time() % interval);
    if(time_to_next_run <= 1)
      time_to_next_run += interval;
    COLLECTD_WERR("::: Waiting %O (interval: %O, time: %O)\n", time_to_next_run, interval, time());
    Thread.MutexKey key = sender_mutex->lock();
    sender_cond->wait(key, time_to_next_run);
    destruct (key);
  } 
  Roxen.name_thread(this_thread(), 0);
  COLLECTD_WERR("::: sender_loop stopped\n");
}

array(mapping) last_run_rows = ({});
float last_run_time;

void do_send()
{
  COLLECTD_WERR("::: do_send() %O\n", time());
  int t = gethrtime();
  array(mapping) rows = get_snmp_rows();
  last_run_rows = rows;
  
  Stdio.File socket = Stdio.File();
  if(!socket->connect_unix(socket_path))
  {
    report_error("Can not connect to socket %s (ERROR: %d)\n", 
		 socket_path, socket->errno());
    return;
  }

  foreach(rows, mapping row) {
    string putval = collectd_putval(row->hostname,
				    row->plugin,
				    row->plugin_instance,
				    row->type,
				    row->type_instance,
				    row->interval,
				    row->timestamp,
				    row->value);

    int r = socket->write(putval);
    COLLECTD_WERR("::: do_send()::write(%O) %d bytes\n", row, r);
    string result;
    result = socket->read(100, 1);
    COLLECTD_WERR("::: do_send()::read -> %O\n", result);
  }
  socket->close();
  socket = 0;
  last_run_time = (gethrtime() - t)/1000.0;
}

string collectd_putval(string host, 
		       string plugin, 
		       string plugin_instance, 
		       string type, 
		       string type_instance, 
		       int interval, 
		       int timestamp, 
		       int value)
{
  return sprintf("PUTVAL \"%s/%s-%s/%s-%s\" interval=%d %d:%d\n",
		 host,
		 plugin, plugin_instance,
		 type, type_instance,
		 interval,
		 timestamp, value);
}

array(mapping) get_snmp_rows() 
{
  array(mapping) res =
    get_global_snmp()+
    get_cache_snmp()+
    get_site_snmp()+
    get_module_snmp(conf->find_module("print-clients#0"))+
    get_module_snmp(conf->find_module("print-backup#0"))+
    get_module_snmp(conf->find_module("feed-import#0"))+
    get_module_snmp(conf->find_module("image#0"))+
    get_module_snmp(conf->find_module("print-indesign-server#0"))+
    get_module_snmp(conf->find_module("print-db#0"));

  RoxenModule memory_logger_module = conf->find_module("memory_logger#0");
  if(memory_logger_module && sizeof(memory_logger_module->pmem))
    res += get_module_snmp(memory_logger_module);
  return res;
}

string status()
{
  string res = "";
  int t = gethrtime();
  res += "<table style='font-size: 8px'>\n"
    "<tr><th>Identifier</th><th>Value</th><th>Timing (ms)</th><th>OID</th><th>Description</th></tr>";
  int count;
  foreach(last_run_rows, mapping row) {
    res += "<tr style='background-color: "+((count % 2)?"white":"#f2f2f2")+"'>"+
      "<td style='white-space: nowrap'>"+sprintf("%s/%s-%s/%s-%s",
			      row->hostname,
			      row->plugin,
			      row->plugin_instance,
			      row->type,
			      row->type_instance)+"</td>"+
      "<td style='white-space: nowrap'>"+row->value+"</td>"+
      "<td style='white-space: nowrap'>"+row->update_time*1000+"</td>"+
      "<td style='white-space: nowrap'>"+row->oid+"</td>"+
      "<td style='white-space: nowrap'>"+row->doc+"</td>"+
      "</tr>\n";
    count++;
  }
  res += "</table>\n";
  if(count)
    res += sprintf("Last run time: %f ms, %d entries.\n", last_run_time, count);
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

array(mapping) get_module_snmp(RoxenModule o)
{
  if (!o || !o->query_snmp_mib) return ({});
  
  // Use fake oid:s below, since we are only interested in the values not the actual address.
  ADT.Trie mib = o->query_snmp_mib(({ 1 }), ({ 1 }));
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
			  "COUNTER": "derive", 
			  "COUNTER64": "derive", 
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
			      string plugin_instance_suffix,
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
    string type = "";
    string doc = "";
    float update;
    mixed err = catch {
	val = mib->lookup(oid);
	if (zero_type(val)) continue;
	if (objectp(val)) {
	  name = val->name || "";
	  type = val->type_name;
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
    
    string collectd_type = type_mapping[type];
    if(collectd_type) {
      res += ({ ([ "hostname":        hostname, 
		   "plugin":          "roxen", 
		   "plugin_instance": plugin_instance+"-"+plugin_instance_suffix, 
		   "type":            collectd_type, 
		   "type_instance":   mangle_snmp_label(name), 
		   "interval":        interval, 
		   "timestamp":       time(), 
		   "value":           (int)val,
		   "update_time":     update,
		   "oid":             (array(string))oid*".",
		   "doc":             doc
		]) });
    }
  }
  return res;
}
