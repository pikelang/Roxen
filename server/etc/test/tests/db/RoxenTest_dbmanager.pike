inherit "../pike_test_common.pike";

array(int) run_tests( Configuration c )
{
  Configuration c1, c2;
  RoxenModule m;

  do_test( 0, roxen.enable_configuration, "dbtest1" );
  do_test( 0, roxen.enable_configuration, "dbtest2" );
  

  c1 = do_test( check_is_configuration,
		roxen.find_configuration,
		"dbtest1" );

  c2 = do_test( check_is_configuration,
		roxen.find_configuration,
		"dbtest2" );

  if( !c2 || !c1 )  {
    report_error( "Failed to find test configurations\n");
    return ({ current_test, tests_failed });
  }

  do_test( check_false, pass, DBManager.NONE );
  do_test( check_true,  pass, DBManager.READ );
  do_test( check_true,  pass, DBManager.WRITE );


  do_test( check_true, DBManager.list, c1 );
  do_test( check_true, DBManager.list );

  do_test( check_equal( ({}) ), DBManager.list, c1 );

  do_test( check_true,
	   DBManager.set_permission, "local", c1, DBManager.WRITE );
  do_test( check_true,
	   DBManager.set_permission, "local", c2, DBManager.WRITE );
  do_test( check_true,
	   DBManager.set_permission, "shared", c1, DBManager.WRITE );
  do_test( check_true,
	   DBManager.set_permission, "shared", c2, DBManager.WRITE );

  do_test( check_equal( DBManager.list(c2) ), DBManager.list, c1 );
  do_test( check_equal( DBManager.list() ), DBManager.list, c2 );
  

  do_test( check_true, DBManager.get_permission_map );
  do_test( check_true, DBManager.db_stats, "shared" );
  do_test( check_true, DBManager.db_stats, "local" );
  

  // NOTE: This assumes a clear setup when running the tests.
  do_test( check_true, DBManager.is_internal, "local" );
  do_test( check_true, DBManager.is_internal, "shared" );
  do_test( check_false,DBManager.db_url, "local" );
  do_test( check_false,DBManager.db_url, "shared" );
  

  Sql.Sql sql_rw = do_test( check_true, DBManager.get, "local" );
  Sql.Sql sql_ro = do_test( check_true, DBManager.get, "local", 0, 1 );

  do_test( check_error, sql_ro->query,
	   "CREATE table testtable (id INT PRIMARY KEY AUTO_INCREMENT,foo VARCHAR(20))" );
  do_test( 0, sql_rw->query,
	   "CREATE table testtable (id INT PRIMARY KEY AUTO_INCREMENT,foo VARCHAR(20))" );

  do_test( check_is( ({}) ), sql_ro->query, "SELECT * from testtable" );

  do_test( check_error, sql_ro->query,
	   "INSERT INTO testtable (foo) VALUES ('bar')" );
  
  do_test( 0, sql_rw->query,
	   "INSERT INTO testtable (foo) VALUES ('bar')" );

  array rows =   do_test( check_not_equal( ({}) ), sql_ro->query,
			  "SELECT * FROM  testtable WHERE foo='bar'" );
  if( sizeof( rows ) )
    do_test( check_is("bar"), predef::`[],  rows[0], "foo" );
  
  do_test( check_error, sql_ro->query,  "DROP TABLE testtable");
  do_test( 0, sql_rw->query,            "DROP TABLE testtable" );
  
  
  // Implicitly check the callback in the new/delete tests below.
  int db_changed;
  void inc_dbcc( ) {  db_changed++; };
  do_test( 0, DBManager.add_dblist_changed_callback, inc_dbcc );


  do_test( 0, DBManager.create_db, "testdb", 0, 1 );
  do_test( check_true,
	   DBManager.set_permission, "testdb", c1, DBManager.NONE );
  do_test( check_true,
	   DBManager.set_permission, "testdb", c2, DBManager.READ );


  do_test( check_false, DBManager.get, "testdb", c1 );
  sql_ro = do_test( check_true,  DBManager.get, "testdb", c2 );

  do_test( check_error, sql_ro->query,
	   "CREATE table testtable (id INT PRIMARY KEY AUTO_INCREMENT,foo VARCHAR(20))" );

  do_test( check_true, `==, db_changed, 1 );

  do_test( 0, DBManager.drop_db, "testdb", 0, 1 );

  do_test( check_true, `==, db_changed, 2 );
  
  do_test( check_false,DBManager.set_permission,
	   "testdb", c1, DBManager.NONE );




  int oc = db_changed;
  do_test( 0, DBManager.remove_dblist_changed_callback, inc_dbcc );
  do_test( 0, DBManager.create_db, "testdb", 0, 1 );
  do_test( check_error, DBManager.create_db, "testdb", 0, 1 );
  do_test( 0, DBManager.drop_db, "testdb", 0, 1 );
  do_test( check_error, DBManager.drop_db, "testdb", 0, 1 );
  do_test( check_true, `==, db_changed, oc );

  
  
  

  do_test( 0, roxen.disable_configuration, "dbtest1" );
  do_test( 0, roxen.disable_configuration, "dbtest2" );

  return ({ current_test, tests_failed });
}
