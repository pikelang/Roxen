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
      "<thead><tr>"
        "<th colspan='2'>" + _(463, "Database") + "</th>"
        "<th>" + _(405,"Directory") + "</th>"
        "<th>&nbsp;</th>"
        "<th>" + _(459,"Date")      + "</th>"
      "</tr></thead>\n";

    foreach( sort( indices( bks ) ), string bk )
    {
      string extra = "";
      // Hide the Roxen-internal databases.
      if ((<"roxen", "mysql">)[bk]) {
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
	continue;
#else
	extra = " " + _(0, "(Roxen-internal database)");
#endif
      }
      mapping done = ([ ]);
      res += "<tr class='column-hdr'><td colspan='5'>" +
	Roxen.html_encode_string(bk + extra) + "</td></tr>\n";

      foreach( bks[bk], mapping b )
      {
	if( !done[b->directory] )
	{
	  done[b->directory] = ({
	    (int)b->whn, b->directory,
	    ({ b->tbl }),
	    "<link-gbutton href='restore_db.pike?db="+Roxen.html_encode_string(bk)
	    +"&amp;dir="+Roxen.html_encode_string( b->directory )+
	    "&amp;&usr.set-wiz-id;' type='reset'>"+
	    ""+_(460,"Restore")+"</link-gbutton> "
	    "<link-gbutton href='restore_db.pike?db="+Roxen.html_encode_string(bk)+
	    "&amp;dir="+Roxen.html_encode_string( b->directory )+
	    "&amp;drop=1&amp;&usr.set-wiz-id;' type='delete'>"+
	    ""+_(227,"Delete")+"</link-gbutton>"
	  });
	}
	else
	  done[b->directory][2] += ({ b->tbl });
      }

      foreach(sort(indices(done)), string dir)
      {
	[int when, string d, array(string) tables, string buttons] = done[dir];
	res += "<tr>";
	res += "  <td>&nbsp;</td>\n";
	res += "  <td class='nowrap'>" + buttons + "</td>\n";
	res += "  <td><tt>" + d + "</tt></td>";
	if (has_value(tables, "")) {
	  // In progress marker.
	  res += "<td class='flag'><em>" + _(0, "Incomplete") + "<em></td>";
	} else {
	  res += "<td>&nbsp;</td>\n";
	}
	res += "  <td>" + isodate(when) + "</td>\n";
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
	if( bk->directory == id->variables->dir && sizeof(bk->tbl) )
	  possible += ({ bk->tbl });

      res += "<h3>"+
	_(461,"Restore the following tables from the backup")+
	"</h3>"
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
	"</blockquote><h3>"+
	_(462,"Restore the tables to the following database")
	+"</h3><blockquote>";

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

      res += "</blockquote><hr class='section'>"
	"<submit-gbutton2 name='ok' type='ok'>"+_(201,"OK")+"</submit-gbutton2> "
	"<cf-cancel href='backups.html'/>\n";
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
