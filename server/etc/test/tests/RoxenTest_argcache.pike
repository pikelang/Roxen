inherit "pike_test_common.pike";


array run_tests( Configuration c  )
{
  string key = test( roxen.argcache.store,
		     ([ "foo":"\4711",
			"gazonk":1,
			"teleledningsanka":42.0
		     ]) );

  test_true( roxen.argcache.key_exists, key );
  test_false( roxen.argcache.key_exists, "not" );


  test_equal( key,
	      roxen.argcache.store,
	      ([ "foo":"\4711",
		 "gazonk":1,
		 "teleledningsanka":42.0
	      ]) );

  test_equal( ([ "foo":"\4711","gazonk":1,"teleledningsanka":42.0 ]),
	      roxen.argcache.lookup, key );

  test_true( pass, (int)key );

  test( roxen.argcache.delete, key );
  
  test_error( roxen.argcache.lookup, key );
  
  
  return ({ current_test, tests_failed });
}
