/*
 * $Id: smtp.pike,v 1.19 1998/09/10 17:32:08 grubba Exp $
 *
 * SMTP support for Roxen.
 *
 * Henrik Grubbström 1998-07-07
 */

constant cvs_version = "$Id: smtp.pike,v 1.19 1998/09/10 17:32:08 grubba Exp $";
constant thread_safe = 1;

#include <module.h>

inherit "module";

#define SMTP_DEBUG

/*
 * Provider module interface:
 *
 * automail_clientlayer:
 *	int check_size(int sz);
 * 	string get_unique_body_id();
 *
 * smtp_rcpt:
 *	string|multiset(string) expn(string addr, object o);
 * 	string desc(string addr, object o);
 *	multiset(string) query_domain();
 *	int put(string sender, string user, string domain,
 * 	        string spooler_id, object o);
 *
 * smtp_filter:
 *	int verify_sender(string sender);
 * 	int verify_recipient(string sender, string recipient, object o);
 * 	int classify_connection(string remoteip, int remoteport,
 * 	                        string remotehost);
 *
 * smtp_relay:
 * 	int relay(string sender, string user, string domain,
 * 	          string spooler_id, object o);
 */

class Mail {
  string id;
  int timestamp;
  object connection;

  string from;
  multiset(string) recipients = (<>);
  string contents;
  mapping extensions;


  void set_from(string f)
  {
    from = f;
  }

  void add_recipients(multiset(string) rcpts)
  {
    recipients |= rcpts;
  }

  void set_contents(string c)
  {
    contents = c;
  }

  void set_extensions(mapping e)
  {
    extensions = e;
  }

  void save()
  {
  }

  void create()
  {
    timestamp = time();
  }
};

class Server {
  class Smtp_Connection {
    inherit Protocols.Line.smtp_style;

    constant errorcodes = ([
      // From RFC 788 and RFC 821:
      211:"System status",
      214:"Help message",
      220:"Service ready",
      221:"Service closing transmission channel",
      250:"Requested mail action okay, completed",
      251:"User not local; will forward",
      354:"Start mail input; end with <CRLF>.<CRLF>",
      421:"Service not available, closing transmission channel",
      450:"Requested mail action not taken: mailbox unavailable",
      451:"Requested action aborted: local error in processing",
      452:"Requested action not taken: insufficient system storage",
      500:"Syntax error, command unrecognized",
      501:"Syntax error in parameters or arguments",
      502:"Command not implemented",
      503:"Bad sequence of commands",
      504:"Command parameter not implemented",
      550:"Requested action not taken: mailbox unavailable",
      551:"User not local; please try",
      552:"Requested action aborted: exceeded storage allocation",
      553:"Requested action not taken: mailbox name not allowed",
      554:"Transaction failed",
      // From RFC 1123:
      252:"Cannot VRFY user, "
      "but will take message for this user and attempt delivery",
    ]);      

    constant command_help = ([
      // SMTP Commands in the order from RFC 788
      "HELO":"<sp> <host> (Hello)",
      "MAIL":"<sp> FROM:<reverse-path> (Mail)",
      "RCPT":"<sp> TO:<forward-path> (Recipient)",
      "DATA":"(Data follows)",
      "RSET":"(Reset)",
      "SEND":"<sp> FROM:<reverse-path> (Send to terminal)",
      "SOML":"<sp> FROM:<reverse-path> (Send or mail)",
      "SAML":"<sp> FROM:<reverse-path> (Send and mail)",
      "VRFY":"<sp> <string> (Verify)",
      "EXPN":"<sp> <string> (Expand alias)",
      "HELP":"[<sp> <string>] (Help)",
      "NOOP":"(No operation)",
      "QUIT":"(Quit)",
      // Added in RFC 822:
      "TURN":"(Turn into client mode)",
      // Added in RFC 1651:
      "EHLO":"<sp> <host> (Extended hello)",
    ]);

    string localhost = gethostname();
    int connection_class;
    string remoteip;		// IP
    string remoteport;		// PORT
    string remotehost;		// Name from the IP.
    string remotename;		// Name given in HELO or EHLO.
    array(string) ident;
    object conf;
    string prot = "SMTP";
    function delayed_answer;

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

    static void got_remotehost(string h,
			       function|void callback, mixed ... args)
    {
      remotehost = h;
      if (callback) {
	callback(@args);
      }
    }

    static void got_remoteident(array(string) i,
				function|void callback, mixed ... args)
    {
      ident = i;
      if (callback) {
	callback(@args);
      }
    }

    static void check_delayed_answer()
    {
      if (functionp(delayed_answer)) {
	delayed_answer();
      }
      delayed_answer = 0;
    }

    static void handle_command(string data)
    {
      int i = search(data, " ");

      string cmd = data;
      string arg = "";

      if (i != -1) {
	cmd = data[..i-1];
	arg = data[i+1..];
      }
      cmd = upper_case(cmd);
#ifdef SMTP_DEBUG
      roxen_perror(sprintf("SMTP: Command: %s\n", cmd));
#endif /* SMTP_DEBUG */
      function f;
      if (f = this_object()["smtp_"+cmd]) {
	f(cmd, arg);
      } else {
	roxen_perror(sprintf("SMTP: Unknown command: %O\n", cmd));
	send(500, ({ sprintf("'%s': Unknown command.", cmd) }));
      }
    }

    static multiset do_expn(multiset in)
    {
#ifdef SMTP_DEBUG
      roxen_perror(sprintf("SMTP: Expanding %O\n", in));
#endif /* SMTP_DEBUG */

      multiset expanded = (<>);		// Addresses expanded ok.
      multiset done = (<>);		// Addresses that have been EXPN'ed.
      multiset to_do = copy_value(in);	// Addresses still left to expand.

      array expns = Array.filter(conf->get_providers("smtp_rcpt")||({}),
				 lambda(object o){ return(o->expn); });

      while (sizeof(to_do)) {
	foreach(indices(to_do), string addr) {
	  done[addr] = 1;
	  to_do[addr] = 0;
	  int verbatim = 1;
	  foreach(expns, object o) {
	    string|multiset e = o->expn(addr, this_object());
	    if (e) {
	      verbatim = 0;
	      if (stringp(e)) {
		expanded[e] = 1;
	      } else if (multisetp(e)) {
		to_do |= e - done;
	      } else {
		report_error(sprintf("SMTP: EXPN returned other than "
				     "mapping or string!\n"
				     "%O => %O\n", addr, e));
	      }
	    }
	  }
	  if (verbatim) {
	    expanded[addr] = 1;
	  }
	}
      }

#ifdef SMTP_DEBUG
      roxen_perror(sprintf("SMTP: EXPN pass done: %O\n", expanded));
#endif /* SMTP_DEBUG */

      return(expanded);
    }

    static array(string) do_parse_address(string addr)
    {
      array a = MIME.tokenize(addr)/({ ',' });

      int i;
      for(i=0; i<sizeof(a); i++) {
	int j;
	if ((j = search(a[i], '<')) != -1) {
	  int k;
	  if ((k = search(a[i], '>', j)) != -1) {
	    a[i] = a[i][j+1..k-1];
	  } else {
	    a[i] = a[i][j+1..];
	  }
	}
	for (j=0; j < sizeof(a[i]); j++) {
	  if (intp(a[i][j])) {
	    if (a[i][j] == '@') {
	      a[i][j] = "@";
	    } else if (a[i][j] == '.') {
	      a[i][j] = ".";
	    } else {
	      a[i][j] = "";
	    }
	  }
	}
	a[i] *= "";
      }
      return(a);
    }

    void smtp_NOOP(string noop, string args)
    {
      send(250, ({ "Nothing done OK" }));
    }

    void smtp_QUIT(string quit, string args)
    {
      send(221, ({ sprintf("%s closing connection", gethostname()) }));
      disconnect();
    }

    void smtp_HELP(string help, string args)
    {
      array(string) res;
      if (!sizeof(args)) {
	res = ({ "This is " + roxen->version(),
		 "Commands:",
		 @(sprintf(" %#70s", sort(indices(command_help))*"\n")/"\n"),
		 "Use \"HELP <command>\" for more help.",
	});
      } else if (command_help[upper_case(args)]) {
	res = ({ upper_case(args) + " " + command_help[upper_case(args)] });
      } else {
	send(504, ({ sprintf("Unknown command %O", args) }));
	return;
      }
      res += ({ "End of help" });
      send(214, res);
    }

    void ident_HELO()
    {
      array(string) res;
      if (((ident[0] - " ") == "ERROR") || (sizeof(ident) < 3)) {
	res = ({ sprintf("%s Hello %s [%s], pleased to meet you",
			 gethostname(), remotehost,
			 (con->query_address()/" ")*":") });
      } else {
	res = ({ sprintf("%s Hello %s@%s [%s], pleased to meet you",
			 gethostname(), ident[2], remotehost,
			 (con->query_address()/" ")*":") });
      }
      if (prot == "ESMTP") {
	// Supported extensions...
	res += ({ "EXPN", "8BITMIME", "SIZE", "HELP" });
      }
      send(250, res);
    }

    void smtp_HELO(string helo, string args)
    {
      remotename = args;

      // NB: Race-condition...
      if (ident)
	ident_HELO();
      else
	delayed_answer = ident_HELO;
    }

    void smtp_EHLO(string ehlo, string args)
    {
      prot = "ESMTP";
      smtp_HELO("HELO", args);
    }

    void smtp_EXPN(string mail, string args)
    {
      if (!sizeof(args)) {
	send(501, "Expected argument");
	return;
      }

      multiset m = do_expn((<@do_parse_address(args)>));

      array result = ({});

      array rcpts = Array.filter(conf->get_providers("smtp_rcpt")||({}),
				 lambda(object o) { return(o->desc); });

      foreach(indices(m), string a) {
	int handled = 0;
	foreach(rcpts, object o) {
	  string l = o->desc(a, this_object());
	  if (l) {
	    result += ({ l });
	    handled = 1;
	  }
	}
	if (!handled) {
	  // Default.
	  result += ({ "<" + a + ">" });
	}
      }

      send(250, sort(result));
    }

    void smtp_VRFY(string mail, string args)
    {
      if (!sizeof(args)) {
	send(501, "Expected argument");
	return;
      }

      array a = do_parse_address(args);

      array descs = Array.filter(conf->get_providers("smtp_rcpt")||({}),
				 lambda(object o) { return(o->desc); });

      array expns = Array.filter(conf->get_providers("smtp_rcpt")||({}),
				 lambda(object o) { return(o->expn); });

      int i;
      for(i=0; i < sizeof(a); i++) {
	string s = 0;
	foreach(descs, object o) {
	  if (s = o->desc(a[i], this_object())) {
	    break;
	  }
	}
	if (!s) {
	  foreach(expns, object o) {
	    string|multiset m;
	    if (m = o->expn(a[i], this_object())) {
	      if (stringp(m)) {
		a[i] = m;
		foreach(descs, object o) {
		  if (s = o->desc(a[i], this_object())) {
		    break;
		  }
		}
	      }
	      if (!s) {
		s = "<" + a[i] + ">";
	      }
	      break;
	    }
	  }
	  if (!s) {
	    send(550, sprintf("%s... User unknown", a[i]));
	    return;
	  }
	}
	a[i] = s;
      }

      send(250, sort(a));
    }

    multiset(string) handled_domains = (<>);
    object(Mail) current_mail;

    static void do_RSET()
    {
      if (current_mail) {
	destruct(current_mail);
      }
    }

    void smtp_RSET(string rset, string args)
    {
      do_RSET();
      send(250, "Reset ok.");
    }

    void smtp_MAIL(string mail, string args)
    {
      do_RSET();

      current_mail = Mail();

      int i = search(args, ":");
      if (i >= 0) {
	string from_colon = args[..i];
	sscanf("%*[ ]%s", from_colon, from_colon);
	if (upper_case(from_colon) == "FROM:") {
	  array a = (args[i+1..]/" ") - ({ "" });

	  if (sizeof(a)) {
	    current_mail->set_from(a[0]);

	    a = a[1..];

	    if (sizeof(a)) {
	      mapping extensions = ([]);
	      foreach(a, string ext) {
		array b = ext/"=";
		if (sizeof(b) > 1) {
		  extensions[upper_case(b[0])] = b[1..]*"=";
		} else {
		  extensions[upper_case(ext)] = 1;
		}
	      }

	      current_mail->set_extensions(extensions);

	      // Check extensions here.

	      foreach(indices(extensions), string ext) {
		switch(ext) {
		case "SIZE":
		  // The message will be approx this size.
		  // We can reply with 452 (temporary limit, try later)
		  // or 552 (hard limit).
		  if (stringp(extensions->SIZE)) {
		    // FIXME: 32bit wraparound.
		    int sz = (int)extensions->SIZE;

		    foreach(conf->get_providers("automail_clientlayer")||({}),
			    object o) {
		      if (o->check_size) {
			int r = o->check_size(sz);
			if (r) {
			  send(r);
			  return;
			}
		      }
		    }
		  }

		  break;
		case "BODY":
		  switch(extensions->BODY) {
		  case "8BITMIME":
		    // We always support 8bit.
		    break;
		  default:
		    // FIXME: Should we have a warning here?
		    break;
		  }
		  break;
		default:
		  break;
		}
	      }
	    }

	    foreach(conf->get_providers("smtp_filter")||({}), object o) {
	      // roxen_perror("Got SMTP filter\n");
	      if (functionp(o->verify_sender) &&
		  o->verify_sender(current_mail->sender)) {
		// Refuse connection.
#ifdef SMTP_DEBUG
		roxen_perror("Refuse sender.\n");
#endif /* SMTP_DEBUG */
		do_RSET();
		send(550);
		return;
	      }
	    }

	    // Update the table of locally handled domains.
	    multiset(string) domains = (<>);
	    foreach(conf->get_providers("smtp_rcpt")||({}), object o) {
	      if (o->query_domain) {
		domains |= o->query_domain();
	      }
	    }

	    handled_domains = domains;

	    send(250);
	    return;
	  }
	}
      }
      send(501);
    }

    void smtp_RCPT(string rcpt, string args)
    {
      if (!current_mail || !sizeof(current_mail->from)) {
	send(503);
	return;
      }

      int i = search(args, ":");
      if (i >= 0) {
	string to_colon = args[..i];
	sscanf("%*[ ]%s", to_colon, to_colon);
	if (upper_case(to_colon) == "TO:") {
	  string recipient = args[i+1..];
	  sscanf("%*[ ]%s", recipient, recipient);
#ifdef SMTP_DEBUG
	  roxen_perror(sprintf("SMTP: RCPT:%O\n", recipient));
#endif /* SMTP_DEBUG */
	  if (sizeof(recipient)) {
	    foreach(conf->get_providers("smtp_filter")||({}), object o) {
	      // roxen_perror("Got SMTP filter\n");
	      if (functionp(o->verify_recipient) &&
		  o->verify_recipient(current_mail->from, recipient,
				      this_object())) {
		// Refuse recipient.
#ifdef SMTP_DEBUG
		roxen_perror("Refuse recipient.\n");
#endif /* SMTP_DEBUG */
		send(550, sprintf("%s... Recipient refused", recipient));
		return;
	      }
	    }

	    int recipient_ok = 0;

	    foreach(conf->get_providers("smtp_rcpt")||({}), object o) {
	      if (functionp(o->expn) &&
		  o->expn(recipient, this_object())) {
		recipient_ok = 1;
		break;
	      }
	      if (functionp(o->desc) &&
		  o->desc(recipient, this_object())) {
		recipient_ok = 1;
		break;
	      }
	    }

	    if (!recipient_ok) {
#ifdef SMTP_DEBUG
	      roxen_perror("Unhandled recipient.\n");
#endif /* SMTP_DEBUG */
	      send(550, sprintf("%s... Unhandled recipient.", recipient));
	      return;
	    }

	    current_mail->add_recipients((< recipient >));
	    send(250, sprintf("%s... Recipient ok.", recipient));
	    return;
	  }
	}
      }
      send(501);
    }

    // DATA handling

    void handle_DATA(string data)
    {
      roxen_perror(sprintf("GOT: %O\n", data));

      // Dequote the lines...
      // ie delete any initial period ('.') signs.
      // RFC 821 4.5.2.2
      data = replace(data, "\n.", "\n");
      if (data[0] == '.') {
	data = data[1..];
      }

      current_mail->set_contents(data);

      array spooler;

      foreach(conf->get_providers("automail_clientlayer")||({}), object o) {
	string id;
	if ((id = o->get_unique_body_id())) {
	  spooler = ({ o, id });
	  break;
	}
      }

      if (!spooler) {
	send(550, "No spooler available");
	report_error("SMTP: No spooler found!\n");
	do_RSET();
	return;
      }

      // Add received-headers here.

      string received = sprintf("from %s (%s [%s]) by %s with %s id %s; %s",
				remotename, remotehost||"", remoteip,
				localhost, prot, spooler[1],
				mktimestamp(current_mail->timestamp));

      data = "Received: " + received + "\r\n" + data;

      roxen_perror(sprintf("Received: %O\n", received));

      object f = spooler[0]->get_fileobject(spooler[1]);

      if (f->write(data) != sizeof(data)) {
	spooler[0]->delete_body(spooler[1]);
	send(452);
	report_error("SMTP: Spooler failed.\n");
	do_RSET();
	return;
      }

      current_mail->save();

      send(250);
      report_notice("SMTP: Mail spooled OK.\n");

      // Now it's time to actually deliver the message.
      // NOTE: After this point error-messages must be sent by mail.

      // Expand.
      multiset expanded = do_expn(current_mail->recipients);

      /* Do the delivery */
      foreach(indices(expanded), string addr) {
	array a = addr/"@";
	string domain;
	string user;

	if (sizeof(a) > 1) {
	  domain = a[-1];
	  user = a[..sizeof(a)-2]*"@";
	} else {
	  user = addr;
	}

	int handled;

	if ((!domain) || (handled_domains[domain])) {
	  // Local delivery.
	  if (domain) {
	    // Primary delivery.
	    foreach(conf->get_providers("smtp_rcpt")||({}), object o) {
	      handled |= o->put(current_mail->from, user, domain,
				spooler[1], this_object());
	    }
	  }
	  if (!handled) {
	    // Fallback delivery.
	    foreach(conf->get_providers("smtp_rcpt")||({}), object o) {
	      handled |= o->put(current_mail->from, user, 0,
				spooler[1], this_object());
	    }
	  }
	} else {
	  // Remote delivery.
	  foreach(conf->get_providers("smtp_relay")||({}), object o) {
	    handled |= o->relay(current_mail->from, user, domain,
				spooler[1], this_object());
	  }
	}
	if (handled) {
	  expanded[addr] = 0;
	}
      }

      if (sizeof(expanded)) {
	// SMTP_ERROR(sprintf("The following recipients were unavailable:\n"
	// 		   "%s\n", String.implode_nicely(indices(expanded))));
      }

      current_mail->done();

      do_RSET();
    }

    void smtp_DATA(string data, string args)
    {
      if (!current_mail || !sizeof(current_mail->from)) {
	send(503, ({ "Need sender (MAIL FROM)" }));
	return;
      }
      if (!sizeof(current_mail->recipients)) {
	send(503, ({ "Need recipient list (RCPT TO)" }));
	return;
      }

      send(354);
      handle_data = handle_DATA;
    }

    static void classify_connection(object con_)
    {
      foreach(conf->get_providers("smtp_filter") ||({}), object o) {
	// roxen_perror("Got SMTP filter\n");
	if (functionp(o->classify_connection)) {
	  int c = o->classify_connection(remoteip, remoteport, remotehost);

	  if (c < 0) {
	    // Refuse connection.
#ifdef SMTP_DEBUG
	    roxen_perror("Refuse connection.\n");
#endif /* SMTP_DEBUG */
	    con_->close();
	    destruct();
	    return;
	  } else if (!connection_class) {
	    connection_class = c;
	  }
	}
      }

      ::create(con_);

      send(220, ({ sprintf("%s ESMTP %s; %s",
			   gethostname(), roxen->version(),
			   mktimestamp(time())) }));
    }

    void create(object con_, object conf_)
    {
      conf = conf_;

      array(string) remote = con_->query_address()/" ";

      remoteip = remote[0];
      remoteport = (remote[1..])*" ";

      // Start two assynchronous lookups...
      roxen->ip_to_host(remoteip, got_remotehost, classify_connection, con_);

      Protocols.Ident->lookup_async(con_, got_remoteident,
				    check_delayed_answer);

    }
  }

  object conf;

  object port = Stdio.Port();
  void got_connection()
  {
    object con = port->accept();

    Smtp_Connection(con, conf);	// Start a new session.
  }

  void create(object c, object|mapping callbacks,
	      int|void portno, string|void host)
  {
    conf = c;

    portno = portno || Protocols.Ports.tcp.smtp;

    object privs;

    if (portno < 1024) {
      privs = Privs("Opening port below 1024 for SMTP.\n");
    }

    mixed err;
    int res;
    err = catch {
      if (host) {
	res = port->bind(portno, got_connection, host);
      } else {
	res = port->bind(portno, got_connection);
      }
    };

    if (privs) {
      destruct(privs);
    }

    if (err) {
      throw(err);
    }

    if (!res) {
      throw(({ "Failed to bind to port\n", backtrace() }));
    }
  }

  void destroy()
  {
    if (port) {
      destruct(port);
    }
  }
};

array register_module()
{
  return({ 0,
	   "SMTP protocol",
	   "Experimental module for receiving mail." });
}

void create()
{
  defvar("port", Protocols.Ports.tcp.smtp, "SMTP port number", TYPE_INT,
	 "Portnumber to listen to. "
	 "Usually " + Protocols.Ports.tcp.smtp + ".\n");
}

object smtp_server;

void start(int i, object c)
{
  if (c) {
    mixed err;
    err = catch {
      if (!smtp_server) {
	smtp_server = Server(c, ([]), QUERY(port));
      }
    };
    if (err) {
      report_error(sprintf("SMTP: Failed to initialize the server:\n"
			   "%s\n", describe_backtrace(err)));
    }
  }
}

void stop()
{
  if (smtp_server) {
    destruct(smtp_server);
  }
}
