// This is a roxen module. Copyright 2000 - 2001, Roxen IS
//
// Module code updated to new 2.0 API

constant cvs_version="$Id: ldaptag.pike,v 2.29 2003/07/02 09:04:10 anders Exp $";
constant thread_safe=1;
#include <module.h>
#include <config.h>

inherit "module";

Configuration conf;

//#define LDAP_DEBUG 1
#ifdef LDAP_DEBUG
# define LDAP_WERR(X) werror("LDAPtags: "+X+"\n")
#else
# define LDAP_WERR(X)
#endif

// global vars
string status_connect_server, status_connect_last, ldap_last_error;
int status_connect_nums;


// Module interface functions

//constant module_type=MODULE_TAG|MODULE_PROVIDER;
constant module_type=MODULE_TAG;
constant module_name="Tags: LDAP tags";
constant module_doc  = "This module gives the tag <tt>&lt;ldap&gt;</tt> and "
  "<tt>&lt;emit&gt;</tt> plugin (<tt>&lt;emit source=\"ldap\" ... &gt;</tt>).\n";


TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
 "ldap":#"<desc type='tag'><p><short>
 Executes a LDAP operation, but doesn't do anything with the
 result.</short>The <tag>ldap</tag> tag is mostly used for LDAP
 operation that change the contents of the directory, for example
 <i>add</i> or <i>modify</i>.</p>
</desc>

<attr name='server' value='LDAP URL' default='Server URL'><p>
 Connection LDAP URL. If omitted the <i>Default server URL</i>
 will be used.</p>
 <p>URLs are written on the format:
    <tt>ldap://hostname[:port]/base_DN[?[attribute_list][?[scope][?[filter][?extensions]]]]</tt>.
    For details, see <a href=\"http://rfc.roxen.com/2255\">RFC 2255</a>.
 </p>
</attr>

<attr name='password' value='password'><p>
 User password for connection to the directory server. If omitted the
 default will be used.</p>
 </attr>

<attr name='dn' value='distinguished name' required='required'><p>
 Distinguished name of object.</p>
</attr>

<attr name='op' value='add,delete,modify,replace' required='required'><p>
 The actual LDAP operation.</p>

 <p>Note that <i>op='modify'</i> will change only the attributes
 given by the <i>attr</i> attribute.</p>
</attr>

<attr name='attr' value='attribute_name1:[(attribute_value1[,... ])][,attribute_name2,...]'>
 <p>The actual values of attributes, for example:</p>
 <ex-box>(sn:'Zappa'),(mail:'hello@nowhere.org','athell@pandemonium.com')</ex-box>
</attr>

<attr name='parser'><p>
 If specified, the content of <att>attr</att> will be parsed
 by the RXML parser. This is useful if the operation is to be
 built dynamically.</p>
</attr>",

"emit#ldap":#"<desc type='plugin'><p><short>
 Use this source to search LDAP directory for information.</short> The
 result will be available in variables named as the LDAP entries
 attribute.</p>

<p>
 <ex-box>
<emit source=\"ldap\"
  server=\"ldap://ldap.foo.com/dc=foo,dc=com?cn,sn,mail?sub?(sn=john)\">
</emit>
</ex-box>

<ex-box>
<emit source=\"ldap\"
      server=\"ldap://ldap.foo.com/?cn,sn,mail\"
      basedn=\"dc=foo,dc=com\"
      search-scope=\"sub\"
      search-filter=\"(sn=john)\" >
</emit>
</ex-box>
</p>
</desc>

<attr name='server' value='LDAP URL' default='Server URL'><p>
 Connection LDAP URL. If omitted the <i>Default server URL</i>
 will be used.</p>
 <p>URLs are written on the format:
    <tt>ldap://hostname[:port]/base_DN[?[attribute_list][?[scope][?[filter][?extensions]]]]</tt>.
    For details, see <a href=\"http://rfc.roxen.com/2255\">RFC 2255</a>.
 </p>
</attr>

<attr name='search-filter' value='search filter'><p>
 Filter of an LDAP search operation. This value will override
 the corresponding part of URL.</p>
</attr>

<attr name='basedn' value='base DN'><p>
 Base DN of an LDAP search operation. This value will override
 the corresponding part of URL.</p>
</attr>

<attr name='search-scope' value='search scope'><p>
 Scope of an LDAP search operation. This value will override
 the corresponding part of URL.</p>
</attr>

<attr name='password' value='user password'><p>
 User password for connection to the directory server. If omitted the
 default will be used.</p>
</attr>"
]);
#endif

// Internal helpers

mapping(string:array(mixed))|int read_attrs(string attrs, string op) {
// from string: (attname1:'val1','val2'...)(attname2:'val1',...) to
// ADD: (["attname1":({"val1","val2"...}), ...
// REPLACE|MODIFY: (["attname1":({op, "val1","val2"...}), ...

  array(string) atypes; // = ({"objectclass","cn","mail","o"});
  array(array(mixed)) avals; // = ({({op, "top","person"}),({op, "sysdept"}), ({op, "sysdept@unibase.cz", "xx@yy.cc"}),({op, "UniBASE Ltd."})});
  array(mixed) tmpvals, tmparr;
  string aval;
  mapping(string:array(mixed)) rv;
  int vcnt, ix, cnt = 0, flg = (op == "replace" || op == "modify"), opval;

  if(flg)
    switch(op) {
	case "replace": opval = 2;
			break;
	case "modify":  opval = 0; // equal to ADD attribute
			break;
    }
  if (sizeof(attrs / "(") < 2)
    return(0);
  atypes = allocate(sizeof(attrs / "(")-1);
  avals = allocate(sizeof(attrs / "(")-1);
  foreach(attrs / "(", string tmp)
    if (sizeof(tmp)) { // without empty '()'
      if ((ix = search(tmp, ":")) < 1) // missed ':' or is first char
	continue;
      //atypes[cnt] = (tmp / ":")[0];
      atypes[cnt] = tmp[..(ix-1)];
      //tmparr = tmp[(sizeof(atypes[cnt])+1)..] / ",";
      tmparr = (tmp[(ix+1)..] / ",") - ({ "" });
      vcnt = sizeof(tmparr); // + 1;
      tmpvals = allocate(vcnt+flg);
      for (ix=0; ix<vcnt; ix++) {
	tmpvals[ix+flg] = (sscanf(tmparr[ix], "'%s'", aval))? aval : "";
      }
      if(flg)
	tmpvals[0] = opval;
      avals[cnt] = tmpvals;
      cnt++;
    } // if

    /*if (avals[al] != ")") {
      // Missed right ')'
      return (0);
    }*/

  rv = mkmapping(atypes,avals);
  //LDAP_WERR(sprintf("DEB: mapping: %O\n",rv));
  return rv;
}


array|object|int do_ldap_op(string op, mapping args, RequestID id)
{
  string host = query("server");
  string pass = ""; // = query("server");

  if (args->server) {
    host=args->server;
    args->server="CENSORED";
  }

  if (args->password) {
    pass=args->password;
    args->password="CENSORED";
  }

  switch (op) {
    case "search":
	break;

    case "add": 
    case "replace": 
    case "modify": 
	if (!args->dn)
	  RXML.parse_error("No DN.");
	if (!args->attr)
	  RXML.parse_error("No attribute.");
	break;

    case "delete": 
	if (!args->dn)
	  RXML.parse_error("No DN.");
	break;

  } //switch

  if (args->parse)
    args->attr = Roxen.parse_rxml(args->attr, id);

  Protocols.LDAP.client con;
  array(mapping(string:mixed))|object|int result;
  function ldap_connect = id->conf->ldap_connect;
  mixed error;
  mapping|int attrvals;

  if(ldap_connect)
    error = catch(con = ldap_connect(host));
  else
    error = catch(con = Protocols.LDAP.client(host));

  if (error) {
    RXML.run_error("Couldn't connect to LDAP server. "+Roxen.html_encode_string(error[0]));
     ldap_last_error = "Couldn't connect to LDAP server. "+Roxen.html_encode_string(error[0]);
  }

  if(op != "delete" && op != "search") {
    attrvals = read_attrs(args->attr, args->op);
    //attrvals = read_attrs(args->attr, (args->op == "replace") ? 2 : 0); // ldap->modify with flag 'replace'
    if(intp(attrvals))
      RXML.run_error("Couldn't parse attribute values.");
  }

  int ver = (int)(args->version)||3;
  if(ver == 2 || sizeof(pass))
    error = catch(sizeof(pass) ? con->bind(args->dn, pass, ver) : con->bind());
  if(error || con->error_number()) // trying v2 of LDAP protocol as fallback
    error = catch(sizeof(pass) ? con->bind(args->dn, pass, 2) : con->bind("","",2));
  if(error) {
    RXML.run_error("Couldn't bind to LDAP server. "+Roxen.html_encode_string(error[0]));
    ldap_last_error = "Couldn't bind to LDAP server. "+Roxen.html_encode_string(error[0]);
  }
  status_connect_last = host + ", proto" + (string)con->ldap_version + ", "
			+ ctime(time());
  status_connect_nums++;

  switch (op) {
    case "search":
	if(args->basedn)
	  con->set_basedn(args->basedn);
	if(args["search-scope"])
	  con->set_scope(args["search-scope"]); // FIXME: add error checking
	error = catch(result = (con->search(args["search-filter"])));
	break;

    case "add":
	error = catch(result = (con->add(args->dn, attrvals)));
	break;

    case "delete":
	error = catch(result = (con->delete(args->dn)));
	break;

    case "modify":
    case "replace":
	error = catch(result = (con->modify(args->dn, attrvals)));
	break;

  } //switch


  if(error) {
    if (!con->error_number())
      report_debug("LDAP operation failed: %s\n%s\n", describe_error(error),
		   describe_backtrace(error[1]));
    error = Roxen.html_encode_string(sprintf("LDAP operation %s failed. %s",
					     op, con->error_string()||""));
    ldap_last_error = error;
    con->unbind();
    RXML.run_error(error);
  }
  con->unbind();

#if 0
  args["ldapobj"]=con;
  if(result && args->rowinfo) {
    int rows;
    if(arrayp(result)) rows=sizeof(result);
    if(objectp(result)) rows=result->num_rows();
    RXML.user_set_var(args->rowinfo, rows);
  }
#endif

  if(op = "search" && objectp(result) && result->num_entries()) {
    array res = ({});
    do
      res += ({ result->fetch() });
    while(result->next());
    return res - ({});
  }
    
  return result;
}


// -------------------------------- Tag handlers -----------------------------

class TagLDAPplugin {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "ldap";


  array get_dataset(mapping m, RequestID id) {
    array res;
    array rv = ({});
    string split = m->split || "\0";
    NOCACHE();

    res=do_ldap_op("search", m, id);

   if(arrayp(res) && sizeof(res)) {
     foreach(res, mapping elem) {
       mapping avalnew = ([]);;
       foreach(indices(elem), string attr) {
#if 0 // var_name.0 .. var_name.n 
         for(int ix=0; ix<sizeof(elem[attr]); ix++)
	   avalnew += ([ (attr+"."+(string)ix): elem[attr][ix] ]);
#else // var_name0\0var_name1 ...
	 switch(upper_case(attr)) { // special attributes
	   case "LABELEDURI":
		avalnew += ([ "labeleduriuri":((Array.map(elem[attr],
				lambda(string el1) {
				  return ((el1/" ")[0]);
				})
			      )*split)
			    ]);
		avalnew += ([ "labeledurilabel":((Array.map(elem[attr],
				lambda(string el1) {
				  string rv = el1;
				  if (sizeof(el1/" ")>1) rv = (el1/" ")[1..]*" ";
				  return rv;
				})
			      )*split)
			    ]);
/*
		avalnew += ([ "labeledurianchor":((Array.map(elem[attr],
				lambda(string el1) {
				  string rv = el1;
				  if (sizeof(el1/" ")>1) rv = (el1/" ")[1..]*" ";
				  return rv;
				})
			      )*split)
			    ]);
*/
		break;
	 }
	 avalnew += ([ attr:(elem[attr]*split) ]);
#endif
       }
       rv += ({ avalnew + ([ "_attributes": indices(avalnew)*split ]) });
     }
   } else
     rv = ({ });

   //LDAP_WERR(sprintf("emit search: rv: %O", rv));
   return(rv);
 
  }
}

class TagLDAPQuery {
  inherit RXML.Tag;
  constant name = "ldap";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      NOCACHE();

      array res=do_ldap_op(args->op, args, id);

      id->misc->defines[" _ok"] = 1;
      return 0;
    }

  }
}

// ------------------- Callback functions -------------------------

Protocols.LDAP.client ldap_object(void|string a_host)
{
  string host = stringp(a_host)?a_host:query("server");
  Protocols.LDAP.client con;
  function ldap_connect = conf->ldap_connect;
  mixed error;
  return ldap_connect(host);
}

string query_provides()
{
  return "ldap";
}


// ------------------------ Setting the defaults -------------------------

void create()
{
  defvar("server", "ldap://localhost/??sub", "Default server URL",
	 TYPE_STRING | VAR_INITIAL | VAR_MORE,
	 "The default LDAP URL that will be used if no <i>host</i> "
	 "attribute is given to the tags. Usually the <i>host</i> "
	 "attribute should be used with a symbolic name definied "
	 "in the <i>Symbolic names</i>."
	 "<p>The default connection is specified as a LDAP URL in the "
	 "format "
	 "<tt>ldap://host:port/basedn??scope?filter?!...</tt>.\n");

}


// --------------------- More interface functions --------------------------

void start(int level, Configuration _conf)
{
  if (_conf)
    conf = _conf;
  ldap_last_error = "";
  status_connect_server = "";
  status_connect_last = "";
}

string status()
{
  string rv = "";

    if(status_connect_nums) {
      rv += "<h2>Connection status</h2>\n";
      rv += sprintf("<p>Last connected to %s [ %s]<br>Number of connections: %d<br /></p><p>Last error: %s<br /></p>\n",
                status_connect_server, status_connect_last,
                status_connect_nums, sizeof(ldap_last_error) ? ldap_last_error : "[none]");
    }

    return rv;
}
