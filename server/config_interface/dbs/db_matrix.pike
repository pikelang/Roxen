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

  array(string) conf_cols = sort (roxen->configurations->name);

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
    "#tbl td, #tbl th {"	// Cell defaults.
    " white-space: nowrap;"
    " border-right: 1px solid &usr.matrix22;;"
    " border-bottom: 1px solid &usr.matrix22;;"
    "}\n"
    "#tbl .db {"		// The database name cells.
    " background-color: &usr.matrix12;;"
    "}\n"
    "#tbl tr.group-hdr > * {"	// The cells in the database group name rows.
    " font-weight: bold;"
    " vertical-align: bottom;"
    " border-bottom-color: black;"
    "}\n"
    "#tbl tr.group-hdr > .conf {" // The cells containing configuration names.
    " text-align: center;"
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

    string res =
      "<tr><td class='db'>" +
      (view_mode ? "" : "<a href='browser.pike?db="+db+"'>") +
      "<cimg style='vertical-align: -2px' border='0' format='gif'"
      " src='&usr.database-small;' alt='' max-height='12'/> " +
      db +
      (view_mode ? "" : "</a>") +
      "</td>";

    mapping(string:int) p = q[db];
    foreach( conf_cols, string conf )
    {
#define PERM(P,T,L)							\
	((view_mode ? "" :						\
	  "<a href='?set_"+L+"="+					\
	  Roxen.http_encode_url(conf)+"&db="+Roxen.http_encode_url(db)+"'>") \
	 + (p[conf] == DBManager.P ? T : "&#x2013;")			\
	 + (view_mode?"":"</a>"))
      res += "<td>" +
	PERM(NONE,_(431,"N"),"none") + " " +
	PERM(READ,_(432,"R"),"read") + " " +
	PERM(WRITE,_(433,"W"),"write") + "</td>";
    }

    rres[db_group] += res + "</tr>\n";
  }

  array(array(string)) cats = ({});
  foreach( indices(rres), string c )
    if( c != "internal" )
      cats += ({ ({DBManager.get_group(c)->lname, c}) });
    else
      cats = ({ ({DBManager.get_group(c)->lname, c}) }) + cats;

  if (sizeof (cats)) {
    res += "<thead>\n"
      "<tr class='group-hdr'><th><br/>"
      "<a style='font-size: larger'"
      " href='edit_group.pike?group=" + cats[0][1] + "'>" +
      cats[0][0] + "</a></th>";
    foreach( conf_cols, string conf )
    {
      res += "<th class='conf'>"
	"<gtext href='/sites/site.html/" + conf + "/' "
	"scale='0.35' fgcolor='black' bgcolor='&usr.matrix12;' rotate='90'>" +
	get_conf_name(conf) + "</gtext>"
	"</th>";
    }
    res += "</tr>\n</thead>\n" +
      "<tbody>\n" + rres[ cats[0][1] ] + "</tbody>\n";

    foreach( sort(cats[1..]), array q )
    {
      res += "<tbody>\n"
	"<tr class='group-hdr'><th><br/>"
	"<a style='font-size: larger'"
	" href='edit_group.pike?group=" + q[1] + "'>" + q[0] + "</a></th>" +
	("<td></td>" *
	 sizeof( roxen->configurations )) +
	"</tr>\n" +
	rres[ q[1] ] +
	"</tbody>\n";
    }
  }

  return Roxen.http_string_answer(res+"</table>");
}
