inherit "pike_test_common.pike";

void verify_logged_data( array logged, int min )
{
  if( sizeof( logged ) != 18 )
    throw( sprintf("Got the log-array size, expected 18, got %d\n",
		   sizeof(logged)));
  
  if( "194.52.182.122" != logged[0] )
    throw( sprintf("Illegal IP field, expected 194.52.182.122, got %O\n",
		   logged[0] ) );
  if( sprintf( "%c%c%c%c", 194,52,182,122 ) != logged[1] )
    throw( sprintf( "Illegal bin-ip field, expected "
		    "\d194\d52\d182\d122, got %O\n", logged[1] ) );

  // logged[2] is cern data. Should probably verify that as well...

  int t;
  sscanf( logged[3], "%4c", t );
  if( (time()-t) > 10  )
    throw( sprintf( "Did not get the expected time in bin-date\n") );
  
  if( logged[4] != "GET" )
    throw( sprintf( "Did not get the expected method, got %O expected %O\n",
		    logged[4], "GET" ) );

  if( min )
  {
    if( logged[5] != "/the/requested/file" )
      throw(sprintf( "Got the wrong URL, got %O\n", logged[5] ));
  }
  else
    if( logged[5] != "/the/requested/file?foo%20bar=hi%20there" )
      throw( "Got the wrong URL\n" );

  if( logged[6] != logged[5] )
    throw( "Full resource differes from resource\n" );
  
  if( logged[7] != "INTERNAL/1.0" )
    throw( sprintf("The protocol is wrong, expected INTERNAL/1.0, got %O\n",
		   logged[7] ) );

  if( logged[8] != "200" )
    throw( sprintf( "The result code is wrong, expected 200, got %s\n",
		    logged[8] ) );

  if( logged[9] != "\0\310" )
    throw( sprintf("The binary result code is wrong, expected \0\310, got %O\n"
		   ,logged[9] ) );

  if( logged[10] != "3611" )
    throw( sprintf( "The length is wrong, expected 3611, got %s\n",
		    logged[10] ) );
    
  if( logged[11] != sprintf( "%4c", 3611 ) )
    throw( sprintf( "The binary length is wrong, expected %O, got %O\n",
		    sprintf( "%4c", 4711 ), logged[11] ) );

  if( min )
  {
    if( logged[12] != "-" )
      throw( sprintf( "The referer is wrong, expected %O got %O\n",
		      "-", logged[12] ) );
  }
  else
    if( logged[12] != "http://foo.bar/" )
      throw( sprintf( "The referer is wrong, expected %O got %O\n",
		      "http://foo.bar/", logged[12] ) );

  if( min )
  {
    if( logged[13] != "-" )
      throw( sprintf( "The user-agent is wrong, expected %O got %O\n",
		      "-", logged[13] ) );
  }
  else
    if( logged[13] != "Internal%201.0" )
      throw( sprintf( "The user-agent is wrong, expected %O got %O\n",
		      "Internal%201.0", logged[13] ) );

  if( logged[14] != "foo" )
    throw( sprintf( "The user is wrong, expected %O got %O\n",
		    "foo", logged[14] ) );

  if( min )
  {
    if( logged[15] != "0" )
      throw( sprintf( "The user-id is wrong, expected %O got %O\n",
		      "0", logged[15] ) );
  }
  else
    if( logged[15] != "iieff1934" )
      throw( sprintf( "The user-id is wrong, expected %O got %O\n",
		      "iieff1934", logged[15] ) );

  // 16 is the time the request took, in seconds, as a float.
  // Should be < 10.0. :-)
  if( (float)logged[16] > 10.0 )
    throw( sprintf("Odd request-taken time, got %O, expected < 10.0\n",
		   (float)logged[16] ) );
  
  if( logged[17] != "\n" )
    throw( sprintf( "The EOL marker is wrong, expected \\n, got %O\n",
		    logged[17] ) );
  
}


void test_spawn_pike( array args,
		      string stdin,
		      string expected_stdout )
{
  // Try to create a process...

  Stdio.File  fd = Stdio.File(), fd2 =  fd->pipe();
  Stdio.File fd3 = Stdio.File(), fd4 = fd3->pipe();
#ifdef __NT__
  Stdio.File fd5 = Stdio.File(), fd6 = fd5->pipe();
#else
  Stdio.File fd5 = Stdio.File("/dev/null", "w");
#endif

  Process.Process p =
    test_true(spawn_pike, args, getcwd(), fd, fd3, fd5 );

  fd->close();  fd3->close();  fd5->close();

  fd2->write( stdin );
  fd2->close();
#ifdef __NT__
  fd6->close();
#endif
  
  string data  = test( fd4->read );
  test( fd4->close );
  test( p->wait );
  test_true( `==, expected_stdout, data );
}

void run_tests( Configuration c )
{
  // Test (some) public APIs in the 'roxen' and 'roxenloader' objects.

  // Should we really test this? I don't know, but for now (as long as
  // both functions exists) verify that they return the same value...
  test( roxen.query_configuration_dir );
  test( roxenloader.query_configuration_dir );
  test_equal( roxen.query_configuration_dir(),
	      roxenloader.query_configuration_dir );


  test_spawn_pike( ({combine_path( __FILE__,"../echo.pike" )}),
		     "Testing testing\n",
		     "\nTesting testing\n" );

  test_spawn_pike( ({combine_path( __FILE__,"../echo.pike" ), "--help"}),
		     "Testing testing\n",
		     "--help\nTesting testing\n" );

  test_spawn_pike( ({combine_path( __FILE__,"../echo.pike" ),
		     "--version"}),
		     "Testing testing\n",
		     "--version\nTesting testing\n" );

  test_spawn_pike( ({combine_path( __FILE__,"../echo.pike" ),
		     "--version", "--help",}),
		     "Testing testing\n",
		     "--version--help\nTesting testing\n" );


  test_error( cd, "/tmp/" );

  test( roxenloader.dump, __FILE__, object_program( this_object() ) );
  test( roxen.dump, __FILE__, object_program( this_object() ) );
  
  // Test globally added functions that are added from roxen and
  // roxenloader.

  test_equal( roxen, roxenp );
  
#ifndef __NT__
  // Note: Assumes writable /tmp, won't work on NT
  test_true( mkdirhier, "/tmp/foo/bar/gazonk" );
  test_false( file_stat, "/tmp/foo/bar/gazonk" );

  test_true( mkdirhier, "/tmp/foo/bar/gazonk/" );
  test_true( file_stat, "/tmp/foo/bar/gazonk" );
  rm( "/tmp/foo/bar/gazonk" ); rm( "/tmp/foo/bar" ); rm( "/tmp/foo" );

  if( getuid() )
    report_notice( "   Not running as root, skipping Privs tests\n" );
  else
  {
    object key = test( Privs, "Testing", "nobody" );
    test_true( getuid );
    key = 0;
    test_false( getuid );
  }
#endif

  test_equal( "foo", Roxen.short_name, "foo" );
  test_equal( "1_2", Roxen.short_name, "\xbd" );
  test_equal( "foo_bar", Roxen.short_name, "Foo/Bar" );
  test_equal( "foo_bar_1_2", Roxen.short_name, "Foo/Bar\xa7\xbd" );

  // Some MySQL configuration tests.

  mapping(string:string) mysql_location =
    test_true(roxenloader->parse_mysql_location);

  if (mysql_location && test_true(predef::`->, mysql_location, "basedir")) {
    // Check that the MySQL upgrade code is available.
    if (mysql_location->mysql_upgrade) {
      // Upgrade script configured or found by parse_mysql_location().
      test_true(Stdio.is_file, mysql_location->mysql_upgrade);
    } else if (Stdio.is_file(combine_path(mysql_location->basedir,
					  "share/mysql",
					  "mysql_fix_privilege_tables.sql"))) {
      // Old-style upgrade code. Gone in MySQL 5.5.
      test_true(Stdio.read_bytes,
		combine_path(mysql_location->basedir,
			     "share/mysql", "mysql_fix_privilege_tables.sql"));
    } else {
      // Old-style upgrade code. Gone in MySQL 5.5.
      test_true(Stdio.read_bytes,
		combine_path(mysql_location->basedir,
			     "share", "mysql_fix_privilege_tables.sql"));
    }
  }

  // Test logging functions.

  class FakeID(
    // Optional variables. Can be missing from some protocols.
    mapping cookies,
    array referer,
    array client,
    string raw_url
  )
  {
    // Invariants -- must be supported by all protocols or bad things
    // will happen.
    int    time       = predef::time();
    int    hrtime     = gethrtime();
    string remoteaddr = "194.52.182.122";
    string method     = "GET";

    string not_query  = "/the/requested/file";
    string prot       = "INTERNAL/1.0";
    string realauth   = "foo:bar";

    mapping misc      = ([]);

    void init_cookies() { }
  };

  FakeID http_id = FakeID(([ "RoxenUserID":"iieff1934"]),
			  ({ "http://foo.bar/"  }),
			  ({ "Internal", "1.0" }),
			  "/the/requested/file?foo%20bar=hi%20there");
  FakeID minimum_id = FakeID(0,0,0,0);

  mapping fake_response = ([
    "error":200,
    "len":3611,
  ]);

  string format1 =
	    ({
	      "$ip_number",  "$bin-ip_number",  "$cern_date",  "$bin-date",
	      "$method",     "$resource",  "$full_resource", "$protocol",
	      "$response", "$bin-response", "$length", "$bin-length",
	      "$referer", "$user_agent", "$user", "$user_id", "$request-time"
	    }) * "$char(9999)"  + "$char(9999)";


  array(string) logged;
  void do_log( string what ) {  logged = what/"\23417";  };
  
  time();
  test( roxen.run_log_format, format1, do_log, http_id, fake_response );

  test( verify_logged_data, logged, 0 );

  test( roxen.run_log_format, format1, do_log, minimum_id, fake_response );

  test( verify_logged_data, logged, 1 );
}
