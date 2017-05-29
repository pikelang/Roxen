#include <config_interface.h>
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">_</locale-token>
#define _(X,Y)	_STR_LOCALE("roxen_config",X,Y)

mapping|string parse( RequestID id )
{
  string res = "";

  array(mapping) backups = DBManager.backups(0);
  mapping(string:array(mapping)) bks = ([]);
  foreach( backups, mapping m )
    if( !bks[m->db] )
      bks[m->db] = ({ m });
    else
      bks[m->db] += ({ m });

  if( !sizeof( bks ) )
  {
    res += _(79,"<p>No backups are currently available. To make a backup of a "
	     "database, focus on it in the Databases tab, and click on the "
	     "make backup button. Please note that you can only make backups "
	     "of databases managed by Roxen.</p>");
  }

  if( !id->variables->db)
  {
    if (!sizeof(bks)) {
      return "<div class='notify'>" + res + "</div>";
    }
    res += "<table class='nice'>\n"
      "<thead><tr><th colspan='2' align='left'>" + _(463, "Database") +
      "</th><th align='left'>"+_(405,"Directory")+
      "</th><th align='left'>"+_(459,"Date")+"</th></tr></thead>\n";
    foreach( sort( indices( bks ) ), string bk )
    {
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
      // Hide the Roxen-internal databases.
      if ((<"roxen", "mysql">)[bk]) continue;
#endif
      mapping done = ([ ]);
      res += "<tr><td colspan='4'><gtext scale='0.6'>" +
	Roxen.html_encode_string(bk) + "</gtext></td></tr>\n";

      foreach( bks[bk], mapping b )
      {
	if( !done[b->directory] )
	{
	  done[b->directory] = ({
	    b->whn, b->directory,
	    ({ b->tbl }),
	    "<a href='restore_db.pike?db="+Roxen.html_encode_string(bk)
	    +"&amp;dir="+Roxen.html_encode_string( b->directory )+
	    "&amp;&usr.set-wiz-id;'>"+
	    "<gbutton>"+_(460,"Restore")+"</gbutton></a> "
	    "<a href='restore_db.pike?db="+Roxen.html_encode_string(bk)+
	    "&amp;dir="+Roxen.html_encode_string( b->directory )+
	    "&amp;drop=1&amp;&usr.set-wiz-id;'>"+
	    "<gbutton>"+_(227,"Delete")+"</gbutton></a>"
	  });
	}
	else
	  done[b->directory][2] += ({ b->tbl });
      }

      foreach( sort( values( done ) ), array r )
      {
	res += "<tr>";
	res += "  <td>&nbsp;</td>\n";
	res += "  <td>"+r[3]+"</td>\n";
	res += "  <td>"+r[1]+"</td>\n";
	res += "  <td>"+isodate((int)r[0])+"</td>\n";
	res += "</tr>\n";
      }
    }
    res += "</table>\n";
  }
  else
  {
    if( id->variables->drop )
    {
      DBManager.delete_backup( id->variables->db, id->variables->dir );
      return Roxen.http_redirect("/dbs/backups.html", id );
    }
    else if( id->variables["ok.x"] )
    {
      array tables = ({});
      foreach( glob( "bk_tb_*", indices( id->variables )), string tb )
	tables += ({ tb[6..] });
      DBManager.restore( id->variables->db,
			 id->variables->dir,
			 id->variables->todb,
			 tables );
      return Roxen.http_redirect("/dbs/backups.html", id );
    }
    else
    {
      array possible = ({});
      foreach( bks[ id->variables->db ], mapping bk )
	if( bk->directory == id->variables->dir )
	  possible += ({ bk->tbl });

      res += "<gtext scale=0.5>"+
	_(461,"Restore the following tables from the backup")+
	"</gtext> <br />"
	"<input type=hidden name=db value='&form.db:http;' />"
	"<input type=hidden name=dir value='&form.dir:http;' />";

      res += "<blockquote><table>";
      int n;
      foreach( possible, string d )
      {
	if( n & 3 )
	  res += "</td><td>";
	else if( n )
	  res += "</td></tr><tr><td>\n";
	else
	  res += "<tr><td>";
	n++;
	res += "<input name='bk_tb_"+Roxen.html_encode_string(d)+
	  "' type=checkbox checked=checked />"+
	  d+"<br />";
      }
      res += "</td></tr></table>";

      res +=
	"</blockquote><gtext scale='0.5'>"+
	_(462,"Restore the tables to the following database")
	+"</gtext><blockquote>";

      res += "<select name='todb'>";
      foreach( sort(DBManager.list()), string db )
      {
	if( DBManager.is_internal( db ) )
	{
	  if( db == id->variables->db )
	    res += "<option selected=selected>"+db+"</option>";
	  else
	    res += "<option>"+db+"</option>";
	}
      }
      res += "</select>";

      res += "</blockquote><table width='100%'><tr><td>"
	"<submit-gbutton2 name='ok'>"+_(201,"OK")+"</submit-gbutton2></td>\n"
	"<td align=right><cf-cancel href='backups.html'/></td></tr>\n</table>\n";
    }
  }
  if( !id->variables->db )
    return Roxen.http_string_answer(res);
  return
    "<use file='/template'/><tmpl>"
    "<topmenu base='../' selected='dbs'/>"
    "<content><cv-split><subtablist width='100%'><st-tabs>"
    "<insert file='subtabs.pike'/></st-tabs><st-page>"
    "<input type=hidden name='sort' value='&form.sort:http;' />\n"
    "<input type=hidden name='db' value='&form.db:http;' />\n"
    +
    res
    +"</st-page></subtablist></cv-split></content></tmpl>";
}
