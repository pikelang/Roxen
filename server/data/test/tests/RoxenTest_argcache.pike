inherit "pike_test_common.pike";


void run_tests( Configuration c  )
{
  string key2,key = test( core.argcache.store,
		     ([ "foo":"\4711",
			"gazonk":1,
			"teleledningsanka":42.0
		     ]) );

  test_true( core.argcache.key_exists, key );
  test_false( core.argcache.key_exists, "not" );


  test_equal( key,
	      core.argcache.store,
	      ([ "foo":"\4711",
		 "gazonk":1,
		 "teleledningsanka":42.0
	      ]) );


  test_equal( ([ "foo":"\4711","gazonk":1,"teleledningsanka":42.0 ]),
	      core.argcache.lookup, key );

  key2 = test_not_equal( key,
	      core.argcache.store,
	      ([ "foo":"\4711",
		 "gazonk":2,
		 "teleledningsanka":42.0
	      ]) );

  test_equal( ([ "foo":"\4711","gazonk":2,"teleledningsanka":42.0 ]),
	      core.argcache.lookup, key2 );
  test_equal( ([ "foo":"\4711","gazonk":1,"teleledningsanka":42.0 ]),
	      core.argcache.lookup, key );

  test( core.argcache.delete, key );
  test( core.argcache.delete, key2 );
  
  test_error( core.argcache.lookup, key );
  test_error( core.argcache.lookup, key );
}
