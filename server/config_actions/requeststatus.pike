/*
 * $Id: requeststatus.pike,v 1.1 1997/08/24 02:20:53 peter Exp $
 */

inherit "wizard";
constant name= "Status//Access / request status";

constant doc = ("Shows the amount of data has handled since last restarted.");

constant more=0;

mixed page_0(object id, object mc)
{
  return roxen->full_status();
}

mixed handle(object id) { return wizard_for(id,0); }
