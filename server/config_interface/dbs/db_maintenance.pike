// Copyright 2007 - 2009 Roxen Internet Software
// Contributed by:
// Digital Fractions 2007
// www.digitalfractions.net

// Note: The difference between this and the normal db_list/browse
// interfaces is that it also includes databases in the local mysql
// that aren't registered with DBManager. You need -DMORE_DB_OPTS to
// add a tab for this.

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
	
	array colors = ({ ({"&usr.matrix11;","&usr.matrix21;",}), ({"&usr.matrix12;","&usr.matrix22;",}) });
  
	// CSS stylesheet
	string res = "<style type='text/css'>";
	res += ".table_column { font-size: 8pt; font-weight: bold; background-color: &usr.matrix12;; color: black; padding: 2px; border-top: 1px solid &usr.matrix11;; border-left: 1px solid &usr.matrix11;; border-right: 1px solid &usr.matrix21;; border-bottom: 1px solid &usr.matrix21;; }\n";
	res += ".table_row { font-size: 8pt; padding: 1px; border-bottom: 1px solid &usr.matrix22;; }\n";
	res += ".df_text { font-size: 8pt; }";
	res += "</style>";
		
	// Database table
	res += "<table cellspacing='0' cellpadding='1'>";
	res += "<tr>";
	res += "<td class='table_column'>Target</td>";
	res += "<td class='table_column'>Tables</td>";
	res += "<td class='table_column'>Rows</td>";
	res += "<td class='table_column'>Actions</td>";
	res += "<tr>";
	
	// List databases
	mixed m = query( "SHOW DATABASES" );
	if( sizeof( m ) ) {
		foreach( m, m ) {
			int table_count = 0;
			int table_rows = 0;
			
			mixed q = query( "SHOW TABLE STATUS IN " + m->Database );
			if( sizeof( q ) ) {
				foreach( q, q ) {
					table_count += 1;
					table_rows += (int)q->Rows;
				}
			}
			
			res += "<tr>" +
			"<td class='table_row'><a href='browser.pike?db=" + m->Database + "'>" + m->Database + "</a></td>" +
			"<td class='table_row'>" + table_count + "</td>" +
			"<td class='table_row'>" + table_rows + "</td>" +
			"<td class='table_row'><a href='&page.path;?repair=" + m->Database + "'>[Repair]</a> <a href='&page.path;?optimize=" + m->Database + "'>[Optimize]</a> <a href='&page.path;?repair=" + m->Database + "&optimize=" + m->Database + "'>[Both]</a></td>" +
			"</tr>\n";
		}
	}
	res += "</table><br/>";
	res += "<a href='db_repairall.html'><gbutton>Repair all</gbutton></a> <a href='db_optimizeall.html'><gbutton>Optimize all</gbutton></a>";
	res += "<br/><br/>";
	
	// Draw result table
	if (id->variables->repair || id->variables->optimize) {
		res += "<table cellspacing='0' cellpadding='1'>";
		res += "<tr>";
		res += "<td class='table_column'>Target</td>";
		res += "<td class='table_column'>Operation</td>";
		res += "<td class='table_column'>Result</td>";
		res += "<td class='table_column'>Time</td>";
		res += "<tr>";
	}
	
	// Repair and optimize
	float t3 = 0;
	if (id->variables->repair) {
		mixed m = query( "SHOW TABLE STATUS IN " + id->variables->repair );
		if( sizeof( m ) ) {
			foreach( m, m ) {
				int t = time();
				float t1 = time(t);
				mixed q = query( "REPAIR TABLE `" + id->variables->repair + "`.`" + m->Name + "`" );
				float t2 = (time(t)-t1);
				t3 += t2;
				
				string result = "";
				if (q->Msg_text = "OK") 
					result = "<font color='green'>OK</font>";
				else
					result = "<font color='red'>Error</font>";
					
				res += "<tr>" +
				"<td class='table_row'><a href='browser.pike?db=" + id->variables->repair + "'>" + id->variables->repair + "</a>.<a href='browser.pike?db=" + id->variables->repair + "&table=" + m->Name + "'>" + m->Name + "</a></td>" +
				"<td class='table_row'>Repair</td><td class='table_row'><b>" + result + "</b></td>" +
				"<td class='table_row'>" + t2 + " sec</td>" +
				"</tr>";
			}
		}
	}
	if (id->variables->optimize) {
		mixed m = query( "SHOW TABLE STATUS IN " + id->variables->optimize );
		if( sizeof( m ) ) {
			foreach( m, m ) {
				int t = time();
				float t1 = time(t);
				mixed q = query( "OPTIMIZE TABLE `" + id->variables->optimize + "`.`" + m->Name + "`" );
				float t2 = (time(t)-t1);
				t3 += t2;
				
				string result = "";
				if (q->Msg_text = "OK") 
					result = "<font color='green'>OK</font>";
				else
					result = "<font color='red'>Error</font>";
					
				res += "<tr>" +
				"<td class='table_row'><a href='browser.pike?db=" + id->variables->optimize + "'>" + id->variables->optimize + "</a>.<a href='browser.pike?db=" + id->variables->optimize + "&table=" + m->Name + "'>" + m->Name + "</a></td>" +
				"<td class='table_row'>Optimize</td><td class='table_row'><b>" + result + "</b></td>" +
				"<td class='table_row'>" + t2 + " sec</td>" +
				"</tr>";
			}
		}
	}
	if (id->variables->repair || id->variables->optimize) res += "<tr><td colspan='3'>Total:</td><td>" + t3 + " sec</td></tr></table><br/>";
	
	// Done
	return Roxen.http_string_answer(res);
}
