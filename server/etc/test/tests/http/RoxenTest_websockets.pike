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

function run( string script, string file, int|string ... ma  )
{
  return lambda() {
	   run_pikescript( script, file, @((array(string))ma) );
	 };
}

#define rtest( COMMENT, SCRIPT, PATH, ARGS...) \
  atest(COMMENT, run(SCRIPT, PATH, ARGS), simple_check)

// NB: Keep in sync with the brokeness enum in websocket.pike.
constant descriptions = ({
  "Trivial",
  "Bad path",
  "Bad path suffix",
  "Bad HTTP version",
  "No Connection header",
  "Bad Connection header",
  "No Upgrade header",
  "Bad Upgrade header",
  "No Sec-WebSocket-Version header",
  "Bad Sec-WebSocket-Version header",
  "No Sec-WebSocket-Key header",
  "Bad Sec-WebSocket-Key header",
});

void setup( )
{
  foreach(descriptions; int i; string descr) {
    rtest(descr, "http/websocket.pike", "/websocket_example/", i, descr);
  }
}
