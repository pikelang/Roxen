/*
 * $Id: openfiles.pike,v 1.1 1997/08/24 02:20:44 peter Exp $
 */

inherit "wizard";
constant name= "Status//Open files";

constant doc = ("Show a list of all open files.");

constant more=1;

mixed page_0(object id, object mc)
{
  return roxen->checkfd(0);
}

mixed handle(object id) { return wizard_for(id,0); }
