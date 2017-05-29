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

  string res =
    "<table id='tbl' class='matrix'>\n";

  mapping(string:string) rres = ([]);
  foreach( DBManager.list_groups(), string g )
    rres[g]="";

  foreach( sort(indices(q)), string db )
  {
    string db_group = DBManager.db_group(db);

    string res =
      "<tr><td class='db'>" +
      (view_mode ?
        "" :
        "<a href='browser.pike?db="+db+"&amp;&usr.set-wiz-id;'"
        " class='icon db no-decoration'>") +
      db +
      (view_mode ? "" : "</a>") +
      "</td>";

    mapping(string:int) p = q[db];
    foreach( conf_cols, string conf )
    {
#define PERM(P,T,L)							\
	((view_mode ? "" :						\
	  "<a href='?set_"+L+"="+					\
	  Roxen.http_encode_url(conf)+"&amp;db="+Roxen.http_encode_url(db)+\
	  "&amp;&usr.set-wiz-id;'>")					\
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
      "<tr class='group-hdr'><th>"
      "<a"
      " href='edit_group.pike?group=" + cats[0][1] + "&amp;&usr.set-wiz-id;'>" +
      cats[0][0] + "</a></th>";
    foreach( conf_cols, string conf )
    {
      res += "<th class='conf'>"
        "<a href='/sites/site.html/" + conf + "/'>" +
	get_conf_name(conf) + "</a>"
	"</th>";
    }
    res += "</tr>\n</thead>\n" +
      "<tbody>\n" + rres[ cats[0][1] ] + "</tbody>\n";

    foreach( sort(cats[1..]), array q )
    {
      res += "<tbody>\n"
	"<tr class='group-hdr'><th>"
	"<a"
	" href='edit_group.pike?group=" + q[1] + "&amp;&usr.set-wiz-id;'>" +
	q[0] + "</a></th>" +
	("<td></td>" *
	 sizeof( roxen->configurations )) +
	"</tr>\n" +
	rres[ q[1] ] +
	"</tbody>\n";
    }
  }

  return Roxen.http_string_answer(res+"</table>");
}
