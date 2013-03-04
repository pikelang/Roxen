// This is a roxen module. Copyright 2000 - 2009, Roxen IS
//
// Module code updated to new 2.0 API

constant cvs_version="$Id$";
constant thread_safe=1;
#include <module.h>
#include <config.h>

inherit "module";

//#define LDAP_DEBUG 1
#ifdef LDAP_DEBUG
# define LDAP_WERR(X) werror("LDAPtags: "+X+"\n")
#else
# define LDAP_WERR(X)
#endif

// Module interface functions

//constant module_type=MODULE_TAG|MODULE_PROVIDER;
constant module_type=MODULE_TAG;
constant module_name="Tags: LDAP tags";
constant module_doc  = #"\
This module provides RXML tags for querying and updating an LDAP directory.\n";

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
 "ldap":#"<desc type='tag'><p><short>
 Executes an LDAP operation that change the contents of the
 directory.</short></p>
<p>
Add (adds an object):
<ex-box>
<ldap server=\"ldap://ldap.foo.com/\"
      op=\"add\"
      binddn=\"cn=admin,dc=foo,dc=com\"
      dn=\"cn=user,dc=foo,dc=edu\"
      attr=\"(cn:'user')(sn:'surname')(objectClass:'req'd objectClass')\"
      password=\"<password>\" />
</ex-box>
</p>

<p>
Delete (deletes an object):
<ex-box>
<ldap server=\"ldap://ldap.foo.com/\"
      op=\"delete\"
      binddn=\"cn=admin,dc=foo,dc=com\"
      dn=\"cn=user,dc=foo,dc=com\"
      password=\"<password>\" />
</ex-box>
</p>

<p>
Replace (replaces a value of an attribute):
<ex-box>
<ldap server=\"ldap://ldap.foo.com/\"
      op=\"replace\"
      binddn=\"cn=admin,dc=foo,dc=com\"
      dn=\"cn=user,dc=foo,dc=com\"
      attr=\"(sn:'new value')\"
      password=\"<password>\" />
</ex-box>
</p>

<p>
Modify (adds a second value to an existing attribute):
<ex-box>
<ldap server=\"ldap://ldap.foo.com/\"
      op=\"modify\"
      binddn=\"cn=admin,dc=foo,dc=com\"
      dn=\"cn=user,dc=foo,dc=com\"
      attr=\"(sn:'additional value')\"
      password=\"<password>\" />
</ex-box>
</p>
</desc>

<attr name='server' value='URL' default='Server URL'><p>
 Connection LDAP URL. If omitted the \"Default server URL\" in the
 module configuration will be used.</p>

 <p>URLs are written on the format:
    <tt>ldap://hostname[:port]/base_DN[?[attribute_list][?[scope][?[filter][?extensions]]]]</tt>.
    For details, see <a href=\"http://rfc.roxen.com/2255\">RFC 2255</a>.
 </p>
</attr>

<attr name='binddn' value='distinguished name'><p>
 Applicable only if the \"server\" attribute is used. This is the bind
 DN for authentication in the directory server. If the LDAP URL
 contains a \"bindname\" extension, that one takes precedence.</p>
</attr>

<attr name='password' value='password'><p>
 Applicable only if the \"server\" attribute is used. Password for
 authentication in the directory server. If omitted the empty string
 will be used.</p>
</attr>

<attr name='dn' value='distinguished name' required='required'><p>
 Distinguished name of the object to operate on.</p>
</attr>

<attr name='op' value='add|delete|modify|replace' required='required'><p>
 The actual LDAP operation:</p>

 <list type='dl'>
   <item name='add'>
     <p>Add a new object. The \"attr\" argument specifies the
     attributes for the new object. The \"add-attr\" argument also
     works for this.</p></item>

   <item name='delete'>
     <p>Delete an object.</p></item>

   <item name='modify'>
     <p>Modify an existing object. The \"add-attr\",
     \"replace-attr\", and \"delete-attr\" arguments specifies the
     attribute values to add, replace, and delete, respectively. The
     same attribute name may not occur in both \"add-attr\" and
     \"delete-attr\".</p>

     <p>For compatibility, the \"attr\" argument is the same as
     \"add-attr\".</p></item>

   <item name='replace'>
     <p>This operation exists for compatibility only. It's the
     same as \"modify\" except that the \"attr\" argument is an alias
     for \"replace-attr\" instead.</p></item>
 </list>
</attr>

<attr name='attr' value='(attr:[val[,...]])[(attr:...)...]'><p>
 Specifies the attributes for the new object in the \"add\" operation.</p>

 <p>The format consists of a series of parentheses on the form
 \"<tt>(</tt><i>attr</i><tt>:</tt><i>values</i><tt>)</tt>\"
 where <i>attr</i> is the attribute name and <i>values</i> a comma
 separated list of zero or more values to give it. Whitespace which is
 ignored may occur around the parentheses, the colon and the commas.
 Superfluous commas and empty parenthesis pairs are ignored.</p>

 <p>Each value in the <i>values</i> list is either a string literal
 surrounded by double quotes (\") or the name of an RXML variable
 (without the \"&amp;\" and \";\" around it). JavaScript-like quoting
 is used inside string literals, e.g. a \" is written as \\\" and a \\
 is written as \\\\.</p>

 <p>If an RXML variable has multiple values, i.e. is an array, then
 all its values are added one by one to the set of values for the
 attribute. (RXML variables with multiple values commonly occur in the
 form scope when the browser sends multiple values for the same form
 variable.)</p>

 <p>For compatibility, string literals may also be surrounded by
 single quotes ('), but in that case there's no quoting mechanism, so
 a single quote cannot be written inside.</p>

 <p>The same attribute name may occur in several parentheses. All the
 values from all the parentheses are simply joined in that case.</p>

 <p>An example:
<ex-box>
  (sn: \"Zappa\")
  (givenName: form.givenName)
  (mail: \"hello@nowhere.org\", \"athell@pandemonium.com\")
</ex-box></p>
</attr>

<attr name='add-attr' value='(attr:[val[,...]])[(attr:...)...]'><p>
 Specifies the attribute values to add to the object in a \"modify\"
 or \"add\" operation. These attribute values will be added to the
 existing values for the corresponding attributes in the object.</p>

 <p>A new attribute is added to the object if it doesn't exist
 already.</p>

 <p>See the description for \"attr\" for details about the format.</p>
</attr>

<attr name='replace-attr' value='(attr:[val[,...]])[(attr:...)...]'><p>
 Specifies the attribute values to replace in the object in a
 \"modify\" operation. These attribute values will replace the
 existing values for the corresponding attributes in the object.</p>

 <p>A new attribute is added to the object if it doesn't exist already
 and the list of values isn't empty. An attribute is removed
 completely if the list of values is empty and the attribute existed
 before.</p>

 <p>See the description for \"attr\" for details about the format.</p>
</attr>

<attr name='delete-attr' value='(attr:[val[,...]])[(attr:...)...]'><p>
 Specifies the attribute values to delete from the object in a
 \"modify\" operation.</p>

 <p>An attribute is removed completely if the list of values is empty
 or if it specifies all the existing values for the attribute.</p>

 <p>See the description for \"attr\" for details about the format.</p>
</attr>

<attr name='parse'><p>
 If specified, the content of <att>attr</att> will be parsed
 by the RXML parser.</p>
</attr>",

"emit#ldap":({#"<desc type='plugin'><p><short>
 Use this source to search LDAP directory for information.</short> The
 result will be available in variables named like the returned LDAP
 attributes.</p>

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

<attr name='server' value='URL' default='Server URL'><p>
 Connection LDAP URL. If omitted the \"Default server URL\" in the
 module configuration will be used.</p>

 <p>URLs are written on the format:
    <tt>ldap://hostname[:port]/base_DN[?[attribute_list][?[scope][?[filter][?extensions]]]]</tt>.
    For details, see <a href=\"http://rfc.roxen.com/2255\">RFC 2255</a>.
 </p>
</attr>

<attr name='binddn' value='distinguished name'><p>
 Applicable only if the \"server\" attribute is used. This is the bind
 DN for authentication in the directory server. If the LDAP URL
 contains a \"bindname\" extension, that one takes precedence.</p>
</attr>

<attr name='password' value='password'><p>
 Applicable only if the \"server\" attribute is used. Password for
 authentication in the directory server. If omitted the empty string
 will be used.</p>
</attr>

<attr name='search-filter' value='search filter'><p>
 Filter of an LDAP search operation. This value will override the
 corresponding part of the URL. If the URL doesn't specify a filter
 then this attribute is required.</p>
</attr>

<attr name='basedn' value='distinguished name'><p>
 Base DN of an LDAP search operation. This value will override
 the corresponding part of the URL.</p>
</attr>

<attr name='search-scope' value='base|one|sub'><p>
 Scope of an LDAP search operation. This value will override
 the corresponding part of the URL.</p>
</attr>

<attr name='attrs' value='attr[,...]'><p>
 Comma-separated list of attributes to retrieve. This value will
 override the corresponding part of the URL.</p>
</attr>

<attr name='lower-attrs'><p>
 If specified, all attribute names will be converted to lowercase in
 the result. This is useful to access specific attributes reliably
 through the scope variables since LDAP attributes are case
 insensitive and different servers might return them with different
 casing.</p>
</attr>

<attr name='split' value='string'><p>
 This string is used as a separator between multiple values for the
 same attribute when they are concatenated together to a single
 string. The default string is a NUL character (&amp;#0;).</p>
</attr>

<attr name='array-values'><p>
 If specified, multiple values aren't concatenated together using the
 \"split\" argument for attributes that aren't single-valued. Instead,
 the values for such attributes are returned as arrays so that they
 can be processed accurately with e.g. &lt;insert source=\"values\"
 ...&gt;.</p>
</attr>

<attr name='no-values'><p>
 If specified, no values will be queried, just the attribute names for
 which values would be returned otherwise. The value for each
 attribute is instead the name of the same attribute.</p>
</attr>",
([
  "&_._attributes;": #"<desc type='entity'><p>
    List of the attributes returned by the server. This is affected by
    the \"split\" and \"array-values\" arguments just like a
    multi-valued attribute value. It's however not affected by
    \"no-values\".</p></desc>",

  "&_.dn;": #"<desc type='entity'><p>
    The distinguished name of the object for this entry. Note that
    this field is not affected by \"no-values\".</p></desc>",

  "&_.labeleduriuri;": #"<desc type='entity'><p>
    If there's a labeledURI attribute in the result then this is set
    to the URI part of it. See RFC 2079 for details about
    labeledURI.</p></desc>",

  "&_.labeledurilabel;": #"<desc type='entity'><p>
    If there's a labeledURI attribute in the result then this is set
    to the label part of it. See RFC 2079 for details about
    labeledURI.</p></desc>",
])}),
]);
#endif

// Internal helpers

protected class ConnectionStatus
{
  int last_connect_time;
  string status_msg = "Not connected";
}

protected mapping(string:ConnectionStatus) connection_status = ([]);
// Status for every server url.

protected constant Connection = Protocols.LDAP.client;

protected ConnectionStatus get_conn_status (string server_url)
{
  return connection_status[server_url] ||
    (connection_status[server_url] = ConnectionStatus());
}

protected string format_ldap_error (Connection conn)
{
  if (string srv_err = conn->server_error_string())
    return sprintf ("%s (%s)", srv_err,
		    Protocols.LDAP.ldap_error_strings[conn->error_number()]);
  else
    return Protocols.LDAP.ldap_error_strings[conn->error_number()];
}

protected void connection_error (ConnectionStatus status, string msg, mixed... args)
{
  if (sizeof (args)) msg = sprintf (msg, @args);
  status->status_msg =
    "<font color='red'>" + Roxen.html_encode_string (msg) + "</font>";
  RXML.run_error (msg);
}

#if 1

// FIXME: Compat.
mapping(string:array(int|string)) read_attrs(string attrs, int op, string arg_name)
{
  mapping(string:array(int|string)) res = ([]);

#define WS "%*[ \t\n\r]"
#define EXCERPT(STR) (sizeof (STR) > 30 ? (STR)[..27] + "..." : (STR))

  while (1) {
    string name;

    int fields = sscanf (attrs, WS"(%[-A-Za-z0-9.]"WS":"WS"%s", name, attrs);
    if (fields < 2) {
      if (sscanf (attrs, WS"%*c") == 1)
	break;			// At the end.
      else
	RXML.parse_error ("Expected '(' at the start of %O in the %O argument.\n",
			  EXCERPT (attrs), arg_name);
    }
    if (name == "" || fields < 5)
      RXML.parse_error ("Expected attribute name followed by ':' "
			"at the start of %O in the %O argument.\n",
			EXCERPT (attrs), arg_name);

    RXML.Context ctx = RXML_CONTEXT;
    array(int|string) value = res[name] || (op >= 0 ? ({op}) : ({}));

    string firstchar = attrs[..0];
    if (firstchar == ")")
      sscanf (attrs, ")"WS"%s", attrs);
    else {
    parse_values:
      while (1) {
	switch (firstchar) {

	  case "\"": {		// Newstyle string literal.
	    string lit;
#if __PIKE_VERSION__ >= 7.6
	    if (sscanf (attrs, "%O"WS"%s", lit, attrs) < 3)
	      RXML.parse_error ("String at the start of %O in the %O argument isn't "
				"terminated.\n", EXCERPT (attrs), arg_name);
#else
	    // Older pikes doesn't have %O in sscanf.
	    string tmp = attrs[1..];
	    lit = "";
	    while (1) {
	      sscanf (tmp, "%[^\"\\]%s", string val, tmp);
	      lit += val;
	      if (sscanf (tmp, "\""WS"%s", tmp) == 2) break;
	      int escchar;
	      if (sscanf (tmp, "\\%c%s", escchar, tmp) != 2)
		RXML.parse_error ("String at the start of %O in the %O argument isn't "
				  "terminated.\n", EXCERPT (attrs), arg_name);
	      string char = (['\'': "'", '"': "\"", '\\': "\\", 'b': "\b",
			      'f': "\f", 'n': "\n", 'r': "\r", 't': "\t",
			      'v': "\v",
			      // Unsupported. Use pike >= 7.6.
			      '0': "", '1': "", '2': "", '3': "", '4': "",
			      '5': "", '6': "", '7': "", '8': "", '9': "",
			      'x': "", 'u': ""])[escchar];
	      if (char == "") {
		tmp = sprintf ("\\%c%s", escchar, tmp);
		RXML.parse_error ("Escape sequence at the start of %O in the %O "
				  "argument isn't supported in this version.\n",
				  EXCERPT (tmp), arg_name);
	      }
	      if (char)
		lit += char;
	      else
		lit += sprintf ("%c", escchar);
	    }
	    attrs = tmp;
#endif
	    value += ({lit});
	    break;
	  }

	  case "'": {		// Oldstyle string literal.
	    string lit;
	    if (sscanf (attrs, "'%[^']'"WS"%s", lit, attrs) < 3)
	      RXML.parse_error ("String at the start of %O in the %O argument isn't "
				"terminated.\n", EXCERPT (attrs), arg_name);
	    value += ({lit});
	    break;
	  }

	  case ",":		// Extra comma.
	    break;

	  default: {		// RXML variable.
	    // Allow letters, digits, and the chars '.', '-', '_',
	    // ':'. Since there are many letters and digits in
	    // unicode, we instead deny only the ASCII chars outside
	    // this set of chars.
	    sscanf (attrs, "%[^\0-,/;-@[-^`{-\177]"WS"%s", string varref, string tmp);
	    array(string|int) splitted = ctx->parse_user_var (varref, 1);
	    if (splitted[0] == 1)
	      RXML.parse_error ("Invalid attribute value "
				"at the start of %O in the %O argument.\n",
				EXCERPT (attrs), arg_name);
	    attrs = tmp;

	    mixed varval = ctx->get_var (splitted[1..], splitted[0]);

	    // Coerce the value to an array to be concatenated with value.
#if 0
	    // Is this a good idea?
	    if (mappingp (varval))
	      varval = values (varval);
	    else
#endif
	      if (multisetp (varval))
		varval = indices (varval);
	    if (!arrayp (varval))
	      varval = ({varval});
	    value += map (
	      varval,
	      lambda (mixed v) {
		if (mixed err = catch {return (string) v;})
		  RXML.run_error ("Failed to convert %s in the value of %O "
				  "specified in the %O argument to a string: %s\n",
				  RXML.utils.format_short (v),
				  varref, arg_name, describe_error (err));
	      });
	    break;
	  }
	}

	sscanf (attrs, "%1s"WS"%s", firstchar, string tmp);
	switch (firstchar) {
	  case ")":
	    attrs = tmp;
	    break parse_values;
	  case ",":
	    attrs = tmp;
	    firstchar = attrs[..0];
	    break;
	  default:
	    RXML.parse_error ("Expected ',' or ')' "
			      "at the start of %O in the %O argument.\n",
			      EXCERPT (attrs), arg_name);
	}
      }
    }

    // The old parser accepted and ignored more or less anything
    // outside the parentheses. We're not so lax, but we still accept
    // commas since the old doc hinted there could be such things there.
    while (sscanf (attrs, ","WS"%s", attrs) == 2) {}

    res[name] = value;
  }

  return res;
}

#else

mapping(string:array(mixed))|int read_attrs(string attrs, int opval, void|string ignored) {
// from string: (attname1:'val1','val2'...)(attname2:'val1',...) to
// ADD: (["attname1":({"val1","val2"...}), ...
// REPLACE|MODIFY: (["attname1":({op, "val1","val2"...}), ...

  array(string) atypes; // = ({"objectclass","cn","mail","o"});
  array(array(mixed)) avals; // = ({({op, "top","person"}),({op, "sysdept"}), ({op, "sysdept@unibase.cz", "xx@yy.cc"}),({op, "UniBASE Ltd."})});
  array(mixed) tmpvals, tmparr;
  string aval;
  mapping(string:array(mixed)) rv;
  int vcnt, ix, cnt = 0, flg = opval >= 0;

  if (sizeof(attrs / "(") < 2)
    return ([]);
  atypes = allocate(sizeof(attrs / "(")-1);
  avals = allocate(sizeof(attrs / "(")-1);
  foreach(attrs / "(", string tmp)
    if (sizeof(tmp)) { // without empty '()'
      if ((ix = search(tmp, ":")) < 1) // missed ':' or is first char
	continue;
      //atypes[cnt] = (tmp / ":")[0];
      atypes[cnt] = tmp[..(ix-1)];
      //tmparr = tmp[(sizeof(atypes[cnt])+1)..] / ",";
      tmparr = (tmp[(ix+1)..] / ",") - ({ "", ")" });
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

#endif

protected void join_attrvals (mapping(string:array) into,
			      mapping(string:array) from)
{
  foreach (indices (from), string attr)
    if (into[attr])
      into[attr] += from[attr][1..];
    else
      into[attr] = from[attr];
}

int|array(mapping(string:string|array(string))) do_ldap_op (
  string op, mapping args, RequestID id)
{
  string host, binddn, pass;

  if (args->server) {
    host = args->server;
    binddn = args->binddn;
    pass = args->password;
  }
  else {
    host = query ("server");
    binddn = query ("binddn");
    pass = query ("password");
  }

  if (!binddn)
    // Avoid an arbitrarily bound connection from Protocols.LDAP.get_connection.
    binddn = "";

  if (args->password)
    args->password = "CENSORED";

  if (args->parse && args->attr)
    args->attr = Roxen.parse_rxml(args->attr, id);

  mapping(string:array) attrvals;

  switch (op) {
    case "add":
      if (!args->attr && !args["add-attr"])
	RXML.parse_error ("\"attr\" or \"add-attr\" argument required "
			  "for \"add\" operation.\n");
      if (string attr = args->attr)
	attrvals = read_attrs (attr, -1, "attr");
      if (string add_attr = args["add-attr"]) {
	mapping(string:array) add_attrs = read_attrs (add_attr, -1, "add-attr");
	if (attrvals)
	  join_attrvals (attrvals, add_attrs);
	else
	  attrvals = add_attrs;
      }
      break;

    case "modify":
    case "replace": {
      mapping(string:array) add_attrs = args["add-attr"] ?
	read_attrs (args["add-attr"], Protocols.LDAP.MODIFY_ADD,
		    "add-attr") : ([]);
      attrvals = args["replace-attr"] ?
	read_attrs (args["replace-attr"], Protocols.LDAP.MODIFY_REPLACE,
		    "replace-attr") : ([]);
      mapping(string:array) delete_attrs = args["delete-attr"] ?
	read_attrs (args["delete-attr"], Protocols.LDAP.MODIFY_DELETE,
		    "delete-attr") : ([]);

      if (string attr = args->attr) {
	mapping(string:array) attrs1, attrs2;
	if (op == "modify") {
	  attrs1 = add_attrs;
	  attrs2 = read_attrs (attr, Protocols.LDAP.MODIFY_ADD, "attr");
	}
	else {
	  attrs1 = attrvals;
	  attrs2 = read_attrs (attr, Protocols.LDAP.MODIFY_REPLACE, "attr");
	}
	join_attrvals (attrs1, attrs2);
      }
      else
	if (!args["add-attr"] && !args["replace-attr"] && !args["delete-attr"])
	  RXML.parse_error ("No attribute argument specified. Use at least one of "
			    "\"add-attr\", \"replace-attr\" or \"delete-attr\".\n");

      foreach (indices (add_attrs), string attr) {
	if (delete_attrs[attr])
	  RXML.parse_error ("Attribute %O found in both "
			    "\"add-attr\" and \"delete-attr\".\n", attr);
	else if (array repl = attrvals[attr])
	  attrvals[attr] = repl + add_attrs[attr][1..];
	else
	  attrvals[attr] = add_attrs[attr];
      }

      foreach (indices (delete_attrs), string attr) {
	if (array repl = attrvals[attr]) {
#ifdef DEBUG
	  if (repl[0] != Protocols.LDAP.MODIFY_REPLACE) error ("Oops..\n");
#endif
	  attrvals[attr] = ({Protocols.LDAP.MODIFY_REPLACE}) +
	    // NB: This doesn't use the proper equality matchers
	    // according to the attribute syntax.
	    (repl[1..] - delete_attrs[attr][1..]);
	}
	else
	  attrvals[attr] = delete_attrs[attr];
      }

      if (!sizeof (attrvals))
	// Nothing to do.
	return 1;
      break;
    }
  }

  Connection con;
  ConnectionStatus status = get_conn_status (host);
  if (mixed error =
      catch (con = Protocols.LDAP.get_connection (host, binddn, pass)))
    connection_error (status, "Couldn't connect to LDAP server: %s",
		      describe_error (error));
  if (con->error_number())
    connection_error (status, "Failed to bind to LDAP server: %s",
		      format_ldap_error (con));
  status->last_connect_time = time();
  status->status_msg = "Connected with LDAPv" + con->get_protocol_version();

  int|array(mapping(string:string|array(string))) result;

  switch (op) {
    case "search": {
      if(args->basedn)
	con->set_basedn(args->basedn);

      if (string scope = args["search-scope"]) {
	if (!(<"base", "one", "sub">)[scope])
	  RXML.parse_error ("Unknown scope %O.\n", scope);
	con->set_scope (scope);
      }

      object filter;
      string filter_arg = args["search-filter"];
      if (mixed error = catch {
	    if (filter_arg)
	      filter = con->make_filter (filter_arg);
	    else {
	      filter = con->get_default_filter();
	      if (!filter)
		RXML.parse_error ("No filter specified.\n");
	    }
	  }) {
	if (objectp (error) && error->is_ldap_filter_error)
	  RXML.parse_error ("Parse error in %s: %s\n",
			    filter_arg ?
			    "\"search-filter\" argument" : "default filter",
			    error->error_message);
	else
	  throw (error);
      }

      array(string) attr_list;
      if (args->attrs)
	attr_list = map (args->attrs / ",",
			 String.trim_all_whites) - ({""});

      Connection.result res =
	con->search (filter, attr_list, !!args["no-values"], 0,
		     (args["lower-attrs"] &&
		      Protocols.LDAP.SEARCH_LOWER_ATTRS) |
		     (args["array-values"] &&
		      Protocols.LDAP.SEARCH_MULTIVAL_ARRAYS_ONLY));

      if (res) {
	result = ({});
	for (mapping(string:string|array(string)) entry;
	     entry = res->fetch(); res->next())
	  result += ({entry});

#if 0
	if(args->rowinfo) {
	  int rows;
	  if(arrayp(result)) rows=sizeof(result);
	  if(objectp(result)) rows=result->num_rows();
	  RXML.user_set_var(args->rowinfo, rows);
	}
#endif
      }
      break;
    }

    case "add":
      result = con->add(args->dn, attrvals);
      break;

    case "delete":
      result = con->delete(args->dn);
      break;

    case "modify":
    case "replace":
      result = con->modify(args->dn, attrvals);
      break;
  } //switch

  if (!result || con->error_number())
    connection_error (status, "LDAP operation %s failed: %s\n",
		      op, format_ldap_error (con));

  Protocols.LDAP.return_connection (con);

  return result;
}


// -------------------------------- Tag handlers -----------------------------

class TagLDAPplugin {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "ldap";

  array get_dataset(mapping m, RequestID id) {
    NOCACHE();

    array(mapping(string:mixed)) res = do_ldap_op ("search", m, id);

    if (sizeof (res)) {
      mapping(string:mixed) some_entry = res[0];

      if (m["no-values"]) {
	foreach (res, mapping(string:string|array(string)) entry)
	  foreach (indices (entry), string attr)
	    if (attr != "dn")
	      entry[attr] = attr;
      }

      else {
	mapping(string:string) lc_attrs =
	  !m["lower-attrs"] &&
	  mkmapping (map (indices (some_entry), lower_case), indices (some_entry));

	// Split labeledURI values.
	if (lc_attrs ? lc_attrs->labeleduri : some_entry->labeleduri) {
	  // Assumes the server doesn't change around the casing in different entries.
	  string orig_attr = lc_attrs ? lc_attrs->labeleduri : "labeleduri";
	  foreach (res, mapping(string:string|array(string)) elem) {
	    // Note: labeledURI is not single-valued.
	    elem->labeleduriuri =
	      Array.map(elem[orig_attr],
			lambda(string el1) {
			  sscanf (el1, "%[^ ]", el1);
			  return el1;
			});
	    elem->labeledurilabel =
	      Array.map(elem[orig_attr],
			lambda(string el1) {
#if 0
			  // FIXME: Compat.
			  string rv = el1;
			  if (sizeof(el1/" ")>1) rv = (el1/" ")[1..]*" ";
			  return rv;
#else
			  sscanf (el1, "%*[^ ]%*[ ]%s", el1);
			  return el1;
#endif
			});
	  }
	}
      }

      string split = !m["array-values"] && (m->split || "\0");

      array(string)|string attr_list =
	indices (some_entry)
#if 1
	// FIXME: Compat.
	- ({"dn", "labeleduriuri", "labeledurilabel"})
#endif
	;
      if (split) attr_list *= split;

      foreach (res, mapping(string:string|array(string)) elem) {
	if (split) {
	  foreach (indices (elem), string attr)
	    elem[attr] *= split;
	}
	elem->_attributes = attr_list;
      }
    }

    return res;
  }
}

class TagLDAPQuery {
  inherit RXML.Tag;
  constant name = "ldap";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([
    "dn": RXML.t_text(RXML.PEnt),
    "op": RXML.t_text(RXML.PEnt),
  ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      NOCACHE();

      do_ldap_op(args->op, args, id);

      id->misc->defines[" _ok"] = 1;
      return 0;
    }

  }
}

// ------------------- Callback functions -------------------------

string query_provides()
{
  return "ldap";
}


// ------------------------ Setting the defaults -------------------------

void create()
{
  defvar ("server", "ldap://localhost/??sub",
	  "Default server URL", TYPE_STRING,
	  #"\
The default LDAP URL that will be used if no <i>host</i> attribute is
given to the tags.

<p>LDAP URL form:
<code>ldap://hostname[:port]/base_DN[?[attribute_list][?[scope][?[filter][?extensions]]]]</code>
See <a
href=\"http://community.roxen.com/developers/idocs/rfc/rfc2255.html\">RFC
2255</a> for details.");

  defvar ("binddn", "",
	  "Default bind DN", TYPE_STRING,
	  #"\
The bind DN that will be used with the \"Default server URL\" if it
doesn't specify any \"bindname\" extension.");

  defvar ("password", "",
	  "Default password", TYPE_STRING,
	  #"\
The password that will be used with the \"Default server URL\".");
}


// --------------------- More interface functions --------------------------

string status()
{
  // Use tables for everything to get consistent spacing.

  if (sizeof (connection_status)) {
    string res = "<h3>LDAP connection status</h3>\n"
      "<dl>\n";

    foreach (indices (connection_status), string url)
      res += "<dt><strong>" + Roxen.html_encode_string (url) + "</strong></dt>\n"
	"<dd><table border='0'>\n"
	"<tr><td>Status</td>"
	"<td>&nbsp;" + connection_status[url]->status_msg + "</td></tr>\n"
	"<tr><td>Open connections</td>"
	"<td>&nbsp;" + Protocols.LDAP.num_connections (url) + "</td></tr>\n"
	"<tr><td>Time of last query</td>"
	"<td>&nbsp;" + Roxen.html_encode_string (
	  ctime (connection_status[url]->last_connect_time)) + "</td></tr>\n"
	"</table></dd>\n";

    return res + "</dl>\n";
  }

  else
    return "<h3>No connections</h3>\n";
}
