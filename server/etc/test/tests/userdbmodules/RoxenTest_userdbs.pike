inherit "../pike_test_common.pike";

void verify_user_list( array list, RoxenModule m )
{
  foreach( list, mixed u )
  {
    if( !stringp( u ) )
      throw(sprintf("Found %O in user list, expected array of strings\n", u));
    User uid = m->find_user( u );
    if( !uid || !objectp(uid) || !(uid->name && uid->uid) )
      throw( sprintf("User %O; Expected user object, got %O\n",u,uid) );
    foreach( uid->groups(), mixed grp )
      if( !stringp( grp ) )
	throw(sprintf("Found %O in group list for %O, "
		      "expected array of strings\n", grp, u ));
  }
}


void lookup_threaded( array f, RoxenModule m )
{
  mixed failed;
  void lookup_and_group( string u )
  {
    User uid = m->find_user( u );
    if( !objectp(uid) || !uid->uid )
      failed = sprintf("Expected user, got %O\n", uid);
    else
    {
      mixed err;
      if( err = catch {
	array grps = map( uid->groups(), m->find_group );
	foreach( grps, object q )
	  if( !objectp( q ) || !q->name )
	    failed = sprintf( "Expected group, got %O\n", q );
      } )
	failed = err;
    }
  };

  for( int i = 0; i<sizeof( f ); i++ )
    f[i] = thread_create( lookup_and_group, f[i] );
  f->wait();
  if( failed )
    throw( failed );
}

void do_thread_tests( RoxenModule m )
{
  // 1: Look up all users in parallell
  do_test( 0, lookup_threaded, m->list_users(), m );
}

array(int) run_tests( Configuration c )
{
  RoxenModule m;

  do_test( 0, roxen.enable_configuration, "usertestconfig" );
  

  c = do_test( check_is_configuration,
	       roxen.find_configuration,
	       "usertestconfig" );

  if( !c )  {
    report_error( "Failed to find test configuration\n");
    return ({ current_test, tests_failed });
  }

  do_test( 0, c->enable_module, "userdb_system" );

  m = do_test( check_is_module, c->find_module,  "userdb_system#0" );

  if( !do_test( check_is_not_zero, predef::`[], m, "list_users"  ) )  {
    report_error( "Failed to enable userdb module\n");
    return ({ current_test, tests_failed });
  }
  
  
  // 1: Do a few simple tests by calling the module directly.
  array user_list = do_test( 0, m->list_users );
  array group_list = do_test( 0, m->list_groups );

  do_test( 0, verify_user_list, user_list, m );
  
#if constant(thread_create)
  do_thread_tests( m );
#else
  report_notice("Threads not available, skipping thread related UserDB tests\n");
#endif
  
  return ({ current_test, tests_failed });
}
