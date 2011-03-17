#include <config_interface.h>
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">_</locale-token>
#define _(X,Y)	_STR_LOCALE("roxen_config",X,Y)

mapping|string parse( RequestID id )
{
  string res =
    "<use file='/template'/><tmpl>"
    "<topmenu base='../' selected='dbs'/>"
    "<content><cv-split><subtablist width='100%'><st-tabs>"
    "</st-tabs><st-page><blockquote><br />"
    "<input type=hidden name='group' value='&form.group:http;' />\n";

  mapping c = DBManager.get_group( id->variables->group );

  if( id->variables["ok.x"]  )
  {
    foreach( glob( "db_*", indices(id->variables) ), string db )
    {
      DBManager.create_db( db[3..],0,1,id->variables->group );
      foreach( roxen->configurations, Configuration c )
	DBManager.set_permission( db[3..], c, DBManager.READ );
      DBManager.set_permission( db[3..], id->conf, DBManager.WRITE );
    }
    return Roxen.http_redirect( "/dbs/", id );
  }

  
  Sql.Sql sql = Sql.Sql( c->pattern );
  array q = sql->query( "SHOW databases" )->Database;

  res += "<b><font size=+1>"+
    _(435,"When the group is created, the checked databases will "
      "be imported as well")+"</b></font>";
  
  res += "<table>";
  
  int n;
  foreach( sort( q ) - DBManager.list() - ({ "roxen", "mysql" }),string d )
  {
    if( n & 3 )
      res += "</td><td>";
    else if( n )
      res += "</td></tr><tr><td>\n";
    else
      res += "<tr><td>";
    n++;
    res += "<input name='db_"+d+"' type=checkbox />"+ d;
  }
  res += "</table>";


  return res+"<cf-ok /></blockquote></st-page></content></tmpl>";
}
