#include <config_interface.h>
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">_</locale-token>
#define _(X,Y)	_STR_LOCALE("roxen_config",X,Y)


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
  
  res += "</table>";
  mapping connections = ([]);
#ifdef THREADS
  foreach( indices( roxenloader->my_mysql_cache ),  object t )
    foreach( indices( roxenloader->my_mysql_cache[t] ), string name )
#else
    foreach( indices( roxenloader->my_mysql_cache ), string name )
#endif
      connections[name]++;

#ifdef THREADS
  foreach( indices( DBManager->sql_cache ), object t )
    foreach( indices( DBManager->sql_cache[t] ), string name )
#else
    foreach( indices( DBManager->sql_cache ), string name )
#endif
      connections[replace(name,":",";")+":rw"]++;

#ifdef THREADS
  foreach( indices( DBManager->dead_sql_cache ), object t )
    foreach( indices( DBManager->dead_sql_cache[t] ), string name )
#else
    foreach( indices( DBManager->dead_sql_cache ), string name )
#endif
      connections[replace(name,":",";")+":rw"]++;

  res += "<h2>Active connections</h2>";
  
  res +=
    "<table>"
    "<tr><td><b>"+_(463,"Database")+"</b></td><td><b>"+
    _(206,"User")+"</b></td><td><b>"+_(464,"Connections")+
    "</b></td></tr>\n";

  int total;
  foreach( sort(indices( connections ) ), string c )
  {
    array(string) t = c/":";
    res += "<tr><td>"+Roxen.html_encode_string(replace(t[0],";",":"))+"</td><td>"+
      Roxen.html_encode_string(t[1])+"</td><td align=right>"+
      connections[c]+"</td></tr>\n";
    total += connections[c];
  }
  res += "<tr><td></td><td></td><td align=right>"+total+"</td></tr>";
  res += "</table>";

  return res;
}
