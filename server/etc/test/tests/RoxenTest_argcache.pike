inherit "pike_test_common.pike";


void run_tests( Configuration c  )
{
  string key2,key = test( roxen.argcache.store,
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

  key2 = test_not_equal( key,
	      roxen.argcache.store,
	      ([ "foo":"\4711",
		 "gazonk":2,
		 "teleledningsanka":42.0
	      ]) );

  test_equal( ([ "foo":"\4711","gazonk":2,"teleledningsanka":42.0 ]),
	      roxen.argcache.lookup, key2 );
  test_equal( ([ "foo":"\4711","gazonk":1,"teleledningsanka":42.0 ]),
	      roxen.argcache.lookup, key );

  test( roxen.argcache.delete, key );
  test( roxen.argcache.delete, key2 );
  
  test_error( roxen.argcache.lookup, key );
  test_error( roxen.argcache.lookup, key );
}
