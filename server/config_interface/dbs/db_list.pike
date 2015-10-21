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


string get_conf_name( string c )
{
  Configuration cfg = roxen.find_configuration( c );
  return cfg->query_name();
}

string format_table_owner (mapping(string:string) mod_info, void|int skip_conf)
{
  // Note: Code duplication in browser.pike.

  if ((<0, "">)[mod_info->conf]) return 0;

  Configuration c = roxen.find_configuration( mod_info->conf );
  RoxenModule m = c && !(<0, "">)[mod_info->module] &&
    c->find_module( mod_info->module );
  ModuleInfo i =
    !(<0, "">)[mod_info->module] &&
    roxen.find_module( (mod_info->module/"#")[0] );
  string mn;

  if (!skip_conf) {
    if (c) {
      mn = "<a href='../sites/site.html/" +
	Roxen.http_encode_url (mod_info->conf) + "/'>" +
	Roxen.html_encode_string (c->query_name()) + "</a>";
    }
    else
      mn = Roxen.html_encode_string (
	sprintf ((string) _(542, "the deleted site %O"), mod_info->conf));
  }

  if( m ) {
    string module = "<a href='../sites/site.html/"+
      Roxen.http_encode_url(mod_info->conf)+"/n!n/"+
      replace(mod_info->module,"#","!")+"/"+
      "'>"+ Roxen.html_encode_string (i->get_name())+"</a>";
    if (mn)
      mn = sprintf ((string) _(543, "%s in %s"), module, mn);
    else
      mn = module;
  }
  else if( i ) {
    if (mn)
      mn = sprintf (
	(string) _(544, "the deleted module %s in %s"),
	Roxen.html_encode_string (sprintf ("%O", (string) i->get_name())),
	mn);
    else
      mn = sprintf (
	(string) _(545, "the deleted module %s"),
	Roxen.html_encode_string (sprintf ("%O", (string) i->get_name())));
  }

  return mn;
}

string|mapping parse( RequestID id )
{
  int view_mode;
  if ( !(CU_AUTH( "Edit Global Variables" )) )
    view_mode = 1;

  if( id->variables->db  && !view_mode )
  {
    if( id->variables->set_read )
      DBManager.set_permission( id->variables->db,
                                roxen.find_configuration(id->variables->set_read),
                                DBManager.READ );
    if( id->variables->set_write )
      DBManager.set_permission( id->variables->db,
                                roxen.find_configuration(id->variables->set_write),
                                DBManager.WRITE );
    if( id->variables->set_none )
      DBManager.set_permission( id->variables->db,
                                roxen.find_configuration(id->variables->set_none),
                                DBManager.NONE );
  }

  mapping(string:mapping(string:int)) q = DBManager.get_permission_map( );
  if( !sizeof( q ) )
    return _(549, "No defined databases.\n");
	
  string res = "<style type='text/css'>\n"
    "#tbl {"
    " font-size: smaller;"
    " text-align: left;"
    " empty-cells: show;"
    "}\n"
    "#tbl a {"
    " color: #0033aa;"
    " text-decoration: none;"
    "}\n"
    "#tbl a:hover {"
    " color: #0055ff;"
    " text-decoration: underline;"
    "}\n"
    "#tbl tr > * {"	// Cell defaults.
    " padding-left: 1em;"
    " border-bottom: 1px solid &usr.matrix22;;"
    "}\n"
    "#tbl tr > *:first-child {"
    " white-space: nowrap;" // No wrapping between the table icon and the name.
    " padding-left: 0;"
    "}\n"
    "#tbl .num {"
    " text-align: right;"
    " white-space: nowrap;"
    "}\n"
    "#tbl tr.group-hdr > * {"	// The cells in the database group name rows.
    " font-weight: bold;"
    " border-bottom-color: black;"
    "}\n"
    "#tbl tr.column-hdr > * {"	// The cells in the column header rows.
    " font-weight: bold;"
    " background-color: &usr.matrix12;;"
    "}\n"
    "</style>\n"
    "<table id='tbl' border='0' cellpadding='2' cellspacing='0'>\n";

  mapping(string:string) rres = ([]);
  foreach( DBManager.list_groups(), string g )
    rres[g]="";

  foreach( sort(indices(q)), string db )
  {
    string db_group = DBManager.db_group(db);
    string db_url = DBManager.db_url( db );

    string res =
      "<tr><td class='db'>" +
      (view_mode ? "" : "<a href='browser.pike?db="+db+"'>") +
      "<cimg style='vertical-align: -2px' border='0' format='gif'"
      " src='&usr.database-small;' alt='' max-height='12'/> " +
      db +
      (view_mode ? "" : "</a>") +
      "</td>";

    mapping(string:int) db_stats;
    if ( mixed e = catch {
	db_stats = DBManager.db_stats( db ) || ([]);
      } ) {
      string em = describe_error(e);
      sscanf( em, "%*sreconnect to SQL-server%s", em);
      rres[db_group] += res +
	"<td colspan='4'>" +
	(db_url ? Roxen.html_encode_string (db_url) + "<br />" : "") +
	"<font color='&usr.warncolor;'>" + em + "</font></td>"
	"</tr>\n";
      continue;
    }

    res += "<td class='num'>" +
      (zero_type (db_stats->tables) ? "" : (string) db_stats->tables) + "</td>"
      // "<td class='num'>" +
      // (zero_type (db_stats->rows) ? "" : (string) db_stats->rows) + "</td>"
      "<td class='num'>" +
      (zero_type (db_stats->size) ? "" :
       db_stats->size ?
       sprintf ("%.1f MiB", db_stats->size / (1024.0 * 1024.0)) :
       "empty") + "</td>";

    // Type column

    if( !db_url )
      res += "<td>internal</td>";
    else
    {
      if( mixed err = catch( DBManager.cached_get( db ) ) )
	res += "<td><font color='&usr.warncolor;'>" +
	  _(381,"Failed to connect") + ": " +
	  describe_error(err) + "</font></td>";
      else
	res += "<td>remote</td>";
    }

    // Backup schedule

    res += "<td>" + (DBManager.db_schedule(db) ||
		     ("<i>" + _(0, "NONE") + "</i>")) + "</td>";

    // Owner/info column

    mapping(string:string) db_mod_info = DBManager.module_table_info( db, "" );

    if (db == "local")
      res += "<td>" +
	_(546, "Internal data that cannot be shared between servers.") +
	"</td>";
    else if (db == "shared")
      res += "<td>" +
	_(547, "Internal data that may be shared between servers.") +
	"</td>";
    else if (db == "docs")
      res += "<td>" + _(1024, "Contains all documentation.") + "</td>";
    else if (!sizeof (db_mod_info))
      res += "<td>" + _(1025, "Unknown database") + "</td>";
    else if (string owner = format_table_owner (db_mod_info))
      res += "<td>" + String.capitalize (owner) + "</td>";
    else
      res += "<td>" +
	Roxen.html_encode_string (db_mod_info->comment || "") + "</td>";

    rres[db_group] += res + "</tr>\n";
  }

  array(array(string)) cats = ({});
  foreach( indices(rres), string c )
    if( c != "internal" )
      cats += ({ ({DBManager.get_group(c)->lname, c}) });
    else
      cats = ({ ({DBManager.get_group(c)->lname, c}) }) + cats;
	
  foreach( cats[0..0]+sort(cats[1..]); int i; array q ) {
    res += "<tbody>\n"
      "<tr class='group-hdr'><th colspan='6'>" + (i ? "<br/>" : "") +
      "<a style='font-size: larger'"
      " href='edit_group.pike?group=" + q[1] + "'>" + q[0] + "</a>"
      "</th></tr>\n"
      "<tr class='column-hdr'>"
      "<th>Name</th>"
      "<th class='num'>Tables</th>"
      // "<th class='num'>Rows</th>"
      "<th class='num'>Size</th>"
      "<th>Type</th>"
      "<th>Backup Schedule</th>"
      "<th>Owner/info</th>"
      "</tr>\n" +
      rres[ q[1] ] +
      "</tbody>\n";
  }

  return Roxen.http_string_answer(res+"</table>");
}
