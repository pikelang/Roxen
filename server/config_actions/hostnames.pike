/*
 * $Id: hostnames.pike,v 1.2 1997/08/30 16:13:15 peter Exp $
 */

inherit "wizard";
constant name= "Status//Hostname lookup status";

constant doc = "Show status for the nslookup process.";

constant more=1;

mixed page_0(object id, object mc)
{ 
  if(!sizeof(roxen->out))
    return "No processes running";
  return ("Number of host name lookup processes : "+sizeof(roxen->out)+"<br>"
	  "Host name lookup queue size          : "  
	  + (sizeof(roxen->do_when_found)?sizeof(roxen->do_when_found)
//	     + " (" + (string)roxen->get_size( roxen->do_when_found ) +
          + sprintf(" (%2.1f per process)<br>",
		     (float)sizeof(roxen->do_when_found)
		     / (float)sizeof(roxen->out))
	     :"empty"));
}

mixed handle(object id) { return wizard_for(id,0); }
