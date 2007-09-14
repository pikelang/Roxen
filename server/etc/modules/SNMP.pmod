//
// SNMP helper stuff.
//
// $Id: SNMP.pmod,v 1.4 2007/09/14 11:23:37 grubba Exp $
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
      this_object()->value = fun();
      this_object()->der = UNDEFINED;
    }
  }
}

// ASN1 datatypes.

class app_integer
{
  inherit Standards.ASN1.Types.asn1_integer : integer;
  inherit Documentation : doc;
  inherit Updateable : update;
  constant cls = 1;
  constant type_name = "APPLICATION INTEGER";
  constant tag = 0;
  static void create(int|function(:int) val, string|void name, string|void doc_string)
  {
    if (intp(val)) {
      update::create(UNDEFINED);
      integer::create(val);
    } else {
      update::create(val);
      integer::create(val());
    }
    doc::create(name, doc_string);
  }
}

class app_octet_string
{
  inherit Standards.ASN1.Types.asn1_octet_string : octet_string;
  inherit Documentation : doc;
  inherit Updateable : update;
  constant cls = 1;
  constant type_name = "APPLICATION OCTET_STRING";
  constant tag = 0;
  static void create(string|function(:string) val, string|void name, string|void doc_string)
  {
    if (stringp(val)) {
      update::create(UNDEFINED);
      octet_string::create(val);
    } else {
      update::create(val);
      octet_string::create(val());
    }
    doc::create(name, doc_string);
  }
}

class OID
{
  inherit Standards.ASN1.Types.asn1_identifier : identifier;
  inherit Documentation : doc;
  constant type_name = "OID";
  static void create(array(int) oid, string|void name, string|void doc_string)
  {
    identifier::create(@oid);
    doc::create(name, doc_string);
  }
}

class Integer
{
  inherit Standards.ASN1.Types.asn1_integer : integer;
  inherit Documentation : doc;
  inherit Updateable : update;
  constant type_name = "INTEGER";
  static void create(int|function(:int) val, string|void name, string|void doc_string)
  {
    if (intp(val)) {
      update::create(UNDEFINED);
      integer::create(val);
    } else {
      update::create(val);
      integer::create(val());
    }
    doc::create(name, doc_string);
  }
}

class String
{
  inherit Standards.ASN1.Types.asn1_octet_string : octet_string;
  inherit Documentation : doc;
  inherit Updateable : update;
  constant type_name = "STRING";
  static void create(string|function(:string) val, string|void name, string|void doc_string)
  {
    if (stringp(val)) {
      update::create(UNDEFINED);
      octet_string::create(val);
    } else {
      update::create(val);
      octet_string::create(val());
    }
    doc::create(name, doc_string);
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

class Tick
{
  inherit app_integer;
  constant tag = 3;
  constant type_name = "TICK";
}

class Opaque
{
  inherit app_octet_string;
  constant tag = 4;
  constant type_name = "OPAQUE";
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

  static void create(array(int) oid,
		     array(int) oid_suffix,
		     array(Standards.ASN1.Types.Object|function)|
		     mapping(int:Standards.ASN1.Types.Object|function) values)
  {
    ::create(oid);
    foreach(values; int i; function|Standards.ASN1.Types.Object val) {
      if (!zero_type(val)) {
	insert(oid + ({ i }) + oid_suffix + ({ 0 }), val);
      }
    }
  }

  Standards.ASN1.Types.Object lookup(array(int) key)
  {
    function|Standards.ASN1.Types.Object res = ::lookup(key);
    if (zero_type(res)) return UNDEFINED;
    if (functionp(res)) return res();
    return res;
  }
}
