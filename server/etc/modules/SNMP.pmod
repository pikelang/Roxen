//
// SNMP helper stuff.
//
// $Id$
//
// 2007-08-29 Henrik Grubbström
//

// Some OIDs

//! iso.organizations.dod.internet
constant INTERNET_OID = ({ 1, 3, 6, 1 });

//! iso.organizations.dod.internet.private.enterprises.roxenis
constant RIS_OID = INTERNET_OID + ({ 4, 1, 8614 });

//! iso.organizations.dod.internet.private.enterprises.roxenis.app.webserver
constant RIS_OID_WEBSERVER = RIS_OID + ({ 1, 1 });

class Documentation(string name,
		    string doc)
{
}

class Updateable(function(:mixed) fun)
{
  void update_value()
  {
    if (fun) {
      mixed val = fun();
      if (
#if __VERSION__ < 7.6
	  intp(val)
#else
	  0
#endif
	  ) {
	this_object()->value = Gmp.mpz(val);
      } else {
	this_object()->value = val;
      }
      this_object()->der = UNDEFINED;
    }
  }
}

class OwnerInfo
{
  Configuration conf;
  RoxenModule module;
}

// ASN1 datatypes.

class app_integer
{
  inherit Standards.ASN1.Types.asn1_integer : integer;
  inherit Documentation : doc;
  inherit Updateable : update;
  inherit OwnerInfo : owner_info;
  constant cls = 1;
  constant type_name = "APPLICATION INTEGER";
  constant tag = 0;
  protected void create(int|function(:int) val, string|void name,
			string|void doc_string)
  {
    if (intp(val)) {
      update::create(UNDEFINED);
      integer::create(val);
    } else {
      update::create(val);
      integer::create(0);
    }
    doc::create(name, doc_string);
  }
  protected string _sprintf(int t)
  {
    switch(t) {
    case 's': return (string)value;
    default: return sprintf("%s[%d][%d](%O)", type_name, cls, tag, value);
    }
  }
}

class app_octet_string
{
  inherit Standards.ASN1.Types.asn1_octet_string : octet_string;
  inherit Documentation : doc;
  inherit Updateable : update;
  inherit OwnerInfo : owner_info;
  constant cls = 1;
  constant type_name = "APPLICATION OCTET_STRING";
  constant tag = 0;
  protected void create(string|function(:string) val, string|void name,
			string|void doc_string)
  {
    if (stringp(val)) {
      update::create(UNDEFINED);
      octet_string::create(val);
    } else {
      update::create(val);
      octet_string::create("");
    }
    doc::create(name, doc_string);
  }
  protected string _sprintf(int t)
  {
    switch(t) {
    case 's': return (string)value;
    default: return sprintf("%s[%d][%d](%O)", type_name, cls, tag, value);
    }
  }
}

class OID
{
  inherit Standards.ASN1.Types.asn1_identifier : identifier;
  inherit Documentation : doc;
  inherit OwnerInfo : owner_info;
  constant type_name = "OID";
  protected void create(array(int) oid, string|void name,
			string|void doc_string)
  {
    identifier::create(@oid);
    doc::create(name, doc_string);
  }
  protected string _sprintf(int t)
  {
    switch(t) {
    case 's': return ((array(string))id) * ".";
    default: return sprintf("%s[%d][%d](%O)",
			    type_name, cls, tag,
			    ((array(string))id) * ".");
    }
  }
}

class Integer
{
  inherit Standards.ASN1.Types.asn1_integer : integer;
  inherit Documentation : doc;
  inherit Updateable : update;
  inherit OwnerInfo : owner_info;
  constant type_name = "INTEGER";
  protected void create(int|function(:int) val, string|void name,
			string|void doc_string)
  {
    if (intp(val)) {
      update::create(UNDEFINED);
      integer::create(val);
    } else {
      update::create(val);
      integer::create(0);
    }
    doc::create(name, doc_string);
  }
  protected string _sprintf(int t)
  {
    switch(t) {
    case 'd':
    case 's': return (string)value;
    default: return sprintf("%s[%d][%d](%O)", type_name, cls, tag, value);
    }
  }
}

class String
{
  inherit Standards.ASN1.Types.asn1_octet_string : octet_string;
  inherit Documentation : doc;
  inherit Updateable : update;
  inherit OwnerInfo : owner_info;
  constant type_name = "STRING";
  protected void create(string|function(:string) val, string|void name,
			string|void doc_string)
  {
    if (stringp(val)) {
      update::create(UNDEFINED);
      octet_string::create(val);
    } else {
      update::create(val);
      octet_string::create("");
    }
    doc::create(name, doc_string);
  }
  protected string _sprintf(int t)
  {
    switch(t) {
    case 's': return (string)value;
    default: return sprintf("%s[%d][%d](%O)",
			    type_name, cls, tag, (string)value);
    }
  }
}

class Counter
{
  inherit app_integer;
  constant tag = 1;
  constant type_name = "COUNTER";
}

class Gauge
{
  inherit app_integer;
  constant tag = 2;
  constant type_name = "GAUGE";
}

//! One tick is 1/100 seconds.
class Tick
{
  inherit app_integer;
  constant tag = 3;
  constant type_name = "TICK";
  protected string _sprintf(int t)
  {
    if (t == 's') {
      return Roxen.short_date((int)(time(1) - value/100));
    }
    return ::_sprintf(t);
  }
}

class Opaque
{
  inherit app_octet_string;
  constant tag = 4;
  constant type_name = "OPAQUE";
  protected string _sprintf(int t)
  {
    if (t == 's') return "";
    return ::_sprintf(t);
  }
}

class Counter64
{
  inherit app_integer;
  constant tag = 6;
  constant type_name = "COUNTER64";
}

//! No such object marker.
Protocols.LDAP.ldap_privates.asn1_context_octet_string NO_SUCH_OBJECT =
  Protocols.LDAP.ldap_privates.asn1_context_octet_string(0, "");

//! No such instance marker.
Protocols.LDAP.ldap_privates.asn1_context_octet_string NO_SUCH_INSTANCE =
  Protocols.LDAP.ldap_privates.asn1_context_octet_string(1, "");

//! End of MIB marker.
Protocols.LDAP.ldap_privates.asn1_context_octet_string END_OF_MIB =
  Protocols.LDAP.ldap_privates.asn1_context_octet_string(2, "");

//! The NULL counter.
Counter NULL_COUNTER = Counter(0);


class SimpleMIB
{
  inherit ADT.Trie;

  protected void init(array(int) oid,
		      array(int) oid_suffix,
		      array(Standards.ASN1.Types.Object|
			    function|array|mapping)|
		      mapping(int:Standards.ASN1.Types.Object|
			      function|array|mapping) values)
  {
    foreach(values; int i;
	    function|Standards.ASN1.Types.Object|array|mapping val) {
      if (arrayp(val) || mappingp(val)) {
	init(oid + ({ i }), oid_suffix, val);
      } else if (!zero_type(val)) {
	insert(oid + ({ i }) + oid_suffix + ({ 0 }), val);
      }
    }
  }

  protected void create(array(int) oid,
			array(int) oid_suffix,
			array(Standards.ASN1.Types.Object|
			      function|array|mapping)|
			mapping(int:Standards.ASN1.Types.Object|
				function|array|mapping) values)
  {
    ::create(oid);
    init(oid, oid_suffix, values);
  }

  Standards.ASN1.Types.Object lookup(array(int) key)
  {
    function|Standards.ASN1.Types.Object res = ::lookup(key);
    if (zero_type(res)) return UNDEFINED;
    if (functionp(res)) return res();
    return res;
  }
}

void set_owner(ADT.Trie mib, Configuration conf, RoxenModule|void module)
{
  array(int) oid = mib->first();
  while (oid) {
    Standards.ASN1.Types.Object o = mib->lookup(oid);
    catch {
      o->conf = conf;
      if (module) {
	o->module = module;
      }
    };
    oid = mib->next(oid);
  }
}

void remove_owned(ADT.Trie mib, Configuration conf, RoxenModule|void module)
{
  array(int) oid = mib->first();
  while(oid) {
    Standards.ASN1.Types.Object o = mib->lookup(oid);
    if (objectp(o) && (o->conf == conf) &&
	(!module || (o->module == module))) {
      mib->remove(oid);
    }
    oid = mib->next(oid);
  }
}

#if 0	// Not ready for production yet.

class Describer(string symbol)
{
}

class IndexDescriber
{
  inherit Describer;
  constant is_index = "int";
}

class StringIndexDescriber
{
  inherit Describer;
  constant is_index = "string";
}

class IndexedDescriber
{
  inherit Describer;
  constant index = "int";
}

class StringIndexedDescriber
{
  inherit Describer;
  constant index = "string";
}

ADT.Trie OID_ParseInfo = ADT.Trie();

void add_oid_path(array(int) oid, string symbolic_oid)
{
  int i;
  foreach(symbolic_oid/".", string symbol) {
    if (i >= sizeof(oid)) return;
    if (sizeof(symbol)) {
      if (symbol[0] == '"') {
	OID_ParseInfo->insert(oid[..i], StringDescriber(symbol));
	i += oid[i];
      } else {
	OID_ParseInfo->insert(oid[..i], Describer(symbol));
      }
    }
    i++;
  }
}

string format_oid(array(int) oid)
{
  ADT.Trie parse_info = OID_ParseInfo;
  
  int i;
  array(IndexDescriber) indexers = ({});
  array(string) res = ({});
  for (i=0; i < sizeof(oid); i++) {
    int j = i;
    while(i < parse_info->offset) {
      if (oid[i] != parse_info->path[i]) {
	i = j;
	break;
      }
      i++;
    }
    if (i < parse_info->offset) break;
    Describer desc = parse_info->value;
    switch(desc && desc->is_index) {
    case "string":
      if (i + oid[i] < sizeof(oid)) {
	res += ({ sprintf("%O", (string)oid[i+1..i+oid[i]]) });
	i += oid[i];
	break;
      }
      res += ({ (string)oid[i] });
      break;
    case 0:
      if (desc->symbol) {
	res += desc->symbol;
	break;
      }
    case "int":
    default:
      res += ({ (string)oid[i] });
    }
    if (desc && desc->index) {
      indexers += ({ desc });
    }
    while (parse_info && parse_info->offset < i) {
      parse_info = parse_info->trie[oid[parse_info->offset]];
    }
    if (parse_info) break;
  }
  return res * ".";
}

protected void create()
{
  add_oid_path(RIS_OID_WEBSERVER,
	       "iso.organizations.dod.internet.private."
	       "enterprises.roxenis.app.webserver");
}

#endif /* 0 */
