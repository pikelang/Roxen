inherit "pike_test_common.pike";


array(int) run_tests( Configuration c )
{
  // Test (some) public APIs in the 'roxen' and 'roxenloader' objects.

  // Should we really test this? I don't know, but for now (as long as
  // both functions exists) verify that they return the same value...
  
  do_test( 0, roxen.query_configuration_dir );
  do_test( 0, roxenloader.query_configuration_dir );
  do_test( check_is( roxen.query_configuration_dir() ),
	   roxenloader.query_configuration_dir );



  // Try to create a process...

  Stdio.File  fd = Stdio.File(), fd2 =  fd->pipe();
  Stdio.File fd3 = Stdio.File(), fd4 = fd3->pipe();
  Stdio.File fd5 = Stdio.File(), fd6 = fd5->pipe();
  
  Process.Process p =
    do_test( check_true,
	     spawn_pike,
	     ({combine_path( __FILE__,"../echo.pike" )}),
	     getcwd(),
	     fd, fd3, fd5 );

  fd->close();
  fd3->close();
  fd5->close();

  fd2->write( "Testing testing\n" );
  fd2->close();fd6->close();

  string data  = do_test( 0, fd4->read );
  do_test( 0, fd4->close );
  do_test( 0, p->wait );
  do_test( check_is( data ), pass, "Testing testing\n" );


  do_test( check_error, cd, "/tmp/" );

  do_test( 0, roxenloader.dump, __FILE__, object_program( this_object() ) );
  do_test( 0, roxen.dump, __FILE__, object_program( this_object() ) );
  
  // Test globally added functions that are added from roxen and
  // roxenloader.

  do_test( check_is( roxen ), roxenp );
  
#ifndef __NT__
  // Note: Assumes writable /tmp, won't work on NT
  do_test( check_true, mkdirhier, "/tmp/foo/bar/gazonk" );
  do_test( check_false,file_stat, "/tmp/foo/bar/gazonk" );

  do_test( check_true, mkdirhier, "/tmp/foo/bar/gazonk/" );
  do_test( check_true, file_stat, "/tmp/foo/bar/gazonk" );
  rm( "/tmp/foo/bar/gazonk" ); rm( "/tmp/foo/bar" ); rm( "/tmp/foo" );

  if( getuid() )
    report_notice( "   Not running as root, skipping Privs tests\n" );
  else
  {
    object key = do_test( 0, Privs, "Testing", "nobody" );
    do_test( check_true, getuid );
    key = 0;
    do_test( check_false, getuid );
  }
#endif


  return ({ current_test, tests_failed });
}
