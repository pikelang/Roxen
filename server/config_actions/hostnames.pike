/*
 * $Id: hostnames.pike,v 1.4 1997/12/15 01:46:37 per Exp $
 */

inherit "wizard";
constant name= "Status//Hostname lookup status";

constant doc = "Show status for the nslookup process.";

constant more=1;

mixed page_0(object id, object mc)
{ 
  if(!roxen->out)
    return ("Host name lookup queue size          : "  
	    + (sizeof(roxen->do_when_found)?sizeof(roxen->do_when_found):0)+
	    "<br>Internal DNS is used.");
  mixed kluge = roxen->out;
  if(!sizeof(kluge)) return "No processes running";
  return ("Number of host name lookup processes : "+sizeof(kluge)+"<br>"
	  "Host name lookup queue size          : "  
	  + (sizeof(roxen->do_when_found)?sizeof(roxen->do_when_found)
          + sprintf(" (%2.1f per process)<br>",
		    (float)sizeof(roxen->do_when_found) / (float)sizeof(kluge))
	     :"empty"));
}

mixed handle(object id) { return wizard_for(id,0); }
