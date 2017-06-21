// $Id$
//
// Tests of the ftp protocol module.
//
// Henrik Grubbström 2001-08-23

inherit "../pike_async_process_test_common";

string simple_check()
{
  return common_wait(([
    2:"Bad URL",
    3:"Connection failed",
    4:"Timeout",
    5:"Connection closed",
    6:"Write failed",
    7:"Bad protocol code",
    8:"Bad data",
  ]));
}

function run(string script, int testno)
{
  return lambda() {
	   // Really a misnomer, but...
	   if (!http_url) {
	     foreach(c->query("URLs"), string url) {
	       if(has_prefix( url, "ftp://")) {
		 http_url = (url/"#")[0];
	       }
	     }
	     if(!http_url) {
	       werror("Cannot run test -- no FTP port open\n");
	       return;
	     }
	   }

	   run_pikescript(script, (string)testno);
	 };
}

void setup()
{
  int testno;

  atest("FTP protocol test", run("ftp/ftp_test.pike", testno++), simple_check);
}
