/*
 * $Id: cachestatus.pike,v 1.3 1998/10/10 03:40:57 per Exp $
 */

inherit "wizard";
constant name= "Cache//Cache status";

constant doc = ("Show hitrate of the caching system.");

constant more=1;

constant ok_label = " Refresh ";
constant cancel_label = " Done ";

mixed page_0(object id, object mc)
{
  string ret;

  ret = "<font size=\"+1\">Memory</font>";
  ret += html_border(cache->status());
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
