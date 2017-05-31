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

  res += "<table class='nice no-th auto'>";
  res += "<tr><td><b>Version:</b></td><td class='text-right'>"+q(sql->query( "select VERSION() as v" )[0]->v)+"</td></tr>\n";
  res += "<tr><td><b>Protocol Version:</b></td><td class='text-right'>"+
      sql->master_sql->protocol_info()+"</td></tr>\n";

  string st = sql->master_sql->statistics();
  string n;
  float i;

  while( sscanf( st, "%*[ ]%[^:]: %f%s", n,i,st ) == 4 )
  {
    res += "<tr><td><b>"+n+":</b></td><td class='text-right'>";
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

  res += "</table>";
  mapping connections = roxenloader->sql_active_list+([]);

  res += "<h2 class='section'>Active connections</h2>";

  res +=
    "<table class='nice auto'>"
    "<thead><tr><th>"+_(463,"Database")+"</th><th>"+
    _(206,"User")+"</th><th>"+_(464,"Connections")+
    "</th></tr></thead>\n";

  int total;
  foreach( sort(indices( connections ) ), string c )
  {
    if (connections[c]) {
      array(string) t = c/":";
      res += "<tr><td>"+Roxen.html_encode_string(replace(t[0],";",":"))+"</td><td>"+
	Roxen.html_encode_string(t[1])+"</td><td align=right>"+
	connections[c]+"</td></tr>\n";
      total += connections[c];
    }
  }
  res += "<tfoot><tr><td colspan='3' class='num'>Total: "+total+"</td></tr></tfoot>";
  res += "</table>";

  // Inactive connections.
  connections = roxenloader->get_sql_free_list_status();

  res += "<h2 class='section'>Inactive connections</h2>";

  res +=
    "<table class='nice auto'>"
    "<thead><tr><th>"+_(463,"Database")+"</th><th>"+
    _(206,"User")+"</th><th>"+_(464,"Connections")+
    "</th></tr></thead>\n";

  total = 0;
  foreach( sort(indices( connections ) ), string c )
  {
    array(string) t = c/":";
    res += "<tr><td>"+Roxen.html_encode_string(replace(t[0],";",":"))+"</td><td>"+
      Roxen.html_encode_string(t[1])+"</td><td align=right>"+
      connections[c]+"</td></tr>\n";
    total += connections[c];
  }
  res += "<tfoot><tr><td colspan='3' class='num'>Total: "+total+"</td></tr></tfoot>";
  res += "</table>";

#ifdef DB_DEBUG
  res += sprintf("<h2>Live connections</h2>"
		 "<pre>\n"
		 "%{%s\n\n\n%}"
		 "</pre>\n",
		 values(roxenloader->my_mysql_last_user));
#endif /* DB_DEBUG */

  return res;
}
