/*
 * $Id: snmpagent.pike,v 1.7 2001/08/14 01:47:17 hop Exp $
 *
 * The Roxen SNMP agent
 * Copyright © 2001, Roxen IS.
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
 Todos:
    v1.0 todo:
	- cold/warm start trap generation
	- 'basic' Roxen working variables

    v1.1 todo:
	- trap handling

    v2.0 todo:
	- Roxen.module API for registering MIB subtree

    v3.0 todo:
	- SNMP v3 
	- security


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

#define RISMIB_BASE			"1.3.6.1.4.1.8614"
#define RISMIB_BASE_WEBSERVER		RISMIB_BASE+".1.1"

//! The starting part of OID of every object will have, so we stripp it out
//! before making index from OID to the MIB DB
#define MIBTREE_BASE "1.3.6.1"

#define LOG_EVENT(txt, pkt) log_event(txt, pkt)

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
  private object th;
  private static object mib;
  private mapping vsdb;

  array get_snmpinpkts() { return OBJ_COUNT(snmpinpkts); };
  array get_snmpoutpkts() { return OBJ_COUNT(snmpoutpkts); };
  array get_snmpbadver() { return OBJ_COUNT(snmpbadver); };
  array get_snmpbadcommnames() { return OBJ_COUNT(snmpbadcommnames); };
  array get_snmpbadcommuses() { return OBJ_COUNT(snmpbadcommuses); };
  array get_snmpenaauth() { return OBJ_COUNT(snmpenaauth); };

  array get_virtserv() { return OBJ_COUNT(sizeof(vsdb)); };


  void create() {
    vsdb = ([]);
    //disable();
  }

  //! Enable SNMPagent processing.
  int enable() {

    if(enabled)
      return(enabled);
    mib = SubMIBsystem();		// system.* table
    if(objectp(mib)) {
      // snmp.*
      mib->register(MIBTREE_BASE+"."+"2.1.11", SubMIBsnmp(this_object()));
      // enterprises.roxenis.*
      mib->register(MIBTREE_BASE+"."+"4.1.8614", SubMIBroxenis(this_object()));
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
  private int chk_access(string level /*, string attrname*/, mapping pkt) {

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
	    if (arrayp(val) && val[0])
	      rdata[attrname] += val;
	    break;

	  case SNMP_OP_GETNEXT:
		val = mib->getnext(attrname, pdata[msgid]);
	    if (arrayp(val) && val[0])
	      //rdata[attrname] += val;
	      rdata[val[0]] += val[1..2];
	    break;

	  case SNMP_OP_SETREQUEST:
		val = mib->set(attrname, attrval, pdata[msgid]);
		if(arrayp(val))
		  setflg = val[0];
		//rdata[attrname] += ({ "int", attrval });
		rdata["1.3.6.1.2.1.1.3.0"] += ({"tick", get_uptime() });
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
    mapping data;
    array hp = query("snmp_hostport")/":";
    int p = (sizeof(hp)>1) ? (int)hp[1] : (int)SNMPAGENT_DEFAULT_PORT;

    if(!sizeof(hp[0]))
      hp[0] = get_cif_domain();
    err = catch( fd = Protocols.SNMP.protocol(0, hp[0], p||161) );
    if(arrayp(err))
      RXML.run_error("SNMPagent: can't open UDP port " + hp[0]+":"+(string)(p||161)+"[" + err[0] + "].");
    SNMPAGENT_MSG(sprintf("SNMP UDP port %s:%d binded successfully.", hp[0], p||161));

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

  //! Cold start notificator. Sends trap for all virtual servers in the vsarr.
  void coldstart_trap(array(int) vsarr) {

	object uri;

    if(intp(vsarr))
	  return;
	foreach(vsarr, int vsid)
	  if(vsdb[vsid] && vsdb[vsid]->variables["snmp_traphosts"]) {
	     SNMPAGENT_MSG(sprintf("virt.serv[%d/%s]'s traphosts:%O",
			vsid, vsdb[vsid]->name,
			vsdb[vsid]->variables["snmp_traphosts"]->query()));
	    foreach(vsdb[vsid]->variables["snmp_traphosts"]->query(), mixed thost) {
		  uri = Standards.URI(thost);
		  SNMPAGENT_MSG(sprintf("Trap sent: %s.", thost));
/*
		  fd->trap(
		    ([RISMIB_BASE_WEBSERVER+".999.1.1":
                        ({ "str", Standards.URI(vsdb[vsid]->variables["MyWorldLocation"]->query())->host}) ]),
		    uri->host, uri->port);
*/
		}
	  } else
	    if(vsdb[vsid])
	      SNMPAGENT_MSG(sprintf("virt.serv[%d/%O] hasn't any traphosts.",
			    vsid, vsdb[vsid] && vsdb[vsid]->name));

  }

  //! Warm start notificator
  void warmstart_trap() {

  }

  //! Authentication failure notificator
  void authfailure_trap() {

  }

  //! Enterprise specific trap notificator
  void enterprise_trap() {

  }

  //! Adds virtual server to the DB of managed objects
  int add_virtserv(int vsid) {

    if(zero_type(vsdb[vsid])) {
      report_debug(sprintf("snmpagent: virt.serv.[%d/%s] added.\n",
		           vsid,roxen->configurations[vsid]->name));
//report_debug(sprintf("snmpagent:DEB: %O\n",mkmapping(indices(roxen->configurations[vsid]), values(roxen->configurations[vsid]))));
	  vsdb += ([vsid: roxen->configurations[vsid]]);
     }

    return(1);
  }

  //! Returns name of the virtual server
  string get_virtservname(int vsid) {
    if(zero_type(vsdb[vsid]))
      return 0; // bad index number
    return (roxen->configurations[vsid]->name);
  }

  //! Deletes virtual server's specific objects from DB
  int del_virtserv(int vsid) {

    if(!zero_type(vsdb[vsid])) {
SNMPAGENT_MSG(sprintf("snmpagent:DEB: del: %O->%O\n",vsid,roxen->configurations[vsid]->name));
	  vsdb -= ([ vsid: 0 ]);
	}

    return(1);
  }

} // end of SNMPagent object

//! Removes first four octets from OID string, as internal table works
//! on such stripped OIDs.
private string|int oid_strip (string oid) { // note: this method must be public!

  array arr = oid / ".";
  if (sizeof(arr) < 7)  // FIXME: exists oid with less octets?
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
  int register(string oid, object manager) {

    if(!(oid = oid_strip(oid))) return -1; // false => bad OID
    if(oid_check(oid))
      return 0; // false => the OID is already registered. What about stackable organization ?
    if(subtreeman[oid])
      return 0; // false => already registered
    subtreeman += ([oid: manager]); // FIXME: autohiding of subtree. Is it goood?
    return 1; // ok (registered)
  }

  void create() {
  
	report_error("SubMIBManager object [" + (string)name + "] hasn't replaced contructor!\n");
  } // create

  //! Returns array. First element is type of second element.
  //! Is usable for very primitive managed objects, in which case the value
  //! is got by calling function from submibtab table.
  //array `[](string oid) {
  array get(string oid, mapping|void pkt) {

    function rval;
    string soid;

    SNMPAGENT_MSG(sprintf("GET(%s): %O", name, oid));
    soid = oid_strip(oid);
    if (functionp(rval = submibtab[soid])) {
      SNMPAGENT_MSG("found MIB object.");
      return rval();
    }

    // hmm, now we have to try some of the registered managers
    array s = soid/".";
    for(int cnt = sizeof(s)-1; cnt>0; cnt--)
      if(subtreeman[s[..cnt]*"."]) {
	// good, subtree manager exists
	string manoid = s[..cnt]*".";
        SNMPAGENT_MSG(sprintf("found subtree manager: %s(%O)",
				subtreeman[manoid]->name, manoid));
	return subtreeman[manoid]->get(oid);
      }
  }

  //! Returns array ({ nextoid, type, val }) or 0
  array|int getnext(string oid, mapping|void pkt) {

    array(string) idxnums = Array.sort(indices(submibtab));
    int idx;
    string soid;
    array s;

    SNMPAGENT_MSG(sprintf("GETNEXT(%s): %O", name, oid));
    if(!(soid = oid_strip(oid)))
      return 0;
SNMPAGENT_MSG(sprintf("DEB: %O", soid));
    idx = search(idxnums, soid);
SNMPAGENT_MSG(sprintf("arr: %d, %O", idx, idxnums));
    if(idx >= 0) {
      // good, we found equality
      SNMPAGENT_MSG(sprintf("%s: eq match: %O", tree, idx));
      if(idx < sizeof(idxnums)-1)
	return (({ MIBTREE_BASE+"."+(string)idxnums[idx+1],
                   @submibtab[idxnums[idx+1]]() }));
      else
	return 0;
    } else {

SNMPAGENT_MSG(sprintf("DEB: %O - %O", soid[..(sizeof(tree)-1)], tree));
      int tlen = sizeof(tree/".");
      array sarr = soid/".";
      //if(soid[..(sizeof(tree)-1)] == tree) { // only inside owned subtree
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

      SNMPAGENT_MSG(name+": foreign object detected.");
      s = soid/".";
      // hmm, now we have to try some of the registered managers
      for(int cnt = sizeof(s)-1; cnt>0; cnt--) {
SNMPAGENT_MSG(sprintf("DEB: %d: %O", cnt, s[..cnt]*"."));
        if(subtreeman[s[..cnt]*"."]) {
	  // good, subtree manager exists
	  string manoid = s[..cnt]*".";
          SNMPAGENT_MSG(sprintf("found subtree manager: %s(%O)",
				subtreeman[manoid]->name, manoid));
	  return subtreeman[manoid]->getnext(oid, pkt);
        }
      }

    }

    return 0;
  }

  //! Tries to do SET operation.
  array set(string oid, mixed val, mapping|void pkt) {

    return ({ 0, 0});
  }

  //! Tries to guess next OID. Usable to situation when GET_NEXT op
  //! contains OID without .0
  string|int oid_guess_next(string oid) {

    if(oid_check(oid+".0"))
      return oid+".1";
    return 0;
  }

  //! External function for MIB object returning nothing
  array get_null() { return OBJ_COUNT(0); }

} // SubMIBManager

// base external feeders

//! External function for MIB object 'system.sysDescr'
array get_description() {
  return OBJ_STR("Roxen Webserver SNMP agent v"+("$Revision: 1.7 $"/" ")[1]+" (devel. rel.)");
}

//! External function for MIB object 'system.sysOID'
array get_sysoid() {
  return OBJ_OID(RISMIB_BASE_WEBSERVER);
}

//! External function for MIB object 'system.sysUpTime'
array get_uptime() {
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
class SubMIBsystem {

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
	  "2.1.1.3.0": get_uptime,
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

} // SubMIBsystem


//! snmp subtree manager
//! Manages the basic snmp.snmp* submib tree.
class SubMIBsnmp {

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
class SubMIBroxenis {

  inherit SubMIBManager;

  constant name = "roxenis";
  constant tree = "4.1.8614";

  void create(object agent) {

    submibtab = ([
	// enterprises
	// hack2 :)
	"4.1.8614.1.1.999.2.1.0": agent->get_virtserv,
	"4.1.8614.1.1.999.2.1.1": agent->get_virtservname	// !! tabular op !!
// !! nedoreseno! Melo by to vracet ..2.1.1.0 az ..2.1.1.n (tj. podle velikosti)
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

SNMPagent snmpagent;
//! Global SNMPagent object
