/*
 * $Id: smtprelay.pike,v 1.16 1998/09/16 17:29:37 grubba Exp $
 *
 * An SMTP-relay RCPT module for the AutoMail system.
 *
 * Henrik Grubbström 1998-09-02
 */

#include <module.h>

inherit "module";

#define RELAY_DEBUG

constant cvs_version = "$Id: smtprelay.pike,v 1.16 1998/09/16 17:29:37 grubba Exp $";

/*
 * Some globals
 */

#ifdef THREADS
static object queue_mutex = Thread.Mutex();
#endif /* THREADS */

static object conf;
static object sql;

static object dns = Protocols.DNS.async_client();

static void check_mail(int seconds);

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

  defvar("sqlurl", "mysql://auto:site@kopparorm/autosite", "Database URL",
	 TYPE_STRING, "");

  defvar("postmaster", "postmaster@"+gethostname(), "Postmaster address",
	 TYPE_STRING, "Email address of the postmaster.");
}

array(string)|multiset(string)|string query_provides()
{
  return(< "smtp_relay" >);
}

void start(int i, object c)
{
  if (c) {
    conf = c;

    sql = Sql.sql(QUERY(sqlurl));

    /* Start delivering mail soon after everything has loaded. */
    check_mail(10);
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
  mapping lt = localtime(t);
    
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

class SocketNotSelf
{
  private void connected(array args)
  {
    if (!args) {
#ifdef SOCKET_DEBUG
      perror("SOCKETS: async_connect: No arguments to connected\n");
#endif /* SOCKET_DEBUG */
      return;
    }
#ifdef SOCKET_DEBUG
    perror("SOCKETS: async_connect ok.\n");
#endif
    args[2]->set_id(0);
    args[0](args[2], @args[1]);
  }

  private void failed(array args)
  {
#ifdef SOCKET_DEBUG
    perror("SOCKETS: async_connect failed\n");
#endif
    args[2]->set_id(0);
    destruct(args[2]);
    args[0](0, @args[1]);
  }

  private void got_host_name(string host, string oh, int port,
			     function callback, mixed ... args)
  {
    // *** BEGIN CODE THAT DIFFERS FROM socket.pike ***

    object p = Stdio.Port;

    if (p->bind(0,0,host)) {
      // We were just about to connect to ourselves!

      callback(-1, @args);
      destruct(p);
      return;
    }
    destruct(p);

    // *** END CODE THAT DIFFERS FROM socket.pike ***

    object f;
    f=Stdio.File();
#ifdef SOCKET_DEBUG
    perror("SOCKETS: async_connect "+oh+" == "+host+"\n");
#endif
    if(!f->open_socket())
    {
#ifdef SOCKET_DEBUG
      perror("SOCKETS: socket() failed. Out of sockets?\n");
#endif
      callback(0, @args);
      destruct(f);
      return;
    }
    f->set_id( ({ callback, args, f }) );
    f->set_nonblocking(0, connected, failed);
#ifdef FD_DEBUG
    mark_fd(f->query_fd(), "async socket communication: -> "+host+":"+port);
#endif
    if(catch(f->connect(host, port))) // Illegal format...
    {
#ifdef SOCKET_DEBUG
      perror("SOCKETS: Illegal internet address in connect in async comm.\n");
#endif
      callback(0, @args);
      destruct(f);
      return;
    }
  }

  void async_connect(string host, int port, function|void callback,
		     mixed ... args)
  {
#ifdef SOCKET_DEBUG
    perror("SOCKETS: async_connect requested to "+host+":"+port+"\n");
#endif
    roxen->host_to_ip(host, got_host_name, host, port, callback, @args);
  }
};

class MailSender
{
  private static inherit SocketNotSelf;

  static object parent;

  static mapping message;
  static array(string) servers;
  static int servercount;

  static object dns;

  static object con;
  static object mail;

  static int state;
  static int result;

  static function send_done;

  static multiset(string) esmtp_features = (<>);

  static void connect_and_send();

  static string out_buf = "";
  static void send_data()
  {
    int i = con->write(out_buf);
#ifdef RELAY_DEBUG
    roxen_perror("SMTP: Wrote %d bytes\n", i);
#endif /* RELAY_DEBUG */
    if (i < 0) {
      // Error
      con->close();
      connect_and_send();
    } else {
      out_buf = out_buf[i..];
      if (!sizeof(out_buf)) {
	con->set_write_callback(0);
      }
    }
  }

  static void send(string s)
  {
#ifdef RELAY_DEBUG
    roxen_perror("SMTP: send(%O)\n", s);
#endif /* RELAY_DEBUG */
    out_buf += s;

    if (sizeof(out_buf)) {
      con->set_write_callback(send_data);
    }
  }

  static string last_command = "";
  static void send_command(string s)
  {
    last_command = s;
    send(s + "\r\n");
  }

  /*
   * Functions called by the state machine
   */
  
  static void send_ehlo()
  {
    send_command(sprintf("EHLO %s", gethostname()));
  }

  static void send_helo()
  {
    send_command(sprintf("HELO %s", gethostname()));
  }

  static void send_mail_from(string code, array(string) reply)
  {
    if (state == 1) {
      if (sizeof(reply) > 1) {
	// Parse EHLO reply
	esmtp_features = (< @Array.map(reply[1..], lower_case) >);
      }
    }
    string extras = "";
    if (esmtp_features["8bitmime"]) {
      extras += " BODY=8BITMIME";
    }
    if (esmtp_features["size"]) {
      // Add some margin for safety.
      extras += " SIZE="+(sizeof(message)+10);
    }
    send_command(sprintf("MAIL FROM:%s%s", message->sender, extras));
  }

  static void send_rcpt_to()
  {
    send_command(sprintf("RCPT TO:%s@%s", message->user, message->domain));
  }

  static void send_bounce(string code, array(string) text)
  {
    parent->bounce(message, code, text, last_command);

    send_command("QUIT");
  }

  static void bad_address(string code, array(string) text)
  {
    // Permanently bad address.
    result = -2;

    send_bounce(code, text);
  }

  static void send_body()
  {
    string m = mail->read(0x7fffffff);
    if (sizeof(m)) { 
      if (m[0] == '.') {
	// Not likely...
	// Especially not since the first line is probably the
	// Received header...
	m = "." + m;
      }
      if (m[-1] != '\n') {
	// Not likely either, but...
	m += "\r\n";
      }
      m = replace(m, "\n.", "\n..") + ".\r\n";
      send(m);
    } else {
      send(".\r\n");
    }
  }

  static void send_ok()
  {
#ifdef RELAY_DEBUG
    roxen_perror(sprintf("SMTP: Message %O sent ok!\n",
			 message->mailid));
#endif /* RELAY_DEBUG */
    result = 1;
    send_command("QUIT");
  }

  // The state machine

  static constant state_machine = ({
    ([ "220":1, ]), 	// 0 (Connection established), EHLO
    ([ "250":2, ]),	// 1 EHLO reply, MAIL FROM:, HELO
    ([ "250":4, ]),	// 2 MAIL FROM: reply, RCPT TO:
    ([ "250":2, ]),	// 3 HELO reply, MAIL FROM:
    ([ "25":5, ]),	// 4 RCPT TO: reply, DATA
    ([ "354":6, ]),	// 5 DATA reply, body
    ([]),		// 6 body reply,
    ([ "":-1 ]),	// 7 QUIT reply, disconnect
  });

  static array(mapping) state_actions = ({
    ([ "220":send_ehlo, ]),
    ([ "250":send_mail_from, "":send_helo, ]),
    ([ "250":send_rcpt_to, "5":send_bounce, ]),
    ([ "250":send_mail_from, "5":send_bounce, ]),
    ([ "25":"DATA", "55":bad_address, ]),
    ([ "354":send_body, "":send_bounce, ]),
    ([ "250":send_ok, "":send_bounce, ]),
    ([]),
  });

  static mixed find_next(mapping(string:mixed) machine,
			 string code, mixed def)
  {
    mixed res;
    int i;
    for (i=sizeof(code); i--; ) {
      if (!zero_type(res = machine[code[..i]])) {
	return res;
      }
    }
    if (!zero_type(res = machine[""])) {
      return res;
    }
    return def;
  }

  static void got_reply(string code, array(string) data)
  {
    int next_state = find_next(state_machine[state], code, 7);
    function|string action = find_next(state_actions[state], code, "QUIT");

#ifdef DEBUG
    roxen_perror(sprintf("code %s: State %d => State %d:%O\n",
			 code, state, next_state, action));
#endif /* DEBUG */

    if (stringp(action)) {
      send_command(action);
    } else {
      action(code, data);
    }
    state = next_state;
    if (state < 0) {
      con->close();
      connect_and_send();
      return;
    }
  }

  static string in_code = "";
  static array(string) in_arr = ({});
  static string in_buf = "";
  static void got_data(mixed id, string data)
  {
#ifdef RELAY_DEBUG
    roxen_perror(sprintf("SMTP: got_data(%O, %O)\n", id, data));
#endif /* RELAY_DEBUG */
    in_buf += data;

    int i;
    while ((i = search(in_buf, "\r\n")) != -1) {
      if (i < 3) {
	// Shouldn't happen, but...
	in_buf = in_buf[i+2..];

	if (sizeof(in_arr)) {
	  got_reply(in_code, in_arr);
	}

	continue;
      }
      string line = in_buf[..i-1];	// No crlf;
      in_buf = in_buf[i+2..];

      in_code = line[..2];
      int cont = line[3..3] == "-";
      line = line[4..];
      in_arr += ({ line });
      if (!cont) {
	got_reply(in_code, in_arr);
	in_arr = ({});
      }
    }
  }

  static void con_closed()
  {
    if (state == 1) {
      // FIXME: Reconnect, and try with HELO this time.
    }
    con->close();
    connect_and_send();
  }

  static void got_connection(object c)
  {
    if (!c) {
#ifdef RELAY_DEBUG
      roxen_perror("Connection refused.\n");
#endif /* RELAY_DEBUG */
      // Connection refused.
      connect_and_send();
      return;
    } else if (c == -1) {
      // Connected to ourselves.
      if (servercount == 1) {
	// FIXME: This won't work since bounce() won't be able
	// to send to localhost.

	// We're the primary MX!
	result = -3;

	parent->bounce(message, "554", ({
	  sprintf("MX list for %s points back to %s",
		  message->domain, gethostname()),
	  sprintf("<%s@%s>... Local configuration error",
		  message->user, message->domain),
	}));
      }
      connect_and_send();
    }

    con = c;

    in_buf = "";
    con->set_nonblocking(got_data, 0, con_closed);
  }

  static void connect_and_send()
  {
    if (result) {
      // We've succeeded to send the message!
      send_done(result, message);
      return;
    }

    // Try the next SMTP server.
    int server = servercount++;

    if (server >= sizeof(servers)) {
      // Failure

      report_error(sprintf("SMTP: Failed to send message to domain %O\n",
			   message->domain));

      // Send failure message.
      send_done(0, message);
      return;
    }

#ifdef RELAY_DEBUG
    roxen_perror(sprintf("SMTP: Trying with the SMTP server at %s\n",
			 servers[server]));
#endif /* RELAY_DEBUG */

    message->remote_mta = servers[server];
    message->last_attempt_at = time();

    roxen->async_connect(servers[server], 25, got_connection);
  }

  static void got_mx(array(string) mx)
  {
    if (!(servers = mx)) {
    // No MX record for the domain.
      servers = ({ message->domain });
    }
    
    connect_and_send();
  }

  void create(object d, mapping(string:string) m, string dir,
	      function cb, object p)
  {
    dns = d;
    message = m;
    send_done = cb;
    parent = p;

    string fname = combine_path(dir, m->mailid);

    mail = Stdio.File();
    if (!(mail->open(fname, "r"))) {
      report_error(sprintf("Failed to open spoolfile %O\n", fname));
      call_out(cb, 0, -1, m);
      return;
    }

#ifdef RELAY_DEBUG
    roxen_perror(sprintf("Sending %O to %s@%s from %s...\n",
			 message->mailid, message->user, message->domain,
			 message->sender));
#endif /* RELAY_DEBUG */

    dns->get_mx(message->domain, got_mx);
  }
};

static void mail_sent(int res, mapping message)
{
  if (res) {
    switch(res) {
    case 1:
      report_notice(sprintf("SMTP: Mail %O sent successfully!\n",
			    message->mailid));
      break;
    case -1:
      report_error(sprintf("SMTP: Failed to open %O!\n",
			   message->mailid));
      
      return;	// FIXME: Should we remove it from the queue or not?
    case -2:
      report_error(sprintf("SMTP: Permanently bad address %s@%s\n",
			   message->user, message->domain));
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
    report_notice(sprintf("SMTP: Sending of %O failed!\n",
			  message->mailid));
  }
}

static int check_interval = 0x7fffffff;

static void send_mail()
{
#ifdef RELAY_DEBUG
  roxen_perror("SMTP: send_mail()\n");
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
    MailSender(dns, mm, QUERY(spooldir), mail_sent, this_object());
  }

  // Recheck again in 10 sec <= X <= 1 hour.

  m = sql->query("SELECT min(send_at) AS send_at FROM send_q");

  int t = 60*60;
  if (m && sizeof(m) && (m[0]->send_at)) {
    t = ((int)m[0]->send_at) - time();
#ifdef RELAY_DEBUG
    roxen_perror(sprintf("t:%d\n", t));
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
  roxen_perror(sprintf("SMTP: check_mail(%d)\n", t));
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
 * Callable from elsewhere to send message's
 */
void send_message(string from, multiset(string) rcpt,
		  string message, string|void csum)
{
  roxen_perror(sprintf("SMTP: send_message(%O, %O, X)\n", from, rcpt));

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
    report_error(sprintf("send_message() Failed!\n"));
  }
}

/*
 * Used to bounce error messages
 */

void bounce(mapping msg, string code, array(string) text, string last_command)
{
  // FIXME: Generate a bounce.

  roxen_perror(sprintf("SMTP: bounce(%O, %O, %O, %O)\n",
		       msg, code, text, last_command));

  if (sizeof(msg->sender)) {
    // Send a bounce.

    // Create a bounce message.

    object f = Stdio.File();
    string oldmessage = "";
    string oldheaders = "";
    if (f->open(combine_path(QUERY(spooldir), msg->mailid), "r")) {
      int i;
      string s;
      while((s = f->read(8192)) && (s != "")) {
	oldmessage += s;
      }
      f->close();
      oldheaders = oldmessage;
      if (i = search(oldheaders, "\r\n\r\n")) {
	oldheaders = oldheaders[..i+1];
      } 
    }

    string statusmessage = sprintf("Reporting-MTA: DNS; %s\r\n"
				   "Received-From-MTA: DNS; %s\r\n"
				   "Arrival-Date: %s\r\n"
				   "\r\n"
				   "Final-Recipient: RFC822; %s@%s\r\n"
				   "Action: failed\r\n"
				   "Status: 5.1.1\r\n"
				   "Remote-MTA: DNS; %s\r\n"
				   "Diagnostic-Code: SMTP; %s %s\r\n"
				   "Last-Attempt-Date: %s\r\n",
				   gethostname(),
				   "Somewhere",
				   mktimestamp((int)msg->received_at),
				   msg->user, msg->domain,
				   msg->remote_mta,
				   code, sizeof(text)?text[-1]:"",
				   mktimestamp((int)msg->last_attempt_at));

    string body = sprintf("Message to %s@%s from %s bounced (code %s):\r\n"
			  "Mailid:%s\r\n"
			  "Last command:%s\r\n"
			  "Description:\r\n"
			  "%s\r\n",
			  msg->user, msg->domain, msg->sender, code,
			  msg->mailid,
			  last_command,
			  text*"\r\n");

    // Send a bounce
    string message = (string)
      MIME.Message(body, ([
	"Subject":"Delivery failure",
	"X-Mailer":roxen->version(),
	"MIME-Version":"1.0",
	"From":QUERY(postmaster),
	"To":msg->sender,
	"Date":mktimestamp(time()),
	"Content-Type":"multipart/report; "
	"Report-Type=delivery-status",
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
	  "Content-Type":"message/rfc822",
	])),
      }));
    send_message("<>", (< msg->sender >), message);

    // Inform the postmaster too, but send only the headers.
    message = (string)
      MIME.Message(body, ([
	"Subject":"Delivery failure",
	"X-Mailer":roxen->version(),
	"MIME-Version":"1.0",
	"From":QUERY(postmaster),
	"To":QUERY(postmaster),
	"Date":mktimestamp(time()),
	"Content-Type":"multipart/report; "
	"Report-Type=delivery-status",
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
    send_message("<>", (< QUERY(postmaster) >), message);
  } else {
    roxen_perror("A bounce which bounced!\n");
  }
}

/*
 * SMTP_RELAY callbacks
 */

int relay(string from, string user, string domain,
	  object mail, string csum, object o)
{
#ifdef RELAY_DEBUG
  roxen_perror(sprintf("SMTP: relay(%O, %O, %O, X, %O, X)\n",
		       from, user, domain, csum));
#endif /* RELAY_DEBUG */

  if (!domain) {
    // Shouldn't happen, but...
    return(0);
  }

  // Some more filtering here?

  // FIXME: Extract the non-local addresses from recipients.

  // Calculate the checksum if it isn't calculated already.

  if (!csum) {
    object sha = Crypto.sha();
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
    object spoolfile = Stdio.File();
    if (!spoolfile->open(fname, "cwxa")) {
      report_error(sprintf("SMTPRelay: Failed to open spoolfile %O!\n",
			   fname));

      // FIXME: Should send a message to from here.

      return(0);
    }

    mail->seek(0);
    string s;
    while((s = mail->read(8192)) && (s != "")) {
      if (spoolfile->write(s) != sizeof(s)) {
	report_error(sprintf("SMTPRelay: Failed to write spoolfile %O!\n",
			     fname));

	// FIXME: Should send a message to from here.

	rm(fname);

	return(0);
      }
    }
    spoolfile->close();
  }
  
  sql->query(sprintf("INSERT INTO send_q "
		     "(sender, user, domain, mailid, received_at, send_at) "
		     "VALUES('%s', '%s', '%s', '%s', %d, 0)",
		     sql->quote(from), sql->quote(user),
		     sql->quote(domain), sql->quote(csum), time()));

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

