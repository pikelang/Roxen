inherit "roxenlib";

// add_group
//	add an ad group to the database
void add_group(mapping m, object db)
{
  object result;
  string query;
  array row;

  query = "INSERT INTO groups (name) VALUES "
        "('" + db->quote(m->name) + "')";
  db->query(query);
}

// get_groups
//	get a listing of ad groups
array(mapping) get_groups(object db)
{
  object result;
  string query, ret;
  array row, groups;

  query = "SELECT id, name FROM groups ORDER BY name";
  result = db->big_query(query);

  groups = ({});
  while(row = result->fetch_row())
    groups += ({ (["id":row[0],"name":row[1]]) });

  return groups;
}

// get_info
//	get an ad group's data
mapping get_info(int id, object db)
{
  object result;
  string query, ret;
  array row;

  query = "SELECT id, name FROM groups WHERE id="+id;
  result = db->big_query(query);
  row = result->fetch_row();

  return ([ "id" : row[0], "name" : row[1] ]);
}

// set_info
//	set an ad group's data
void set_info(mapping m, object db)
{
  string query;

  query = "UPDATE groups SET "
	  "name='" + db->quote(m->name) + "' "
  	  "WHERE id="+m->id;
  db->query(query);
}

// delete_group
//	delete an ad group. this will delete any impressions associated
//	with this ad group.
void delete_group(int id, object db)
{
  db->query("DELETE FROM groupAds WHERE gid="+id);
  db->query("DELETE FROM groupDefaultAds WHERE gid="+id);
  db->query("DELETE FROM groups WHERE id="+id);
  db->query("DELETE FROM impressions WHERE gid="+id);
}

// get_active_ads
//	returns ads in the specified ad group with an active run
//	with remaining hourly impressions.
array(mapping) get_active_ads(int group, object db)
{
  array(mapping) ads;
  object result;
  string query;
  array row;

  // cnt    == impressions during the past hour
  // weight == desired hourly impressions
  query = "SELECT a.id, a.type, a.ad, r.weight, r.id, COUNT(i.id) AS cnt, "
	  "r.exposure, r.domains, r.browsers, r.oses, r.competitors, "
	  "r.campaign FROM "
	  "ads AS a, runs AS r, groupAds AS ga LEFT JOIN impressions AS i ON "
	  "i.timestmp > UNIX_TIMESTAMP(DATE_FORMAT(NOW(),'%Y-%m-%d %H:00:00')) "
	  " AND i.run=r.id WHERE a.id=r.ad AND r.id=ga.run AND "
	  "ga.gid="+group+" AND r.startd <= NOW() AND r.endd >= NOW() "
	  "GROUP BY r.id HAVING cnt < r.weight ORDER BY r.id";
  result = db->big_query(query);
  ads = ({});
  while(row = result->fetch_row())
    ads += ({ 
	     ([ 
		"id" : row[0], 
		"type" : row[1], 
		"ad" : row[2], 
		"weight" : row[3], 
		"run" : row[4], 
		"campaign" : row[11],
		"exposure" : row[6], 
		"domains" : row[7]/"!",
		"browsers" : (row[8]/"!") - ({""}), 
		"oses" : (row[9]/"!") - ({""}),
		"competitors" : (row[10]/"!") - ({""})
	     ])
	   });

  return ads;
}

// get_default_ads
//	returns default ads for the specified ad group
array(mapping) get_default_ads(int group, object db)
{
  array(mapping) ads;
  object result;
  string query;
  array row;

  query = "SELECT a.id, a.type, a.ad, r.id "
	  "FROM ads AS a, runs AS r, groupDefaultAds AS gda "
	  "WHERE a.id=r.ad AND r.id=gda.run AND gda.gid="+group;
  result = db->big_query(query);
  ads = ({});
  while(row = result->fetch_row())
    ads += ({ ([ "id" : row[0], "type" : row[1], "ad" : row[2], 
		 "run" : row[3] ]) });
  return ads;
}

// get_id
//	returns the gid associated with a group
int get_gid(string group, object db)
{
  object result;
  string query;
  array row;

  query = "SELECT id FROM groups WHERE name='"+db->quote(group)+"'";
  result = db->big_query(query);
  if (row = result->fetch_row())
    return (int)row[0];
  return 0;
}

// get_stats
//	returns as html the statistics for the ad group
string get_stats(int gid, object db)
{
  return .Ad.do_stats("gid="+gid, db);
}

