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
	string res = #"<use file='/template-insert' />
	<tmpl>
	  <p><link-gbutton href='/dbs/'>Continue...</link-gbutton></p>
		<table class='nice db-list'>
	    <thead>
	      <tr>
	        <th>Target</td>
	  			<th>Result</td>
	  			<th>Time</td>
	  		<tr>
	  	</thead>
	  	<tbody>";

	string mysql_action = "REPAIR";

	if (id->variables->action && id->variables->action == "optimize") {
		mysql_action = "OPTIMIZE";
	}

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

					string sql = sprintf("%s TABLE `%s`.`%s`",
						                   mysql_action,
						                   q_dbs->Database,
						                   m->Name);

					if (mixed e = catch(q = query(sql))) {
						result = "<span class='notify error inline'>Error: " +
						         describe_error(e) + "</span>";
					}
					else {
						t2 = (time(t)-t1);
						t3 += t2;

						if (q->Msg_text = "OK") {
							result = "<span class='notify ok inline'>Ok</span>";
						}
						else {
							result = "<span class='notify error inline'>Failed: " +
							         q->Msg_text + "</span>";
						}
					}

					res += sprintf(#"
						<tr>
							<td>
								<a href='browser.pike?db=%s&amp;&usr.set-wiz-id;'>%[0]s</a>."
							 "<a href='browser.pike?db=%[0]s&amp;table=%s&amp;&usr.set-wiz-id;'"
							#">%[1]s</a>
							</td>
							<td>%s</td>
							<td>%.5f sec</td>
						</tr>",
						q_dbs->Database,
						m->Name,
						result,
						t2 || 0.0
					);
				}
			}
		}
	}

	res += #"
		  </tbody>
		  <tfoot>
				<tr>
			    <td colspan='2'>Total:</td>
			    <td>" + t3 + #" sec</td>
			  </tr>
		  </tfoot>
		</table>
		<p><link-gbutton href='/dbs/'>Continue...</link-gbutton></p>
	</tmpl>";

	// Done
	return Roxen.http_rxml_answer(res, id);
}
