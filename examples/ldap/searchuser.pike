#!pike
/* $Id: searchuser.pike,v 1.1 1999/04/24 16:39:42 js Exp $ */


	searchuser.pike,
	(c) hop@unibase.cz

1998-02-17	hop: Initial version
1998-07-07	hop: updated to new LDAP API

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


mixed parse(object id)
{

    object o,e;
    //string rv= "<HTML><HEAD><TITLE>Search user</TITLE> </HEAD> <BODY bgcolor=#ffffff><P><CENTER><GH1>Search user</GH1></CENTER> <BR><BR><BR>";
    string rv= "<HTML><HEAD><TITLE>Search user</TITLE> </HEAD> <BODY bgcolor=#ffffff><P><CENTER><GH1>Search user</GH1></CENTER> ";
    string url = "", headtree, attval = "", searchstr, sstr, olist = "";
    int cnt = 0, flg=0;
    mapping(string:array(string)) entry;


    	catch { if (!sizeof(indices(master()->resolv("Ldap"))))
	  return("Ldap support is NOT implemented!</BODY></HTML>");
	};

	if(id->variables)
	  if(id->variables->ldap_server)
	    rv += "<CENTER>on " + id->variables->ldap_server +
		"</FONT></CENTER>";
	rv += "<BR><BR><BR>";

	if(!id->query || !id->variables) { //first call
	  rv += "<BR><P><FORM action=\""+THIS+"\">LDAP server: <SELECT name=ldap_server><OPTION>gandalf.unibase.cz<OPTION>ldap.four11.com<OPTION>lide.seznam.cz<OPTION>ldap.atlas.cz</SELECT>" +
	        "<BR>search base: <INPUT type=text name=ldap_base size=40><BR>" +
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
	  o=Ldap.ldap(id->variables->ldap_server);
	};
	if (!o) { // error
	  rv += "<H1>Error: can't connect to LDAP server " + id->variables->ldap_server + (id->variables->ldap_base ? id->variables->ldap_base : "") + ".</H1>";
	  rv += "</BODY> </HTML>";
	  return(rv);
	}
	if(id->variables->ldap_base)
	  o->set_base(http_decode_string(id->variables->ldap_base));
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
	//if(id->variables->cn)
	//  if (sizeof(id->variables->cn))
	//  searchstr += "(cn=" + http_decode_string(id->variables->cn) + ")";
	if(id->variables->dn)
	  if (sizeof(id->variables->dn))
	  searchstr = "((" + http_decode_string(id->variables->dn) + ")";
	searchstr += ")";

	e=o->search(searchstr);

        if (e)
          do {
	    string stmp = "";

	    if (!id->variables->dn) { // username listing
	      //stmp = "&cn=" + e->fetch()->cn[0];
	      stmp = "&dn=" + e->get_dn();
              //olist += "<A href=\"" + id->raw_url + stmp + "\">" + (e->get_dn() / ",")[0] + "</A><BR>";
              olist += "<A href=\"" + id->raw_url + stmp + "\">" + e->get_dn() + "</A><BR>";
	    } else
	      olist += sprintf("<PRE>%O</PRE>",e->fetch()) + "<P>";
          } while (e->next());
	else
	  olist += "<I>Empty search</I>";



	//rv += "<P>" + url;
	rv += "<P>" + olist;
        rv += "<BR><BR><P><FONT size=-2>&copy; Honza Petrous, usersearch.pike.</FONT>";
	rv += "</BODY> </HTML>";
	return(rv);




}
