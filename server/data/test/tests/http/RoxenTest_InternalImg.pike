inherit "../pike_async_process_test_common";


string simple_check( )
{
  return
    common_wait( ([ 2:"Illegal headers",
		    3:"Illegal data",
		    4:"Connection failed",
		    5:"Bad protocol value in reply",
		    6:"Bad response code in reply",
		    7:"No date header",
		    8:"Bad or no content-length header",
		    9:"Bad or no last-modified header",
		    11:"Did not expect headers",
		    12:"Did not expect data",
		    13:"Did not expect connection",
		 ]) );
}

function run( string url, string ... more  )
{
  return lambda() {
	   run_pikescript( "http/internal.pike", url, @more );
	 };
}

#define ir(X) "/$/"+X

#define test_r_c( X,Y ) atest( ir(X), run(ir(X), Y), simple_check )
#define test_r( X ) atest( ir(X), run(ir(X)), simple_check )

void setup( )
{
  test_r_c( "unit", "5kd0hnfnfrsjjtlfutmbik7q22" );
  test_r_c( "colsel", "7o7msa9m802m7e4ia09vhebgqf" );
  test_r_c( "colsel-small", "3lf70uo7cmqqhour7kfqsoe7p4" );
  test_r_c( "squares", "7t969it672etl25fkdcf3uap00" );

  test_r( "help" );
  test_r( "pike" );
  test_r( "testimage" );

  test_r( "colorbar:0,0,0" );
  test_r( "colorbar:50,50,50" );
  test_r( "colorbar:255,255,2550" );
  test_r( "colorbar:500,500,500" );
}
