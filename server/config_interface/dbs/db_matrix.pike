#include <config_interface.h>
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">_</locale-token>
#define _(X,Y)	_STR_LOCALE("roxen_config",X,Y)



string get_conf_name( string c )
{
  Configuration cfg = roxen.find_configuration( c );
  return cfg->query_name();
}

string parse( RequestID id )
{
  if( id->variables->db )
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

  array colors = ({
    ({
      "&usr.matrix11;",
      "&usr.matrix21;",
    }),
    ({
      "&usr.matrix12;",
      "&usr.matrix22;",
    }),
  });
  
  mapping q = DBManager.get_permission_map( );
  if( !sizeof( q ) )
    return "No defined datbases\n";
  string res = "<br /><table width='80%' border='0' cellpadding='2' cellspacing='0'>\n";
  int x, y;
  int i = 1;
  int tc = sizeof( roxen->configurations )+2;
  if( tc < 8 )
  {
    foreach( sort(roxen->configurations->name), string conf )
    {
      res += "<tr>";
      for( int j = 0; j<i; j++ )
      {
        if( j )
        {
          string ct = colors[0][j%sizeof(colors)];
          res += "<td bgcolor='"+ct+"'>&nbsp;</td>";
        }
        else
          res += "<td></td>";
      }
      string ct = colors[0][i%sizeof(colors)];
      res += "<td bgcolor='"+ct+"' colspan='"+(tc-i)+"'><gtext scale='0.4'>    "+
          get_conf_name(conf)+"</gtext></td>";
      res += "</tr>\n";
      i++;
    }
    res += "<tr>";
    for( int j = 0; j<i; j++ )
    {
      if( j )
      {
        string ct = colors[0][j%sizeof(colors)];
        res += "<td bgcolor='"+ct+"'>"
            "<img src='/internal-roxen-unit' alt='' width='1' height='5' /></td>";
      }
      else
        res += "<td></td>";
    }
    res += "</tr>";
  }
  else
  {
    res += "<tr><td></td>";
    foreach( sort(roxen->configurations->name), string conf )
    {
      x++;
      string ct = colors[0][x%sizeof(colors)];
      res += "<td bgcolor='"+ct+"'valign=bottom><gtext scale='0.4' bgcolor='"+ct+"' rotate='90'>"+
          get_conf_name(conf)+"</gtext></td>";
    }
    res += "</tr>\n";
  }


  foreach( sort(indices(q)), string db )
  {
    mapping p = q[db];
    y++;
    x=0;
    string ct = colors[y%sizeof(colors)][0];
    int ii = DBManager.is_internal( db );
    res +=
        "<tr><td bgcolor='"+ct+"'>"
        "<nobr>"
        +"<a href='browser.pike?db="+db+"'>"+
        "<cimg border='0' format='gif'"
        "      src='&usr.database-small;' alt='' max-height='12'/>"
        "  <gtext border='0' scale='0.4'>"+db+"</gtext> &nbsp;"
        +"</a>"+
        "</nobr>"
        "</td>";
    foreach( sort(roxen->configurations->name), string conf )
    {
      x++;
      string col = colors[y%sizeof(colors)][x%sizeof(colors[0])];
      switch( p[conf] )
      {
       case DBManager.NONE:
         res += sprintf("<td bgcolor='"+col+"'>"
                        "<a href='dbs.html?set_read=%s&db=%s'>"
                        "<gtext "
                        "        scale='0.5' verbatim=''>&nbsp; - </gtext>"
                        "</a>"
                        "</td>",
                        Roxen.http_encode_string(conf),
                        Roxen.http_encode_string(db));
         break;
       case DBManager.READ:
         res += sprintf("<td bgcolor='"+col+"'>"
                        "<a href='dbs.html?set_write=%s&db=%s'>"
                        "<gtext  scale=0.5>R</gtext>"
                        "</a>"
                        "</td>",
                        Roxen.http_encode_string(conf),
                        Roxen.http_encode_string(db));
         break;
       case DBManager.WRITE:
         res += sprintf("<td bgcolor='"+col+"'>"
                        "<a href='dbs.html?set_none=%s&db=%s'>"
                        "<gtext fgcolor='&usr.warncolor;' scale=0.5>W</gtext>"
                        "</a>"
                        "</td>",
                        Roxen.http_encode_string(conf),
                        Roxen.http_encode_string(db));
         break;
      }
    }

    string format_stats( mapping s, string url )
    {
      if( !url )
        url = "internal";
      else
      {
	if( catch( DBManager.get( db )->query("select 1") ) )
	  url="<font color='&usr.warncolor;'>"+
	    _(381,"Failed to connect")+"</font>";
	else
	  url = "remote";
      }
      if( !s )
        return url;
      return sprintf( "%s %.1fMb", url, s->size/1024.0/1024.0 );
    };

#if 1
    res += "<td align=right width='100%' >"+
             format_stats( DBManager.db_stats( db ),
                           DBManager.db_url( db ) )+"</td>";
#else
    res += "<td width='100%'>&nbsp;</td>";
#endif
    res += "</tr>\n";
  }
  return res+"</table>";
}
