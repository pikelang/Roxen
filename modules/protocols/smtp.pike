/*
 * $Id: smtp.pike,v 1.1 1998/07/07 15:27:14 grubba Exp $
 *
 * SMTP support for Roxen.
 *
 * $Author: grubba $
 */

constant cvs_version = "$Id: smtp.pike,v 1.1 1998/07/07 15:27:14 grubba Exp $";
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

    void ident_HELO(array(string) ident, string args)
    {
      if (((ident[0] - " ") == "ERROR") || (sizeof(ident) < 3)) {
	send(250, ({ sprintf("%s Hello %s [%s], pleased to meet you",
			     gethostname(), args,
			     (con->query_address()/" ")*":") }));
      } else {
	send(250, ({ sprintf("%s Hello %s@%s [%s], pleased to meet you",
			     gethostname(), ident[2], args,
			     (con->query_address()/" ")*":") }));
      }
    }

    void smtp_HELO(string helo, string args)
    {
      Protocols.Ident->lookup_async(con, ident_HELO, args);
    }

    void smtp_EHLO(string ehlo, string args)
    {
      send(250, ({ sprintf("%s Hello %s [%s], pleased to meet you",
			   gethostname(), args,
			   (con->query_address()/" ")*":") }));
    }


    string sender = "";
    array(string) recipients = ({});

    void smtp_MAIL(string mail, string args)
    {
      sender = "";
      recipients = ({});

      int i = search(args, ":");
      if (i >= 0) {
	string from_colon = args[..i];
	sscanf("%*[ ]%s", from_colon, from_colon);
	if (upper_case(from_colon) == "FROM:") {
	  sender = args[i+1..];
	  sscanf("%*[ ]%s", sender, sender);
	  if (sizeof(sender)) {
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
      }
      int i = search(args, ":");
      if (i >= 0) {
	string to_colon = args[..i];
	sscanf("%*[ ]%s", to_colon, to_colon);
	if (upper_case(to_colon) == "TO:") {
	  string recipient = args[i+1..];
	  sscanf("%*[ ]%s", recipient, recipient);
	  if (sizeof(recipient)) {
	    recipients += ({ recipient });
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
      send(354);
      handle_data = handle_DATA;
    }

    constant weekdays = ({ "Sun", "Mon", "Tue", "Wed", "Thr", "Fri", "Sat" });
    constant months = ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
			 "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" });

    void create(object con_)
    {
      ::create(con_);

      mapping lt = localtime(time());
      send(220, ({ sprintf("%s ESMTP %s; %s, %02d %s %04d %02d:%02d:%02d",
			   gethostname(), roxen->version(),
			   weekdays[lt->wday], lt->mday, months[lt->mon],
			   1900 + lt->year, lt->hour, lt->min, lt->sec) }));
    }
  }

  object port = Stdio.Port();
  void got_connection()
  {
    object con = port->accept();
#if 0
    if (callbacks->verify_connection) {
      callbacks->verify_connection(con);
    }
#endif /* 0 */
    Smtp_Connection(con);	// Start a new session.
  }

  void create(object|mapping callbacks, int|void portno, string|void host)
  {
    portno = portno || 25;	// SMTP

    int res;
    if (host) {
      res = port->bind(portno, got_connection, host);
    } else {
      res = port->bind(portno, got_connection);
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

object smtp_server;

void start(int i)
{
  if (!smtp_server) {
    mixed err;
    err = catch {
      smtp_server = Server(([]), 25252);
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
