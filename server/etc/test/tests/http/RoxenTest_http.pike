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

function run( string script, string file, int len, string ... ma  )
{
  return lambda() {
	   run_pikescript( script, file, (string)len, @ma );
	 };
}

#define stest( X,Y,Z,Å ) atest( X, run( Y,Z,Å ), simple_check )
#define stest2( X,Y,Z,Å ) atest( X+" (no \\r)", run( Y,Z,Å,"1" ), simple_check )

void setup( )
{
  stest( "HTTP/0.9 /1k.raw",  "http/http09.pike", "/1k.raw",  1024 );
  stest( "HTTP/0.9 /10k.raw", "http/http09.pike", "/10k.raw", 1024*10 );
  stest( "HTTP/0.9 /",        "http/http09.pike", "/",        0 );
  stest( "HTTP/0.9 /nofile",  "http/http09.pike", "/nofile",  0 );

  stest( "HTTP/1.0 /1k.raw",  "http/http10.pike", "/1k.raw",  1024 );
  stest( "HTTP/1.0 /10k.raw", "http/http10.pike", "/10k.raw", 1024*10 );
  stest( "HTTP/1.0 /",        "http/http10.pike", "/",        0 );
  stest( "HTTP/1.0 /nofile",  "http/http10.pike", "/nofile",  0 );

  stest( "PING",              "http/ping.pike",   "/",        0 );

  stest2( "HTTP/0.9 /1k.raw",  "http/http09.pike", "/1k.raw",  1024 );
  stest2( "HTTP/0.9 /10k.raw", "http/http09.pike", "/10k.raw", 1024*10 );
  stest2( "HTTP/0.9 /",        "http/http09.pike", "/",        0 );
  stest2( "HTTP/0.9 /nofile",  "http/http09.pike", "/nofile",  0 );

  stest2( "HTTP/1.0 /1k.raw",  "http/http10.pike", "/1k.raw",  1024 );
  stest2( "HTTP/1.0 /10k.raw", "http/http10.pike", "/10k.raw", 1024*10 );
  stest2( "HTTP/1.0 /",        "http/http10.pike", "/",        0 );
  stest2( "HTTP/1.0 /nofile",  "http/http10.pike", "/nofile",  0 );

  stest2( "PING",              "http/ping.pike",   "/",        0 );

}
