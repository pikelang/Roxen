/*
 * $Id: requeststatus.pike,v 1.2 1997/11/19 15:23:15 grubba Exp $
 */

inherit "wizard";
constant name= "Status//Access / request status";

constant doc = ("Shows the amount of data handled since last restart.");

constant more=0;

mixed page_0(object id, object mc)
{
  return roxen->full_status();
}

mixed handle(object id) { return wizard_for(id,0); }

