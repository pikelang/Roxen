#define q(X) Roxen.html_encode_string(X)

string parse( RequestID id )
{
  string res = "";
  Sql.Sql sql = connect_to_my_mysql( 0, "mysql" );

  res += "<table>";
  res += "<tr><td valign=right><b>Version:</b></td><td align=right>"+q(sql->query( "select VERSION() as v" )[0]->v)+"</td></tr>\n";
  res += "<tr><td><b>Protocol Version:</b></td><td align=right>"+
      sql->master_sql->protocol_info()+"</td></tr>\n";

  string st = sql->master_sql->statistics();
  string n;
  float i;

  while( sscanf( st, "%*[ ]%[^:]: %f%s", n,i,st ) == 4 )
  {
    res += "<tr><td><b>"+n+":</b></td><td align=right>";
    if( n == "Uptime" )
      res += Roxen.msectos((int)(i*1000));
    else
    {
      if( i < 4.0 && ((float)((int)i) != i) )
        res += sprintf("%.1f",i);
      else
        res += (int)i;
    }
    res += "</td></tr>\n";
  }
//   res += "<tr><td><b>Connection:</b></td><td>"+
//       sql->master_sql->host_info()+"</td></tr>\n";
  
  return res+"</table>";
}
