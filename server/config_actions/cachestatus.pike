/*
 * $Id: cachestatus.pike,v 1.5 1998/11/22 17:08:43 per Exp $
 */

inherit "wizard";
inherit "configlocale";

string name_svenska = "Cache//Cachestatus";
string name = "Cache//Cache status";

string doc_svenska  = "Visa cachesystemts träffratio och minnesanvändning";
constant doc = ("Show the hitrate of the caching system.");

constant more=1;

constant ok_label_svenska =     " Uppdatera ";
constant cancel_label_svenska = " Klar ";

constant ok_label = " Refresh ";
constant cancel_label = " Done ";

mixed page_0(object id, object mc)
{
  string ret;

  ret = html_border(cache->status());
  if( roxen->query("cache") )
  {
    ret += "<p><font size=\"+1\">Disk</font>";
    ret += html_border( roxen->get_garb_info(), 0, 5 );
  }
  return ret;
}

int verify_0()
{
  return 1;
}

mixed handle(object id) { return wizard_for(id,0); }
