int current_test, tests_failed;
int verbose;

void create( int vb ) { verbose = vb; }


string describe_arglist( array args )
{
  array res = ({});
  foreach( args, mixed arg )
    if( mappingp(arg) || arrayp(arg) )
      res+=({sprintf("%t<%d>",arg,sizeof(arg))});
    else if( objectp( arg ) )
      if( arg->is_module )
	res += ({ sprintf("%s",arg->my_configuration()->otomod[arg])});
      else if( arg->is_configuration )
	res += ({ sprintf("%s", arg->name ) });
      else
	res += ({ sprintf("%O", arg ) });
    else
      res+=({sprintf("%O",arg)});
  return replace(res * ", ","%","%%");
}

void report_1st(function cb, array args, function check )
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
  report_error("%3d %c%-66s  ", current_test,
	       checkid,sprintf("%O("+describe_arglist( args )+")",cb)[..65]
	       );
}

string indent( int l, string what )
{
  array q = what/"\n";
//   if( q[-1] == "" )  q = q[..sizeof(q)-2];
  string i = (" "*l+"|  ");
  return i+q*("\n"+i)+"\n";
}

string do_describe_error( mixed err )
{
  if( stringp( err ) )
    return indent(2,err + (sizeof(err)?(err[-1] == '\n' ? "": "\n" ):""));
  catch {
    err = (array)err;
    err[1] = err[1][sizeof(err[1])-3..];
    return indent(2, describe_backtrace( err ) );
  };
  return indent(2, describe_backtrace( err ) );
}

void report_test_failure( mixed err, function cb, array args, int st )
{
  if( verbose ) 
    report_debug(" FAILED\n");
  report_debug(do_describe_error(sprintf( "%O( %s ) FAILED\n",
					  cb, describe_arglist( args ))));
  if( err )
    report_debug( do_describe_error( err ) );
  tests_failed++;
}


void report_test_ok( mixed err, function cb, array args, int st )
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


mixed test_generic( function check_return, function cb, mixed ... args )
{
  current_test++;
  mixed result;
  report_1st( cb, args, check_return );
  int st = gethrtime();
  mixed err = catch {
    result = cb( @args );
  };
  if( check_return )
    check_return( result, err, cb, args,st );
  else if( err )
    report_test_failure( err, cb, args,st );
  else
    report_test_ok( err, cb, args,st );
  return result;
}


void check_error( mixed res, mixed err, function cb, array args,int st )
{
  if( err )
    report_test_ok( err, cb, args, st );
  else
    report_test_failure( "Expected error", cb, args, st ); 
}

void check_is_module( mixed res, mixed err, function cb, array args, int st )
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

void check_is_configuration( mixed res, mixed err, function cb, array args,
			     int st)
{
  if( err )
    report_test_failure( err, cb, args, st );
  else
    if( !objectp(res) || !res->is_configuration )
      report_test_failure( sprintf("Got %O, expected configuration", res),cb,args, st);
    else
      report_test_ok( err, cb, args, st );
}


void check_true( mixed res, mixed err, function cb, array args, int st )
{
  if( err )
    report_test_failure( err, cb, args, st );
  else
    if( !res )
      report_test_failure( "expected non-zero, got 0", cb, args, st);
    else
      report_test_ok( err, cb, args, st );
}

void check_false( mixed res, mixed err, function cb, array args, int st )
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
    lambda( mixed res, mixed err, function cb, array args, int st )
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
    lambda( mixed res, mixed err, function cb, array args, int st )
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
    lambda( mixed res, mixed err, function cb, array args, int st )
    {
      if( err )
	report_test_failure( err, cb, args, st );
      else
	if( equal( res, m ))
	  report_test_failure(sprintf("Got %O, expected %O", res,m),
			      cb,args,st);
	else
	  report_test_ok( err, cb, args, st );
    };
}


mixed test( function f, mixed ... args )
{
  return test_generic( 0, f, @args );
}

mixed test_true( function f, mixed ... args )
{
  return test_generic( check_true, f, @args );
}

mixed test_false( function f, mixed ... args )
{
  return test_generic( check_false, f, @args );
}

mixed test_error( function f, mixed ... args )
{
  return test_generic( check_error, f, @args );
}

mixed test_equal( mixed what, function f, mixed ... args )
{
  return test_generic( check_equal( what ), f, @args );
}

mixed test_not_equal( mixed what, function f, mixed ... args )
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
  if( err )
    write( describe_backtrace( err ) );
  go_on(  current_test, tests_failed  );
}
