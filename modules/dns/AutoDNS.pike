#include <module.h>
#include <roxen.h>
#include <stdio.h>
inherit "module";
inherit "roxenlib";
import Thread;

string host_ip_no;

#define ZTTL     "Zone TTL Value"
#define ZREFRESH "Zone Refresh Time"
#define ZRETRY   "Zone Failed-Refresh Retry Time"
#define ZEXPIRE  "Zone Expire Time"
#define DBURL    "Database URL"
#define ZONEDIR  "Zone Dir"
#define TMPFILENAME  "/tmp/new-dns-hosts"

void create()
{  defvar(ZONEDIR, "/tmp/named/",
         ZONEDIR, TYPE_STRING,
         "The name of the directory where to put the zone subfiles.");

  defvar(DBURL, "mysql://auto:site@kopparorm.idonex.se/autosite",
         DBURL, TYPE_STRING,
         "The SQL database URL.");

  defvar(ZTTL, "1 day",
         ZTTL, TYPE_MULTIPLE_STRING,
         "Time-To-Live for a resource record in a cache?",
         ({ "12 hours", "1 day", "2 days", "3 days", "5 days", "1 week" })
        );

  defvar(ZREFRESH, "30 minutes",
         ZREFRESH, TYPE_MULTIPLE_STRING,
         "How long does a cached resource record last in a secondary server?",
          ({ "15 minutes", "30 minutes", "1 hour", "2 hours",
             "3 hours", "6 hours" })
        );

  defvar(ZRETRY, "5 minutes",
         ZRETRY, TYPE_MULTIPLE_STRING,
         "How long should a secondary server wait before retrying after "
         "failure to complete a refresh?",
         ({ "2 minutes", "5 minutes", "10 minuters", "15 minutes" })
        );

  defvar(ZEXPIRE, "1 week",
         ZEXPIRE, TYPE_MULTIPLE_STRING,
         "How long, at most, should secondary servers remember resource "
         "records for this domain if the refresh keeps failing?",
         ({ "1 day", "2 days", "3 days", "5 days", "1 week", "2 weeks" })
        );

  roxen->set_var("AutoDNS_hook", this_object());
}

int query_timeunit(string var, int defaultvalue)
{ int x; string value = query(var); string dummy;
  if (sscanf(value, "%d w%s", x, dummy) == 2) return x * 3600 * 24 * 7;
  if (sscanf(value, "%d d%s", x, dummy) == 2) return x * 3600 * 24;
  if (sscanf(value, "%d h%s", x, dummy) == 2) return x * 3600;
  if (sscanf(value, "%d m%s", x, dummy) == 2) return x * 60;
  if (sscanf(value, "%d s%s", x, dummy) == 2) return x;
  return defaultvalue;
}

array register_module()
{ return ({ MODULE_PARSER, "AutoSite DNS Administration Module", "", 0, 1 });
}

string database_status
       = "will try to connect.";

string dns_update_status
       = "none since restart.";

string status()
{ return "<B>DNS Administration Status</B>\n<DL>"
       + "\n <DT>Database Status:<DD>" +database_status
       + "\n <DT>DNS Update:<DD>" + dns_update_status
       + "\n</DL>\n";
}

object database;

int update_scheduled = 0;

int last_update_time = 0;

static string rr_entry(string owner, int ttl, string type, string value)
{ return owner + "                        "[sizeof(owner)..24] + " " +
         ttl + " IN " + type + "     "[sizeof(type)..5] + value;
}


void do_update()
// Update the DNS master file from the DOMAINS table.
{
  werror("do_update()\n");
  if (!database)
  { // If the database is not available, leave the
    // update_schduled variable in its current state,
    // return for now, and let the update take until
    // the next time start() manages to open a connection
    // to the database.
    dns_update_status = "pending. Database presently unavailable.";
    return;
  }
  string zonedirname    = query(ZONEDIR);

  if (file_size(zonedirname) != -2)
  { dns_update_status = "pending. Zone directory invalid.";
    call_out(do_update, 300);
    return;
  }

  object masterfile = Stdio.FILE(zonedirname+"/named.conf", "wct");

  if (!masterfile)
  { dns_update_status = "pending. Unable to write zonemaster file.";
    call_out(do_update, 300);
  }

  masterfile->write(
       "options {\n"
       "    directory \""+zonedirname+"\";\n"
       "};\n\n"
       "logging {\n"
       "    category lame-servers { null; };\n"
       "    category cname { null; };\n"
       "};\n\n" 
       "zone \".\" in {\n"
       "    type hint;\n"
       "    file \"root.cache\";\n};\n\n"
    );

  array row;

  int    ttl      = query_timeunit(ZTTL, 50000);
  string hostname = gethostname();

  object domains = database->big_query(
      "SELECT DISTINCT domain,customer_id FROM dns ORDER BY customer_id");

  int error_count = 0;
  int domain_count= 0;

  while (row = domains->fetch_row())
  { string domain = row[0];
    string customer_id = row[1];

    object domain_info = database->big_query(
      "SELECT rr_owner,rr_type,rr_value FROM dns WHERE domain='" +
             domain + "'");

    object file = Stdio.File(zonedirname + "/db." + domain, "wct");

    ++domain_count;

    if (file)
    { file->write(";;; db." + domain + " -- DNS zone file for\n"
                  ";;;\n"
                  ";;;            *." + domain + ".\n"
                  ";;;\n"
                  ";;; Automatically generated from the DOMAINS table\n"
                  ";;; in the AutoSite DNS database.\n");
      file->write("@   IN    SOA  kopparorm.idonex.se. hostmaster.idonex.se. (");
      file->write("\n                    " + time() + " ;; Serial"
                  "\n                    " + query_timeunit(ZREFRESH, 2000) +
                                                 "    ;; Refresh"
                  "\n                    " + query_timeunit(ZRETRY, 500) +
                                                 "     ;; Retry"
                  "\n                    " + query_timeunit(ZEXPIRE, 500000) +
                                                 "  ;; Expire"
                  "\n                    " + ttl + " )    ;; Minimum TTL\n"
                  "              IN NS  kopparorm.idonex.se.\n\n");

      while (row = domain_info->fetch_row())
      { string rr_owner = row[0];
        string rr_type  = row[1];
        string rr_value = row[2];

        if (rr_type == "A" && rr_value == "")
               rr_value = host_ip_no;

        if      (rr_owner == "")              rr_owner = domain + ".";
        else if (sizeof(rr_owner / ".") == 1) rr_owner += "." + domain + "."; 

        file->write(rr_entry(rr_owner, ttl, rr_type, rr_value) + "\n");
      }
      masterfile->write("zone \""+domain+".\" in {\n"
			"    type master;\n"
			"    file \"db." + domain + "\";\n\};\n\n");
    }
    else
    { ++error_count;
      dns_update_status = "failed to generate database for '" +
                domain + "': unable to write file.";
    }
  }

  if (error_count || domain_count == 0)
  { if (!error_count)
         dns_update_status = "no domains in database!";
    call_out(do_update, 300); // try again in 5 minutes.
    return;
  }
  string s=Process.popen("/bin/sh -c 'ps -uroot|grep named'");
  int pid;
  sscanf(s," %d %*s",pid);
  if(pid)
    kill(pid,1); // SIGHUP
  dns_update_status = "complete " + ctime(time());
  last_update_time = time();
  update_scheduled = 0;
}

void update()
{ // Schedule an update if one is not already scheduled.
  if (update_scheduled) return;
  update_scheduled = 1;
  thread_create(do_update);
}

string tag_update()
{
  update();
  return "DNS configuration update initiated.";
}

mapping query_tag_callers()
{
  return ([ "autosite-dns-update" : tag_update ]);
}



void start()
{ if (! host_ip_no)
     host_ip_no = gethostbyname(gethostname())[1][0];
  
  if (! database)
  { database = Sql.sql(query(DBURL));

    if (database)
    { database_status = "connected (" + database->host_info() + ")";
      update();
    }
    else
      database_status = "unavailable.";
  }

  if (database &&
      last_update_time + 86400 < time())
  { // If the database is available, and a zonemaster file
    // update hasn't been done in 24 hours, schedule one.

    update();
  }
}

