#include <module.h>
#include "advert.h"

inherit "module";
inherit "wizard";
inherit "roxenlib";

constant thread_safe = 1;

string location;
string database;
string disklocation;
int nads;
int debug = 1;
int target_last_ad;
int target_page_ads;

constant infostr = "The Advert module is ad serving system for Roxen. "
                  "It introduces a new tag, &lt;ad&gt;. "
                  "Please use the configuration interface to set it up.";

array(mixed) register_module()
{
  return ({ MODULE_LOCATION|MODULE_PARSER, "Advert Module", infostr, ({}), 1 });
}

string info()
{
  return infostr;
}

void create(object conf)
{
  array path = __FILE__  / "/";
  disklocation = path[0..(sizeof(path) - 2)] * "/";
  master()->add_module_path(disklocation);

  defvar("adminname", "advert", "Module administrator user name",
         TYPE_STRING,
         "User name to manage the Advert module.");

  defvar("adminpassword", "", "Module administrator password",
         TYPE_PASSWORD,
         "Password to manage the Advert module. "
         "The password is sent clear text over the network when using "
	 "HTTP. It is recommended you use HTTPS to access the module's "
	 "configuration interface.");

  defvar("location", "/advert/", "Mountpoint", TYPE_LOCATION,
         "The mount point for the confirugation interface and click "
	  "throughs.");

  defvar("database", "", "Database URL", TYPE_STRING,
         "Database URL where to store ad information.<BR>"
         "E.g. \"mysql://username:password@hostname/database\"");

  defvar("target_last_ad", 0, "Last Ad Targeting", TYPE_FLAG,
	 "Enabling Last Ad Targeting will stop the module from servering "
	 "the same ad back to back. This is acomplished by saving the last "
	 "ad the user has seen in a cookie. You may not want to enable Last "
	 "Ad Targeting if you do not have many ads in rotation.");

  defvar("target_page_ads", 0, "Page Ads Targeting", TYPE_FLAG,
	 "Enabling Page Ads Targeting will stop the module from serving "
	 "the same ad more than once in the same page. You may not want to "
	 "enable this option if you do not have many ads in rotation.");
}

void start(int count, object conf)
{
  module_dependencies(conf,
        ({ "htmlparse", "business", "configtablist" }) );

  if (count == 0)
    nads = 0;

  location        = query("location");
  target_last_ad  = query("target_last_ad");
  target_page_ads = query("target_page_ads");
  database        = query("database");

  if (stringp(database) && sizeof(database))
  {
    object db;
    array(string) tables;

    // create our tables if they do not exists
    db  =  conf->sql_connect(database);
    tables = db->list_tables();
    foreach(indices(create_tables), string table)
      if (search(tables, table) < 0)
        db->query(create_tables[table]);

    // we don't need a cryptographicly strong rgn
    random_seed(time());

    // recompute the weights and start the call out
    update_weights(conf);
  }
}

void stop()
{
  remove_call_out(update_weights);
}

string status()
{
  return "Ads served: " + nads;
}

string query_location()
{
  return location;
}

// configuration interface and hit counting
mixed find_file(string path, object id)
{
  array(string) req;
  string user;

  if(id->method != "GET" && id->method != "POST")
    return 0;

  req = (path / "/") - ({""});

  switch( req[0] )
  {
    case "click":
      // handle hit
      return clickthrough(id);
      break;

    case "conf":
      return config(req, id);

    default:
      return 0;
  }
}

// config
//	handle requests for the configuration interface
mixed config(array(string) req, object id)
{
  // authenticate the user
  if(!validate_user(id))
    return (["type":"text/html",
             "error":401,
             "extra_heads":
               ([ "WWW-Authenticate":
                  "basic realm=\"Advert\""]),
             "data":"<title>Access Denied</title>"
               "<h2 align=center>Access forbidden</h2>"
           ]);

  if (sizeof(req) == 1)
    return http_string_answer(parse_rxml(index_page, id));

  switch(req[1])
  {
    case "ads":
    case "campaigns":
    case "groups":
    case "runs":
    {
      mixed w;
      if(mappingp(w = wizard_menu(id, disklocation+"/wizards/"+req[1]+"/",
        "/advert/conf/"+req[1],   id->conf->sql_connect(database))))
      return w;

      return http_string_answer(parse_rxml(print_header(req[1]) + 
						"<ul>"+w+"</ul>", id));
    }

    default:
      return 0;
  }
}

constant tabs = ({ "ads", "runs", "groups", "campaigns", "help" });

// print_header
//	print configuration interface header
string print_header(string section)
{
  string header;

  header = "<HTML><HEAD><TITLE>Advert Configuration: "+
	   String.capitalize(section)+"</TITLE></HEAD>"
           "<BODY BGCOLOR='#ffffff' TEXT='#000000' LINK='#000070' "
	   "VLINK='#000070' ALINK='#ff000'>"
           "<config_tablist>";
  foreach(tabs, string t)
    header += "<tab bgcolor=#FFFFFF href='"+t+"' "+
	(t==section?"selected":"")+">"+String.capitalize(t)+"</tab>";
  header += "</config_tablist>";
  return header;
}

// validate_user
//	authenticate the configuration interface user
int validate_user(object id)
{
  string user = ((id->realauth||"*:*")/":")[0];
  string key = ((id->realauth||"*:*")/":")[1];
  if(user == query("adminname") && stringp(query("adminpassword")) && 
	crypt(key, query("adminpassword")))
      return 1;
  return 0;
}

// clickthrough
//	handle clickthrough requests
mixed clickthrough(object id)
{
  mapping v = id->variables;

  if (!v->ad || !v->run || !v->group || !v->url)
    return;

  .Advert.Ad.log_clickthrough((int)v->impression, (int)v->ad,
	(int)v->run,(int)v->group, 
	id->remoteaddr, (int)id->cookies->RoxenUserID,
	id->conf->sql_connect(database));
  return http_redirect(v->url, id);
}

// query_tag_callers
//      register our tag
mapping(string:function) query_tag_callers()
{
  return ([ "ad" : ad_tag ]);
}

// ad_tag
//	handle the ad tag
void|string|array(string) 
	ad_tag(string tag, mapping(string:string) att, object id)
{
  if (att->help)
    return ad_help;

  if (!att->group) 
    return "";

  if (att->nocache == "client")
    no_client_cache(id);
  else if (att->nocache == "proxy")
    no_proxy_cache(id);

  if (att->pagead)
  {
    if (!id->misc->pagead)
      id->misc->pagead = get_ad(att->group, id);
    return id->misc->pagead;
  }
  else
    return get_ad(att->group, id);
}

// no_proxy_cache
//	attempts to stop proxies (but not clients) from caching the page 
//	(and thus the ad). does not work with HTTP/1.0 proxies. hopefully
//	the only "private" cache in the request chain is the client cache
void no_proxy_cache(object id)
{
  if(!mappingp(id->misc->moreheads))
    id->misc->moreheads = ([]);

  id->misc->moreheads["Cache-Control"] = "private";
}

// no_client_cache
//	attempts to stop clients (and proxies) from caching the page (and thus
//	the ad). some clients (e.g. IE) may still try to used the cached copy
//	by validating it using an If-Modified-Since request. Since Roxen
//	will respond to such a request by looking at the file timestamp
//	you will need some external means to update the Last-Modified time.
void no_client_cache(object id)
{
  if(!mappingp(id->misc->moreheads))
    id->misc->moreheads = ([]);

  id->misc->moreheads["Cache-Control"] = "no-cache";
  id->misc->moreheads["Pragma"] = "no-cache";
}

// get_ad
//	return an ad for the specified ad group and log the impression
string get_ad(string group, object id)
{
  array(mapping) ads;
  mapping ad;
  int gid;
  object db;

  db = id->conf->sql_connect(database);

  if (!(gid = .Advert.Group.get_gid(group, db)))
    return "<!-- unknown ad group -->";

  // returns ads in this group with an active run
  // (start date before now and end date after now)
  // and remaining hourly impressions left, and that
  ads = .Advert.Group.get_active_ads(gid, db);

  // filter ads by targeting dimensions
  // they are ordered from less computationaly expensive to most

  // filter by last seen ad
  if (target_last_ad) 
    ads = .Advert.Ad.target_last_ad(ads, id);

  // filter by page ads
  if (target_page_ads)
    ads = .Advert.Ad.target_page_ads(ads, id);

  // filter by competitors
  ads = .Advert.Ad.target_competitors(ads, id);

  // filter by domain
  ads = .Advert.Ad.target_domain(ads, id, db);

  // filter by browser and os
  ads = .Advert.Ad.target_browser_and_os(ads, id);

  // filter by user exposure
  ads = .Advert.Ad.target_exposure(ads, id, db);

  // no more ads scheduled for this group
  // try a default ad
  if (sizeof(ads) == 0)
  {
//    perror("Advert: no active ads, trying defaults.\n");

    ads = .Advert.Group.get_default_ads(gid, db);

    if (sizeof(ads) == 0)
    {
      // no default ads for this group. we are screwed
      perror("Advert: no active or default ad found for ad group '"+
		group+"'\n");
      return "<!-- no default ads found -->";
    }

    ad = rand_ad(ads);
  }
  // return a random ad from the set weighted by its
  // remaining hourly impressions
  else
    ad = rand_weighted_ad(ads);

  // display the ad and log the impression
  set_last_ad(ad->id, id);
  save_page_state(ad, id);
  ad->location = location;
  ad->gid = gid;
  return .Advert.Ad.view(ad, gid, id->remoteaddr, 
			(int)id->cookies->RoxenUserID, db);
}

// rand_ad
// 	return a random ad from the set
mapping rand_ad(array(mapping) ads)
{
  return ads[random(sizeof(ads))];
}

// rand_weighted_ad
// 	return a random ad weighted by its desired impressions per hour
mapping rand_weighted_ad(array(mapping) ads)
{
  int n, r;

  n = 0;
  foreach(ads, mapping ad)
    n += (int)ad->weight;
  r = random(n);
  n = 0;
  foreach(ads, mapping ad)
  {
    n += (int)ad->weight;
    if (r < n)
      return ad;
  }
}

// update_weights
// 	updates the weights of each run once per hour
void update_weights(object conf)
{
  object db, result;
  array row;
  string query;

  db = conf->sql_connect(database);

  query = "SELECT r.id, COUNT(i.id) FROM runs AS r LEFT JOIN impressions AS i "
	  "ON r.id=i.run WHERE r.startd <= NOW() GROUP BY r.id";
  result = db->big_query(query);
  while(row = result->fetch_row())
    .Advert.Run.do_update_weight(db, row[1], row[0]);

  remove_call_out(update_weights);
  call_out(update_weights, 60*60, conf);
}

// set_last_ad
//	stores in the client via a cookie the last ad it has been served.
void set_last_ad(string ad, object id)
{
  string cookie;

  cookie = "last_ad="+http_encode_cookie(ad)+"; path=/";

  if(!mappingp(id->misc->moreheads)) {
    id->misc->moreheads = ([]);
  }

  if(id->misc->moreheads["Set-Cookie"])
    if(arrayp(id->misc->moreheads["Set-Cookie"]))
      id->misc->moreheads["Set-Cookie"] += ({ cookie });
    else
      id->misc->moreheads["Set-Cookie"] = 
                ({ id->misc->moreheads["Set-Cookie"], cookie });
  else
    id->misc->moreheads["Set-Cookie"] = cookie;
}

// save_page_state
//	saves in the request object state about ad to make targeting
//	decitions when processing other ads in the same page
void save_page_state(mapping ad, object id)
{

  // save page ad state
  if (!multisetp(id->misc->page_ads))
    id->misc->page_ads = (< ad->id >);
  else
    id->misc->page_ads[ad->id] = 1;

  // save page campaign state
  if (!multisetp(id->misc->page_campaigns))
    id->misc->page_campaigns = (< ad->campaign >);
  else
    id->misc->page_campaigns[ad->campaign] = 1;

  // save page competitor state
  if (!multisetp(id->misc->page_competitors))
    id->misc->page_competitors = (< >);
  foreach(ad->competitors, string competitor)
    id->misc->page_competitors[competitor] = 1;
}

