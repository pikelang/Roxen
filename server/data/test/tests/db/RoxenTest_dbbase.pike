inherit "../pike_test_common.pike";

void run_tests( Configuration c )
{
  // This should _never_ fail
  Sql.Sql sql = test_true( connect_to_my_mysql, 0, "mysql" );

  if( !sql )
  {
    werror("  | *** Note: Failed to connect to mysql.\n" );
    werror("  | ***       ChiliMoon will not work\n" );
    return;
  }
  test(sql->query, "CREATE TABLE testtable (value VARCHAR(10) NOT NULL)" );

  string str1 = "\0\1\2\3\4\5\6\7\10\11";
  string str2 = "\xff\xfe\xf0\xa0\x7f\x20\xa0";

  test( sql->query, "INSERT INTO testtable (value) VALUES (%s)", str1 );
  test( sql->query, "INSERT INTO testtable (value) VALUES (%s)", str2 );

  array m;

  m = test( sql->query, "SELECT value FROM testtable WHERE value=%s", str1 );
  if( test_equal( 1, sizeof, m ) )
    test_equal( str1, pass, m->value[0] );
  
  m = test( sql->query, "SELECT value FROM testtable");

  if( !test_equal( ({ str1,str2 }), pass, m->value ) )
  {
    werror("  | *** Note: Mysql does not support binary data.\n" );
    werror("  | ***       ChiliMoon will not work\n" );
  }

  test( sql->query, "DROP TABLE testtable" );
}
