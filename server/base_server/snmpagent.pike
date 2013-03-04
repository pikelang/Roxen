/*
 * $Id$
 *
 * The Roxen SNMP agent
 * Copyright © 2001, Honza Petrous, hop@unibase.cz
 *
 * Author: Honza Petrous
 * January 2001


RFC 1213	base MIB
		 system.* (all done)
		 snmp.* (all done, but most of them all still death)

Future:

RFC 1215	Convention for defining traps
RFC 1227	SNMP MUX procotol and MIB
RFC 2248	Network Services Monitoring MIB
RFC 2576	Coexistence between v1, v2 and v3 of SNMP protocol
RFC 2594	Definitions of managed objects for WWW services

Developer notes:

 Known issues:
	- every reload spawne a new thread, I guess that old ones are never
	  used then. [threads leak] // FIXME: solved by switching to the async i/o
	- the OID must be minimally 5 elements long, otherwise GETNEXT return
	  "no such name" error
	- default value for snmpagent host/port variable in the config. int.
	  hasn't set correctly hostname part // FIXME: how reach config.int.'s URL
						       from define_global_variables ?
	- vsStopTrap is generated even if the virtual server wasn't started

 Todos:

	- module reloading
	- Roxen.module API for registering MIB subtree

	- SNMP v3 
	- security (DES?)


 */

inherit "global_variables";
inherit Roxen;
#define roxen roxenp()



// FIXME: thread leaking is hiden by moving to the async i/o model
//#define NO_THREADS !constant(thread_create)
#define NO_THREADS 1 

#ifdef SNMPAGENT_DEBUG
# define SNMPAGENT_MSG(X) report_notice("SNMPagent: "+X+"\n")
# define SNMPAGENT_MSGS(X, Y) report_notice("SNMPagent: "+X+"\n", @Y)
#else
# define SNMPAGENT_MSG(X)
# define SNMPAGENT_MSGS(X, Y)
#endif

//! Default port number for agent
#ifndef SNMPAGENT_DEFAULT_PORT
#define SNMPAGENT_DEFAULT_PORT	1610
#endif

#define SNMP_OP_GETREQUEST	0
#define SNMP_OP_GETNEXT		1
#define SNMP_OP_GETRESPONSE	2
#define SNMP_OP_SETREQUEST	3
#define SNMP_OP_TRAP		4

#define OBJ_STR(x)		({"str", x})
#define OBJ_INT(x)		({"int", x})
#define OBJ_OID(x)		({"oid", x})
#define OBJ_TICK(x)		({"tick", x})
#define OBJ_COUNT(x)		({"count", x})

// The starting part of OID of every object will have, so we strip it out
// before making index from OID to the MIB DB
#define MIBTREE_BASE				"1.3.6.1"

#define RISMIB_BASE_ADD				"4.1.8614"
// enterprises.roxenis
#define RISMIB_BASE				MIBTREE_BASE+"."+RISMIB_BASE_ADD
#define RISMIB_BASE_WEBSERVER_ADD		"1.1"
// enterprises.roxenis.app.webserver
#define RISMIB_BASE_WEBSERVER			RISMIB_BASE+"."+RISMIB_BASE_WEBSERVER_ADD
//
// enterprises.roxenis.app.webserver.global
#define RISMIB_BASE_WEBSERVER_GLOBAL		RISMIB_BASE_WEBSERVER+".1"
// enterprises.roxenis.app.webserver.global.restart
#define RISMIB_BASE_WEBSERVER_GLOBAL_BOOT	RISMIB_BASE_WEBSERVER_GLOBAL+".1"
// enterprises.roxenis.app.webserver.global.vsCount
#define RISMIB_BASE_WEBSERVER_GLOBAL_VS		RISMIB_BASE_WEBSERVER_GLOBAL+".2"
//
// enterprises.roxenis.app.webserver.vsTable
#define RISMIB_BASE_WEBSERVER_VS		RISMIB_BASE_WEBSERVER+".2"
// enterprises.roxenis.app.webserver.vsTable.vsEntry.vsIndex
#define RISMIB_BASE_WEBSERVER_VS_INDEX		RISMIB_BASE_WEBSERVER_VS+".1.1"
// enterprises.roxenis.app.webserver.vsTable.vsEntry.vsName
#define RISMIB_BASE_WEBSERVER_VS_NAME		RISMIB_BASE_WEBSERVER_VS+".1.2"
// enterprises.roxenis.app.webserver.vsTable.vsEntry.vsDescription
#define RISMIB_BASE_WEBSERVER_VS_DESC		RISMIB_BASE_WEBSERVER_VS+".1.3"
// enterprises.roxenis.app.webserver.vsTable.vsEntry.vsSent
#define RISMIB_BASE_WEBSERVER_VS_SDATA		RISMIB_BASE_WEBSERVER_VS+".1.4"
// enterprises.roxenis.app.webserver.vsTable.vsEntry.vsReceived
#define RISMIB_BASE_WEBSERVER_VS_RDATA		RISMIB_BASE_WEBSERVER_VS+".1.5"
// enterprises.roxenis.app.webserver.vsTable.vsEntry.vsHeaders
#define RISMIB_BASE_WEBSERVER_VS_SHDRS		RISMIB_BASE_WEBSERVER_VS+".1.6"
// enterprises.roxenis.app.webserver.vsTable.vsEntry.vsRequests
#define RISMIB_BASE_WEBSERVER_VS_REQS		RISMIB_BASE_WEBSERVER_VS+".1.7"
//
// enterprises.roxenis.app.webserver.trapGlobal
#define RISMIB_BASE_WEBSERVER_TRAPG		RISMIB_BASE_WEBSERVER+".3"
// enterprises.roxenis.app.webserver.trapGlobal.serverDownTrap
#define RISMIB_BASE_WEBSERVER_TRAPG_DOWN	RISMIB_BASE_WEBSERVER_TRAPG+".1"
// enterprises.roxenis.app.webserver.trapVs
#define RISMIB_BASE_WEBSERVER_TRAPVS		RISMIB_BASE_WEBSERVER+".4"
// enterprises.roxenis.app.webserver.trapVs.vsExternalTrap
#define RISMIB_BASE_WEBSERVER_TRAP_VSEXT	RISMIB_BASE_WEBSERVER_TRAPVS+".1"
// enterprises.roxenis.app.webserver.trapVs.vsStartTrap
#define RISMIB_BASE_WEBSERVER_TRAP_VSSTART	RISMIB_BASE_WEBSERVER_TRAPVS+".2"
// enterprises.roxenis.app.webserver.trap.vsStopTrap
#define RISMIB_BASE_WEBSERVER_TRAP_VSSTOP	RISMIB_BASE_WEBSERVER_TRAPVS+".3"
// enterprises.roxenis.app.webserver.trapVs.vsCongChangedTrap
#define RISMIB_BASE_WEBSERVER_TRAP_VSCONF	RISMIB_BASE_WEBSERVER_TRAPVS+".4"

#define LOG_EVENT(txt, pkt) log_event(txt, pkt)

#if !efunc(Array.oid_sort_func)
int oid_sort_func(string a0,string b0) {
    string a2="",b2="";
    int a1, b1;
    sscanf(a0,"%d.%s",a1,a2);
    sscanf(b0,"%d.%s",b1,b2);
    if (a1>b1) return 1;
    if (a1<b1) return 0;
    if (a2==b2) return 0;
    return oid_sort_func(a2,b2);
}
#define OID_SORT_FUNC	oid_sort_func
#else
#define OID_SORT_FUNC	Array.oid_sort_func
#endif


//!
class SNMPagent {
  private int enabled;

  // Global variables
  private object fd;		// opened UDP port
  private int inited;		// flag
  private int snmpinpkts;
  private int snmpoutpkts;
  private int snmpbadver;
  private int snmpbadcommnames;
  private int snmpbadcommuses;
  private int snmpenaauth;
  private mapping events;
  private mixed co;
  private object mib;
  private mapping vsdb;		// table of registered virtual servers
  private array dtraps;		// delayed traps

  array get_snmpinpkts() { return OBJ_COUNT(snmpinpkts); }
  array get_snmpoutpkts() { return OBJ_COUNT(snmpoutpkts); }
  array get_snmpbadver() { return OBJ_COUNT(snmpbadver); }
  array get_snmpbadcommnames() { return OBJ_COUNT(snmpbadcommnames); }
  array get_snmpbadcommuses() { return OBJ_COUNT(snmpbadcommuses); }
  array get_snmpenaauth() { return OBJ_INT(snmpenaauth); }

  array get_virtserv() { return OBJ_COUNT(sizeof(vsdb)); }

  int get_uptime() { return (time(1) - roxen->start_time)*100; }

  void create() {
    vsdb = ([]);
    dtraps = ({});
    //disable();
  }

  //! Enable SNMPagent processing.
  int enable() {

    if(enabled)
      return(enabled);
    mib = SubMIBSystem();		// system.* table
    if(objectp(mib)) {
      // snmp.*
      mib->register(SubMIBSnmp(this_object()));
      // enterprises.roxenis.*
      mib->register(SubMIBRoxenVS(this_object()));
      mib->register(SubMIBRoxenVSTable(this_object()));
      mib->register(SubMIBRoxenBoot(this_object()));
    }
    if (!status())
      start();
    enabled = 1;
    return (enabled);
  }

  //! Disable SNMPagent processing.
  int disable() {

    if(status())
      stop();
    enabled = 0;
    return (!enabled);
  }

  int status() {
    return enabled;
  }

  private void log_event(string txt, mapping pkt) {

    SNMPAGENT_MSG(sprintf("event: %O", txt));
    if(zero_type(events[txt]))
      events[txt] += ([ pkt->ip : ([ pkt->community: 1]) ]) ;
    else if(zero_type(events[txt][pkt->ip]))
      events[txt][pkt->ip] += ([ pkt->community: 1]);
    else
      events[txt][pkt->ip][pkt->community]++;
  }

  //! Check access aginst snmp_community array.
  int chk_access(string level /*, string attrname*/, mapping pkt) {

    return
      (search(query("snmp_community"), pkt->community+":"+level) > -1) ||
      (search(query("snmp_community"), pkt->community+":"+"rw") > -1);
  }


  //! The main code of SNMPagent.
  private void process_query(mapping data) {

    mapping pdata, rdata = ([]);
    int msgid, op, errnum = 0, setflg = 0;
    string attrname, comm;
    array val;

    snmpinpkts++;
    pdata = fd->decode_asn1_msg(data);

    //SNMPAGENT_MSG(sprintf("Got parsed: %O", pdata));

    if(!mappingp(pdata)) {
      SNMPAGENT_MSG("SNMP message can not be decoded. Silently ommited.");
      return;
    }

    msgid = indices(pdata)[0];
    comm = pdata[msgid]->community || "";
    op = pdata[msgid]->op;

    // test for correct community string
    if(!chk_access("ro", pdata[msgid])) {
      snmpbadcommnames++;
      errnum = 5 /*SNMP_ERR_GENERR*/;
      attrname = indices(pdata[msgid]->attribute[0])[0];
      LOG_EVENT("Bad community name", pdata[msgid]);
      authfailure_trap(pdata[msgid]);
    } else
    foreach(pdata[msgid]->attribute, mapping attrs) {
      mixed attrval = values(attrs)[0];
      attrname = indices(attrs)[0];

      if(!mib) {
		SNMPAGENT_MSG(" MIB table isn't loaded!\n");
		// what to do now ?
	  }
	  switch(op) {

	  case SNMP_OP_GETREQUEST:
		val = mib->get(attrname, pdata[msgid]);
	    if (arrayp(val) && sizeof(val) && val[0])
	      rdata[attrname] += val;
	    break;

	  case SNMP_OP_GETNEXT:
		val = mib->getnext(attrname, pdata[msgid]);
	    if (arrayp(val) && sizeof(val) && val[0])
	      //rdata[attrname] += val;
	      rdata[val[0]] += val[1..2];
	    break;

	  case SNMP_OP_SETREQUEST:
		val = mib->set(attrname, attrval, pdata[msgid]);
		if(arrayp(val) && sizeof(val))
		  setflg = val[0];
		//rdata[attrname] += ({ "int", attrval });
		rdata["1.3.6.1.2.1.1.3.0"] += OBJ_TICK(get_uptime());
		if (arrayp(val) && stringp(val[1]))
		  report_warning(val[1]);
		break;


	    } //switch
        //else
	//  SNMPAGENT_MSG(sprintf(" unknown or unsupported OID: %O:%O", attrname, attrval));
      
    } //foreach

    if(op == SNMP_OP_SETREQUEST && !setflg && !errnum) {
      LOG_EVENT("Set not allowed", pdata[msgid]);
	  snmpbadcommuses++;
    }

    //SNMPAGENT_MSG(sprintf("Answer: %O", rdata));
    snmpoutpkts++;
    if(!sizeof(rdata)) {
      if (!errnum) LOG_EVENT("No such name", pdata[msgid]);
      fd->get_response(([attrname:({"oid", attrname})]), pdata, errnum || 2 /*SNMP_NOSUCHNAME*/);
      // future note: v2c, v3 protos want to return "endOfMibView"
    } else
      fd->get_response(rdata, pdata);
  }

  //! Returns domain name of the config. int. virtual server
  private string get_cif_domain() {

    return(Standards.URI(roxen->configurations[0]->get_url()||"http://0.0.0.0")->host);
  }

  //! Opens the SNMP port. Then waits for the requests. 
  private void real_start() {

    mixed err;
    array hp = query("snmp_hostport")/":";
    int p = (sizeof(hp)>1) ? (int)hp[1] : (int)SNMPAGENT_DEFAULT_PORT;

    if(!sizeof(hp[0]))
      hp[0] = get_cif_domain();
    err = catch( fd = Protocols.SNMP.protocol(0, hp[0], p||161) );
    if(arrayp(err))
      RXML.run_error("SNMPagent: can't open UDP port " + hp[0]+":"+(string)(p||161)+"[" + err[0] + "].");
    SNMPAGENT_MSG(sprintf("SNMP UDP port %s:%d binded successfully.", hp[0], p||161));

    // first we server dealyed traps
    if(arrayp(dtraps) && sizeof(dtraps))
      foreach(dtraps, array dtrap1)
	fd->trap( @dtrap1 );
    dtraps = ({});

    enabled = 1;
#if NO_THREADS
    // set callbacks
    fd->set_nonblocking(process_query);
#else
    // wait for connection
    //while(1) process_query(fd->read());
    while(enabled)
      if(!arrayp(err=catch(data=fd->read())))
        process_query(data);
#endif

  }

  //! Starts SNMP agent by calling real_start method
  private void start() {

    events = ([]);
    if(!inited) {
      inited++;
      SNMPAGENT_MSG("Initializing...");
      //fd = Stdio.UDP(); //Port();

#if NO_THREADS
      //SNMPAGENT_MSG("Threads don't detected. Async I/O used intstead.");
      co = call_out( real_start, 1 );
#else
      //SNMPAGENT_MSG("Threads detected. One thread will be created for agent processing.");
      th = thread_create( real_start );
#endif
    }
  }

  //! Stops processing of SNMP agent by cleaning all internal objects
  void stop() {

    SNMPAGENT_MSG("Shutting down...");
    fd->set_read_callback(0);
    catch(fd->set_blocking());
    catch(fd->close());
#if NO_THREADS
    remove_call_out(co);
#else
    th = 0;
#endif
    destruct(fd); // avoid fd leaking; FIXME: some cyclic dependencies in SNMP pmod.
    fd = 0;
    inited = 0;
    SNMPAGENT_MSG("Shutdown complete.");
  }

  // start/stop notificator
  private void x_trap(string oid, array|void val) {

    object uri;
    int rtype = 6;
    mapping aval = ([oid: val]);

    switch (oid) {

	case "0"+RISMIB_BASE_WEBSERVER:		// flagged
		oid = RISMIB_BASE_WEBSERVER;
		rtype = 0;
		break;

	case "4"+RISMIB_BASE_WEBSERVER:		// flagged
		oid = RISMIB_BASE_WEBSERVER;
		rtype = 4;
		break;

	case RISMIB_BASE_WEBSERVER_TRAPG_DOWN:
		break;

    }
    if(!arrayp(val))
      aval = ([]);
    foreach(query("snmp_global_traphosts"), string url) {
      if(catch(uri = Standards.URI(url))) {
	SNMPAGENT_MSG(sprintf("Traphost is invalid: %s !", url));
	continue; // FIXME: what about possibility to add some warnings?
      }
      if(objectp(fd)) {
	SNMPAGENT_MSG(sprintf("Trap sent: %s", url));
	fd->trap( aval,
			oid, rtype, 0,
			get_uptime(),
			0, uri->host, uri->port );
      } else {
	SNMPAGENT_MSG(sprintf("Trap delayed: %s", url));
	dtraps += ({ ({ aval,
			oid, rtype, 0,
			get_uptime(),
			0, uri->host, uri->port }) });
      }
    }
  }

  //! Start notificator.
  void start_trap() {
    x_trap("0"+RISMIB_BASE_WEBSERVER);
  }

  //! Stop notificator.
  void stop_trap() {
    x_trap(RISMIB_BASE_WEBSERVER_TRAPG_DOWN);
  }

  //! Virtual server start notificator
  void vs_start_trap(int vsid) {
    x_trap(RISMIB_BASE_WEBSERVER_TRAP_VSSTART+".0", OBJ_INT(vsid));
  }

  //! Virtual server stop notificator
  void vs_stop_trap(int vsid) {
    x_trap(RISMIB_BASE_WEBSERVER_TRAP_VSSTOP+".0", OBJ_INT(vsid));
  }

  //! Warm start notificator
  void warmstart_trap() {

  }

  //! Authentication failure notificator
  void authfailure_trap(mapping data) {
    x_trap("4"+RISMIB_BASE_WEBSERVER);
  }

  //! Enterprise specific trap notificator
  void enterprise_trap(int vsid, mapping attrvals) {

    object uri;

      if(vsdb[vsid] && vsdb[vsid]->variables["snmp_traphosts"] &&
             sizeof(vsdb[vsid]->variables["snmp_traphosts"]->query())) {
	     SNMPAGENT_MSG(sprintf("server %O(#%d): traphosts:%O",
			vsdb[vsid]->name, vsid,
			vsdb[vsid]->variables["snmp_traphosts"]->query()));
	    foreach(vsdb[vsid]->variables["snmp_traphosts"]->query(), mixed thost) {
		  if(catch(uri = Standards.URI(thost))) {
		    SNMPAGENT_MSG(sprintf("Traphost is invalid: %s !", thost));
		    continue; // FIXME: what about possibility to add some warnings?
		  }
		  SNMPAGENT_MSG(sprintf("Enterprise trap sent: %s", thost));
		  fd->trap(
		    attrvals || ([RISMIB_BASE_WEBSERVER_TRAP_VSEXT+".0": OBJ_STR(vsdb[vsid]->name)]),
		    RISMIB_BASE_WEBSERVER_TRAP_VSEXT, 6, 0,
		    get_uptime(),
		    0,
		    uri->host, uri->port);
		}
	  } else
	    if(vsdb[vsid])
	      SNMPAGENT_MSG(sprintf("server %O(#%d) hasn't any traphosts.",
			    vsdb[vsid] && vsdb[vsid]->name, vsid));
  }

  //! Adds virtual server to the DB of managed objects
  int add_virtserv(int vsid) {

    if(zero_type(vsdb[vsid])) {
      report_debug(sprintf("SNMPagent: added server %O(#%d)\n",
		           roxen->configurations[vsid]->name, vsid));
	  vsdb += ([vsid: roxen->configurations[vsid]]);
     }

    // some tabulars handlers ...
    

    return(1);
  }

  //! Returns name of the virtual server
  string get_virtservname(int vsid) {
    if(zero_type(vsdb[vsid]))
      return 0; // bad index number
    return (roxen->configurations[vsid]->name);
  }

  //! Returns description of the virtual server
  string get_virtservdesc(int vsid) {
    if(zero_type(vsdb[vsid]))
      return 0; // bad index number
    return "blahblah!"; //(roxen->configurations[vsid]->name);
  }

  //! Returns send data statistics of the virtual server
  int get_virtservsdata(int vsid) {
    if(zero_type(vsdb[vsid]))
      return -1; // bad index number
    return (roxen->configurations[vsid]->sent);
  }

  //! Returns received data statistics of the virtual server
  int get_virtservrdata(int vsid) {
    if(zero_type(vsdb[vsid]))
      return -1; // bad index number
    return (roxen->configurations[vsid]->received);
  }

  //! Returns send headers statistics of the virtual server
  int get_virtservshdrs(int vsid) {
    if(zero_type(vsdb[vsid]))
      return -1; // bad index number
    return (roxen->configurations[vsid]->hsent);
  }

  //! Returns request statistics of the virtual server
  int get_virtservreqs(int vsid) {
    if(zero_type(vsdb[vsid]))
      return -1; // bad index number
    return (roxen->configurations[vsid]->requests);
  }


  //! Deletes virtual server's specific objects from DB
  int del_virtserv(int vsid) {

    if(!zero_type(vsdb[vsid])) {
      report_debug(sprintf("SNMPagent: deleted server %O(#%d)\n",
		           roxen->configurations[vsid]->name, vsid));
	  vsdb -= ([ vsid: 0 ]);
	}

    return(1);
  }

} // end of SNMPagent object

//! Removes first four octets from OID string, as internal table works
//! on such stripped OIDs.
private string|int oid_strip (string oid) { // note: this method must be public!

  array arr = oid / ".";
  if (sizeof(arr) < 5)  // FIXME: exists oid with less octets?
    return 0;
  oid = arr[4..] * ".";
  return oid;
}

//!
//! Generic class for submib tree managers, or individual objects as well.
//!
class SubMIBManager {

  //! Name of object
  constant name = "generic skeleton";

  //! OID number of the registered subtree
  constant tree = "";

  //! Table of managed objects in the form:
  //!   ([ string stripped_oid: function get_value ])
  mapping submibtab = ([]);

  //! Table of registered subtree managers in the form:
  //!    ([ string stripped_oid: object manager ])
  mapping subtreeman = ([]);

  //! Checks existence of an managed object in the database
  private int|string oid_check(string oid) {

    if(!(oid = oid_strip(oid))) return 0;
    return zero_type(submibtab[oid]) ? 0 : oid;
  }

  //! Low level method for registering a new manager for object or the whole subtree.
  //! Note: If oid is ancessor of already existing oids, then autohiding of existing
  //!       object's managers will be done. Unregistering reenabled such hided managers
  //!       again.
  int register(object manager) {

    string oid = manager->tree;

    if(oid_check(oid))
      return 0; // false => the OID is already registered.
		// What about stackable organization ?
    if(subtreeman[oid])
      return 0; // false => already registered
    subtreeman += ([oid: manager]); // FIXME: autohiding of subtree. Is it goood?
    SNMPAGENT_MSG(sprintf("manager %O registered for tree %O", manager->name, manager->tree));
    return 1; // ok (registered)
  }

  void create() {
  
	report_error("SubMIBManager object [" + (string)name + "] hasn't replaced contructor!\n");
  } // create

  //! Returns array. First element is type of second element.
  //! Is usable for very primitive managed objects, in which case the value
  //! is got by calling function from submibtab table.
  array get(string oid, mapping|void pkt) {

    function rval;
    string soid;

    SNMPAGENT_MSG(sprintf("%s: GET(%O) from %s@%s:%d", name, oid, pkt->community, pkt->ip,pkt->port));
    soid = oid_strip(oid);
    if (functionp(rval = submibtab[soid])) {
      SNMPAGENT_MSG("found MIB object.");
      return rval();
    }

    // hmm, now we have to try some of the registered managers
    array s = soid/".";
    for(int cnt = sizeof(s)-1; cnt>0; cnt--) {
      SNMPAGENT_MSG(sprintf("finding manager for tree %O", s[..cnt]*"."));
      if(subtreeman[s[..cnt]*"."]) {
	// good, subtree manager exists
	string manoid = s[..cnt]*".";
        SNMPAGENT_MSG(sprintf("found subtree manager: %s(%O)",
				subtreeman[manoid]->name, manoid));
	return subtreeman[manoid]->get(oid, pkt);
      }
    }

    SNMPAGENT_MSG("Not found any suitable manager");
    return 0;
  }

  //! Returns array ({ nextoid, type, val }) or 0
  array|int getnext(string oid, mapping|void pkt) {

    //array(string) idxnums = Array.sort(indices(submibtab));
    array idxnums = Array.sort_array(indices(submibtab), OID_SORT_FUNC);
    int idx;
    string soid, manoid;
    array s;

    SNMPAGENT_MSG(sprintf("%s: GETNEXT(%O) from %s@%s:%d", name, oid, pkt->community, pkt->ip,pkt->port));
    if(!(soid = oid_strip(oid)))
      return 0;
    idx = search(idxnums, soid);
    if(idx >= 0) {
      // good, we found equality
      SNMPAGENT_MSG(sprintf("%s: eq match: %O", tree, idx));
      if(idx < sizeof(idxnums)-1)
	return (({ MIBTREE_BASE+"."+(string)idxnums[idx+1],
                   @submibtab[idxnums[idx+1]]() }));
    } else {
      int tlen = sizeof(tree/".");
      array sarr = soid/".";
      if(sizeof(sarr)>=tlen && (sarr[..tlen-1]*".") == tree) {
        SNMPAGENT_MSG(name+": owned subtree found.");
        // hmm, now we have to find nearest subtree
        for(idx = 0; idx < sizeof(idxnums); idx++)
	  if (soid < idxnums[idx]) {
            SNMPAGENT_MSG(sprintf("subtree match: %O", idxnums[idx]));
	    return (({ MIBTREE_BASE+"."+(string)idxnums[idx],
		     @submibtab[idxnums[idx]]() }));
	  }
      }
    }

    SNMPAGENT_MSG(name+": trying foreign object");
    s = soid/".";
    // hmm, now we have to try some of the registered managers
    for(int cnt = sizeof(s)-1; cnt>0; cnt--) {
      SNMPAGENT_MSG(sprintf("finding manager for tree %O", s[..cnt]*"."));
      if(subtreeman[s[..cnt]*"."]) {
	// good, subtree manager exists
	manoid = s[..cnt]*".";
	SNMPAGENT_MSG(sprintf("found subtree manager: %s(%O)",
				subtreeman[manoid]->name, manoid));
	return subtreeman[manoid]->getnext(oid, pkt);
      }
    }

    SNMPAGENT_MSG(name+": trying nearest manager");
    // OK, we have to find nearest oid manager
    //idxnums = Array.sort(indices(subtreeman));
    idxnums = Array.sort_array(indices(subtreeman), OID_SORT_FUNC);
    idx = Array.search_array(idxnums, OID_SORT_FUNC, soid);
    if(idx >= 0) {
      manoid = idxnums[idx];
      SNMPAGENT_MSG(sprintf("found nearest manager: %s(%O)",
				subtreeman[manoid]->name, manoid));
      return subtreeman[manoid]->getnext(MIBTREE_BASE+"."+manoid, pkt);
    }

    SNMPAGENT_MSG("Not found any suitable manager");
    return 0;
  }

  int compare_oid(string oid1, string oid2) {

    array o1 = oid1/".", o2 = oid2/".";
    int len = sizeof(o1)<sizeof(o2)?sizeof(o1):sizeof(o2);

    for (int idx = 0; idx < len; idx++)
      if(o1[idx] > o2[idx])
	return 1;
    return 0;
  }

  //! Tries to do SET operation.
  array set(string oid, mixed val, mapping|void pkt) {

    string soid;

    SNMPAGENT_MSG(sprintf("SET(%s): %O = %O", name, oid, val));
    soid = oid_strip(oid);

    // hmm, now we have to try some of the registered managers
    array s = soid/".";
    for(int cnt = sizeof(s)-1; cnt>0; cnt--) {
      SNMPAGENT_MSG(sprintf("finding manager for tree %O", s[..cnt]*"."));
      if(subtreeman[s[..cnt]*"."]) {
	// good, subtree manager exists
	string manoid = s[..cnt]*".";
        SNMPAGENT_MSG(sprintf("found subtree manager: %s(%O)",
				subtreeman[manoid]->name, manoid));
	return subtreeman[manoid]->set(oid, val, pkt);
      }
    }

    SNMPAGENT_MSG("Not found any suitable manager");
    return ({ 0, 0});
  }

  //! External function for MIB object returning nothing
  array get_null() { return OBJ_COUNT(0); }

} // SubMIBManager

// base external feeders

//! External function for MIB object 'system.sysDescr'
array get_description() {
  return OBJ_STR("Roxen Webserver SNMP agent v"+("$Revision: 1.28 $"/" ")[1]+" (devel. rel.)");
}

//! External function for MIB object 'system.sysOID'
array get_sysoid() {
  return OBJ_OID(RISMIB_BASE_WEBSERVER);
}

//! External function for MIB object 'system.sysUpTime'
array get_sysuptime() {
  return OBJ_TICK((time(1) - roxen->start_time)*100);
}

//! External function for MIB object 'system.sysContact'
array get_syscontact() {
  return OBJ_STR(query("snmp_syscontact"));
}

//! External function for MIB object 'system.sysName'
array get_sysname() {
  return OBJ_STR(query("snmp_sysname"));
}

//! External function for MIB object 'system.sysLocation'
array get_syslocation() {
  return OBJ_STR(query("snmp_syslocation"));
}

//! External function for MIB object 'system.sysServices'
array get_sysservices() {
  return OBJ_INT(query("snmp_sysservices"));
}



//! system subtree manager
//! Manages the basic system.sys* submib tree.
class SubMIBSystem {

  inherit SubMIBManager;

  constant name = "system";
  constant tree = "2.1.1";

  void create() {

    submibtab = ([
	  // system "2.1.1"
	  // system.sysDescr
	  "2.1.1.1.0": get_description,
	  // system.sysObjectID
	  "2.1.1.2.0": get_sysoid,
	  // system.sysUpTime
	  "2.1.1.3.0": get_sysuptime,
	  // system.sysContact
	  "2.1.1.4.0": get_syscontact,
	  // system.sysName
	  "2.1.1.5.0": get_sysname,
	  // system.sysLocation
	  "2.1.1.6.0": get_syslocation,
	  // system.sysServices
	  "2.1.1.7.0": get_sysservices,
	]);
  } // create

  array|int getnext(string oid, mapping|void pkt) {

    array rv = ::getnext(oid, pkt);
    mapping sm = ::subtreeman;

    if(intp(rv)) {
      ::subtreeman = subtreeman;
      rv = ::getnext(oid, pkt);
      ::subtreeman = sm;
    }
      return rv;
  }
   
      
} // SubMIBsystem


//! snmp subtree manager
//! Manages the basic snmp.snmp* submib tree.
class SubMIBSnmp {

  inherit SubMIBManager;

  constant name = "snmp";
  constant tree = "2.1.11";

  void create(object agent) {

    submibtab = ([
	// snmp
	//"2.1.11": ({ 0, get_null, "2.1.11.1.0" }),
	// snmp.snmpInPkts
	"2.1.11.1.0": agent->get_snmpinpkts,
	// snmp.snmpOutPkts
	"2.1.11.2.0": agent->get_snmpoutpkts,
	// snmp.snmpBadVers
	"2.1.11.3.0": agent->get_snmpbadver,
	// snmp.snmpInBadCommunityNames
	"2.1.11.4.0": agent->get_snmpbadcommnames,
	// snmp.snmpInBadCommunityUses
	"2.1.11.5.0": get_null,
	// snmp.snmpInASNParseErrs
	"2.1.11.6.0": get_null,
	// 7 is not used
	// snmp.snmpInTooBigs
	"2.1.11.8.0": get_null,
	// snmp.snmpInNoSuchNames
	"2.1.11.9.0": get_null,
	// snmp.snmpInBadValues
	"2.1.11.10.0": get_null,
	// snmp.snmpInReadOnlys
	"2.1.11.11.0": get_null,
	// snmp.snmpInGenErrs
	"2.1.11.12.0": get_null,
	// snmp.snmpInTotalReqVars
	"2.1.11.13.0": get_null,
	// snmp.snmpInTotalSetVars
	"2.1.11.14.0": get_null,
	// snmp.snmpInGetRequests
	"2.1.11.15.0": get_null,
	// snmp.snmpInGetNexts
	"2.1.11.16.0": get_null,
	// snmp.snmpInSetRequests
	"2.1.11.17.0": get_null,
	// snmp.snmpInGetResponses
	"2.1.11.18.0": get_null,
	// snmp.snmpInTraps
	"2.1.11.19.0": get_null,
	// snmp.snmpOutTooBigs
	"2.1.11.20.0": get_null,
	// snmp.snmpOutNoSuchNames
	"2.1.11.21.0": get_null,
	// snmp.snmpOutBadValues
	"2.1.11.22.0": get_null,
	// 23 is not used
	// snmp.snmpOutGenErrs
	"2.1.11.24.0": get_null,
	// snmp.snmpOutGetRequests
	"2.1.11.25.0": get_null,
	// snmp.snmpOutGetNexts
	"2.1.11.26.0": get_null,
	// snmp.snmpOutSetRequests
	"2.1.11.27.0": get_null,
	// snmp.snmpOutGetResponses
	"2.1.11.28.0": get_null,
	// snmp.snmpOutTraps
	"2.1.11.29.0": get_null,
	// snmp.snmpEnableAuthenTraps
	"2.1.11.30.0": agent->get_snmpenaauth,
	
	]);

  }
}

//! roxenis enterprise subtree manager
//! Manages the enterprise.roxenis.* submib tree.
class SubMIBRoxenVS {

  inherit SubMIBManager;

  constant name = "enterprises.roxenis.app.webserver.global.vsCount";
  constant tree = RISMIB_BASE_WEBSERVER_GLOBAL_VS - (MIBTREE_BASE+".");

  void create(object agent) {

    submibtab = ([
	// enterprises
	// hack2 :)
	tree+".0": agent->get_virtserv,
    ]);
  }
}

/*
	    switch (attrname) {
	      case RISMIB_BASE_WEBSERVER+".1.0":
	        // HACK! For testing purpose only!
	        // Server restart = 1; server shutdown = 2
	        if(chk_access("rw", pdata[msgid])) {
		  setflg = 1;
		  rdata[attrname] += ({ "int", attrval });
	          rdata["1.3.6.1.2.1.1.3.0"] += ({"tick", get_uptime() });
		  if(attrval == 1 || attrval == 2) {
		    report_warning("SNMPagent: Initiated " + ((attrval==1)?"restart":"shutdown") + " from snmp://" + pdata[msgid]->community + "@" + pdata[msgid]->ip + "/\n");
	  	    if (attrval == 1) roxen->restart(0.5);
	  	    if (attrval == 2) roxen->shutdown(0.5);
		  }
	        } else
	          snmpbadcommuses++;
	        break;
	      case MIBTREE_BASE+".2.1.11.30.0":
	        // The standard-based (RFC1213) method of disabling auth. traps
	        if(chk_access("rw", pdata[msgid])) {
		  setflg = 1;
		  rdata[attrname] += ({ "int", attrval });
	          rdata["1.3.6.1.2.1.1.3.0"] += ({"tick", get_uptime() });
		  if(attrval == 0 || attrval == 1) {
		    report_warning("SNMPagent: Requested " + attrval?"en":"dis" + "abling of auth. traps from snmp://" + pdata[msgid]->community + "@" + pdata[msgid]->ip + "/\n");
	  	    // here will be ena/disabling of such traps
		  }
	        } else
	          snmpbadcommuses++;
	        break;
*/

//! roxenis enterprise subtree manager
//! Manages the enterprises.roxenis.app.webserver.vsTable submib tree.
class SubMIBRoxenVSTable {

  inherit SubMIBManager;

  constant name = "enterprises.roxenis.app.webserver.vsTable";
  constant tree =  RISMIB_BASE_WEBSERVER_VS  - (MIBTREE_BASE+".");

  object agent;
  
  void create(object agentp) {
    agent = agentp;
    submibtab = ([ ]);
  }

  array get(string oid, mapping|void pkt) {

    string soid, vname;
    int vdata, idx;

    SNMPAGENT_MSG(sprintf("%s: GET(%O) from %s@%s:%d", name, oid, pkt->community, pkt->ip,pkt->port));
    soid = oid_strip(oid);

    /* fist, we will try to find  an "ordinary" object in the MIB
    if (functionp(rval = submibtab[soid])) {
      SNMPAGENT_MSG("found ordinary MIB object.");
      return rval();
    }*/

    // no, so we will try to find "tabular" object instead
    if(sizeof((soid = soid - (tree + "."))/".") != 3 || (soid/".")[0] != "1")
      return ({}); // exactly two points, please (vsEntry.vs<xxx>.<num>)

    idx = ((int)(soid/".")[2]);
    switch ((soid/".")[1]) {

	case "1": // VS_INDEX
    	  vname = agent->get_virtservname(idx);
    	  if(!stringp(vname))
	    return ({}); // wrong index
    	  return (OBJ_INT(idx));

	case "2": // VS_NAME
    	  vname = agent->get_virtservname(idx);
    	  if(!stringp(vname))
	    return ({}); // wrong index
    	  return (OBJ_STR(vname));

	case "3": // VS_DESC
    	  vname = agent->get_virtservdesc(idx);
    	  if(!stringp(vname))
	    return ({}); // wrong index
    	  return (OBJ_STR(vname));

	case "4": // VS_SDATA
    	  vdata = agent->get_virtservsdata(idx);
    	  if(vdata < 0)
	    return ({}); // wrong index
    	  return (OBJ_COUNT(vdata));

	case "5": // VS_RDATA
    	  vdata = agent->get_virtservrdata(idx);
    	  if(vdata < 0)
	    return ({}); // wrong index
    	  return (OBJ_COUNT(vdata));

	case "6": // VS_SHDRS
    	  vdata = agent->get_virtservshdrs(idx);
    	  if(vdata < 0)
	    return ({}); // wrong index
    	  return (OBJ_COUNT(vdata));

	case "7": // VS_REQS
    	  vdata = agent->get_virtservreqs(idx);
    	  if(vdata < 0)
	    return ({}); // wrong index
    	  return (OBJ_COUNT(vdata));

    }
    return ({});

  }

  array getnext(string oid, mapping|void pkt) {

    string soid, noid, vname;
    int idx, vdata;
    array arr;

    SNMPAGENT_MSG(sprintf("%s: GETNEXT(%O)", name, oid));
    soid = oid_strip(oid);

    if(soid == tree) soid +=".";
    arr = allocate(5);
    switch(idx = sscanf(soid-(tree+"."), "%d.%d.%d.%s", arr[0], arr[1], arr[2], arr[3])) {

	case 3:
	  break;

	case 0:
	  arr[0] = 1;
	case 1:
	  arr[1] = 1;
	case 2:
	  arr[2] = 0;
	  break;

	default:
	  return ({});
    }
    if(!stringp(agent->get_virtservname(arr[2]+1))) {  // check on correct index
      SNMPAGENT_MSG(sprintf("DEB: idx:%O soid: %O arr: %O", idx, soid, arr));
      arr[1]++;
      if(arr[1] > 7)
	    return ({}); // outside of current manager scope
      arr[2] = 0;
    }
    arr[2]++;
    idx = arr[2];  
    noid = MIBTREE_BASE+"."+tree + "."+(string)arr[0]+"."+(string)arr[1]+"."+(string)arr[2];

    //SNMPAGENT_MSG(sprintf("DEB: arr:%O, soid: %O, noid: %O", arr, soid, noid));

    //switch ((soid/".")[1]) {
    switch (arr[1]) {

	case 1: // VS_INDEX
	  vname = agent->get_virtservname(idx);  // only checking
	  if(!stringp(vname))
	    return ({}); // wrong index
	  return (({noid, @OBJ_INT(idx)}));

	case 2: // VS_NAME
	  vname = agent->get_virtservname(idx);
	  if(!stringp(vname))
	    return ({}); // wrong index
	  return (({noid, @OBJ_STR(vname)}));

	case 3: // VS_DESCR
	  vname = agent->get_virtservname(idx);  // FIXME:  change to descr!
	  if(!stringp(vname))
	    return ({}); // wrong index
	  return (({noid, @OBJ_STR(vname)}));

	case 4: // VS_SDATA
	  vdata = agent->get_virtservsdata(idx);
	  if(vdata < 0)
	    return ({}); // wrong index
	  return (({noid, @OBJ_COUNT(vdata)}));

	case 5: // VS_RDATA
	  vdata = agent->get_virtservrdata(idx);
	  if(vdata < 0)
	    return ({}); // wrong index
	  return (({noid, @OBJ_COUNT(vdata)}));

	case 6: // VS_SHDRS
	  vdata = agent->get_virtservshdrs(idx);
	  if(vdata < 0)
	    return ({}); // wrong index
	  return (({noid, @OBJ_COUNT(vdata)}));

	case 7: // VS_REQS
	  vdata = agent->get_virtservreqs(idx);
	  if(vdata < 0)
	    return ({}); // wrong index
	  return (({noid, @OBJ_COUNT(vdata)}));

    }
    return ({});
  }

}


//! Manages the enterprises.roxenis.app.webserver.global.boot object
class SubMIBRoxenBoot {

  inherit SubMIBManager;

  constant name = "enterprises.roxenis.app.webserver.global.boot";
  constant tree = RISMIB_BASE_WEBSERVER_GLOBAL_BOOT - (MIBTREE_BASE+".");

  object agent;
  
  void create(object agentp) {
    agent = agentp;
    submibtab = ([ tree+".0": lambda() { return OBJ_INT(0); }  ]);
  }

  // HACK! For testing purpose only!
  // Server restart = 1; server shutdown = 2
  array set(string oid, mixed val, mapping|void pkt) {

    string soid;
    int setflg = 0;

    SNMPAGENT_MSG(sprintf("SET(%s): %O = %O", name, oid, val));
    soid = oid_strip(oid);

    if(soid != tree + ".0")
      return ({});

    if(agent->chk_access("rw", pkt)) {
      SNMPAGENT_MSG(sprintf("%O=%O - access granted", name, val));
      setflg = 1;
      if(val == 1 || val == 2) {
	report_warning("SNMPagent: Initiated " + ((val==1)?"restart":"shutdown") + " from snmp://" + pkt->community + "@" + pkt->ip + "/\n");
	if (val == 1) roxen->restart(0.5);
	if (val == 2) roxen->shutdown(0.5);
      }
    }
    return ({ setflg, "" });
  }

}


SNMPagent snmpagent;
//! Global SNMPagent object
