inherit "../pike_async_process_test_common";


string simple_check( )
{
  return
    common_wait( ([ 1:"Illegal headers",
		    2:"Illegal data",
		    3:"Connection failed",
		    11:"Did not expect headers",
		    12:"Did not expect data",
		    13:"Did not expect connection",
		 ]) );
}

function run( string script, string file, int len )
{
  return lambda() {
	   run_pikescript( script, file, (string)len );
	 };
}


constant test_1_desc = "HTTP/0.9 /1k.raw";
function test_1 = run( "http/http09.pike", "/1k.raw", 1024 );
function test_1_check = simple_check;

constant test_2_desc = "HTTP/1.0 /1k.raw";
function test_2 = run( "http/http10.pike", "/1k.raw", 1024 );
function test_2_check = simple_check;

constant test_3_desc = "HTTP/1.0 /10k.raw";
function test_3 = run( "http/http10.pike", "/10k.raw", 1024*10 );
function test_3_check = simple_check;


