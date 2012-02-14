int current_test, tests_failed;
int verbose;

constant single_thread = 0;
// If this constant is set then the test will run in the backend
// thread while all handler threads are on hold (which implies the
// background_run queue is on hold as well). Otherwise tests are run
// in one handler thread while another one is free to execute
// background jobs right away.

void create( int vb ) { verbose = vb; }


string describe_test (function|string cb, array args)
{
  if (!stringp (cb)) {
    object describer = master()->Describer();
    return describer->describe (cb) +
      "(" + describer->describe_comma_list (args, 512) + ")";
  }
  if (sizeof (args))
    catch {return sprintf (cb, @args);};
  return cb;
}

string pad_to_column (string str, int col, string cont_prefix)
{
  array(string) split = str / "\n";
  if (sizeof (split) > 1 && split[-1] == "") split = split[..<1];
  if (sizeof (split[-1]) > col) split += ({""});
  split[-1] += " " * (col - sizeof (split[-1]));
  return split * ("\n" + cont_prefix);
}

void report_1st(function|string|array cb, array args, function check )
{
  if( !verbose )
    return;
  int checkid = ' ';
  if( check == check_error )
    checkid = '#';
  else if( check == check_false )
    checkid = '!';
  else if( check != check_is_configuration &&
	   check == check_is_module )
    checkid = '~';

  if (arrayp (cb))
    // Got line number info.
    report_error ("%3d  %s:%d:\n"
		  "   %c %s  ",
		  current_test, cb[0], cb[1], checkid,
		  pad_to_column (describe_test (cb[2], args),
				 66, sprintf ("   %c ", checkid)));
  else
    report_error("%3d%c %s  ", current_test, checkid,
		 pad_to_column (describe_test (cb, args),
				66, sprintf ("   %c ", checkid)));
}

string indent( int l, string what )
{
  array q = what/"\n";
  int trailing_nl = q[-1] == "";
  if (trailing_nl) q = q[..<1];
  string i = (" "*l+"|  ");
  return i+q*("\n"+i) + (trailing_nl ? "\n" : "");
}

void log (string msg, mixed... args)
{
  if (sizeof (args)) msg = sprintf (msg, @args);
  report_debug (indent (2, msg));
}

void log_verbose (string msg, mixed... args)
{
  if (!verbose) return;
  if (sizeof (args)) msg = sprintf (msg, @args);
  report_debug (indent (2, msg));
}

string do_describe_error( mixed err )
{
  if (!stringp (err)) err = describe_backtrace (err);
  if (has_suffix (err, "\n")) err = err[..<1];
  return indent(2, err) + "\n";
}

void report_test_failure( mixed err,
			  function|string|array cb, array args, int st )
{
  if( verbose ) 
    report_debug(" ################ FAILED\n");
  else {
    if (arrayp (cb)) {
      // Got line number info.
      report_debug (indent (2, sprintf ("################ %s:%d:   FAILED",
					cb[0], cb[1])) + "\n" +
		    do_describe_error(describe_test (cb[2], args)));
    }
    else
      report_debug(indent (2, "################ " +
			   describe_test (cb, args) + "   FAILED\n"));
  }

  if( err )
    report_debug( do_describe_error( err ) );
  report_debug ("\n");
  tests_failed++;
}


void report_test_ok( mixed err, function|string|array cb, array args, int st )
{
  if( verbose )
  {
    int tt = (gethrtime()-st);
    if( tt > 200000 )
      report_debug(" %4dms\n", tt/1000);
    else
      report_debug( "   PASS\n" );
    //   if( err ) report_error( do_describe_error( err ) );
  }
}


mixed test_generic( function check_return, function|array cb, mixed ... args )
{
  current_test++;
  mixed result;
  report_1st( cb, args, check_return );
  int st = gethrtime();
  function test_fn = arrayp (cb) ? cb[2] : cb;
  mixed err = catch {
    result = test_fn( @args );
  };
  if( check_return )
    check_return( result, err, cb, args,st );
  else if( err )
    report_test_failure( err, cb, args,st );
  else
    report_test_ok( err, cb, args,st );
  return result;
}

mixed test_really_generic( function check_return, function(void:mixed) test_fn,
			   string|array test_text, array test_text_args )
{
  current_test++;
  mixed result;
  int st = gethrtime();
  mixed err = catch {
      result = test_fn();
  };

  // Write out the test after running it, since the macros change
  // test_text_args in the test.
  report_1st( test_text, test_text_args, check_return );

  if( check_return )
    check_return( result, err, test_text, test_text_args,st );
  else if( err )
    report_test_failure( err, test_text, test_text_args,st );
  else
    report_test_ok( err, test_text, test_text_args,st );
  return result;
}


void check_error( mixed res, mixed err,
		  function|string|array cb, array args, int st )
{
  if( err )
    report_test_ok( err, cb, args, st );
  else
    report_test_failure( "Expected error", cb, args, st ); 
}

void check_is_module( mixed res, mixed err,
		      function|string|array cb, array args, int st )
{
  if( err )
    report_test_failure( err, cb, args, st );
  else
    if( !objectp(res) || !res->is_module || !res->my_configuration() )
      report_test_failure( sprintf("Got %O, expected module", res),cb,args,
			 st);
    else
      report_test_ok( err, cb, args, st );
}

void check_is_configuration( mixed res, mixed err,
			     function|string|array cb, array args, int st)
{
  if( err )
    report_test_failure( err, cb, args, st );
  else
    if( !objectp(res) || !res->is_configuration )
      report_test_failure( sprintf("Got %O, expected configuration", res),cb,args, st);
    else
      report_test_ok( err, cb, args, st );
}

void silent_check_true( mixed res, mixed err,
			function|string|array cb, array args, int st )
{
  if (err || !res)
    report_test_failure( err, cb, args, st );
  else
    report_test_ok( 0, cb, args, st );
}

void check_true( mixed res, mixed err,
		 function|string|array cb, array args, int st )
{
  if( err )
    report_test_failure( err, cb, args, st );
  else
    if( !res )
      report_test_failure( sprintf ("expected non-zero, got %O", res),
			   cb, args, st);
    else
      report_test_ok( err, cb, args, st );
}

void check_false( mixed res, mixed err,
		  function|string|array cb, array args, int st )
{
  if( err )
    report_test_failure( err, cb, args, st );
  else
    if( res )
      report_test_failure( sprintf("expected zero, got %O",res), cb, args, st);
    else
      report_test_ok( err, cb, args, st );
}


function check_is( mixed m )
{
  return
    lambda( mixed res, mixed err, function|string|array cb, array args, int st )
    {
      if( err )
	report_test_failure( err, cb, args, st );
      else
	if( res != m )
	  report_test_failure(sprintf("Got %O, expected %O", res,m),
			      cb,args,st);
	else
	  report_test_ok( err, cb, args, st );
    };
}

mixed pass( mixed arg )
{
  return arg;
}

function check_equal( mixed m )
{
  return
    lambda( mixed res, mixed err, function|string|array cb, array args, int st )
    {
      if( err )
	report_test_failure( err, cb, args, st );
      else
	if( !equal( res, m ))
	  report_test_failure(sprintf("Got %O, expected %O", res,m),
			      cb,args,st);
	else
	  report_test_ok( err, cb, args, st );
    };
}

function check_not_equal( mixed m )
{
  return
    lambda( mixed res, mixed err, function|string|array cb, array args, int st )
    {
      if( err )
	report_test_failure( err, cb, args, st );
      else
	if( equal( res, m ))
	  report_test_failure(sprintf("Got %O, expected different value", res),
			      cb,args,st);
	else
	  report_test_ok( err, cb, args, st );
    };
}

mixed cpp_test_true (string file, int line, function(void:mixed) test_fn,
		     string test_text, array test_text_args)
{
  return test_really_generic (silent_check_true, test_fn,
			      ({file, line, test_text}), test_text_args);
}

mixed test( function|array f, mixed ... args )
{
  return test_generic( 0, f, @args );
}

mixed test_true( function|array f, mixed ... args )
{
  return test_generic( check_true, f, @args );
}

mixed test_false( function|array f, mixed ... args )
{
  return test_generic( check_false, f, @args );
}

mixed test_error( function|array f, mixed ... args )
{
  return test_generic( check_error, f, @args );
}

mixed test_equal( mixed what, function|array f, mixed ... args )
{
  return test_generic( check_equal( what ), f, @args );
}

mixed test_not_equal( mixed what, function|array f, mixed ... args )
{
  return test_generic( check_not_equal( what ), f, @args );
}


void run_tests( Configuration c );

void low_run_tests( Configuration c,
		    function go_on )
{
  mixed err = catch {
    run_tests( c );
  };
  if( err ) {
    write( "################ " + describe_backtrace( err ) );
    go_on (++current_test, ++tests_failed);
  }
  else
    go_on (++current_test, tests_failed);
}
