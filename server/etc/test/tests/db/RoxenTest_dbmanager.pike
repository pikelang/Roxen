inherit "../pike_test_common.pike";

#charset utf-8

int db_changed;
void inc_dbcc( ) { db_changed++; };

void run_tests( Configuration c )
{
  Configuration c1, c2;

  test( roxen.enable_configuration, "dbtest1" );
  test( roxen.enable_configuration, "dbtest2" );
  

  c1 = test_generic( check_is_configuration,
		     roxen.find_configuration,
		     "dbtest1" );

  c2 = test_generic( check_is_configuration,
		     roxen.get_configuration,
		     "dbtest2" );

  if( !c2 || !c1 )  {
    report_error( "Failed to find test configurations\n");
    return;
  }

  test_false( pass, DBManager.NONE );
  test_true(  pass, DBManager.READ );
  test_true(  pass, DBManager.WRITE );


  test_true( DBManager.list, c1 );
  test_true( DBManager.list );

  test_equal( ({}), DBManager.list, c1 );

  test_true( DBManager.set_permission, "local", c1, DBManager.WRITE );
  test_true( DBManager.set_permission, "local", c2, DBManager.WRITE );

  test_equal( DBManager.list(c2), DBManager.list, c1 );
  test_equal( DBManager.list(c1), DBManager.list, c2 );
  

  test_true( DBManager.get_permission_map );
  test_true( DBManager.db_stats, "local" );
  

  // NOTE: This assumes a clear setup when running the tests.
  test_true(  DBManager.is_internal, "local" );
  test_false( DBManager.db_url, "local" );
  

  // Resort to broken-unicode for now due to the mysql lib dependency. :(
#if 0
  Sql.Sql sql_rw = test_true( DBManager.get, "local", 0, 0, 0, "unicode" );
  Sql.Sql sql_ro = test_true( DBManager.get, "local", 0, 1, 0, "unicode" );
#else
  Sql.Sql sql_rw = test_true( DBManager.get, "local", 0, 0, 0, "broken-unicode" );
  Sql.Sql sql_ro = test_true( DBManager.get, "local", 0, 1, 0, "broken-unicode" );
#endif

#define CR "CREATE table testtable (id INT PRIMARY KEY AUTO_INCREMENT,foo VARCHAR(20),bin VARBINARY(20)) CHARSET utf8"
  test_error( sql_ro->query, CR);
  test( sql_rw->query, CR );

  test_equal( ({}), sql_ro->query, "SELECT * from testtable" );

  test_error( sql_ro->query,
	      "INSERT INTO testtable (foo, bin) VALUES ('bar', 'x')" );
  
  test( sql_rw->query,
	"INSERT INTO testtable (foo, bin) VALUES ('åäö', 'åäö')" );
  test( sql_rw->query,
	"INSERT INTO testtable (foo, bin) VALUES ('åäö€uro', 'åäö€uro')" );

  array rows = test_not_equal( ({}),
			       sql_ro->query,
			       "SELECT * FROM  testtable WHERE foo='åäö'" );
  test_true( `==, "åäö", rows[0]["foo"] );
  test_true( `==, string_to_utf8 ("åäö"), rows[0]["bin"] );

  rows = test_not_equal( ({}),
			 sql_ro->query,
			 "SELECT * FROM  testtable WHERE foo='åäö€uro'" );
  test_true( `==, "åäö€uro", rows[0]["foo"] );
  test_true( `==, string_to_utf8 ("åäö€uro"), rows[0]["bin"] );

  test_error( sql_ro->query,  "DROP TABLE testtable");
  test( sql_rw->query,            "DROP TABLE testtable" );
  
  
  // Implicitly check the callback in the new/delete tests below.
  test( DBManager.add_dblist_changed_callback, inc_dbcc );


  test( DBManager.create_db, "testdb", 0, 1 );
  test_true( DBManager.set_permission, "testdb", c1, DBManager.NONE );
  test_true( DBManager.set_permission, "testdb", c2, DBManager.READ );

  test_false( DBManager.get, "testdb", c1 );
  sql_ro = test_true( DBManager.get, "testdb", c2 );

  test_error( sql_ro->query, CR );

  test_true( `==, db_changed, 1 );

  test( DBManager.drop_db, "testdb", 0, 1 );

  test_true( `==, db_changed, 2 );
  
  test_false( DBManager.set_permission, "testdb", c1, DBManager.NONE );

  int oc = db_changed;
  test( DBManager.remove_dblist_changed_callback, inc_dbcc );
  test( DBManager.create_db, "testdb", 0, 1 );
  test_error( DBManager.create_db, "testdb", 0, 1 );
  test( DBManager.drop_db, "testdb", 0, 1 );
  test_error( DBManager.drop_db, "testdb", 0, 1 );
  test_true( `==, db_changed, oc );

  

  test( roxen.disable_configuration, "dbtest1" );
  test( roxen.disable_configuration, "dbtest2" );
}
