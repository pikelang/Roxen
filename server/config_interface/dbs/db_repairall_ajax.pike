// Copyright 2007 - 2009 Roxen Internet Software
// Contributed by:
// Digital Fractions 2007
// www.digitalfractions.net

#include <config_interface.h>
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">_</locale-token>
#define _(X,Y)	_STR_LOCALE("roxen_config",X,Y)

#define CU_AUTH id->misc->config_user->auth

mixed query( mixed ... args ) {
	return connect_to_my_mysql( 0, "roxen" )->query( @args );
}

string|mapping parse( RequestID id )
{ 
	// Permissions check
	if ( !(CU_AUTH( "Edit Global Variables" )) ) return "Access denied";
	
	// Draw continue button
	string res = "<nooutput><eval><insert file='/themes/&usr.theme;/theme'/></eval><define preparse='1' variable='var.leftimage'><img src='&usr.left-image;' alt='' /></define><define preparse='1' name='tab-frame-image'>&usr.tab-frame-image;</define><define preparse='1' name='tab-font-size'>&usr.tab-font-size;</define><define preparse='1' name='gbutton-frame-image'>&usr.gbutton-frame-image;</define><define name='font' preparse='1'>&usr.font;</define><expire-time now='1'/></nooutput>\n";
	res += "<a href='/dbs/'><gbutton>Continue...</gbutton></a><br/><br/>";
	
	// Draw result table
	res += "<table id='tbl' cellspacing='0' cellpadding='1'>\n"
	  "<thead>\n"
	  "<tr>"
	  "<th>Target</td>"
	  "<th>Result</td>"
	  "<th>Time</td>"
	  "<tr>\n"
	  "</thead>\n"
	  "<tbody>\n";
	
	// Enumerate databases
	mixed q_dbs = query( "SHOW DATABASES" );
	
	// Repair and optimize
	float t3 = 0;
	foreach (q_dbs,q_dbs) {
		if( sizeof( q_dbs ) ) {
			mixed m = query( "SHOW TABLE STATUS IN " + q_dbs->Database );
			if( sizeof( m ) ) {
				foreach( m, m ) {
					string result = "";
					mixed q;
					int t = time();
					float t1 = time(t);
					float t2;
					
					if ( mixed e = catch { q = query( "REPAIR TABLE `" + q_dbs->Database + "`.`" + m->Name + "`" ); } ) {
						result = "<font color='red'>Error: " + describe_error(e) + "</font>";
					} else {
						t2 = (time(t)-t1);
						t3 += t2;
						
						if (q->Msg_text = "OK") 
							result = "<font color='green'>OK</font>";
						else
							result = "<font color='red'>Failed: " + q->Msg_text + "</font>";
					}
					
					res += "<tr>" +
					"<td><a href='browser.pike?db=" + q_dbs->Database + "&amp;&usr.set-wiz-id;'>" + q_dbs->Database + "</a>.<a href='browser.pike?db=" + q_dbs->Database + "&amp;table=" + m->Name + "&amp;&usr.set-wiz-id;'>" + m->Name + "</a></td>" +
					"<td><b>" + result + "</b></td>" +
					"<td>" + t2 + " sec</td>" +
					"</tr>";
				}
			}
		}
	}
	res += "<tr><td colspan='2'>Total:</td><td>" + t3 + " sec</td></tr>"
	  "</tbody></table><br/>\n";
	res += "<a href='/dbs/'><gbutton>Continue...</gbutton></a><br/>";
	
	// Done
	return Roxen.http_rxml_answer(res, id);
}
