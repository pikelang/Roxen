string get_conf_name( string c )
{
  Configuration cfg = roxen.find_configuration( c );
  return cfg->query_name();
}

string parse( RequestID id )
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


  mapping q = DBManager.get_permission_map( );
  if( !sizeof( q ) )
    return "No defined datbases\n";
  string res = "<table>\n";
#if 0
  int i = 1;
  int tc = sizeof( roxen->configurations )+2;
  foreach( sort(roxen->configurations->name), string conf )
  {
    res += "<tr><td colspan='"+(i)+"'></td>";
    res += "<td colspan='"+(tc-i)+"'><gtext scale='0.4'>"+
        get_conf_name(conf)+"</gtext></td>";
    res += "</tr>\n";
    i++;
  }
#else
  res += "<tr><td></td>";
  foreach( sort(roxen->configurations->name), string conf )
  {
    res += "<td valign=bottom><gtext scale='0.4' rotate='90'>"+
        get_conf_name(conf)+"</gtext></td>";
  }
  res += "</tr>\n";
#endif
  
  foreach( sort(indices(q)), string db )
  {
    mapping p = q[db];
    res += "<tr><td><b><gtext scale='0.4'>"+db+"</gtext></b></td>";
    foreach( sort(roxen->configurations->name), string conf )
    {
      switch( p[conf] )
      {
       case DBManager.NONE:
         res += sprintf("<td bgcolor='&usr.fade1;'>"
                        "<a href='dbs.html?set_read=%s&db=%s'>"
                        "<gtext "
                        "        scale='0.5' verbatim=''>&nbsp; - </gtext>"
                        "</a>"
                        "</td>",
                        Roxen.http_encode_string(conf),
                        Roxen.http_encode_string(db));
         break;
       case DBManager.READ:
         res += sprintf("<td bgcolor='&usr.bgcolor;'>"
                        "<a href='dbs.html?set_write=%s&db=%s'>"
                        "<gtext  scale=0.5>R</gtext>"
                        "</a>"
                        "</td>",
                        Roxen.http_encode_string(conf),
                        Roxen.http_encode_string(db));
         break;
       case DBManager.WRITE:
         res += sprintf("<td bgcolor='&usr.warncolor;'>"
                        "<a href='dbs.html?set_none=%s&db=%s'>"
                        "<gtext fgcolor='&usr.bgcolor;' scale=0.5>W</gtext>"
                        "</a>"
                        "</td>",
                        Roxen.http_encode_string(conf),
                        Roxen.http_encode_string(db));
         break;
      }
    }
    res += "<td  width='100%'> </td>";
    res += "</tr>\n";
  }
  return res+"</table>";
}
