/*
 * $Id: smtp.pike,v 1.7 1998/09/02 00:25:40 grubba Exp $
 *
 * SMTP support for Roxen.
 *
 * Henrik Grubbström 1998-07-07
 */

constant cvs_version = "$Id: smtp.pike,v 1.7 1998/09/02 00:25:40 grubba Exp $";
constant thread_safe = 1;

#include <module.h>

inherit "module";

#define SMTP_DEBUG

class Server {
  class Smtp_Connection {
    inherit Protocols.Line.smtp_style;

    constant errorcodes = ([
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
    ]);      

    constant command_help = ([
      // SMTP Commands in the order from RFC 788
      "HELO":"<sp> <host>",
      "MAIL":"<sp> FROM:<reverse-path>",
      "RCPT":"<sp> TO:<forward-path>",
      "DATA":"",
      "RSET":"",
      "SEND":"<sp> FROM:<reverse-path>",
      "SOML":"<sp> FROM:<reverse-path>",
      "SAML":"<sp> FROM:<reverse-path>",
      "VRFY":"<sp> <string>",
      "EXPN":"<sp> <string>",
      "HELP":"[<sp> <string>]",
      "NOOP":"",
      "QUIT":"",
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

    constant weekdays = ({ "Sun", "Mon", "Tue", "Wed", "Thr", "Fri", "Sat" });
    constant months = ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
			 "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" });

    static string mktimestamp()
    {
      mapping lt = localtime(time());

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
      roxen_perror(sprintf("SMTP: Expanding %O\n", recipients));
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
	    string|multiset e = o->expn(addr);
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
		 @(sprintf(" %#70s", sort(indices(command_help))*"\n")/"\n") });
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
	res += ({});	// Supported extensions...
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

      multiset m = do_expn((<args>));

      array result = ({});

      array rcpts = Array.filter(conf->get_providers("smtp_rcpt")||({}),
				 lambda(object o) { return(o->desc); });

      foreach(indices(m), string a) {
	int handled = 0;
	foreach(rcpts, object o) {
	  string l = o->desc(a);
	  if (l) {
	    result += ({ l });
	    handled = 1;
	  }
	}
	if (!handled) {
	  // Default.
	  result += ({ a });
	}
      }

      send(250, sort(result));
    }

    string sender = "";
    multiset(string) recipients = (<>);

    void smtp_MAIL(string mail, string args)
    {
      sender = "";
      recipients = (<>);

      int i = search(args, ":");
      if (i >= 0) {
	string from_colon = args[..i];
	sscanf("%*[ ]%s", from_colon, from_colon);
	if (upper_case(from_colon) == "FROM:") {
	  sender = args[i+1..];
	  sscanf("%*[ ]%s", sender, sender);
	  if (sizeof(sender)) {

	    foreach(conf->get_providers("smtp_filter")||({}), object o) {
	      // roxen_perror("Got SMTP filter\n");
	      if (functionp(o->verify_sender) &&
		  o->verify_sender(sender)) {
		// Refuse connection.
#ifdef SMTP_DEBUG
		roxen_perror("Refuse sender.\n");
#endif /* SMTP_DEBUG */
		send(550);
		return;
	      }
	    }

	    send(250);
	    return;
	  }
	}
      }
      send(501);
    }

    void smtp_RCPT(string rcpt, string args)
    {
      if (!sizeof(sender)) {
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
	  if (sizeof(recipient)) {
	    foreach(conf->get_providers("smtp_filter")||({}), object o) {
	      // roxen_perror("Got SMTP filter\n");
	      if (functionp(o->verify_recipient) &&
		  o->verify_recipient(sender, recipient, this_object())) {
		// Refuse recipient.
#ifdef SMTP_DEBUG
		roxen_perror("Refuse recipient.\n");
#endif /* SMTP_DEBUG */
		send(550);
		return;
	      }
	    }

	    int recipient_ok = 0;

	    foreach(conf->get_providers("smtp_expn")||({}), object o) {
	      if (functionp(o->expn) &&
		  o->expn(sender, recipient, this_object())) {
		recipient_ok = 1;
		break;
	      }
	    }

	    if (!recipient_ok) {
#ifdef SMTP_DEBUG
	      roxen_perror("Unhandled recipient.\n");
#endif /* SMTP_DEBUG */
	      send(450);
	      return;
	    }

	    recipients += (< recipient >);
	    send(250);
	    return;
	  }
	}
      }
      send(501);
    }

    void handle_DATA(string data)
    {
      roxen_perror(sprintf("GOT: %O\n", data));

      array spooler;

      foreach(conf->get_proviers("automail_clientlayer")||({}), object o) {
	string id;
	if ((id = o->get_unique_body_id())) {
	  spooler = ({ o, id });
	  break;
	}
      }

      if (!spooler) {
	send(550);
	report_error("SMTP: No spooler found!\n");
	return;
      }

      // Add received-headers here.

      string received = sprintf("from %s (%s [%s]) by %s with %s id %s; %s",
				remotename, remotehost||"", remoteip,
				localhost, prot, spooler[1], mktimestamp());

      data = "Received: " + received + "\r\n" + data;

      roxen_perror(sprintf("Received: %O\n", received));

      object f = spooler[0]->get_fileobject(spooler[1]);

      if (f->write(data) != sizeof(data)) {
	spooler[0]->delete_body(spooler[1]);
	send(452);
	report_error("SMTP: Spooler failed.\n");
	return;
      }

      send(250);
      report_notice("SMTP: Mail spooled OK.\n");

      // Now it's time to actually deliver the message.

      // Expand.
      multiset expanded = do_expn(recipients);

      /* Do the delivery */
      foreach(conf->get_providers("smtp_rcpt")||({}), object o) {
	o->put(expanded, spooler[1]);
      }
    }

    void smtp_DATA(string data, string args)
    {
      if (!sizeof(sender)) {
	send(503, ({ "Need sender (MAIL FROM)" }));
	return;
      }
      if (!sizeof(recipients)) {
	send(503, ({ "Need recipient list (RCPT TO)" }));
	return;
      }

      // Handling of 8BITMIME?
      
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

      mapping lt = localtime(time());
      send(220, ({ sprintf("%s ESMTP %s; %s",
			   gethostname(), roxen->version(), mktimestamp()) }));
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
      if (spooler && !smtp_server) {
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
