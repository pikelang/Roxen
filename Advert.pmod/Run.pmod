inherit "roxenlib";

constant browsers =
({
        "AvantGo",
        "Internet Explorer",
        "Netscape",
        "Lynx",
        "Opera",
        "Other"
});

constant oses =
({
        "AIX",
        "AmigaOS",
        "BSD/OS",
        "BeOS",
        "FreeBSD",
        "HP-UX",
        "IRIX",
        "Linux",
        "MacOS",
        "NetBSD",
        "OS/2",
        "OSF1",
        "OpenBSD",
        "SCO",
        "Solaris",
        "SunOS",
        "Windows",
        "Windows 95",
        "Windows 98",
        "Windows NT",
        "Other"
});


// add_run
//	add an ad run to the database
void add_run(mapping m, object db)
{
  object result;
  string query;
  array row;

  query = "INSERT INTO runs (ad, campaign, startd, endd, impressions, "
	"exposure, domains, browsers, oses, competitors) VALUES (" +
	db->quote(m->ad) 		+ " , " + 
	db->quote(m->campaign) 		+ " , " +
	db->quote(m->start) 		+ " , " + 
	db->quote(m->end) 		+ " , " + 
	db->quote(m->impressions) 	+ " , " + 
	db->quote(m->exposure) 		+ " ,'" +
	db->quote(m->domains * "!") 	+ "','" +
	db->quote(m->browsers * "!") 	+ "','" +
	db->quote(m->oses * "!") 	+ "','" +
	db->quote(m->competitors * "!") + "'  )";

  db->query(query);
  result = db->big_query("SELECT LAST_INSERT_ID()");
  row = result->fetch_row();
  set_ad_groups((int)row[0], db, m->groups / "\0");
  set_default_groups((int)row[0], db, 
	m->defaul_groups?m->default_groups/"\0":({}));
  do_update_weight(db, "0", row[0]);
}

// get_runs
//	get a listing of ad runs
array(mapping) get_runs(object db)
{
  object result;
  string query, ret;
  array row, runs;

  query = "SELECT r.id, CONCAT(c.name,':',r.startd,'-',r.endd) AS n "
	  "FROM runs AS r, campaigns AS c WHERE r.campaign=c.id ORDER BY n";
  result = db->big_query(query);

  runs = ({});
  while(row = result->fetch_row())
    runs += ({ (["id":row[0],"name":row[1]]) });

  return runs;
}

// get_ad_groups
//	get the ad groups associated with a run
array get_ad_groups(int id, object db)
{
  object result;
  array row, groups;

  groups = ({});
  result = db->big_query("SELECT gid FROM groupAds WHERE run="+id);
  while(row = result->fetch_row())
    groups += ({ row[0] });

  return groups;
}

// get_default_groups
//	get the ad groups for which the run is a default ad
array get_default_groups(int id, object db)
{
  object result;
  array row, groups;

  groups = ({});
  result = db->big_query("SELECT gid FROM groupDefaultAds WHERE run="+id);
  while(row = result->fetch_row())
    groups += ({ row[0] });

  return groups;
}

// set_ad_groups
//	set the ad groups associated with the run
void set_ad_groups(int id, object db, array groups)
{
  db->query("DELETE FROM groupAds WHERE run="+id);
  foreach(groups, string g)
    db->query("INSERT INTO groupAds (run, gid) "
	      "VALUES (" + id + "," + db->quote(g) + ")");
}

// set_default_groups
//	set the ad groups for which this run is a default ad
void set_default_groups(int id, object db, array groups)
{
  db->query("DELETE FROM groupDefaultAds WHERE run="+id);
  foreach(groups, string g)
    db->query("INSERT INTO groupDefaultAds (run, gid) "
	      "VALUES (" + id + ", " + db->quote(g) + ")");
}

// get_info
//	get an ad run's data
mapping get_info(int id, object db)
{
  object result;
  string query, ret;
  array row;

  query = "SELECT id, ad, campaign, startd, endd, impressions,"
	  "exposure, domains, browsers, oses, competitors "
	  "FROM runs WHERE id="+id;
  result = db->big_query(query);
  row = result->fetch_row();

  return 
    ([ 
	"id" 		: row[0], 
	"ad" 		: row[1], 
	"campaign" 	: row[2], 
	"start" 	: row[3], 
	"end" 		: row[4], 
	"impressions" 	: row[5],
	"groups" 	: get_ad_groups((int)row[0], db) * "\0",
	"default_groups": get_default_groups((int)row[0], db) * "\0",
	"exposure" 	: row[6], "domains" : (row[7]/"!") - ({""}),
	"browsers" 	: (row[8]/"!") - ({""}),
	"oses" 		: (row[9]/"!") - ({""}),
	"competitors" 	: (row[10]/"!") - ({""}) 
    ]);
}

// set_info
//	set an ad run's data
void set_info(mapping m, object db)
{
  string query;

  query = "UPDATE runs SET "
	  "ad=" 	+ db->quote(m->ad) + ", "
	  "campaign=" 	+ db->quote(m->campaign) + ", "
	  "startd=" 	+ db->quote(m->start) + ", "
	  "endd=" 	+ db->quote(m->end) + ", "
	  "impressions="+ db->quote(m->impressions) + ", "
	  "exposure=" 	+ db->quote(m->exposure) + ", "
	  "domains='" 	+ db->quote(arrayp(m->domains)?m->domains*"!":"")+"', "
	  "browsers='"	+ db->quote(arrayp(m->browsers)?m->browsers*"!":"")+"',"
	  "oses='" 	+ db->quote(arrayp(m->oses)?m->oses*"!":"")+"', "
	  "competitors='"
              + db->quote(arrayp(m->competitors)?m->competitors*"!":"") + "' "
  	  "WHERE id="+m->id;
  db->query(query);
  set_ad_groups((int)m->id, db, m->groups / "\0");
  set_default_groups((int)m->id, db, 
	m->defaul_groups?m->default_groups/"\0":({}));
  update_weight(db, m->id);
}

// delete_run
//	deletes an ad run. this will delete any impressions associated
//	with the run.
void delete_run(int id, object db)
{
  object result;
  string query, ret;
  mapping m;

  db->query("DELETE FROM impressions WHERE run="+id);
  db->query("DELETE FROM groupAds WHERE run="+id);
  db->query("DELETE FROM groupDefaultAds WHERE run="+id);
  db->query("DELETE FROM runs WHERE id="+id);
}

// get_stats
//	returns html output with the ad run's statistics.
string get_stats(int run, object db)
{
  return .Ad.do_stats("run="+run, db);
}


// update_weight
//	updates the desired hourly impressions (weight) for a run
void update_weight(object db, string rid)
{
  object db, result;
  array row;
  string query;

  query = "SELECT COUNT(*) FROM impressions AS i WHERE i.run="+rid;
  result = db->big_query(query);
  if (row = result->fetch_row())
    do_update_weight(db, row[0], rid);
}

// do_update_weight
//	updates the desired hourly impressions (weight) for a run
//	given the number of impressions already done
void do_update_weight(object db, string done, string rid)
{
  string query;

  // impressions left = impressions requested -  impressions done
  // hours left in run = ( end - cur_time ) / 3600
  // new hourly impression rate = impressions left / hours left in run
  query = "UPDATE runs SET weight= ((impressions - "+done+") / "
          "((UNIX_TIMESTAMP(endd) - UNIX_TIMESTAMP())/3600) ) "
          "WHERE id="+rid;
  db->query(query);
}

