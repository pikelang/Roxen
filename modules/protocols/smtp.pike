/*
 * $Id: smtp.pike,v 1.3 1998/07/08 18:01:32 grubba Exp $
 *
 * SMTP support for Roxen.
 *
 * Henrik Grubbström 1998-07-07
 */

constant cvs_version = "$Id: smtp.pike,v 1.3 1998/07/08 18:01:32 grubba Exp $";
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

    object conf;
    int ehlo_mode;

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

    void ident_HELO(array(string) ident, string args)
    {
      array(string) res;
      if (((ident[0] - " ") == "ERROR") || (sizeof(ident) < 3)) {
	res = ({ sprintf("%s Hello %s [%s], pleased to meet you",
			 gethostname(), args,
			 (con->query_address()/" ")*":") });
      } else {
	res = ({ sprintf("%s Hello %s@%s [%s], pleased to meet you",
			 gethostname(), ident[2], args,
			 (con->query_address()/" ")*":") });
      }
      if (ehlo_mode) {
	res += ({});	// Supported extensions...
      }
      send(250, res);
    }

    void smtp_HELO(string helo, string args)
    {
      Protocols.Ident->lookup_async(con, ident_HELO, args);
    }

    void smtp_EHLO(string ehlo, string args)
    {
      ehlo_mode = 1;
      Protocols.Ident->lookup_async(con, ident_HELO, args);
    }

    static multiset(string) expand_recipient(string recipient)
    {
      multiset(string) expanded = (<>);
      multiset(string) seen = (<>);
      multiset(string) to_expand = (< recipient >);

      while(sizeof(to_expand)) {
	foreach(indices(to_expand), string r) {
	  if (seen[r]) {
	    // Shouldn't happen, but...
	    expanded[r] = 1;
	    continue;
	  }
	  to_expand[r] = 0;
	  seen[r] = 1;
	  foreach(conf->get_providers("smtp_recipient"), object o) {
	    if (functionp(o->expand_recipient)) {
	      multiset(string) nr = o->expand_recipient(r);
	      if (nr) {
		if (nr[r]) {
		  // Loop means keep me.
		  expanded[r] = 1;
		}
		to_expand |= nr - seen;
		break;
	      }
	    }
	  }
	  expanded[r] = 1;
	}
      }
      return(expanded);
    }

    void smtp_EXPN(string mail, string args)
    {
      if (!sizeof(args)) {
	send(501, "Expected argument");
	return;
      }

      multiset m = expand_recipient(args);

      send(250, sort(indices(m)));
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

	    foreach(conf->get_providers("smtp_filter"), object o) {
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
	    foreach(conf->get_providers("smtp_filter"), object o) {
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

	    recipients += expand_recipient(recipient);
	    send(250);
	    return;
	  }
	}
      }
      send(501);
    }

    void handle_DATA(string data)
    {
      // Add received-headers here.
      send(250);
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
      
      send(354);
      handle_data = handle_DATA;
    }

    constant weekdays = ({ "Sun", "Mon", "Tue", "Wed", "Thr", "Fri", "Sat" });
    constant months = ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
			 "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" });

    void create(object con_, object conf_)
    {
      conf = conf_;

      foreach(conf->get_providers("smtp_filter"), object o) {
	// roxen_perror("Got SMTP filter\n");
	if (functionp(o->verify_connection) &&
	    o->verify_connection(con_)) {
	  // Refuse connection.
#ifdef SMTP_DEBUG
	  roxen_perror("Refuse connection.\n");
#endif /* SMTP_DEBUG */
	  con->close();
	  return;
	}
      }

      ::create(con_);

      mapping lt = localtime(time());
      send(220, ({ sprintf("%s ESMTP %s; %s, %02d %s %04d %02d:%02d:%02d",
			   gethostname(), roxen->version(),
			   weekdays[lt->wday], lt->mday, months[lt->mon],
			   1900 + lt->year, lt->hour, lt->min, lt->sec) }));
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
	 "Portnumber to listen to. Usually " + Protocols.Ports.tcp.smtp + ".\n");
}

object smtp_server;

void start(int i, object c)
{
  if (c && !smtp_server) {
    mixed err;
    err = catch {
      smtp_server = Server(c, ([]), QUERY(port));
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
