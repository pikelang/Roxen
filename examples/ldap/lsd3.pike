/* $Id: lsd3.pike,v 1.1 1999/04/24 16:39:41 js Exp $ */
/*


	ls directory
	v1.8, 1998 hop@unibase.cz

 History:

  1998-02-12	v1.0, hop
		Initial version
		Know bug: Display ALL persons if nonexistent 'ou'
  1998-02-17	v1.1, hop
		Interactive connection dialog
		Nonexistent 'ou' catched
  1998-07-02	v1.2, hop
		Updated to new LDAP API
  1998-07-28	v1.3, hop
		Now is context "auto-sensing" (without needs of any tree)
  1998-07-30	v1.4, hop
		Added error checking search operation
  1998-08-05	v1.5, hop
		Added ld->unbind(), initial form updated
  1998-09-18	v1.6, hop
		Added support for authorisation
  1998-11-06	v1.7, hop
		Initialize variable: filt = "objectclass"
  1998-11-11	v1.8, hop
		Resolved problems with authorized access to the subtree

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

string get_rdn(string dn) {
  int s0, s1;

  s1 = search(dn[s0..], ",");
  if (s1 < 0)
    s1 = sizeof(dn) + 1;
  return(dn[s0..(s1-1)]);
}

string get_attrval(string atype, mapping res, int|void idx) {

    string rv;

        if(!zero_type(res[atype]))
          if(sizeof(res[atype]) > idx)
            rv = res[atype][idx];
        else
          rv = "";
        return(rv);
};



// --------------------------------------------------------------------

mixed parse(object id) {

    string host = "", param, basedn = "", userdn = "", userpw = "", auth;
    string body = "<!-- No entry !? ->";
    string header0 = "<HTML><HEAD><TITLE>LDAP browser</TITLE> </HEAD> <BODY bgcolor=#ffffff><P>\n";
    string header1 = "";
    string footer = "\n</BODY> </HTML>";
    int ix;
    object ld, en;
    array ar;

    if(!id->variables->host) { // query LDAP connection variables
	  body = "<CENTER><H1>LDAP connection</H1></CENTER>" +
		"<P><RIGHT><FONT size=-2>&copy; Honza Petrous, <A href=\"http://www.unibase.cz/ftpserver/src/Roxen\">LDAP for Pike/Roxen</A>.</FONT></RIGHT><P>\n";
	  body += "<BR><P><FORM action=\""+THIS+"\">LDAP server: <INPUT type=text name=host value=\"localhost\" size=40> (or try <I>e.rs.itd.umich.edu</I>)<BR>" +
	        "<BR>search base: <INPUT type=text name=basedn value=\"c=CZ\" size=50><BR>" +
	        "<BR>bind as: <INPUT type=text name=userdn value=\"\" size=50><BR>" +
	        "<BR>password: <INPUT type=password name=userpw value=\"\" size=30><BR>" +
		"<P><CENTER><INPUT type=submit value=\"Search directory\"></FORM>";
	  return (header0 + body + footer);
    }

    host = id->variables->host;
    if(id->variables->basedn)
      basedn = id->variables->basedn;

    // Connect to LDAP server
    if(!(objectp(ld = Protocols.LDAP.client(host)))) {
	  body = "<RED>Can't connect to LDAP server:</RED> \"" + host + "\"<BR><P>\n";
	  return (header0 + body + footer);
    }
    if(id->variables->userdn)
      userdn = id->variables->userdn;
    if(id->variables->userpw)
      userpw = id->variables->userpw;
    if(sizeof(userdn))
      auth="&userdn="+http_encode_string(userdn)+"&userpw="+http_encode_string(userpw);
    else
      auth="";
    ld->bind(userdn, userpw);
    ld->set_option(2, 100); // Only first 100 entries

    // Header1 processing
    param = "";
    header1 = ""; //<FONT fgcolor=\"green\">";
    ar = reverse(basedn/",");
    for(ix = 0; ix < sizeof(ar); ix++) {
	param = ar[ix] + (ix ? ",":"") + param;
	if (ix == (sizeof(ar)-1)) 
	  header1 += (ix ? "<GTEXT>></GTEXT>":"") + "<GTEXT fg=darkgray>" +
		ar[ix] + "</GTEXT>";
	else
	  header1 += (ix ? "<GTEXT>></GTEXT>":"") + "<A href=\"" + THIS + "?host=" + host +
		"&basedn=" + param +
		"\"><GTEXT fg=red>" + ar[ix] + "</GTEXT> </A>";
    }
    header1 += "<BR><BR><P><RIGHT><FONT size=-2>&copy; Honza Petrous, <A href=\"http://www.unibase.cz/ftpserver/src/Roxen\">LDAP for Pike/Roxen</A>.</FONT></RIGHT><P>\n";


    // do LDAP search
    ld->bind(userdn, userpw);
    ld->set_scope(1);
    //if(sizeof(subtree) > sizeof(basedn))
    //  ld->set_basedn(subtree);
    //else
      ld->set_basedn(basedn);
    if(!(objectp(en = ld->search("objectclass")))) {
      body = "<RED>Internal errror:</RED> \"" + ld->error_string() + "\"<BR><P>\n";
      return (header0 + body + footer);
    }
    if(ld->error_number() && (ld->error_number() != 4)) {
      body = "<RED>Search errror:</RED> \"" + ld->error_string() + "\" [" + (string)ld->error_number() + "] <BR><P>\n";
      ld->unbind();
      return (header0 + body + footer);
    }
    if(!en->num_entries()) {

      ld->set_scope(0);
      if(!(objectp(en = ld->search("objectclass")))) {
        body = "<RED>No entries!</RED><BR><P>\n";
        return (header0 + body + footer);
      }
      // Entry exists -> output attributes
      body = "\n<BR><P><PRE>" + sprintf("%O", en->fetch()) + "</PRE><BR>\n";

      ld->unbind();
      return (header0 + header1 + body + footer);
    }
    ld->unbind();

    // Body processing
    body = "";
    do {
	mapping av = en->fetch();
      body += "<A href=\"" + THIS + "?host=" + host + "&basedn=" + 
		http_encode_string(get_attrval("dn", av)) + auth + "\">" +
		get_rdn(get_attrval("dn", av)) +
	      "</A><BR>\n";
    } while(en->next());
    


    return(header0 + header1 + body + footer);

}
