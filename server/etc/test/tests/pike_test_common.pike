int current_test, tests_failed;
int verbose = 1;

string describe_arglist( array args )
{
  array res = ({});
  foreach( args, mixed arg )
  {
    if( mappingp(arg) || arrayp(arg) )
      res+=({sprintf("%t<%d>",arg,sizeof(arg))});
    else
      res+=({sprintf("%O",arg)});
  }
  return res * ", ";
}

void report_1st(function cb, array args )
{
  report_error("  Test %3d %-40s  ", current_test,
	       sprintf("%O("+describe_arglist( args )+")",cb)[..39]);
}

string do_describe_error( mixed err )
{
  if( stringp( err ) )
    return err + (strlen(err)?(err[-1] == '\n' ? "": "\n" ):"");
  err = (array)err;
  err[1] = err[1][sizeof(err[1])-3..];
  return describe_backtrace( err );
}

void report_test_failure( mixed err, function cb, array args, int st )
{
  report_error("FAILED\n");
  if( err ) report_error( do_describe_error( err ) );
  tests_failed++;
}


void report_test_ok( mixed err, function cb, array args, int st )
{
  report_error("OK [%dms]\n", (gethrtime()-st)/1000);
  if( err ) report_error( do_describe_error( err ) );
}


mixed do_test( function check_return, function cb, mixed ... args )
{
  current_test++;
  mixed result;
  report_1st( cb, args );
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


void check_is_not_zero( mixed res, mixed err, function cb, array args, int st )
{
  if( err )
    report_test_failure( err, cb, args, st );
  else
    if( !res )
      report_test_failure( "expected non-zero", cb, args, st);
    else
      report_test_ok( err, cb, args, st );
}
