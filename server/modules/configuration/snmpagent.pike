/*
 * $Id: snmpagent.pike,v 1.1 2001/04/21 03:45:06 hop Exp $
 *
 * The Roxen SNMP agent
 * Copyright © 2000, Roxen IS.
 *
 * Author: Honza Petrous
 * January 2001


RFC 1156	base MIB (done marked by *):
		 system:
		   sysDescr *
		   sysObjectID *
		   sysUpTime *
		   sysL
		 snmp:
		   snmpInPkts *
		   snmpOutPkts *
RFC 2248	Network Services Monitoring MIB

Developer notes:

 Known issues:
	- every reload spawne a new thread, I guess that old ones are never
	  used then.
	- every reload add a new record about opened UDP port (at least
	  on Linux, try 'netstat -ap | grep udp-port-number'
 Todos:
    before release:
	- implement cold trap
	- implement MIB tree 'browsing', ie. reaction on the 'getNext' op.
	- create RIS private MIB
    later:
	- MODULE_PROVIDER
	- v2 enhancements
	- define module API for MIB oid generation, trap providing, ....
	- enhance trap features
	- optimize using of the ASN1 module and remove ASN1 objects hack

 */

#define SNMPAGENT_DEBUG 1
#ifdef SNMPAGENT_DEBUG
# define SNMPAGENT_MSG(X) werror("SNMPagent: "+X+"\n")
# define SNMPAGENT_MSGS(X, Y) werror("SNMPagent: "+X+"\n", @Y)
#else
# define SNMPAGENT_MSG(X)
# define SNMPAGENT_MSGS(X, Y)
#endif

inherit "module";
#include <roxen.h>
#include <module.h>
#include <config_interface.h>

#define SNMP_OP_GETREQUEST	0
#define SNMP_OP_GETNEXT		1
#define SNMP_OP_GETRESPONSE	2
#define SNMP_OP_SETREQUEST	3
#define SNMP_OP_TRAP		4

#define RISMIB_BASE			"1.3.6.1.4.1.8614"
#define RISMIB_BASE_WEBSERVER		RISMIB_BASE+".1"

constant module_type = MODULE_CONFIG;
constant module_name = "SNMP agent";
constant module_doc = "The embeded SNMP agent for Roxen Server. "
     "<br />"
     "<p>Roxen IS has assigned Private Enterprise Number 8614</p>"
     "<p>Roxen enterprise MIBs are accessible at <a href='http://community.roxen.com/mib/'>http://community.roxen.com/mib/</a></p>";

// Global variables
object fd;		// opened UDP port
int inited;		// flag
int snmpinpkts;
int snmpoutpkts;
mapping events;
mixed co;

#define NO_THREADS !constant(thread_create)
#define RET_NEXTOID(oidnext) if(op == SNMP_OP_GETNEXT) rdata += ([attrname:({"oid", oidnext+".0"})])
#define RET_VALUE(arr) if(op == SNMP_OP_GETREQUEST) rdata[attrname] += arr
#define LOG_EVENT(txt, pkt) log_event(txt, pkt)

void log_event(string txt, mapping pkt) {

  SNMPAGENT_MSG(sprintf("event: %O", txt));
  if(zero_type(events[txt]))
    events[txt] += ([ pkt->ip : ([ pkt->community: 1]) ]) ;
  else if(zero_type(events[txt][pkt->ip]))
    events[txt][pkt->ip] += ([ pkt->community: 1]);
  else
    events[txt][pkt->ip][pkt->community]++;

}

int chk_access(string level /*, string attrname*/, mapping pkt) {
// check access aginst CI_snmp_community array

  return
    (search(query("CI_snmp_community"), pkt->community+":"+level) > -1) ||
    (search(query("CI_snmp_community"), pkt->community+":"+"rw") > -1);

}

void process_query(mapping data) {

  mapping pdata, rdata = ([]);
  int msgid, op, errnum = 0, setflg = 0;
  string attrname, comm;

  snmpinpkts++;
  pdata = fd->decode_asn1_msg(data);

SNMPAGENT_MSG(sprintf("Got parsed: %O", pdata));

  if(!mappingp(pdata)) {
    SNMPAGENT_MSG("SNMP message can not be decoded. Silently ommited.");
    return;
  }

  msgid = indices(pdata)[0];
  comm = pdata[msgid]->community || "";
  op = pdata[msgid]->op;

  // test for correct community string
  if(!chk_access("ro", pdata[msgid])) {
    errnum = 5 /*SNMP_ERR_GENERR*/;
    attrname = indices(pdata[msgid]->attribute[0])[0];
    LOG_EVENT("Bad community name", pdata[msgid]);
  } else
  foreach(pdata[msgid]->attribute, mapping attrs) {
    mixed attrval = values(attrs)[0];
    attrname = indices(attrs)[0];
    switch(attrname) {

      case "1.3.6.1.2.1.1":
	RET_NEXTOID("1.3.6.1.2.1.1.1");
	break;
	// system.sysDescr
      case "1.3.6.1.2.1.1.1.0":
      case "1.3.6.1.2.1.1.1":
	RET_NEXTOID("1.3.6.1.2.1.1.2");
	RET_VALUE(({"str", "Roxen Webserver generic SNMP agent v0.1(development release)"}));
	break;

	// system.sysObjectID
      case "1.3.6.1.2.1.1.2.0":
      case "1.3.6.1.2.1.1.2":
	RET_NEXTOID("1.3.6.1.2.1.1.3");
	RET_VALUE (({"oid", RISMIB_BASE_WEBSERVER})); 
	break;

	// system.sysUpTime
      case "1.3.6.1.2.1.1.3.0":
      case "1.3.6.1.2.1.1.3":
	RET_NEXTOID("1.3.6.1.2.1.1.4");
	RET_VALUE (({"tick", (time(1) - roxen->start_time)*1000 }));
	break;

	// system.sysContact
      case "1.3.6.1.2.1.1.4.0":
      case "1.3.6.1.2.1.1.4":
	RET_NEXTOID("1.3.6.1.2.1.1.5");
	RET_VALUE (({"str", query("CI_snmp_syscontact")}));
	break;

	// system.sysName
      case "1.3.6.1.2.1.1.5.0":
      case "1.3.6.1.2.1.1.5":
	RET_NEXTOID("1.3.6.1.2.1.1.6");
	RET_VALUE (({"str", query("CI_snmp_sysname")}));
	break;

	// system.sysLocation
      case "1.3.6.1.2.1.1.6.0":
      case "1.3.6.1.2.1.1.6":
	RET_NEXTOID("1.3.6.1.2.1.1.7");
	RET_VALUE (({"str", query("CI_snmp_syslocation")}));
	break;

	// system.sysServices
      case "1.3.6.1.2.1.1.7.0":
      case "1.3.6.1.2.1.1.7":
	RET_NEXTOID("1.3.6.1.2.1.11.1");
	RET_VALUE (({"int", query("CI_snmp_sysservices")}));
	break;

	// snmp.snmpInPkts
      case "1.3.6.1.2.1.11.1.0":
      case "1.3.6.1.2.1.11.1":
	RET_NEXTOID("1.3.6.1.2.1.11.2");
	RET_VALUE (({"count", snmpinpkts}));
	break;

	// snmp.snmpOutPkts
      case "1.3.6.1.2.1.11.2.0":
      case "1.3.6.1.2.1.11.2":
	//RET_NEXTOID("1.3.6.1.2.1.11.2");
	RET_VALUE (({"count", snmpoutpkts}));
	break;

	// www group 1.3.6.1.2.1.65.1
	// www.wwwService 1.3.6.1.2.1.65.1.1
	// www.wwwServiceTable 1.3.6.1.2.1.65.1.1.1
	// www.wwwServiceEntry 1.3.6.1.2.1.65.1.1.1.1 ...

      case RISMIB_BASE_WEBSERVER+"1.0": // HACK! For testing purpose only!
	// Server restart = 1; server shutdown = 2
	if(op == SNMP_OP_SETREQUEST && chk_access("rw", pdata[msgid])) {
	  if (attrval == 1) roxen->restart(0.5);
	  if (attrval == 2) roxen->shutdown(0.5);
	  //RET_VALUE (({"tick", (time(1) - roxen->start_time)*1000 })); // let remains client happy :)
	}
	break;


      default: 			// unknown/unsupported
	SNMPAGENT_MSG(sprintf(" unknown or unsupported OID: %O:%O", attrname, attrval));
	break;
    }
  }

  if(op == SNMP_OP_SETREQUEST && !setflg && !errnum) {
    LOG_EVENT("Set not allowed", pdata[msgid]);
  }

  //SNMPAGENT_MSG(sprintf("Answer: %O", rdata));
  // process response, if any
  snmpoutpkts++;
  if(!sizeof(rdata)) {
    if (!errnum) LOG_EVENT("No such name", pdata[msgid]);
    fd->get_response(([attrname:({"oid", attrname})]), pdata, errnum || 2 /*SNMP_NOSUCHNAME*/);
  } else
    fd->get_response(rdata, pdata);

}

void post_start() {

  mixed err;
  mapping data;
  string host = (query("CI_snmp_hostport")/":")[0];
  string port = query("CI_snmp_hostport") == host ? "" : (query("CI_snmp_hostport")/":")[1];


  fd = Protocols.SNMP.protocol(0,host,(int)port);
  if(arrayp(err))
    RXML.run_error("SNMPagent: can't open UDP port " + host+":"+port + "[" + err[0] + "].");
  SNMPAGENT_MSG(sprintf("SNMP UDP port %s:%s binded successfully.", host, port));

#ifdef COLDSTART_TRAP // Not working, yet
  // Cold start TRAP
  if (sizeof(query("CI_snmp_traphost"))) {
    mapping rdata;
    rdata = ([attrname:({"oid", "1.3.6.1.4.1.0.1.1"})]);
    rdata += ([attrname:({"ipaddr", "127.0.0.1" }) ]);   // FIXME
    rdata += ([attrname:({"int", 1 }) ]); // generic trap = warmStart
    rdata += ([attrname:({"int", 0 }) ]); // specific trap = none
    rdata += ([attrname:({"tick", (time(1) - roxen->start_time)*1000 }) ]); // uptime
  }
#endif

#if NO_THREADS
  // set callbacks
  fd->set_nonblocking(process_query);
#else
  // wait for connection
  //while(1) process_query(fd->read());
  while(1)
    if(!arrayp(err=catch(data=fd->read())))
      process_query(data);
#endif

}

void start(int num, Configuration conf)
{
  events = ([]);
  if(conf && !inited) {
    inited++;
    SNMPAGENT_MSG("Initializing...");
    fd=Stdio.UDP(); //Port();

#if NO_THREADS
    SNMPAGENT_MSG("Threads don't detected. Async I/O used intstead.");
    co = call_out( post_start, 1 );
#else
    SNMPAGENT_MSG("Threads detected. One thread will be created for agent processing.");
    thread_create( post_start );
#endif
  }
}

void stop()
{
  SNMPAGENT_MSG("Shutting down...");
  catch(fd->set_blocking());
  catch(fd->close());
#if NO_THREADS
  remove_call_out(co);
//#else
#endif
  fd = 0;
  SNMPAGENT_MSG("Shutdown complete.");
}

string status() {
  string rv = "";

  rv =  "<h2>SNMP access table</h2>\n";
#if 0 //SNMP_STATS
    rv += "<table>\n";
    rv += "<tr ><th>From</th><th>To</th><th>Size</th></tr>\n";
    foreach(mails, mapping m)
      rv += "<tr ><td>"+(m->from||"[N/A]")+"</td><td>"+(m->to||"[default]")+"</td><td>"+m->length+"</td></tr>\n";
    rv += "</table>\n";
#else
    rv += "<pre>" + sprintf("%O<br />\n", events) + "</pre>\n";
#endif
  return rv;
}

void create()
{

  inited = 0;

  set_module_creator("Honza Petrous <hop@roxen.com>");

#if 0
  defvar("CI_snmp_enable", 1, "SNMP agent enabled",
	 TYPE_FLAG|VAR_MORE, "Enable/disable SNMP agent"); 
#endif

  defvar("CI_snmp_community", ({"public:ro"}), "Community string",
	 TYPE_STRING_LIST | VAR_INITIAL, " ... ");

#if 0
  defvar("CI_snmp_mode", "smart", "Agent mode",
	 TYPE_STRING_LIST,
	 "Standard SNMP server mode, muxed SNMP mode, "
	 "proxy, agentx or automatic (smart) mode.",
	 ({"smart", "agent", "agentx", "smux", "proxy" }));
#endif

  defvar("CI_snmp_hostport", "", "IP address and port",
	 TYPE_STRING | VAR_INITIAL,
	 "Agent listenning IP adress and port. Format: [[host]:port] "
	 "If host isn't set then will be use IP address of config interface");

#ifdef COLDSTART_TRAP
  defvar("CI_snmp_traphost","","SNMP traps destinations",
	 TYPE_STRING,
	 "...");
#endif

#if 0
  defvar("CI_snmp_version",1,"SNMP protocol version",
	 TYPE_INT_LIST,
	 "...", ({1, 2/*, 3*/}));
#endif

  // system MIB subtree
  defvar("CI_snmp_syscontact","","System MIB: Contact",
	 TYPE_STRING,
	 "The textual identification of the contact person for this managed "
	 "node, together with information on how to contact this person.");
  defvar("CI_snmp_sysname","","System MIB: Name",
	 TYPE_STRING,
	 "An administratively-assigned name for this managed node. By "
	 "convention, this is the node's fully-qualified domain name.");
  defvar("CI_snmp_syslocation","","System MIB: Location",
	 TYPE_STRING,
	 "The physical location of this node (e.g., `telephone closet, 3rd "
	 "floor').");
  defvar("CI_snmp_sysservices",72,"System MIB: Services",
	 TYPE_INT,
	 "A value which indicates the set of services that this entity "
	 "primarily offers.");

}
