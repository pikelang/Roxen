/*
 * $Id: smtprelay.pike,v 2.11 2003/09/03 11:20:59 grubba Exp $
 *
 * An SMTP-relay RCPT module for the AutoMail system.
 *
 * Henrik Grubbström 1998-09-02, 1999-10-18.
 */

#include <module.h>

inherit "module";

#define RELAY_DEBUG

#pragma strict_types

constant cvs_version = "$Id: smtprelay.pike,v 2.11 2003/09/03 11:20:59 grubba Exp $";

/*
 * Some globals
 */

#ifdef THREADS
static Thread.Mutex queue_mutex = Thread.Mutex();
#endif /* THREADS */

static Configuration conf;
static Sql.sql sql;

static Protocols.DNS.async_client dns = Protocols.DNS.async_client();

/*
 * Roxen glue
 */

array register_module()
{
  return({ MODULE_PROVIDER,
	   "SMTP-relay",
	   "SMTP-relay RCPT module for the AutoMail system." });
}

void create()
{
  defvar("spooldir", "/var/spool/mqueue/", "Mail queue directory", TYPE_DIR,
	 "Directory where the mail spool queue is stored.");

  defvar("sqlurl", "mysql://mail:mail@/mail", "Database URL",
	 TYPE_STRING, "");

  defvar("maxhops", 10, "Limits: Maximum number of hops", TYPE_INT,
	 "Maximum number of MTA hops (used to avoid loops).<br>\n"
	 "Zero means no limit.");

  defvar("bounce_size_limit", 262144, "Limits: Maximum bounce size", TYPE_INT,
	 "Maximum size (bytes) of the embedded message in generated bounces.");

  // Try to get our FQDN.
  string hostname = gethostname();
  array(string) hostinfo = gethostbyname(hostname);
  if (hostinfo && sizeof(hostinfo)) {
    hostname = hostinfo[0];
  }

  defvar("hostname", hostname, "Mailserver host name", TYPE_STRING,
	 "This is the hostname used by the server in the SMTP "
	 "handshake (EHLO & HELO).");

  defvar("postmaster", "Postmaster <postmaster@" + hostname + ">",
	 "Postmaster address", TYPE_STRING,
	 "Email address of the postmaster.");

  defvar("mailerdaemon", "Mail Delivery Subsystem <MAILER-DAEMON@" +
	 hostname + ">", "Mailer daemon address", TYPE_STRING,
	 "Email address of the mailer daemon.");
}

array(string)|multiset(string)|string query_provides()
{
  return(< "smtp_relay" >);
}

string status()
{
  if (!sql) {
    return("<font color=red>Failed to connect to sql database!</font>");
  }
  return("Connected OK.");
}

void start(int i, Configuration c)
{
  if (c) {
    conf = c;

    if (!catch { sql = Sql.sql([string]QUERY(sqlurl)); }) {

      /* Initialize the sql-database if needed */
      init_db();

      /* Start delivering mail soon after everything has loaded. */
      check_mail(10);
    } else {
      /* Try reconnecting to the SQL-server in a minute */
      remove_call_out(start);
      call_out(start, 60, i, c);
    }
  }
}

/*
 * Helper functions
 */

constant weekdays = ({ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" });
constant months = ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
		     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" });

static string mktimestamp(int t)
{
  mapping(string:int) lt = localtime(t);
    
  string tz = "GMT";
  int off;
  
  if (off = -lt->timezone) {
    tz = sprintf("GMT%+d", off/3600);
  }
  if (lt->isdst) {
    tz += "DST";
    off += 3600;
  }
  
  off /= 60;
  
  return(sprintf("%s, %02d %s %04d %02d:%02d:%02d %+03d%02d (%s)",
		 weekdays[lt->wday], lt->mday, months[lt->mon],
		 1900 + lt->year, lt->hour, lt->min, lt->sec,
		 off/60, off%60, tz));
}

static string get_addr(string addr)
{
  array a = MIME.tokenize(addr);

  int i;

  if ((i = search(a, '<')) != -1) {
    int j = search(a, '>', i);

    if (j != -1) {
      a = a[i+1..j-1];
    } else {
      // Mismatch, no '>'.
      a = a[i+1..];
    }
  }

  for(i = 0; i < sizeof(a); i++) {
    if (intp(a[i])) {
      if (a[i] == '@') {
	a[i] = "@";
      } else {
	a[i] = "";
      }
    }
  }
  return(a*"");
}

/*
 * Async connection to socket.
 */

constant ACON_REFUSED = 0;
constant ACON_LOOP = -1;
constant ACON_DNS_FAIL = -2;

static void async_connected(int status,
			    function(int|object, mixed ...:void) cb,
			    object f, mixed ... args)
{
  /* Done */
  cb(status && f, @args);
}

static void async_connect_got_hostname(string host, int port,
				       function(int|object, mixed ...:void) cb,
				       mixed ... args)
{
  if (!host) {
    // DNS Failure

    cb(ACON_DNS_FAIL, @args);
    return;
  }

  // Check that we aren't looping.
  object(Stdio.Port) p = Stdio.Port();

  if (p->bind(0,0,host)) {
    // We were just about to connect to ourselves!

    cb(ACON_LOOP, @args);
    destruct(p);
    return;
  }
  destruct(p);

  // Looks OK so far. Try connecting.
  object(Stdio.File) f = Stdio.File();

  if (!f->async_connect(host, port, async_connected, cb, f, @args)) {
    // Connection failed.
    cb(ACON_REFUSED, @args);
    return;
  }
}

int async_connect_not_self(string host, int port,
			   function(int|Stdio.File, mixed ...:void) callback,
			   mixed ... args)
{
#ifdef SOCKET_DEBUG
  roxen_perror("SOCKETS: async_connect requested to "+host+":"+port+"\n");
#endif
  roxen->host_to_ip(host, async_connect_got_hostname, port, callback, @args);
}

class SMTP_Reader
{
  object(Stdio.File) con;

  int sent_bytes;
  int recv_bytes;

  static string read_buffer = "";

  static function(string, array(string):void) _got_code;

  /* ({ ({ "code", ({ "line 1", "line 2" }) }) }) */
  static array(array(string|array(string))) codes = ({});

  /* ({ "line1", "line2" }) */
  static array(string) partial = ({});

  static void reset()
  {
    if (con) {
      con->close();
      con = 0;
    }
    read_buffer = "";
    _got_code = 0;
    codes = ({});
    partial = ({});
  }

  static void call_callback()
  {
    function(string, array(string):void) cb = _got_code;
    _got_code = 0;

    if (sizeof(codes)) {
      string code = [string]codes[0][0];
      array(string) text = [array(string)]codes[0][1];
      codes = codes[1..];

      cb(code, text);
      return;
    }
    cb(0, 0);
  }

  static void parse_buffer()
  {
    array(string) arr = read_buffer/"\r\n";

    if (sizeof(arr) > 1) {
      read_buffer = arr[-1];

      int i;
      for(i=0; i < sizeof(arr)-1; i++) {
	if ((sizeof(arr[i]) < 3) ||
	    ((sizeof(arr[i]) > 3) && (arr[i][3] == '-'))) {
	  // Broken code, or continuation line.
	  if (sizeof(arr[i]) > 4) {
	    partial += ({ arr[i][4..] });
	  }
	} else {
	  codes += ({ ({ arr[i][..2], partial + ({ arr[i][4..] }) }) });
	  partial = ({});
	}
      }
    }
  }

  static void con_closed(mixed ignored)
  {
    if (con) {
      con->set_nonblocking(0,0,0);
      con->close();
      con = 0;
    }
    if (read_buffer != "") {
      // Some data left in the buffer.
      // Add a terminating "\r\n", and parse it.
      if (read_buffer[-1] == '\r') {
	read_buffer += "\n";
      } else {
	read_buffer += "\r\n";
      }
      parse_buffer();
    }

    call_callback();
  }

  static void got_data(mixed ignored, string s)
  {
    read_buffer += s;

    recv_bytes += sizeof(s);

    parse_buffer();

    if (sizeof(codes)) {
      con->set_nonblocking(0,0,0);

      call_callback();
    }
  }

  static void async_get_code(function(string, array(string):void) cb)
  {
    _got_code = cb;

    if (con) {
      con->set_nonblocking(got_data, 0, con_closed);
    } else {
      call_out(call_callback, 0);
    }
  }

  static string send_buffer = "";

  static void write_data(mixed ignored)
  {
    int n = con->write(send_buffer);

    if (n <= 0) {
      // Error!
      con->set_nonblocking(0,0,0);
      con->close();
      con = 0;

      call_callback();
      return;
    }

    sent_bytes += n;

    send_buffer = send_buffer[n..];
    if (send_buffer == "") {
      if (sizeof(codes)) {
	// Already received a reply?
	// This shouldn't happen...
	// But better safe than sorry...
	con->set_nonblocking(0,0,0);

	call_callback();
	return;
      }
      con->set_nonblocking(got_data, 0, con_closed);
      return;
    }
    // More data to send.
  }

  string last_command = "";

  static void send_command(string command,
			   function(string, array(string):void) cb)
  {
    last_command = command;

    _got_code = cb;

    if (con) {
      send_buffer += command + "\r\n";

      con->set_nonblocking(0, write_data, 0);
    } else {
      // Connection closed.
      call_out(call_callback, 0);
    }
  }
}

constant SEND_OK = 1;
constant SEND_FAIL = 0;
constant SEND_OPEN_FAIL = -1;
constant SEND_ADDR_FAIL = -2;
constant SEND_DNS_UNKNOWN = -3;

class MailSender
{
  inherit SMTP_Reader;

  static mapping(string:string) message;
  static array(string) servers;
  static int servercount;

  static object(Stdio.File) mail;

  static function(int, mapping:void) send_done;

  static multiset(string) esmtp_features = (<>);

  static void send_bounce(string code, array(string) text)
  {
    message->sent += sent_bytes;
    sent_bytes = 0;

    if (!code) {
      code = "221";
      text = ({ "Connection closed unexpectedly by foreign host." });
    }

    bounce(message, code, text, last_command);

    send_command("QUIT", got_quit_reply_fail);
  }

  static void send_bounce_and_stop(string code, array(string) text)
  {
    message->sent += sent_bytes;
    sent_bytes = 0;
    bounce(message, code, text, last_command);

    send_command("QUIT", got_quit_reply_stop);
  }

  static void bad_address(string code, array(string) text)
  {
    send_bounce_and_stop(code, text);
  }

  static void got_quit_reply_ok(string code, array(string) text)
  {
    if (con) {
      con->close();
      con = 0;
    }
    message->sent += sent_bytes;
    sent_bytes = 0;
    send_done(SEND_OK, message);
  }

  static void got_quit_reply_fail(string code, array(string) text)
  {
    if (con) {
      con->close();
      con = 0;
    }
    connect_and_send();
  }

  static void got_quit_reply_stop(string code, array(string) text)
  {
    if (con) {
      con->close();
      con = 0;
    }
    message->sent += sent_bytes;
    sent_bytes = 0;

    send_done(SEND_ADDR_FAIL, message);
  }

  static void got_message_reply(string code, array(string) text)
  {
    switch(code) {
    case "250":
      // Message sent OK.
      send_command("QUIT", got_quit_reply_ok);
      break;
    default:
      if (code && (code[0] == '5')) {
	send_bounce_and_stop(code, text);
      } else {
	send_bounce(code, text);
      }
      break;
    }
  }

  static void message_sent(int bytes)
  {
    sent_bytes += bytes;

    send_command(".", got_message_reply);
  }

  static void got_data_reply(string code, array(string) text)
  {
    switch(code) {
    case "354":
      // DATA OK.
      // Send the actual message.
      // Note that the spoolfile has already been sufficiently quoted.
      // Required quoting:
      //   * No lone '\r' or '\n', only "\r\n".
      //   * If a line starts with '.', it must be doubled.
      //   * The file must end with "\r\n".
      Stdio.sendfile(0, mail, 0, -1, 0, con, message_sent);
      break;
    default:
      // Bounce.
      send_bounce(code, text);
      break;
    }
  }

  static void got_rcpt_to_reply(string code, array(string) text)
  {
    switch((code || "00")[..1]) {
    case "25":
      // RCPT TO: OK.
      send_command("DATA", got_data_reply);
      break;
    case "55":
      // Bad address.
      bad_address(code, text);
      break;
    default:
      // Try the mext MX.
      send_command("QUIT", got_quit_reply_fail);
      break;
    }
  }

  static void got_mail_from_reply(string code, array(string) text)
  {
    switch(code) {
    case "250":
      // MAIL FROM: OK.
      send_command(sprintf("RCPT TO:<%s@%s>",
			   message->user, message->domain),
		   got_rcpt_to_reply);
      break;
    default:
      if (code && (code[0] == '5')) {
	// The sender isn't allowed to send messages to this server.
	send_bounce_and_stop(code, text);
      } else {
	// Try the next MX.
	send_command("QUIT", got_quit_reply_fail);
      }
      break;
    }
  }

  static void got_helo_reply(string code, array(string) text)
  {
    switch(code) {
    case "250":
      // HELO OK.
      send_command(sprintf("MAIL FROM:<%s>", message->sender),
		   got_mail_from_reply);
      break;
    default:
      // Try the next MX.
      send_command("QUIT", got_quit_reply_fail);
      break;
    }
  }

  static void got_ehlo_reply(string code, array(string) text)
  {
    switch(code) {
    case "250":
      // EHLO OK.
      if (sizeof(text) > 1) {
	// Parse EHLO reply
	esmtp_features = [multiset(string)](<
	  @Array.map(text[1..], lower_case)
	>);
      }
      string extras = "";
      if (esmtp_features["8bitmime"]) {
	extras += " BODY=8BITMIME";
      }
      if (esmtp_features["size"]) {
	array|Stdio.Stat a = mail->stat();
	if (a && (a[1] >= 0)) {
	  // Add some margin for safety.
	  extras += " SIZE="+(a[1]+128);
	}
      }
      send_command(sprintf("MAIL FROM:<%s>%s", message->sender, extras),
		   got_mail_from_reply);
      break;
    case "221":
      // Server too busy?
      // Try the next MX.
      got_quit_reply_fail(code, text);
      break;
    case 0:
      // Disconnected.
      // EHLO not supported in a bad way.
      // FIXME: Try reconnecting with HELO.
      // Workaround: Try the next MX.
      got_quit_reply_fail(0, 0);
      break;
    default:
      // EHLO not supported.
      // Try HELO.
      message->prot = "SMTP";
      send_command(sprintf("HELO %s", QUERY(hostname)), got_helo_reply);
      break;
    }
  }

  static void got_con_reply(string code, array(string) text)
  {
    switch(code) {
    case "220":
      message->prot = "ESMTP";
      send_command(sprintf("EHLO %s", QUERY(hostname)), got_ehlo_reply);
      break;
    case 0:
      // Immediate disconnect.
      // Try the next MX.
      got_quit_reply_fail(0, 0);
      break;
    default:
      send_command("QUIT", got_quit_reply_fail);
      break;
    }
  }

  static void got_connection(int|object(Stdio.File) c)
  {
    message->sent += sent_bytes;
    sent_bytes = 0;

    if (intp(c)) {
      switch(c) {
      case ACON_REFUSED:
	// Try the next one.
	connect_and_send();
	break;
      case ACON_LOOP:
	if (servercount == 1) {
	  // We're the primary MX!
	  bounce(message, "554",
		 sprintf("MX list for %s points back to %s(%s)\n"
			 "<%s@%2>... Local configuration error",
			 message->domain, message->remote_mta, QUERY(hostname),
			 message->user, message->domain)/"\n",
		 "");
	  send_done(SEND_ADDR_FAIL, message);
	  return;
	}
	// Try again later.
	send_done(SEND_FAIL, message);
	break;;
      case ACON_DNS_FAIL:
	if (sizeof(servers) == 1) {
	  // Permanently bad address.
	  message->status = "5.1.2";
	  bounce(message, "550",
		 sprintf("DNS lookup failed for SMTP server %s",
			 message->remote_mta)/"\n",
		 "");
	  send_done(SEND_DNS_UNKNOWN, message);
	  return;
	}
	bounce(message, "550",
	       sprintf("DNS lookup failed for SMTP server %s",
		       message->remote_mta)/"\n",
	       "");
	// Try the next server.
	connect_and_send();
	break;
      }
      return;
    }

    // Connection ok.

    // Reset buffers etc.
    reset();

    con = [object(Stdio.File)]c;

    async_get_code(got_con_reply);
  }

  static void connect_and_send()
  {
    // Try the next SMTP server.
    int server = servercount++;

    if (server >= sizeof(servers)) {
      // Failure.

      call_out(send_done, 0, SEND_FAIL, message);

      // Make sure we don't have any circular references.
      reset();
      send_done = 0;

      return;
    }

#ifdef RELAY_DEBUG
    report_debug(sprintf("SMTP: Trying with the SMTP server at %s\n",
			 servers[server]));
#endif /* RELAY_DEBUG */

    esmtp_features = (<>);

    message->remote_mta = servers[server];
    message->last_attempt_at = (string)time();

    mail->seek(0);

    async_connect_not_self(servers[server], 25, got_connection);
  }

  static void got_mx(array(string) mx)
  {
    if (!(servers = mx)) {
      // No MX record for the domain.
      servers = ({ message->domain });
    }
    
    connect_and_send();
  }

  void create(mapping(string:string) m, function(int, mapping:void) cb)
  {
    string fname = combine_path(QUERY(spooldir), m->mailid);

    mail = Stdio.File();
    if (!(mail->open(fname, "r"))) {
      report_error(sprintf("Failed to open spoolfile %O\n", fname));
      call_out(cb, 0, SEND_OPEN_FAIL, m);
      return;
    }

    message = m;

    send_done = cb;

#ifdef RELAY_DEBUG
    report_debug(sprintf("Sending %O to %s@%s from %s...\n",
			 message->mailid, message->user, message->domain,
			 message->sender));
#endif /* RELAY_DEBUG */

    dns->get_mx(message->domain, got_mx);    
  }
}

static void mail_sent(int res, mapping message)
{
  // Fake request id for logging purposes.
  RequestID id = RequestID(0, 0, conf);
  id->method = "SEND";
  id->prot = message->prot || "SMTP";
  id->remoteaddr = message->remote_mta || "0.0.0.0";
  id->time = time();
  id->cookies = ([]);
  id->not_query = sprintf("From:%s;To:%s@%s;%s",
			  message->sender,
			  message->user, message->domain,
			  message->mailid);
  if (res) {
    // res != SEND_FAIL
    switch(res) {
    case SEND_OK:
      conf->log(([ "error":200, "len":message->sent ]), id);
      report_notice(sprintf("SMTP: Mail %O sent successfully!\n",
			    message->mailid));
      break;
    case SEND_OPEN_FAIL:
      conf->log(([ "error":404 ]), id);
      report_error(sprintf("SMTP: Failed to open %O!\n",
			   message->mailid));
      
      return;	// FIXME: Should we remove it from the queue or not?
    case SEND_ADDR_FAIL:
      conf->log(([ "error":410 ]), id);
      report_error(sprintf("SMTP: Permanently bad address %s@%s\n",
			   message->user, message->domain));
      break;
    case SEND_DNS_UNKNOWN:
      conf->log(([ "error":503 ]), id);
      report_error(sprintf("SMTP: Unknown SMTP server %s for domain %s\n",
			   message->remote_mta, message->domain));
      break;
    }

#ifdef THREADS
    mixed key = queue_mutex->lock();
#endif /* THREADS */
    sql->query(sprintf("DELETE FROM send_q WHERE id=%s", message->id));

    array a = sql->query(sprintf("SELECT id FROM send_q WHERE mailid='%s'",
				 sql->quote(message->mailid)));

    if (!a || !sizeof(a)) {
      rm(combine_path(QUERY(spooldir), message->mailid));
    }
  } else {
    // res == SEND_FAIL
    conf->log(([ "error":408 ]), id);
    report_notice(sprintf("SMTP: Sending of %O failed!\n",
			  message->mailid));
  }
}

static int check_interval = 0x7fffffff;

static void send_mail()
{
#ifdef RELAY_DEBUG
  // roxen_perror("SMTP: send_mail()\n");
#endif /* RELAY_DEBUG */

  check_interval = 0x7fffffff;

#ifdef THREADS
  mixed key = queue_mutex->lock();
#endif /* THREADS */
  // Select some mail to send.
  array m = sql->query(sprintf("SELECT * FROM send_q WHERE send_at < %d "
			       "ORDER BY mailid, domain",
			       time()));

  // FIXME: Add some grouping code here.

  foreach(m || ({}), mapping mm) {
    // Needed to not send it twice at the same time.
    // Resend in an hour.
    sql->query(sprintf("UPDATE send_q "
		       "SET send_at = %d, times = %d WHERE id = %s",
		       time() + 60*60, ((int)mm->times) + 1, mm->id));
    // Send the message.
    MailSender(mm, mail_sent);
  }

  // Recheck again in 10 sec <= X <= 1 hour.

  m = sql->query("SELECT min(send_at) AS send_at FROM send_q");

  int t = 60*60;
  if (m && sizeof(m) && (m[0]->send_at)) {
    t = ((int)m[0]->send_at) - time();
#ifdef RELAY_DEBUG
    // roxen_perror(sprintf("t:%d\n", t));
#endif /* RELAY_DEBUG */
    if (t < 10) {
      t = 10;
    } else if (t > 60*60) {
      t = 60 * 60;
    }
  }

  check_mail(t);
}

static mixed send_mail_id;
static void check_mail(int t)
{
#ifdef RELAY_DEBUG
  // roxen_perror(sprintf("SMTP: check_mail(%d)\n", t));
#endif /* RELAY_DEBUG */
  if (check_interval > t) {
    check_interval = t;
    if (send_mail_id) {
      // Keep only one send_mail() at a time. 
      remove_call_out(send_mail_id);
    }
    // Send mailid asynchronously.
    send_mail_id = call_out(send_mail, t);
  }
}

/*
 * Callable from elsewhere to send messages
 */
int send_message(string from, multiset(string) rcpt, string message)
{
#ifdef RELAY_DEBUG
  report_debug(sprintf("SMTP: send_message(%O, %O, X)\n", from, rcpt));
#endif /* RELAY_DEBUG */

  array a = indices(rcpt);
  rcpt = (<>);
  foreach(a, string addr) {
    rcpt[get_addr(addr)] = 1;
  }

  int sent;
  foreach(conf->get_providers("smtp_protocol")||({}), object o) {
    if (o->send_mail) {
      array a = o->send_mail(message, ([ "from":from, "recipients":rcpt ]));
      if (a[0]/100 == 2) {
	sent = 1;
	break;
      }
    }
  }
  if (!sent) {
    report_error(sprintf("send_message(%O, %O, %O) Failed!\n",
			 from, rcpt, message));
  }
  return(sent);
}

/*
 * Used to bounce error messages
 */

void bounce(mapping msg, string code, array(string) text, string last_command,
	    string|void body)
{
  // FIXME: Generate a bounce.

#ifdef RELAY_DEBUG
  report_debug(sprintf("SMTP: bounce(%O, %O, %O, %O)\n",
		       msg, code, text, last_command));
#endif /* RELAY_DEBUG */

  if (sizeof(msg->sender)) {
    // Send a bounce.

    // Create a bounce message.

    Stdio.File f = Stdio.File();
    string oldmessage = "";
    string oldheaders = "";
    int only_headers;
    if (f->open(combine_path(QUERY(spooldir), msg->mailid), "r")) {
      int i;
      string s;
      while((s = f->read(8192)) && (s != "")) {
	oldmessage += s;

	if (sizeof(oldmessage) > QUERY(bounce_size_limit)) {
	  // Too large bounce.
	  if ((i = search(oldmessage, "\r\n\r\n")) != -1) {
	    // Just keep the headers.
	    // FIXME: What about the content-length header?
	    oldmessage = oldmessage[..i+1];
	  } else {
	    // Lots of headers.
	    oldmessage =
	      "Subject: Huge amount of headers -- Headers truncated\r\n";
	  }
	  only_headers = 1;
	  break;
	}
      }
      f->close();
      oldheaders = oldmessage;
      if (i = search(oldheaders, "\r\n\r\n")) {
	oldheaders = oldheaders[..i+1];
      } 
    }

    string statusmessage;
    if (sizeof(msg->remotename)) {
      statusmessage = sprintf("Reporting-MTA: DNS; %s\r\n"
			      "Received-From-MTA: DNS; %s\r\n"
			      "Arrival-Date: %s\r\n"
			      "\r\n"
			      "Final-Recipient: RFC822; %s@%s\r\n"
			      "Action: failed\r\n"
			      "Status: %s\r\n"
			      "Remote-MTA: DNS; %s\r\n"
			      "Diagnostic-Code: SMTP; %s %s\r\n"
			      "Last-Attempt-Date: %s\r\n",
			      gethostname(),
			      msg->remotename,
			      mktimestamp((int)msg->received_at),
			      msg->user, msg->domain,
			      msg->status || "5.1.1",
			      msg->remote_mta,
			      code, sizeof(text)?text[-1]:"",
			      mktimestamp((int)msg->last_attempt_at));
    } else {
      statusmessage = sprintf("Reporting-MTA: DNS; %s\r\n"
			      "Arrival-Date: %s\r\n"
			      "\r\n"
			      "Final-Recipient: RFC822; %s@%s\r\n"
			      "Action: failed\r\n"
			      "Status: %s\r\n"
			      "Remote-MTA: DNS; %s\r\n"
			      "Diagnostic-Code: SMTP; %s %s\r\n"
			      "Last-Attempt-Date: %s\r\n",
			      gethostname(),
			      mktimestamp((int)msg->received_at),
			      msg->user, msg->domain,
			      msg->status || "5.1.1",
			      msg->remote_mta,
			      code, sizeof(text)?text[-1]:"",
			      mktimestamp((int)msg->last_attempt_at));
    }

    if (!body) {
      body = sprintf("Message to %s@%s from %s bounced (code %s):\r\n"
		     "Mailid:%s\r\n"
		     "%s"
		     "Description:\r\n"
		     "%s\r\n",
		     msg->user, msg->domain, msg->sender, code,
		     msg->mailid,
		     sizeof(last_command)?
		     ("Last command: "+last_command+"\r\n"):"",
		     text*"\r\n");
    }
    // Send a bounce
    string message = (string)
      MIME.Message(body, ([
	"Subject":"Delivery failure",
	"Message-Id":sprintf("<\"%08x%sfull\"@%s>",
			     time(), msg->mailid, gethostname()),
	"X-Mailer":roxen->version(),
	"MIME-Version":"1.0",
	"From":QUERY(mailerdaemon),
	"To":msg->sender,
	"Date":mktimestamp(time(1)),
	"Auto-Submitted":"auto-generated (failure)",
	"Content-Type":"multipart/report; Report-Type=delivery-status",
	"Content-Transfer-Encoding":"8bit",
      ]), ({
	MIME.Message(body, ([
	  "MIME-Version":"1.0",
	  "Content-Type":"text/plain; charset=iso-8859-1",
	  "Content-Transfer-Encoding":"8bit",
	])),
	MIME.Message(statusmessage, ([
	  "MIME-Version":"1.0",
	  "Content-Type":"message/delivery-status; charset=iso-8859-1",
	  "Content-Transfer-Encoding":"8bit",
	])),
	MIME.Message(oldmessage, ([
	  "MIME-Version":"1.0",
	  "Content-Type":
	  (only_headers?"message/rfc822-headers":"message/rfc822"),
	])),
      }));
    send_message("", (< msg->sender >), message);

    // Inform the postmaster too, but send only the headers.
    message = (string)
      MIME.Message(body, ([
	"Subject":"Delivery failure",
	"Message-Id":sprintf("<\"%08x%shead\"@%s>",
			     time(1), msg->mailid, gethostname()),
	"X-Mailer":roxen->version(),
	"MIME-Version":"1.0",
	"From":QUERY(mailerdaemon),
	"To":QUERY(postmaster),
	"Date":mktimestamp(time()),
	"Auto-Submitted":"auto-generated (failure)",
	"Content-Type":"multipart/report; Report-Type=delivery-status",
	"Content-Transfer-Encoding":"8bit",
      ]), ({
	MIME.Message(body, ([
	  "MIME-Version":"1.0",
	  "Content-Type":"text/plain; charset=iso-8859-1",
	  "Content-Transfer-Encoding":"8bit",
	])),
	MIME.Message(statusmessage, ([
	  "MIME-Version":"1.0",
	  "Content-Type":"message/delivery-status; charset=iso-8859-1",
	  "Content-Transfer-Encoding":"8bit",
	])),
	MIME.Message(oldheaders, ([
	  "MIME-Version":"1.0",
	  "Content-Type":"text/rfc822-headers",
	])),
      }));
    send_message("", (< QUERY(postmaster) >), message);
  } else {
    report_warning("SMTP: A bounce which bounced!\n");
  }
}

/*
 * SMTP_RELAY callbacks
 */

int relay(string from, string user, string domain,
	  Stdio.BlockFile mail, string csum, object|void smtp)
{
#ifdef RELAY_DEBUG
  report_debug(sprintf("SMTP: relay(%O, %O, %O, X, %O, X)\n",
		       from, user, domain, csum));
#endif /* RELAY_DEBUG */

  if (!sql) {
    /* Module is not properly configured yet... */
    return(0);
  }

  if (!domain) {
    // Shouldn't happen, but...
    return(0);
  }

  // Some more filtering here?

  // Calculate the checksum if it isn't calculated already.

  if (!csum) {
    Crypto.sha sha = Crypto.sha();
    string s;
    mail->seek(0);
    while ((s = mail->read(8192)) && (s != "")) {
      sha->update(s);
    }
    csum = sha->digest();
  }

  csum = replace(MIME.encode_base64(csum), "/", ".");

  // Queue mail for sending.

  // NOTE: We assume that an SHA checksum will never occur twice.

  string fname = combine_path(QUERY(spooldir), csum);

#ifdef THREADS
  mixed key = queue_mutex->lock();
#endif /* THREADS */

  if (!file_stat(fname)) {
    Stdio.File spoolfile = Stdio.File();
    if (!spoolfile->open(fname, "cwxa")) {
      report_error(sprintf("SMTPRelay: Failed to open spoolfile %O!\n",
			   fname));

      // FIXME: Should send a message to from here.

      return(0);
    }

    mail->seek(0);
    string s;
    string headers = "";
    int headers_found;
    string rest = "";
    int last_was_lf = 1;
    while((s = mail->read(8192)) && (s != "")) {
      if (last_was_lf && (rest == "") && (s[0] == '.')) {
	s = "." + s;
      } else {
	s = rest + s;
      }
      if (s[-1] == '\r') {
	rest = "\r";
	s = s[..sizeof(s)-2];
      } else {
	rest = "";
      }
      // Perform quoting...
      s = replace(s, ({ "\r.", "\n.", "\r\n.", 
			"\r", "\n", "\r\n", }),
		  ({ "\r\n..", "\r\n..", "\r\n..",
		     "\r\n", "\r\n", "\r\n" }));
      last_was_lf = (s[-1] == '\n');

      if (QUERY(maxhops) && !headers_found) {
	headers += s;
	headers_found = (sscanf(headers, "%s\r\n\r\n", headers) ||
			 sscanf(headers, "%s\n\n", headers));
	if (headers_found) {
	  array a = lower_case(headers)/"received:";
	  int hops = sizeof(a);

	  headers = "";

#ifdef RELAY_DEBUG
	  report_debug(sprintf("SMTPRelay: raw hops:%d\n", hops));
#endif /* RELAY_DEBUG */

	  if (hops > QUERY(maxhops)) {
	    int i;
	    for(i=0; i < sizeof(a)-1; i++) {
	      if (a[i]=="" || a[i][-1] != '\n') {
		hops--;
	      }
	    }

#ifdef RELAY_DEBUG
	    report_debug(sprintf("SMTPRelay: vanilla hops:%d\n", hops));
#endif /* RELAY_DEBUG */

	    if (hops > QUERY(maxhops)) {
	      report_error(sprintf("SMTPRelay: Too many hops!\n"));
	      
	      // FIXME: Should send a message to from here.

	      rm(fname);

	      return(0);
	    }
	  }
	}
      }
      if (spoolfile->write(s) != sizeof(s)) {
	report_error(sprintf("SMTPRelay: Failed to write spoolfile %O!\n",
			     fname));

	// FIXME: Should send a message to from here.

	rm(fname);

	return(0);
      }
    }
    if ((rest != "") || (!last_was_lf)) {
      // The file must be terminated with a \r\n.
      if (spoolfile->write("\r\n") != 2) {
	report_error(sprintf("SMTPRelay: Failed to write spoolfile %O!\n",
			     fname));

	// FIXME: Should send a message to from here.

	rm(fname);

	return(0);
      }
    }
    spoolfile->close();
  }
 
  if (smtp) {
    sql->query(sprintf("INSERT INTO send_q "
		       "(sender, user, domain, mailid, received_at, send_at, "
		       "remoteident, remoteip, remotename) "
		       "VALUES('%s', '%s', '%s', '%s', %d, 0, "
		       "'%s', '%s', '%s')",
		       sql->quote(from), sql->quote(user),
		       sql->quote(domain), sql->quote(csum), time(),
		       smtp->remoteident || "UNKNOWN", smtp->remoteip,
		       smtp->remotename));
  } else {
    sql->query(sprintf("INSERT INTO send_q "
		       "(sender, user, domain, mailid, received_at, send_at, "
		       "remoteident, remoteip, remotename) "
		       "VALUES('%s', '%s', '%s', '%s', %d, 0, "
		       "'', '', '')",
		       sql->quote(from), sql->quote(user),
		       sql->quote(domain), sql->quote(csum), time()));
  }

#ifdef THREADS
  if (key) {
    destruct(key);
  }
#endif /* THREADS */

  // Send mailid asynchronously.
  // Start in half a minute.
  check_mail(30);

  return(1);
}

static void init_db()
{
  /* Check if the required tables exist.
   * FIXME: Probably only works with mysql!
   */
  if (catch(sql->query("DESCRIBE send_q"))) {
    /* Create the required tables. */

    sql->query("CREATE TABLE send_q ("
	       "id int auto_increment primary key,"
	       "sender varchar(255) not null,"
	       "user varchar(255) not null,"
	       "domain varchar(255) not null,"
	       "mailid varchar(32) not null,"
	       "received_at int not null,"
	       "send_at int not null,"
	       "times int not null,"
	       "remoteident varchar(255) not null,"
	       "remoteip varchar(32) not null,"
	       "remotename varchar(255) not null"
	       ")");
  }
}
