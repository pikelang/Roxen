#!pike
/* $Id: searchuser.pike,v 1.2 1999/08/16 00:41:45 peter Exp $ */
/*


	searchuser.pike,
	(c) hop@unibase.cz

1998-02-17	hop: Initial version
1998-07-07	hop: updated to new LDAP API
1999-08-06	hop: - corrected update to the new API (was broken)
		     - improved error checkings
		     - improved object listing (table view)
		     known error: require ',' as separator

*/

inherit "roxenlib";


#define THIS	(id->raw_url/"?")[0]

string http_encode_string(string f)
{
  return replace(f, ({ "\000", " ", "%","\n","\r", "'", "\"" }),
                 ({"%00", "%20", "%25", "%0a", "%0d", "%27", "%22"}));
}

string http_decode_string(string f)
{
  return replace(f, ({"%00", "%20", "%25", "%0a", "%0d", "%27", "%22"}),
  		({ "\000", " ", "%","\n","\r", "'", "\"" }));
}

string get_rdn(string dn)
{
  return((dn / ",")[0]);
}

mixed parse(object id)
{

    object o,e;
    string rv= "<HTML><HEAD><TITLE>Search user</TITLE> </HEAD> <BODY bgcolor=#ffffff><P><CENTER><H1>Search user</H1></CENTER> ";
    string url = "", headtree, searchstr, olist = "";
    int cnt = 0, flg=0;
    mapping(string:array(string)) entry;


    	/*catch { if (!sizeof(indices(master()->resolv("Ldap"))))
	  return("Ldap support is NOT implemented!</BODY></HTML>");
	};*/

	if(id->variables)
	  if(id->variables->ldap_server)
	    rv += "<CENTER>on " + id->variables->ldap_server +
		"</FONT></CENTER>";
	rv += "<BR><BR><BR>";

	if(!id->query || !id->variables) { //first call
	  //rv += "<BR><P><FORM action=\""+THIS+"\">LDAP server: <SELECT name=ldap_server><OPTION>gandalf.unibase.cz<OPTION>ldap.four11.com<OPTION>lide.seznam.cz<OPTION>ldap.atlas.cz</SELECT>" +
	  rv += "<BR><P><FORM action=\""+THIS+"\">LDAP server: <SELECT name=ldap_server>" +
//  --------------- Listing of known LDAP servers -------------------
		"<OPTION>ldap.four11.com" +
		"<OPTION>lide.seznam.cz" +
		"<OPTION>ldap.atlas.cz" +
//  -----------------------------------------------------------------
		"</SELECT><BR>" +
	        "search base: <INPUT type=text name=ldap_base size=40><BR>" +
	        "<P>First name: <INPUT type=text name=givenname size=30><BR>" +
	        "<P>Last name: <INPUT type=text name=sn size=40><BR>" +
	        "<P>E-mail: <INPUT type=text name=mail size=40><BR>" +
	        "<P>Country: <INPUT type=text name=c size=40><BR>" +
	        "<P>Location: <INPUT type=text name=l size=40><BR>" +
		"<P><INPUT type=submit value=\"Search directory\"></FORM>";
	  rv += "</BODY> </HTML>";
	  return (rv);
	}

	catch {
	  o=Protocols.LDAP.client(id->variables->ldap_server);
	};
	if (!o || (objectp(o) && o->error_number())) { // error
	  rv += "<H1>Error: can't connect to LDAP server " + id->variables->ldap_server + " : " + (objectp(o) ? o->error_string() : "unknown reason") + ".</H1>";
	  rv += "</BODY> </HTML>";
	  return(rv);
	}
	catch {
	  o->bind();
	};
	if (o->error_number()) { // error
	  rv += "<H1>Error: can't anonymous bind to LDAP server " + id->variables->ldap_server + (id->variables->ldap_base ? id->variables->ldap_base : "") + " : " + o->error_string() + ".</H1>";
	  rv += "</BODY> </HTML>";
	  return(rv);
	}


	if(id->variables->ldap_base)
	  o->set_basedn(http_decode_string(id->variables->ldap_base));
	o->set_scope(2);

	searchstr = "(&";
	if(id->variables->sn)
	  if (sizeof(id->variables->sn))
	  searchstr += "(|(sn=" + http_decode_string(id->variables->sn) + ")(surname=" + http_decode_string(id->variables->sn) + "))";
	if(id->variables->mail)
	  if (sizeof(id->variables->mail))
	  searchstr += "(|(mail=" + http_decode_string(id->variables->mail) + ")(rfc822mailbox=" + http_decode_string(id->variables->mail) + "))";
	if(id->variables->givenname)
	  if (sizeof(id->variables->givenname))
	  searchstr += "(givenname=" + http_decode_string(id->variables->givenname) + ")";
	if(id->variables->l)
	  if (sizeof(id->variables->l))
	  searchstr += "(l=" + http_decode_string(id->variables->l) + ")";
	if(id->variables->c)
	  if (sizeof(id->variables->c))
	  searchstr += "(c=" + http_decode_string(id->variables->c) + ")";
	if(id->variables->o)
	  if (sizeof(id->variables->o))
	  searchstr += "(o=" + http_decode_string(id->variables->o) + ")";
	if(id->variables->dn)
	  if (sizeof(id->variables->dn))
	  searchstr = "(" + get_rdn(http_decode_string(id->variables->dn));
	searchstr += ")";

	e=o->search(searchstr);

        if (e && (objectp(e) && e->num_entries()))
          do {
	    string stmp = "";

	    if (!id->variables->dn) { // username listing
	      stmp = "&dn=" + e->get_dn();
              olist += "<A href=\"" + id->raw_url + stmp + "\">" + e->get_dn() + "</A><BR>";
	    } else
	    { 
	      mixed aval = e->fetch();

	      olist +="<BR><FONT color=red size=5>" + e->get_dn() + "</FONT><BR>\n";
	      olist +="<TABLE border=2>\n";
	      olist +="  <TR bgcolor=#ffceac>\n";
	      olist +="    <TD>Attribute name</TD><TD>Value(s)</TD>\n";
	      olist +="  </TR>\n";
	      foreach (indices(aval), string attr) {
		olist +="  <TR>\n    <TD>" + attr + "</TD>\n";
		olist +="    <TD>";
		olist +=aval[attr][0];
		if (sizeof(aval[attr]) > 1)
		  foreach (aval[attr], string nextval)
		    olist += " | " + nextval;
		olist +="</TD>\n  </TR>\n";
	      }
	      olist +="</TABLE>\n";
	    }
          } while (e->next());
	else
	  olist += "<I>Empty search result</I>";



	//rv += "<P>" + url;
	rv += "<P>" + olist;
        rv += "<BR><BR><P><FONT size=-2>&copy; 1998-99 Honza Petrous, <A href=\"http://www.unibase.cz/ftpserver/src/Roxen\">searchuser.pike</A>.</FONT>";
	rv += "</BODY> </HTML>";
	return(rv);




}
