/*
 * $Id: pipestatus.pike,v 1.3 1998/10/10 03:41:04 per Exp $
 */

inherit "wizard";
constant name= "Status//Pipe system status";

constant doc = ("Show the number of data shuffling channels.");

constant more=1;

constant ok_label = " Refresh ";
constant cancel_label = " Done ";

int verify_0()
{
  return 1;
}

mixed page_0(object id, object mc)
{
  int *ru;
  ru=_pipe_debug();
  
  if(!ru[0])
    return ("Idle");
  
  return ("<dd>"
	  "<table border=0 cellspacing=0 cellpadding=-1>"
	  "<tr align=right><td colspan=2>Number of open outputs:</td><td>"+
	  ru[0] + "</td></tr>"
	  "<tr align=right><td colspan=2>Number of open inputs:</td><td>"+
	  ru[1] + "</td></tr>"
	  "<tr align=right><td></td><td>strings:</td><td>"+ru[2]+"</td></tr>"
	  "<tr align=right><td></td><td>objects:</td><td>"+ru[3]+"</td></tr>"
	  "<tr align=right><td></td><td>mmapped:</td><td>"+(ru[1]-ru[2]-ru[3])
	  +"<td> ("+(ru[4]/1024)+"."+(((ru[4]*10)/1024)%10)+" Kb)</td></tr>"
	  "<tr align=right><td colspan=2>Buffers used in pipe:</td><td>"+ru[5]
          +"<td> (" + ru[6]/1024 + ".0 Kb)</td></tr>"
	  "</table>\n");
}

mixed handle(object id) { return wizard_for(id,0); }
