// $Id: ftp_test.pike,v 1.1 2001/08/24 12:04:06 grubba Exp $
//
// Tests of the ftp protocol module.
//
// Henrik Grubbström 2001-08-24

constant BADARG = 2;
constant NOCONN = 3;
constant TIMEOUT = 4;
constant CONCLOSED = 5;
constant WRITEFAIL = 6;
constant BADCODE = 7;

// Connection setup.

array get_host_port( string url )
{
  string host;
  int port;

  if( sscanf( url, "ftp://%s:%d/", host, port ) != 2 )
    exit( BADARG );
  return ({ host, port });
}

Stdio.File connect( string url )
{
  Stdio.File f = Stdio.File();
  [string host, int port] = get_host_port( url );
  if( !f->connect( (host=="*"?"127.0.0.1":host), port ) )
    exit( NOCONN );

  return f;
}

// Timeout handling

int timestamp;

void touch()
{
  timestamp = time();
}

void timer()
{
  int t = time();

  if (t - timestamp > 30) {
    werror("TIMEOUT!\n");
    werror("Last sent: %O\n", last_sent);
    werror("got_code: %O\n", got_code);
    exit(TIMEOUT);
  }
  call_out(timer, 10);
}

// State machine.

Stdio.File con;

int done;

string inbuf = "";

array(array(string|function(string, string:void))) got_code = ({
  ({ "220", send_user })
});

void got_data(mixed ignored, string data)
{
  inbuf += data;

  array(string) lines = inbuf/"\r\n";

  string code;
  string line_block = "";

  foreach(lines[..sizeof(lines)-2], string line) {
    line_block += line + "\r\n";
    if (!code) {
      code = line[..2];
    }
    if (line[0] != ' ' && line[3] == ' ') {
      array(array(string|function(string, string:void))) cbs =
	got_code + ({ ({ "", bad_code }) });
      got_code = ({});
      foreach(cbs, array(string|function(string,string:void)) cb_info) {
	if (has_prefix(code, cb_info[0])) {
	  cb_info[1](code, line_block);
	  break;
	}
      }
      code = 0;
      line_block = "";
    }
  }
  inbuf = line_block + lines[-1];
}

void con_closed()
{
  exit(!done && CONCLOSED);
}

// Write queue handling.

string sendq = "";
string last_sent = "";

void send(string command)
{
  if (!sizeof(sendq)) {
    con->set_write_callback(do_send);
  }
  sendq += command + "\r\n";
}

void do_send(mixed ignored)
{
  int bytes = con->write(sendq, 1);

  if (bytes < 0) {
    exit(WRITEFAIL);
  }
  if (!bytes) {
    exit(CONCLOSED);
  }
  last_sent = sendq[..bytes-1];
  if (bytes == sizeof(sendq)) {
    con->set_write_callback(0);
    sendq = "";
  } else {
    // Partial write.
    sendq = sendq[bytes..];
  }
}

// High-level protocol stuff.

void bad_code(string code, string lines)
{
  werror("Unexpected response code: %O\n", code);
  werror("Last sent:%O\n", last_sent);
  werror("Raw:\n%s\n", lines);
  exit(BADCODE);
}

void send_user(string code, string lines)
{
  send("USER ftp");
  got_code = ({ ({ "331", send_pass }),
		({ "230", send_help }) });
}

void send_pass(string code, string lines)
{
  send("PASS roxentest@*");
  got_code = ({ ({ "230", send_help }) });
}

void send_help(string code, string lines)
{
  send("HELP");
  got_code = ({ ({ "214", send_feat }) });
}

void send_feat(string code, string lines)
{
  send("FEAT");
  got_code = ({ ({ "211", send_stat }) });
}

void send_stat(string code, string lines)
{
  send("STAT");
  got_code = ({ ({ "211", send_stat_root }) });
}

void send_stat_root(string code, string lines)
{
  send("STAT /");
  got_code = ({ ({ "213", send_mlst_root }) });
}

void send_mlst_root(string code, string lines)
{
  send("MLST /");
  got_code = ({ ({ "250", send_quit }) });
}

void send_quit(string code, string lines)
{
  send("QUIT");
  got_code = ({ ({ "221", got_quit }) });
}

void got_quit(string code, string lines)
{
  done = 1;
  got_code = ({});
}

// Initialization.

int main(int argc, array(string) argv)
{
  string url = argv[1];

  con = connect(url);

  con->set_nonblocking(got_data, 0, con_closed);

  call_out(timer, 10);

  touch();

  return -1;
}
