// This is a roxen module. Copyright © 1998-2000, Honza Petrous
//
// Module code updateted to new 2.0 API

constant cvs_version="$Id: ldaptag.pike,v 2.0 2000/08/13 20:23:46 hop Exp $";
constant thread_safe=1;
#include <module.h>
#include <config.h>

inherit "module";

Configuration conf;

#define LDAP_DEBUG 1
#ifdef LDAP_DEBUG
# define LDAP_WERR(X) werror("LDAPtags: "+X+"\n")
#else
# define LDAP_WERR(X)
#endif


// Module interface functions

//constant module_type=MODULE_PARSER|MODULE_PROVIDER;
constant module_type=MODULE_PARSER;
constant module_name="LDAP tags";
constant module_doc  = "This module gives the tag <tt>&lt;ldap&gt;</tt> and containers"
  " <tt>&lt;ldapoutput&gt;</tt>, <tt>&lt;ldapfor&gt</tt>; and "
  "<tt>&lt;emit&gt;</tt> tag (<tt>&lt;emit source=\"ldap\" ... &gt;</tt>).\n";


TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
 "ldap":#"<desc tag><short>
 Executes a LDAP operation, but doesn't do anything with the
 result.</short>The <tag>ldap</tag> tag is mostly used for LDAP
 operation that change the contents of the directory, for example
 <i>add</i> or<i>modify</i>.</desc>

<attr name='host' value='hostname'>
 Host name of server on which directory server will connect to. If
 omitted the default host name will be used.
</attr>

<attr name='name' value='username'>
 User name for connection to the directory server. If omitted the
 default user name will be used.
</attr>

<attr name='password' value='password'>
 User password for connection to the directory server. If omitted the
 default will be used.
 </attr>

<attr name='dn' value='distinguished name'>
 Distinguished name of object. Required.
</attr>

<attr name='op' value=add,delete,modify,replace>
 The actual LDAP operation. Required.
 <p>Note that <tt>op='modify'</tt> will change only the attributes
 given by the <i>attr</i> attribute.
</attr>

<attr name='attr' value=''attribute_name1':[('attribute_value1'[,... ])][,'attribute_name2',...]'>
 The actual values of attributes.
  <p> for example:
 (sn:'Zappa'),(mail:'hello@nowhere.org','athell@pandemonium.com')</p>
</attr>

<attr name='quiet'>
 In case of the operation fails, no error messages will show on the page. Error description can be returned by <tag>ldapelse</tag>.
</attr>

<attr name='parser'>
 If specified, the query will be parsed by the RXML parser. This is useful if the operation is to be built dynamically.
 </attr>",

"ldapelse":#"<desc cont><short>Displays the last error message.</short>

 The <tag>ldapelse</tag> tag is executed only if an error occured
 within the last <tag>ldap</tag> or <tag>ldapoutput</tag> tag. The
 content is parsed and the variable #ldaperror# is replaced with the
 last error message.</desc>

<attr name='ldaperror'>
 Returns an error message.
</attr>",

"ldapfor":#"<desc cont><short>

 Repeats the content for a multiple attribute values.</short> <p>Note
 that the <tag>ldapfor</tag> tag only works within the
 <tag>ldapoutput</tag> container tag!</p>.

 <p>By default anything within #'s will be interpreted as a variable.
 Thus #attribute_name# will be replaced by the attribute value. ##
 will be replaced by a #.</p> </desc>

<attr name='attr' value='attribute name'>
 The attribute name. Required.
</attr>

<attr name='index' value='initial value'>
 The initial value for index. If omitted the <i>index=1</i> will be
 used.
</attr>

<attr name='step' value='increment'>
 The increment for index. If omitted the <i>step=1</i> will be used.
</attr>

<attr name='max' value='value'>
 The restriction for returned values. If omitted all values will be
 returned.
</attr>",

"ldapoutput":#"<desc cont><short>
 Insert the results of a LDAP search into HTML or RXML.</short>

 The <tag>ldapoutput</tag> tag works like the old <i>output</i> tags.
 By default anything within #'s will be interpreted as a variable.
 Thus #attribute_name# will be replaced by the attribute value. ##
 will be replaced by a #.

 <p>As the attribute can contains multiple values the #attribute_name#
 expression returns first value only. Second, third ... values can be
 specified by suffix before # (i.e second email value is written as
 #mail:2#). Obviously this isn't more often usable. Better solution is
 the subcontainer <tag>ldapfor</tag>.

 <p>The <tag>ldapoutput</tag> tag will copy its contents and replace
 the named attribute for each row in the result. If the result is
 empty, the <tag>ldapoutput</tag> tag will not return anything.
 </desc>

<attr name='host' value='hostname'>
 Hostname of server on which directory server will connect to. If
 omitted the default hostname will be used.
</attr>

<attribute name='name' value='username'>
 User name for connection to the directory server. If omitted the
 default user name will be used.
</attr>

<attribute name='password' value='user password'>
 User password for connection to the directory server. If omitted the
 default will be used.
</attribute>

<attr name='basedn' value='base DN'>
 Base DN of an object where is started search of
 directory. Required.
</attr>

<attr name='scope' value='base,onelevel,subtree'>
  The scope of search directory.
 <p>Note: The default value is <i>base</i>.</p>
</attr>

<attr name='sortby' value='attribute name'>
 The attribute name used for sorting output.

 <p>Note: Only one attribute name can be used.</p>
</attr>

<attr name='quiet'>
 Do not show any errors in the page, in case the query fails.
</attr>

<attr name='parse'>
 If specified, the content will be parsed by the RXML parser.
</attr>"

]);
#endif

// Internal helpers

mapping(string:array(mixed))|int read_attrs(string attrs, int op) {
// from string: (attname1:'val1','val2'...)(attname2:'val1',...) to
// ADD: (["attname1":({"val1","val2"...}), ...
// REPLACE|MODIFY: (["attname1":({op, "val1","val2"...}), ...

  array(string) atypes; // = ({"objectclass","cn","mail","o"});
  array(array(mixed)) avals; // = ({({op, "top","person"}),({op, "sysdept"}), ({op, "sysdept@unibase.cz", "xx@yy.cc"}),({op, "UniBASE Ltd."})});
  array(mixed) tmpvals, tmparr;
  string aval;
  mapping(string:array(mixed)) rv;
  int vcnt, ix, cnt = 0, flg = (op > 0);;

  if(flg)
    flg = 1;
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
	tmpvals[0] = op;
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
	if (!args->filter)
	  RXML.parse_error("No filter.");
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
    args->query = Roxen.parse_rxml(args->query, id);

  Protocols.LDAP.client con;
  array(mapping(string:mixed))|object|int result;
  function ldap_connect = id->conf->ldap_connect;
  mixed error;
  mapping|int attrvals;

  if(ldap_connect)
    error = catch(con = ldap_connect(host));
  else
    error = catch(con = Protocols.LDAP.client(host));

  if (error)
    RXML.run_error("Couldn't connect to LDAP server. "+Roxen.html_encode_string(error[0]));


  if(op != "delete" && op != "search") {
    attrvals = read_attrs(args->attr, (args->op == "replace") ? 2 : 0); // ldap->modify with flag 'replace'
    if(intp(attrvals))
      RXML.run_error("Couldn't parse attribute values.");
  }

  // binding ?
  if(args->user)
    con->bind(args->user,pass);

  switch (op) {
    case "search":
	// todo: add attributes listing if any
	error = catch(result = (con->search(args->filter)));
	break;

    case "add":
	error = catch(result = (con->add(args->dn, attrvals)));
	break;

    case "delete":
	error = catch(result = (con->delete(args->dn)));
	break;

  } //switch


  if(error) {
    error = Roxen.html_encode_string(sprintf("LDAP operation %s failed. %s",
	    op, con->error_string()||""));
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

    res=do_ldap_op("search", m, id);

   if(arrayp(res) && sizeof(res)) {
     foreach(res, mapping elem) {
       mapping avalnew = ([]);;
       foreach(indices(elem), string attr) {
#if 0 // var_name.0 .. var_name.n 
         for(int ix=0; ix<sizeof(elem[attr]); ix++)
	   avalnew += ([ (attr+"."+(string)ix): elem[attr][ix] ]);
#else // var_name0\0var_name1 ...
	 switch(String.capitalize(attr)) { // special attributes
	   case "LABELEDURI": //avalnew += ([ "ldabeleduriuri": elem[attr]
		break;
	   case "DN":
		break;
	 }
	 avalnew += ([ attr:(elem[attr]*split) ]);
#endif
       }
       rv += ({ avalnew });
     }
   } else
     rv = ({([])});

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

Protocols.LDAP.client ldap_object(void|string host)
{
  string host = stringp(host)?host:query("server");
  Protocols.LDAP.client con;
  function ldap_connect = conf->ldap_connect;
  mixed error;
  /* Is this really a good idea? /mast
  error = catch(con = sql_connect(host));
  if(error)
    return 0;
  return con;
  */
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
	 TYPE_STRING | VAR_INITIAL,
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
}

string status()
{
      "<font color=\"red\">Not connected:</font> " +
      replace (Roxen.html_encode_string ("BLAHBLAH..."), "\n", "<br />\n") +
      "<br />\n";
}
