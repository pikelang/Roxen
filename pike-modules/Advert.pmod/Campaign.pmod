inherit "roxenlib";

// add_campaign
//	add an ad campaign to the database
void add_campaign(mapping m, object db)
{
  object result;
  string query;
  array row;

  query = "INSERT INTO campaigns (name, password) VALUES "
        "('" + db->quote(m->name) + "',"
	"PASSWORD('" + db->quote(m->password) + "') )";
  db->query(query);
}

// get_campaigns
//	get a listing of available campaigns
array(mapping) get_campaigns(object db)
{
  object result;
  string query, ret;
  array row, campaigns;

  query = "SELECT id, name FROM campaigns ORDER BY name";
  result = db->big_query(query);

  campaigns = ({});
  while(row = result->fetch_row())
    campaigns += ({ (["id":row[0],"name":row[1]]) });

  return campaigns;
}

// get_info
//	get an ad campaign's data
mapping get_info(int id, object db)
{
  object result;
  string query, ret;
  array row;

  query = "SELECT id, name, password FROM campaigns WHERE id="+id;
  result = db->big_query(query);
  row = result->fetch_row();

  return ([ "id" : row[0], "name" : row[1], "password" : row[2] ]);
}

// set_info
//	set an ad campaign's data
void set_info(mapping m, object db)
{
  string query;

  query = "UPDATE campaigns SET "
	  "name='" + db->quote(m->name) + "' ";

  if (m->password && sizeof(m->password))
    query += ", password=PASSWORD('"+db->quote(m->password)+"') ";

  query += "WHERE id="+m->id;
  db->query(query);
}

// delete_campaign
//	remove an ad campaign. this will delete any run associated with
//	this campaign, and any impressions associated with those runs.
void delete_campaign(int id, object db)
{
  object result;
  string query;
  array row;

  result = db->big_query("SELECT id FROM runs WHERE campaign="+id);
  while(row = result->fetch_row())
    .Run.delete_run((int)row[0], db);
  db->query("DELETE FROM campaigns WHERE id="+id);
}

// get_stats
//	returns as html the statistics for this campaign
string get_stats(int campaign, object db)
{
  object result;
  array row;
  string ret, query;
  int impressions, clickthroughs;

  query = "SELECT FROM_DAYS(i.day) AS d, COUNT(*), COUNT(DISTINCT i.host), "
          "COUNT(DISTINCT i.user), COUNT(IF(i.click = 'Y',1,NULL)) "
          "FROM impressions AS i, runs AS r WHERE i.run=r.id AND r.campaign="+
	  campaign+" GROUP BY i.day ORDER BY d";

  result = db->big_query(query);
  ret = "<table cellpadding=1 cellspacing=0 border=0 bgcolor=#000000><tr><td>"
        "<TABLE border=0 cellspacing=0 cellpadding=4>"
        "<TR BGCOLOR=#113377><TH><FONT COLOR=#ffffff>Date</FONT></TH>"
        "<TH><FONT COLOR=#ffffff>Impressions</FONT></TH>"
        "<TH><FONT COLOR=#ffffff>Clickthroughs</FONT></TH>"
        "<TH><FONT COLOR=#ffffff>Rate (%)</FONT></TH>"
        "<TH><FONT COLOR=#ffffff>Hosts</FONT></TH>"
        "<TH><FONT COLOR=#ffffff>Users</FONT></TH></TR>";
  impressions = 0;
  clickthroughs = 0;

  while(row = result->fetch_row())
  {
    ret += "<TR ALIGN=RIGHT BGCOLOR=#FFFFFF>"
           "<TD>"+row[0]+"</TD><TD>"+row[1]+"</TD><TD>"+row[4]+"</TD><TD>"+
           sprintf("%.2f",(((float)row[4]/(float)row[1])*100)) + "</TD><TD>" + row[2] + "</TD>"
          "<TD>" + row[3] + "</TD></TR>";
    impressions += (int)row[1];
    clickthroughs += (int)row[4];
  }

  if (impressions)
    ret += "<TR BGCOLOR=#FFFFFF><TD COLSPAN=6><HR NOSHADE></TD></TR>"
         "<TR ALIGN=RIGHT BGCOLOR=#FFFFFF>"
         "<TD>&nbsp;</TD><TD>"+impressions+"</TD><TD>"+clickthroughs+"</TD>" 
        "<TD>"+sprintf("%.2f", ((float)clickthroughs/(float)impressions)*100) +
        "</TD><TD>&nbsp;</TD><TD>&nbsp;</TD></TR>";

  ret += "</TABLE>"
         "</td></tr></table>";

  return ret;
}

