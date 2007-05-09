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

  mapping q = DBManager.get_permission_map( );
  if( !sizeof( q ) )
    return "No defined databases\n";
  
  string res = "<style type='text/css'>\n"
    ".df_table_c {"
    " vertical-align: bottom;"
    " text-align: center;"
    " font-size: 8pt;"
    " background-color: &usr.matrix12;;"
    " padding: 2px;"
    " border-top: 1px solid &usr.matrix11;;"
    " border-left: 1px solid &usr.matrix11;;"
    " border-right: 1px solid &usr.matrix21;;"
    " border-bottom: 1px solid black;"
    "}\n"
    ".df_table_d {"
    " font-size: 8pt;"
    " background-color: &usr.matrix12;;"
    " padding: 2px;"
    " border-top: 1px solid &usr.matrix11;;"
    " border-left: 1px solid &usr.matrix11;;"
    " border-right: 1px solid &usr.matrix21;;"
    " border-bottom: 1px solid &usr.matrix21;;"
    "}\n"
    ".df_table_r {"
    " font-size: 8pt;"
    " padding: 1px;"
    " border-bottom: 1px solid &usr.matrix22;;"
    " border-right: 1px solid &usr.matrix22;;"
    "}\n"
    ".df_table_s {"
    " font-size: 8pt;"
    " padding: 1px;"
    " padding-left: 12px;"
    " border-bottom: 1px solid &usr.matrix22;;"
    "}\n"
    ".df_table_g1 {"
    " vertical-align: bottom;"
    " font-size: 12pt;"
    " padding: 1px;"
    " border-bottom: 1px solid black;"
    "}\n"
    ".df_table_g2 {"
    " font-size: 12pt;"
    " padding: 1px;"
    " padding-top: 16px;"
    " border-bottom: 1px solid black;"
    " border-right: 1px solid &usr.matrix22;;"
    "}\n"
    ".df_table_gr {"
    " padding: 1px;"
    " border-bottom: 1px solid black;"
    " border-right: 1px solid &usr.matrix22;;"
    "}\n"
    ".df_table_gs {"
    " padding: 1px;"
    " padding-left: 12px;"
    " border-bottom: 1px solid black;"
    "}\n"
    "a.dblink {"
    " color: #0033aa;"
    " text-decoration: none;"
    "}\n"
    "a.dblink:hover {"
    " color: #0055ff;"
    " text-decoration: underline;"
    "}\n"
    "</style>\n"
    "<br /><table border='0' cellpadding='2' cellspacing='0'>\n";

  mapping rres = ([]);
  foreach( DBManager.list_groups(), string g )
    rres[g]="";
  
  foreach( sort(indices(q)), string db )
  {
    string db_group = DBManager.db_group(db);
    int ii = DBManager.is_internal( db );
		
    mapping p = q[db];
    if( !rres[ db_group ] )
    {
      rres[ db_group ]="";
    }
	    
    rres[db_group] +=
      "<tr><td class='df_table_d'>" +
      (view_mode ? "" : "<a class='dblink' href='browser.pike?db="+db+"'>") +
      "<cimg border='0' format='gif'"
      " src='&usr.database-small;' alt='' max-height='12'/>"
      "&nbsp;" + db +
      (view_mode ? "" : "</a>") +
      "</td>";
    foreach( sort(roxen->configurations->name), string conf )
    {
      rres[db_group] += "<td class='df_table_r'>";
	
			
#define PERM(P,T,L)							\
      rres[db_group] +=							\
	(view_mode ? "" :						\
	 "<a class='dblink' href='?set_"+L+"="+				\
	 Roxen.http_encode_url(conf)+"&db="+Roxen.http_encode_url(db)+"'>") \
	+ (p[conf] == DBManager.P ? T : "&#x2013;")				\
	+ (view_mode?"":"</a>")
	
      PERM(NONE,_(431,"N"),"none");
      rres[db_group] += "&nbsp;";
      PERM(READ,_(432,"R"),"read");
      rres[db_group] += "&nbsp;";
      PERM(WRITE,_(433,"W"),"write");
      rres[db_group] += "</td>";
    }
    string format_stats( mapping s, string url )
    {
      if( !url )
        url = "internal";
      else
      {
	mixed err;
	if( err = catch( DBManager.cached_get( db ) ) )
	  url="<font color='&usr.warncolor;'>"+
	    _(381,"Failed to connect")+": "+
	    describe_error(err)+"</font>";
	else
	  url = "remote";
      }
      if( !s )
        return url;
      return sprintf( "%s %.1fMb", url, s->size/1024.0/1024.0 );
    };

    array e;
    if( mixed e = catch {
	rres[db_group] += "<td class='df_table_s'>"+
	  format_stats( DBManager.db_stats( db ),
			DBManager.db_url( db ) )+"</td>";
      } )
    {
      string em = describe_error(e);
      sscanf( em, "%*sreconnect to SQL-server%s", em);
      rres[db_group] +=
	"<td class='df_table_s'>" + DBManager.db_url( db ) + "<br />"
	"<font color='&usr.warncolor;'>" + em + "</font></td>";
    }
    rres[db_group] += "</tr>\n";
  }

  array cats = ({});
  foreach( indices(rres), string c )
    if( c != "internal" )
      cats += ({ ({DBManager.get_group(c)->lname, c}) });
    else
      cats = ({ ({DBManager.get_group(c)->lname, c}) }) + cats;

  if (sizeof (cats)) {
    res += "<tr><td class='df_table_g1'><a class='dblink' href='edit_group.pike?group=" + cats[0][1] + "'>" + cats[0][0] + "</a></td>";
    foreach( sort(roxen->configurations->name), string conf )
    {
      res += "<td class='df_table_c'><gtext href='/sites/site.html/" + conf + "/' scale='0.35' fgcolor='black' bgcolor='&usr.matrix12;' rotate='90'>" + get_conf_name(conf) + "</gtext></td>";
    }
    res += "<td class='df_table_gs'>&nbsp;</td></tr>\n" +
      rres[ cats[0][1] ];
  }

  foreach( sort(cats[1..]), array q )
  {
    if (q[1] != "internal") {
      res += "<tr><td class='df_table_g2'><a class='dblink' href='edit_group.pike?group=" + q[1] + "'>" + q[0] + "</a></td>" +
	("<td class='df_table_gr'>&nbsp;</td>" * sizeof( roxen->configurations )) +
	"<td class='df_table_gs'>&nbsp;</td></tr>\n";
    }
    res += rres[ q[1] ];
  }
  return Roxen.http_string_answer(res+"</table>");
}
