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
		    14:"Did not expect valid reply",
		 ]) );
}

function run( string script, string file, int len, string ... ma  )
{
  return lambda() {
	   run_pikescript( script, file, (string)len, @ma );
	 };
}

#define _test( X,Y,Z,Å,Ä,Ö) atest(X+Ä, run(Y,Z,Å,Ö), simple_check )

#define stest( X,Y,Z,Å )   _test( X,Y,Z,Å, "",                 "1" )
#define stest2( X,Y,Z,Å )  _test( X,Y,Z,Å," (no \\r)",          "2" )
#define stest3( X,Y,Z,Å )  _test( X,Y,Z,Å," (1 b packets)",  "3" )
#define stest4( X,Y,Z,Å )  _test( X,Y,Z,Å," (10 b packets)", "4" )

#define stest5( X,Y,Z,Å )  _test( X,Y,Z,Å," (1k headers)", "5" )
#define stest6( X,Y,Z,Å )  _test( X,Y,Z,Å," (10k headers)", "6" )
#define stest7( X,Y,Z,Å )  _test( X,Y,Z,Å," (100k headers)", "7" )

#define stest8( X,Y,Z,Å )  _test( X,Y,Z,Å," (1k headers, no \\r)", "8" )
#define stest9( X,Y,Z,Å )  _test( X,Y,Z,Å," (10k headers, no \\r)", "9" )
#define stest10( X,Y,Z,Å )  _test( X,Y,Z,Å," (100k headers, no \\r)", "10" )

#define stest11( X,Y,Z,Å )  _test( X,Y,Z,Å," (header overflow (>512Kb))","11" )

#define btest( X,Y,Z,Å,Ä)  _test( X,Y,Z,Å, "", Ä )

void setup( )
{
//   stest( "HTTP/0.9 /1k.raw",  "http/http09.pike", "/1k.raw",  1024 );
//   stest( "HTTP/0.9 /10k.raw", "http/http09.pike", "/10k.raw", 1024*10 );
//   stest( "HTTP/0.9 /",        "http/http09.pike", "/",        0 );
//   stest( "HTTP/0.9 /nofile",  "http/http09.pike", "/nofile",  0 );

  stest( "HTTP/1.0 /1k.raw",  "http/http10.pike", "/1k.raw",  1024 );
  stest( "HTTP/1.0 /10k.raw", "http/http10.pike", "/10k.raw", 1024*10 );
  stest( "HTTP/1.0 /",        "http/http10.pike", "/",        0 );
  stest( "HTTP/1.0 /nofile",  "http/http10.pike", "/nofile",  0 );
  stest( "HTTP/1.0 /nofile",  "http/http10.pike", "/nofile",  0 );

  //  stest( "HTTP/1.1 /1k.raw",  "http/http11.pike", "/1k.raw",  1024 );
  //  stest( "HTTP/1.1 /10k.raw", "http/http11.pike", "/10k.raw", 1024*10 );
  //  stest( "HTTP/1.1 /",        "http/http11.pike", "/",        0 );
  //  stest( "HTTP/1.1 /nofile",  "http/http11.pike", "/nofile",  0 );

  btest( "HTTP/01.0 /1k.raw", "http/http010.pike", "/1k.raw", 1024, "01.0" );
  btest( "HTTP/01.0 /nofile", "http/http010.pike", "/nofile", 0, "01.0" );
  btest( "HTTP/001.00 /1k.raw", "http/http010.pike", "/1k.raw", 1024, "001.00" );
  btest( "HTTP/001.00 /nofile", "http/http010.pike", "/nofile", 0, "001.00" );

  stest( "PING",              "http/ping.pike",   "/",        0 );

//   stest2( "HTTP/0.9 /1k.raw",  "http/http09.pike", "/1k.raw",  1024 );
//   stest2( "HTTP/0.9 /10k.raw", "http/http09.pike", "/10k.raw", 1024*10 );
//   stest2( "HTTP/0.9 /",        "http/http09.pike", "/",        0 );
//   stest2( "HTTP/0.9 /nofile",  "http/http09.pike", "/nofile",  0 );

  stest2( "HTTP/1.0 /1k.raw",  "http/http10.pike", "/1k.raw",  1024 );
  stest2( "HTTP/1.0 /10k.raw", "http/http10.pike", "/10k.raw", 1024*10 );
  stest2( "HTTP/1.0 /",        "http/http10.pike", "/",        0 );
  stest2( "HTTP/1.0 /nofile",  "http/http10.pike", "/nofile",  0 );

  //  stest2( "HTTP/1.1 /1k.raw",  "http/http11.pike", "/1k.raw",  1024 );
  //  stest2( "HTTP/1.1 /10k.raw", "http/http11.pike", "/10k.raw", 1024*10 );
  //  stest2( "HTTP/1.1 /",        "http/http11.pike", "/",        0 );
  //  stest2( "HTTP/1.1 /nofile",  "http/http11.pike", "/nofile",  0 );

  stest2( "PING",              "http/ping.pike",   "/",        0 );

//   stest3( "HTTP/0.9 /1k.raw",  "http/http09.pike", "/1k.raw",  1024 );
//   stest3( "HTTP/0.9 /10k.raw", "http/http09.pike", "/10k.raw", 1024*10 );
//   stest3( "HTTP/0.9 /",        "http/http09.pike", "/",        0 );
//   stest3( "HTTP/0.9 /nofile",  "http/http09.pike", "/nofile",  0 );

  stest3( "HTTP/1.0 /1k.raw",  "http/http10.pike", "/1k.raw",  1024 );
  stest3( "HTTP/1.0 /10k.raw", "http/http10.pike", "/10k.raw", 1024*10 );
  stest3( "HTTP/1.0 /",        "http/http10.pike", "/",        0 );
  stest3( "HTTP/1.0 /nofile",  "http/http10.pike", "/nofile",  0 );

  //  stest3( "HTTP/1.1 /1k.raw",  "http/http11.pike", "/1k.raw",  1024 );
  //  stest3( "HTTP/1.1 /10k.raw", "http/http11.pike", "/10k.raw", 1024*10 );
  //  stest3( "HTTP/1.1 /",        "http/http11.pike", "/",        0 );
  //  stest3( "HTTP/1.1 /nofile",  "http/http11.pike", "/nofile",  0 );

  stest3( "PING",              "http/ping.pike",   "/",        0 );

//   stest4( "HTTP/0.9 /1k.raw",  "http/http09.pike", "/1k.raw",  1024 );
//   stest4( "HTTP/0.9 /10k.raw", "http/http09.pike", "/10k.raw", 1024*10 );
//   stest4( "HTTP/0.9 /",        "http/http09.pike", "/",        0 );
//   stest4( "HTTP/0.9 /nofile",  "http/http09.pike", "/nofile",  0 );

  stest4( "HTTP/1.0 /1k.raw",  "http/http10.pike", "/1k.raw",  1024 );
  stest4( "HTTP/1.0 /10k.raw", "http/http10.pike", "/10k.raw", 1024*10 );
  stest4( "HTTP/1.0 /",        "http/http10.pike", "/",        0 );
  stest4( "HTTP/1.0 /nofile",  "http/http10.pike", "/nofile",  0 );

  stest5( "HTTP/1.0 /1k.raw",  "http/http10.pike", "/1k.raw",  1024 );
  stest5( "HTTP/1.0 /10k.raw", "http/http10.pike", "/10k.raw", 1024*10 );
  stest5( "HTTP/1.0 /",        "http/http10.pike", "/",        0 );
  stest5( "HTTP/1.0 /nofile",  "http/http10.pike", "/nofile",  0 );

  stest6( "HTTP/1.0 /1k.raw",  "http/http10.pike", "/1k.raw",  1024 );
  stest6( "HTTP/1.0 /10k.raw", "http/http10.pike", "/10k.raw", 1024*10 );
  stest6( "HTTP/1.0 /",        "http/http10.pike", "/",        0 );
  stest6( "HTTP/1.0 /nofile",  "http/http10.pike", "/nofile",  0 );

  stest7( "HTTP/1.0 /1k.raw",  "http/http10.pike", "/1k.raw",  1024 );
  stest7( "HTTP/1.0 /10k.raw", "http/http10.pike", "/10k.raw", 1024*10 );
  stest7( "HTTP/1.0 /",        "http/http10.pike", "/",        0 );
  stest7( "HTTP/1.0 /nofile",  "http/http10.pike", "/nofile",  0 );

  stest8( "HTTP/1.0 /1k.raw",  "http/http10.pike", "/1k.raw",  1024 );
  stest8( "HTTP/1.0 /10k.raw", "http/http10.pike", "/10k.raw", 1024*10 );
  stest8( "HTTP/1.0 /",        "http/http10.pike", "/",        0 );
  stest8( "HTTP/1.0 /nofile",  "http/http10.pike", "/nofile",  0 );

  stest9( "HTTP/1.0 /1k.raw",  "http/http10.pike", "/1k.raw",  1024 );
  stest9( "HTTP/1.0 /10k.raw", "http/http10.pike", "/10k.raw", 1024*10 );
  stest9( "HTTP/1.0 /",        "http/http10.pike", "/",        0 );
  stest9( "HTTP/1.0 /nofile",  "http/http10.pike", "/nofile",  0 );

  stest10( "HTTP/1.0 /1k.raw",  "http/http10.pike", "/1k.raw",  1024 );
  stest10( "HTTP/1.0 /10k.raw", "http/http10.pike", "/10k.raw", 1024*10 );
  stest10( "HTTP/1.0 /",        "http/http10.pike", "/",        0 );
  stest10( "HTTP/1.0 /nofile",  "http/http10.pike", "/nofile",  0 );

  stest11( "HTTP/1.0 /1k.raw",  "http/http10.pike", "/1k.raw",  0 );
  stest11( "HTTP/1.0 /10k.raw", "http/http10.pike", "/10k.raw", 0 );
  stest11( "HTTP/1.0 /",        "http/http10.pike", "/",        0 );
  stest11( "HTTP/1.0 /nofile",  "http/http10.pike", "/nofile",  0 );

  //  stest4( "HTTP/1.1 /1k.raw",  "http/http11.pike", "/1k.raw",  1024 );
  //  stest4( "HTTP/1.1 /10k.raw", "http/http11.pike", "/10k.raw", 1024*10 );
  //  stest4( "HTTP/1.1 /",        "http/http11.pike", "/",        0 );
  //  stest4( "HTTP/1.1 /nofile",  "http/http11.pike", "/nofile",  0 );
}
