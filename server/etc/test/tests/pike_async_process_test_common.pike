int verbose;
Configuration c;
function do_when_done;

string http_url;
int current_test, tests_failed;
Process.Process test;

mapping all_tests = ([]);
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
    return indent(2,err + (strlen(err)?(err[-1] == '\n' ? "": "\n" ):""));
  err = (array)err;
  err[1] = err[1][sizeof(err[1])-3..];
  return indent(2, describe_backtrace( err ) );
}

string common_wait( mapping m )
{
  if (!test) {
    return "Test not started";
  }
  int err = test->wait();
  if( err == 100 )  return "Illegal arguments";
  if( err == 99 )   return "Timeout";
  if( !m[10] && (err == 10) )
    return "The external pike script triggered an error";
  if( !m[1] && (err == 1) )
    return "The external pike script failed to compile";
  return err && ( m[ err ] || ("Unknown error "+err) );
}

void run_pikescript( string p, string ... args  )
{
  if( !http_url )
    foreach( c->query("URLs"), string url )
      if( has_prefix( url, "http://" ) )
	http_url = (url/"#")[0];

  if( !http_url )
  {
    werror("Cannot run test -- no HTTP port open\n");
    return;
  }

  test = Process.create_process( ({
    getenv("PIKE"),
    combine_path( __FILE__, "../"+p ),
    http_url
  })+args );
}

void current_test_done()
{
#define IND(X) all_tests[ current_test+(X) ]
  if( !test || test->status() )
  {
    if(  function fp = IND("_check") )
      if( string fail = fp( ) )
      {
	tests_failed++;
	if( verbose ) report_debug(" FAILED\n");
	report_debug(do_describe_error(IND("_desc")+" FAILED\n" ));
	report_debug(do_describe_error( fail ));
      }
      else if( verbose )
	report_debug("   PASS\n");


    current_test++;
    if( function t = IND("") )
    {
      if( verbose )
	report_debug("%3d %c%-66s  ", current_test,' ',IND("_desc")[..65] );
      if( mixed err = catch {
	t();
      } )
      {
	if( verbose ) report_debug(" FAILED\n");
	report_debug(do_describe_error( err ) );
      }
      call_out( current_test_done, 0.1 );
    }
    else
      do_when_done( (current_test-1), tests_failed );
  }
  else
    call_out( current_test_done, 0.1 );
}



void low_run_tests( Configuration _c, function go_on )
{
  do_when_done = go_on;
  c = _c;
  call_out( current_test_done, 0 );
}

void setup();
void create( int v )
{
  verbose = v;
  setup();
}


int dt;
void atest( string n,
	    function t,
	    function c )
{
  dt++;
  all_tests[ dt+"_desc" ] = n;
  all_tests[ dt+"" ] = t;
  all_tests[ dt+"_check" ] = c;
}
