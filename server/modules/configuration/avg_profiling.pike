inherit "module.pike";

constant module_name = "Average Profiling";
constant module_doc = "Access the average profiling information";

class DatabaseVar
{
  inherit Variable.StringChoice;
  array get_choice_list( )
  {
    return sort(DBManager.list( my_configuration() ));
  }
}

void create()
{
  defvar( "db",
          DatabaseVar( "local",({}),0, "Database", "The database" ));
}

void dump_iter( function cb )
{
  foreach( roxen->configurations - ({ this_object() }),
	   Configuration c )
  {
    mapping p;
    if( (p=c->profiling_info) )
      foreach( indices( p ), string f )
      {
	mapping i = p[f]->data;
	foreach( indices( i ), string e )
	  cb( c, f, e, @i[e] );
      }
  }    
}

void dump_to_db( )
{
  Sql.Sql sql = DBManager.get( query( "db" ) );

  catch {
    sql->query( "CREATE TABLE average_profiling ( "
		"           session INT,"
		"           calls   INT,"
		"           real_ns INT,"
		"           cpu_ns  INT,"
		"           config  VARCHAR(30),"
		"           file    VARCHAR(100),"
		"           event   VARCHAR(100) )" );
  };
  
  array q = sql->query( "SELECT MAX(session) as m FROM average_profiling" );

  int session;

  if( sizeof( q ) )
    session = q[0]->m+1;
  else
    session = 0;
  
  void dump_row( Configuration c, string file, string event,
		 int realtime, int cputime, int calls )
  {
    sql->query( "INSERT INTO average_profiling VALUES (%d,%d,%d,%d,%s,%s,%s)",
		session, calls, realtime, cputime, c->query_name(), file, event );
    
  };


  dump_iter( dump_row );
}

void flush()
{
  foreach( roxen->configurations, object c )
    c->profiling_info = ([]);
}


void clear_db()
{
  Sql.Sql sql = DBManager.get( query( "db" ) );
  catch {
    sql->query( "DELETE FROM average_profiling" );
  };
}


mapping(string:function) query_action_buttons()
{
  return ([
    "Clear profiling information":flush,
    "Dump to database":dump_to_db,
    "Clear database":clear_db,
  ]);
}

