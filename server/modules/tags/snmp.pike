// This is a ChiliMoon module which provides SNMP get/set facilities.
// Copyright (c) 2003-2005, Stephen R. van den Berg, The Netherlands.
//                     <srb@cuci.nl>
//
// This module is open source software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation; either version 2, or (at your option) any
// later version.
//

#define _ok id->misc->defines[" _ok"]

constant cvs_version=
 "$Id: snmp.pike,v 1.1 2004/05/22 17:45:31 _cvs_stephen Exp $";
constant thread_safe=1;

#include <module.h>
#include <config.h>

inherit "module";

//#define SNMP_DEBUG 1
#ifdef SNMP_DEBUG
# define SNMP_WERR(X) werror("SNMPtags: %O\n",(X))
#else
# define SNMP_WERR(X)
#endif


// Module interface functions

constant module_type=MODULE_TAG;
LocaleString module_name = "Tags: SNMP";
LocaleString module_doc  =
 "This module provides the SNMP tag.<br /> "
 "<p>Copyright &copy; 2003-2005, by "
 "<a href='mailto:srb@cuci.nl'>Stephen R. van den Berg</a>, "
 "The Netherlands.</p>"
 "<p>This module is open source software; you can redistribute it and/or "
 "modify it under the terms of the GNU General Public License as published "
 "by the Free Software Foundation; either version 2, or (at your option) any "
 "later version.</p>";

void create()
{ set_module_creator("Stephen R. van den Berg <srb@cuci.nl>");
}

static string lastserver, lastoid;

void start(int level, Configuration _conf)
{ lastserver="NONE";
  lastoid = "";
}

string status()
{ return sprintf("Last server contacted: %s<br />"
   "Last OID referenced: %s",lastserver,lastoid);
}

#define IS(arg) ((arg) && sizeof(arg)) 
 
string query_provides()
{ return "snmp";
}

// Internal helpers

array snmpget(mapping args,RequestID id)
{ Protocols.SNMP.protocol
   handler=Protocols.SNMP.protocol((int)args->port||161);
  if(args->community)
     handler->snmp_community=args->community;
  handler->snmp_version=(int)args->version||1;
  multiset reqs=(<>);
  args->oid=args->oid/(args->split||",")-({""});
  if(stringp(args->server))
   { reqs+=(<handler->get_request(args->oid,lastserver=args->server)>);
     lastoid=args->oid[sizeof(args->oid)-1];
   }
  else
   { args->server=args->server/(args->split||",")-({""});
     if(sizeof(args->oid)!=sizeof(args->server))
        throw("Size mismatch arrays snmp emit");
     int i=0;
     array nargs=({});
     string ls;
     foreach(args->oid,string oid)
      { if(ls!=args->server[i])
         { if(sizeof(nargs))
            { reqs+=(<handler->get_request(nargs,lastserver=ls)>);
              lastoid=nargs[sizeof(nargs)-1];
            }
	   ls=args->server[i];nargs=({});
         }
        nargs+=({oid});
        i++;
      }
     if(sizeof(nargs))
      { reqs+=(<handler->get_request(nargs,lastserver=ls)>);
        lastoid=nargs[sizeof(nargs)-1];
      }
   }
  mapping nexts=([]);
  array res=({});
  array rnexts=({}),qnexts=({});
  int lasteindex=-1;
  while(sizeof(reqs)&&handler->wait(args->timeout?(float)args->timeout:4))
   { mapping msg=handler->decode_asn1_msg(handler->readmsg());
     int reqid
     ;{ string s;
        reqid=(int)(s=indices(msg)[0]);
        msg=msg[s];
      }
     if(reqs[reqid])
      { array attribute=msg->attribute;
        mapping m;
        reqs[reqid]=0;
SNMP_WERR(msg);
        switch((int)msg["error-status"])
         { case 0:
            { array tnexts=nexts[reqid];
              m_delete(nexts,reqid);
	      array rvals,ridx;
	      rvals=ridx=({});
              foreach(attribute,m)
               { if(tnexts)
                  { string noid=tnexts[0];
                    tnexts=tnexts[1..];
                    string retoid=indices(m)[0];
                    if(noid+"."==retoid[..sizeof(noid)])
                       rnexts+=({noid}),qnexts+=({retoid});
                    else
                       continue;
                  }
#if 0
                 array values=values(m);
                 int i=0;
                 foreach(indices(m),string oid)
                    res+=({(["oid":oid,"value":values[i++]])});
#else
SNMP_WERR(m);
                 ridx+=indices(m);rvals+=values(m);
#endif
               }
	      if(sizeof(ridx))
                 res+=({(["oid":sizeof(ridx)==1?ridx[0]:ridx,
		       "server":msg->ip,
                       "value":sizeof(rvals)==1?rvals[0]:rvals])});
              if(sizeof(qnexts))
               { int neqid;
                 reqs+=(<neqid=handler->get_nextrequest(qnexts,msg->ip)>);
                 nexts+=([neqid:rnexts]);
                 rnexts=qnexts=({});
               }
              break;
            }
           case 2:
            { int badindex=(int)msg["error-index"]-1;
              int i=0;
              array dir=({});
              foreach(attribute,m)
                 if(i++!=badindex)
                    dir+=indices(m);
              foreach(indices(attribute[badindex]),string oid)
                 if(badindex>=lasteindex)	// Accomodate for different
                    rnexts+=({oid}),qnexts+=({oid}); // order parsing in device
	         else
                    rnexts=({oid})+rnexts,qnexts=({oid})+qnexts;
	      lasteindex=badindex;
              if(sizeof(dir))
                 reqs+=(<handler->get_request(dir,msg->ip)>);
              else
               { lasteindex=-1;
		 if(sizeof(qnexts))
                  { int neqid;
                    reqs+=(<neqid=handler->get_nextrequest(qnexts,msg->ip)>);
                    nexts+=([neqid:rnexts]);
                    rnexts=qnexts=({});
                  }
               }
              break;
            }
         }
      }
   }
  _ok = !sizeof(reqs);
SNMP_WERR(res);
  return res;
}

array snmpset(mapping args)
{ Protocols.SNMP.protocol handler=Protocols.SNMP.protocol((int)args->port||161,
   lastserver=args->server);
  if(args->community)
     handler->snmp_community=args->community;
  handler->snmp_version=(int)args->version||1;
  handler->set_read_callback(handler->to_pool);
  mapping req=([]);
  args->oid=args->oid/(args->split||",");
  lastoid=args->oid[0];
  args->value=args->value/(args->split||",");
  args->type=args->type/(args->split||",");
  if(sizeof(args->oid)!=sizeof(args->value)
   ||sizeof(args->oid)!=sizeof(args->type))
     throw("Mismatch in array sizes snmp");
  int i=0;
  foreach(args->oid,string oid)
   { req+=([oid:({args->type[i],args->value[i]})]);
     i++;
   }
  int reqid=handler->set_request(req);
  return ({});
}

// -------------------------------- Tag handlers -----------------------------

class TagSNMPplugin {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "snmp";
  constant flags = RXML.FLAG_DONT_RECOVER;
  mapping(string:RXML.Type) req_arg_types = ([
   "server" : RXML.t_text(RXML.PEnt),
   "oid" : RXML.t_text(RXML.PEnt),
  ]);
  mapping(string:RXML.Type) opt_arg_types = ([
   "port" : RXML.t_text(RXML.PEnt),
   "community" : RXML.t_text(RXML.PEnt),
   "timeout" : RXML.t_text(RXML.PEnt),
   "split" : RXML.t_text(RXML.PEnt),
  ]);

  array get_dataset(mapping args, RequestID id) {
    return snmpget(args,id);
  }
}

class TagSNMP {
  inherit RXML.Tag;
  constant name = "snmp";
  constant flags = RXML.FLAG_DONT_RECOVER;
  mapping(string:RXML.Type) req_arg_types = ([
   "server" : RXML.t_text(RXML.PEnt),
   "oid" : RXML.t_text(RXML.PEnt),
   "type" : RXML.t_text(RXML.PEnt),
  ]);
  mapping(string:RXML.Type) opt_arg_types = ([
   "port" : RXML.t_text(RXML.PEnt),
   "community" : RXML.t_text(RXML.PEnt),
   "value" : RXML.t_text(RXML.PEnt),
   "timeout" : RXML.t_text(RXML.PEnt),
   "split" : RXML.t_text(RXML.PEnt),
  ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      CACHE(0);
      if(!args->value)
	 args->value=content;
      array res=snmpset(args);
      _ok = 1;
      return 0;
    }

  }
}

// --------------------- More interface functions --------------------------

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
 "snmp":#"<desc type='tag'><p><short>
 Executes an SNMP set operation.</short></p>
</desc>

<attr name='server' value='hostname' required='required'><p>
 SNMP server address or array of addresses.</p>
</attr>

<attr name='port' value='SNMP port' default='161'><p>
 SNMP port address.</p>
</attr>

<attr name='version' value='SNMP version' default='1'><p>
 SNMP version.</p>
</attr>

<attr name='community' value='SNMP community' default='public'><p>
 Community to be used to access the SNMP server. If omitted the
 default will be used.</p>
 </attr>

<attr name='split' value='SNMP object id' default=','><p>
 The string the array values are splitted with. </p>
</attr>

<attr name='oid' value='SNMP object id' required='required'><p>
 Name or array of names of the objects that will be set.</p>
</attr>

<attr name='type' value='SNMP type' required='required'><p>
 Type or array of types of the objects.</p>
</attr>

<attr name='value' value='set value'><p>
 New value or array of values the objects will be set to.</p>
</attr>",

"emit#snmp":#"<desc type='plugin'><p><short>
 Use this source to perform SNMP-queries.</short> The
 result will be available in variables specifying oid and value.</p>
</desc>

<attr name='server' value='hostname' required='required'><p>
 SNMP server address.</p>
</attr>

<attr name='port' value='SNMP port'><p>
 SNMP port address.</p>
</attr>

<attr name='version' value='SNMP version' default='1'><p>
 SNMP version.</p>
</attr>

<attr name='timeout' value='SNMP timeout' default='4'><p>
 The maximum amount of seconds to wait for a response from the
 server after the last network activity.</p>
</attr>

<attr name='community' value='SNMP community' default='public'><p>
 Community to be used to access the SNMP server. If omitted the
 default will be used.</p>
 </attr>

<attr name='split' value='SNMP object id' default=','><p>
 The string the array values are splitted with. </p>
</attr>

<attr name='oid' value='SNMP object id' required='required'><p>
 Name or array of names of the objects that will be retrieved.</p>
</attr>"
]);
#endif

