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

  for( int i = 0; i<min(sizeof( f ),20); i++ )
    f[i] = thread_create( lookup_and_group, f[i] );
  (f[0..min(sizeof(f),19)])->wait();
  if( failed )
    throw( failed );
}

void do_thread_tests( RoxenModule m )
{
  // 1: Look up all users in parallell
  test( lookup_threaded, m->list_users(), m );
}


void verify_compat_userinfo( Configuration c, array list )
{
  foreach( list, string s )
  {
    array ui = c->userinfo( s );
    if( !arrayp(ui) )
      throw( sprintf( "Expected array of size 7, got %t\n", ui) );

    if( sizeof( ui ) != 7 )
      throw( sprintf( "Expected array of size 7, got array of size %d\n",
		      sizeof(ui ) ) );

    //  Mac OS X 10.5 returns system users with a "_" prefix even if queried
    //  for the non-prefixed name so we'll look the other way when comparing.
    if( (ui[0] - "_") != (s - "_") )
      throw(sprintf("Got different user (0) from userinfo than given (%O!=%O)",
		    ui[0],s ));


    if( !stringp( ui[1] ) )
      throw( sprintf( "Expected string for password (1), got %O\n", ui[1] ) );
    if( !intp( ui[2] ) )
      throw( sprintf( "Expected int for uid (2), got %O\n", ui[2] ) );
    if( !intp( ui[3] ) )
      throw( sprintf( "Expected int for gid (3), got %O\n", ui[3] ) );
    if( !stringp( ui[4] ) )
      throw( sprintf( "Expected string for gecos (4), got %O\n", ui[4] ) );
    if( !stringp( ui[5] ) )
      throw( sprintf( "Expected string for homedir (5), got %O\n", ui[5] ) );
    if( !stringp( ui[6] ) )
      throw( sprintf( "Expected string for shell (6), got %O\n", ui[6] ) );
  }
}

void verify_compat_user_from_uid( Configuration c, array list )
{
  foreach( list, string s )
  {
    User u = c->find_user( s );
    array ui = c->user_from_uid( u->uid()  );

    if( !arrayp(ui) )
      throw( sprintf( "Expected array of size 7, got %t\n", ui) );

    if( sizeof( ui ) != 7 )
      throw( sprintf( "Expected array of size 7, got array of size %d\n",
		      sizeof(ui ) ) );

    if( ui[2] != u->uid() )
      throw(sprintf("Got different user (0) from userinfo than given (%O!=%O)",
		    ui[0],u->uid() ));


    if( !stringp( ui[1] ) )
      throw( sprintf( "Expected string for password (1), got %O\n", ui[1] ) );
    if( !intp( ui[2] ) )
      throw( sprintf( "Expected int for uid (2), got %O\n", ui[2] ) );
    if( !intp( ui[3] ) )
      throw( sprintf( "Expected int for gid (3), got %O\n", ui[3] ) );
    if( !stringp( ui[4] ) )
      throw( sprintf( "Expected string for gecos (4), got %O\n", ui[4] ) );
    if( !stringp( ui[5] ) )
      throw( sprintf( "Expected string for homedir (5), got %O\n", ui[5] ) );
    if( !stringp( ui[6] ) )
      throw( sprintf( "Expected string for shell (6), got %O\n", ui[6] ) );
  }
}

void run_tests( Configuration c )
{
#ifdef __NT__
  return; // This module does not work on NT.
#endif

  RoxenModule m;

  test( roxen.enable_configuration, "usertestconfig" );
  

  c = test_generic( check_is_configuration,
		    roxen.find_configuration,
		    "usertestconfig" );

  if( !c )  {
    report_error( "Failed to find test configuration\n");
    return;
  }

  test( c->enable_module, "userdb_system" );

  m = test_generic( check_is_module, c->find_module,  "userdb_system#0" );

  if( !test_true( predef::`[], m, "list_users"  ) )  {
    report_error( "Failed to enable userdb module\n");
    return;
  }
  
  
  // 1: Do a few simple tests by calling the module directly.
  array user_list =  test_true( m->list_users );
  array group_list = test_true( m->list_groups );


  // 2: Test the interfaces in the config and module objects.
  foreach( ({ m, c }), object o )
  {
    test( verify_user_list, user_list, o );
    do_thread_tests( o );
  }

  // 3: Test functions in config object
  test_equal( m, c->find_user_database, "system" );



  // 4: Test get/set interface in user objects

  User u =
    test( c->find_user, user_list[ random( sizeof( user_list ) )] );
  

  foreach( ({ "A Random String", 10, "\4711\4712\4713" }),
	   mixed value )
  {
    test_equal( value, u->set_var, 0, "v", value );

    // 0,v exists
    test_equal( value, u->get_var, 0, "v" );
    test_false( u->get_var, m, "v", value );


    test_equal( value, u->set_var, m, "v", value );

    // m,v 0,v exists
    test_equal( value, u->get_var, m, "v" );
    test_equal( value, u->get_var, 0, "v" );

    test( u->delete_var, 0, "v" );

    // m,v exists
    test_false(  u->get_var, 0, "v" );
    test_equal( value, u->get_var, m, "v" );

    test( u->delete_var, m, "v" );
    // no variables exists
  }


  // 5: Test (deprecated) compat interfaces
  array list = test( c->userlist );
  test( verify_compat_userinfo, c, list );
  test( verify_compat_user_from_uid, c, list );
  

  // 6: Shutdown.

  test( c->disable_module, "userdb_system" );
  test( roxen.disable_configuration, "usertestconfig" );

  return;
}
