/*
 * $Id: pop3.pike,v 1.13 1998/09/28 12:30:26 grubba Exp $
 *
 * POP3 protocols module.
 *
 * Henrik Grubbström 1998-09-27
 */

constant cvs_version = "$Id: pop3.pike,v 1.13 1998/09/28 12:30:26 grubba Exp $";
constant thread_safe = 1;

#include <module.h>

inherit "module";

#define POP3_DEBUG

static class Pop_Session
{
  inherit Protocols.Line.simple;

  static object conf;

  static object user;
  static string username;

  static multiset(object) deleted = (<>);

  static void send(string s)
  {
    send_q->put(s);
    con->set_write_callback(write_callback);
  }

  static void send_error(string s)
  {
    send("-ERR "+s+"\r\n");
  }

  static void send_ok(string s)
  {
    send("+OK "+s+"\r\n");
  }

  static string bytestuff(string s)
  {
    // RFC 1939 doesn't explicitly say what quoting is to be used,
    // but it says something about bytestuffing lines beginning with '.',
    // so we use SMTP-style quoting.
    s = replace(s, "\r\n.", "\r\n..");
    if (s[..2] == ".\r\n") {
      s = "." + s;	// Not likely, but...
    }
    if (s[sizeof(s)-2..] != "\r\n") {
      s += "\r\n";
    }
    return(s);
  }

  static void handle_command(string line)
  {
    if (sizeof(line)) {
      array a = (line/" ");

      a[0] = upper_case(a[0]);
      if (!user) {
	// AUTHORIZATION State
	if (!(<"USER", "QUIT", "PASS", "APOP">)[a[0]]) {
	  send_error("You need to login first!");
	  return;
	}
      }
      function fun = this_object()["pop_"+a[0]];
      if (!fun) {
	send_error(sprintf("%O: Not implemented yet.", a[0]));
	return;
      }
      fun(a[1..]);
      return;
    } else {
      send_error("Expected command");
    }
  }

  // Commands:

  void pop_QUIT()
  {
    send_ok(sprintf("%s POP3 server signing off", gethostname()));
    disconnect();
    if (user) {
      array(object) mail = user->get_incoming()->mail();
      indices(deleted)->delete();
    }
  }

  void pop_STAT()
  {
    object mbox = user->get_incoming();

    array(object) mail = mbox->mail() - indices(deleted);
    int num = sizeof(mail);
    int sz = `+(0, @(mail->get_size()));
    send_ok(sprintf("%d %d", num, sz));
  }

  void pop_LIST(array(string) args)
  {
    if (sizeof(args) > 1) {
      send_error("Bad number of arguments to LIST.");
      return;
    }
    object mbox = user->get_incoming();
    if (sizeof(args)) {
      object mail = mbox->get_mail_by_id(args[0]);

      if (!mail) {
	send_error(sprintf("No such mail %s.", args[0]));
	return;
      }
      
      if (deleted[mail]) {
	send_error(sprintf("Mail %s is deleted.", args[0]));
	return;
      }

      send_ok(sprintf("%s %s", mail->id, mail->get_size()));
      return;
    }
    array(object) mail = mbox->mail() - indices(deleted);
    int num = sizeof(mail);
    
    int sz = `+(0, @(mail->get_size()));
    send_ok(sprintf("%d messages (%d octets)", num, sz));
    foreach(mail, object m) {
      send(sprintf("%s %d\r\n", m->id, m->get_size()));
    }
    send(".\r\n");
  }

  void pop_RETR(array(string) args)
  {
    if (sizeof(args) != 1) {
      send_error("Bad number of aguments to RETR.");
      return;
    }
    object mbox = user->get_incoming();
    object mail = mbox->get_mail_by_id(args[0]);

    if (!mail) {
      send_error(sprintf("No such mail %s.", args[0]));
      return;
    }

    if (deleted[mail]) {
      send_error(sprintf("Mail %s is deleted.", args[0]));
      return;
    }

    string body = mail->body();
    
    send_ok(sprintf("%d octets", sizeof(body)));

    body = bytestuff(body);
    send(body);
    send(".\r\n");
  }

  void pop_DELE(array(string) args)
  {
    if (sizeof(args) != 1) {
      send_error("Bad number of arguments to DELE.");
      return;
    }
    
    object mbox = user->get_incoming();
    object mail = mbox->get_mail_by_id(args[0]);

    if (!mail) {
      send_error(sprintf("No such message %s.", args[0]));
      return;
    }

    if (deleted[mail]) {
      send_error(sprintf("message %s already deleted.", args[0]));
      return;
    }
    deleted[mail] = 1;
    send_ok(sprintf("message %s deleted.", args[0]));
  }

  void pop_NOOP()
  {
    send_ok("");
  }

  void pop_RSET()
  {
    deleted = (<>);

    object mbox = user->get_incoming();
    array(object) mail = mbox->mail();

    int num = sizeof(mail);
    int sz = `+(0, @(mail->get_size()));
    send_ok(sprintf("maildrop has %d messages (%d octets)", num, sz));
  }

  void pop_TOP(array(string) args)
  {
    if (sizeof(args) != 2) {
      send_error("Bad number of arguments to TOP.");
      return;
    }
    
    object mbox = user->get_incoming();
    object mail = mbox->get_mail_by_id(args[0]);

    if (!mail) {
      send_error(sprintf("No such message %s.", args[0]));
      return;
    }

    if (deleted[mail]) {
      send_error(sprintf("message %s is deleted.", args[0]));
      return;
    }

    string body = mail->body();
    int i;
    if (body[..1] != "\r\n") {
      i = search(body, "\r\n\r\n");
      if (i < 0) {
	i = sizeof(body);
      } else {
	i += 4;
      }
    } else {
      i = 2;
    }
    // i is the start of the real body...
    int n = (int)args[1];
    int j;
    for(j = 0; j < n; j++) {
      if ((i = search(body, "\r\n", i)) != -1) {
	i += 2;
      } else {
	i = sizeof(body);
	break;
      }
    }
    body = body[..i-1];
    send_ok("");
    body = bytestuff(body);
    send(body);
    send(".\r\n");
  }

  void pop_UIDL(array(string) args)
  {
    if (sizeof(args) > 1) {
      send_error("Bad number of arguments to UIDL.");
      return;
    }
    if (sizeof(args)) {
      object mail = user->get_incoming()->get_mail_by_id(args[0]);
      if (!mail) {
	send_error(sprintf("No such message %s.", args[0]));
	return;
      }
      if (deleted[mail]) {
	send_error(sprintf("Message %s is deleted.", args[0]));
	return;
      }
      send_ok(sprintf("%s %s", mail->id, mail->id));
      return;
    } else {
      send_ok("");
      foreach(user->get_incoming()->mail() - indices(deleted), object m) {
	send(sprintf("%s %s\r\n", m->id, m->id));
      }
      send(".\r\n");
      return;
    }
  }

  void pop_USER(array(string) args)
  {
    if (sizeof(args) != 1) {
      send_error("Bad number of arguments to USER command.");
      return;
    }
    username = args[0];
    user = 0;
    send_ok(sprintf("Password required for %s.", username));
  }

  void pop_PASS(array(string) args)
  {
    user = 0;	// Logout...
    if (!username) {
      send_error("Expected USER.");
      return;
    }
    username = replace(username, ({"*", "_AT_"}), ({ "@", "@" }));
    string pass = args * " ";
    foreach(conf->get_providers("automail_clientlayer")||({}), object o) {
      mixed u = o->get_user(username, pass);
      if (objectp(u)) {
	user = u;
	break;
      } else if (u) {
	roxen_perror(sprintf("POP3: Unexpected result: %O\n", u));
      }
    }
    if (user) {
      send_ok(sprintf("User %s logged in.", username));
    } else {
      send_error(sprintf("Access denied for %O.", username));
      pop_QUIT();
    }
  }

  void pop_APOP()
  {
    user = 0;	// Logout;

    send_error("Not supported yet.");
  }

  void create(object con, object c)
  {
    conf = c;
    ::create(con);

    send_ok(sprintf("POP3 (%s). Timestamp: <%d.%d@%s>",
		    roxen->version(), getpid(), time(), gethostname()));
  }
};

static object conf;

static object port;

static void got_connection()
{
  object con = port->accept();

  Pop_Session(con, conf);	// Start a new session.
}

static void init()
{
  int portno = QUERY(port) || Protocols.Ports.tcp.pop3;
  string host = 0; // QUERY(host);

  port = 0;
  object newport = Stdio.Port();
  object privs;

  if (portno < 1024) {
    privs = Privs("Opening port below 1024 for POP3.\n");
  }

  mixed err;
  int res;
  err = catch {
    if (host) {
      res = newport->bind(portno, got_connection, host);
    } else {
      res = newport->bind(portno, got_connection);
    }
  };

  if (privs) {
    destruct(privs);
  }

  if (err) {
    throw(err);
  }

  if (!res) {
    throw(({ sprintf("POP3: Failed to bind to port %d\n", portno),
	     backtrace() }));
  }

  port = newport;
}

/*
 * Roxen module interface
 */

void destroy()
{
  if (port) {
    destruct(port);
  }
}

array register_module()
{
  return({ MODULE_PROVIDER,
	   "POP3 protocol",
	   "Experimental module for POP3." });
}

array(string)|multiset(string)|string query_provides()
{
  return(< "pop3_protocol" >);
}

void create()
{
  defvar("port", Protocols.Ports.tcp.pop3, "POP3 port number",
	 TYPE_INT | VAR_MORE,
	 "Portnumber to listen to.<br>\n"
	 "Usually " + Protocols.Ports.tcp.pop3 + ".\n");

#if 0
  // Enable this later.
  defvar("timeout", 10*60, "Timeout", TYPE_INT | VAR_MORE,
	 "Idle time before connection is closed (seconds).<br>\n"
	 "Zero or negative to disable timeouts.");
#endif /* 0 */
}

void start(int i, object c)
{
  if (c) {
    conf = c;

    mixed err;
    err = catch {
      if (!port) {
	init();
      }
    };
    if (err) {
      report_error(sprintf("POP3: Failed to initialize the server:\n"
			   "%s\n", describe_backtrace(err)));
    }
  }
}

void stop()
{
  destroy();
}

string query_name()
{
  return(sprintf("pop3://%s:%d/", gethostname(), QUERY(port)));
}


