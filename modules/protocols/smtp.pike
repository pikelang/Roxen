/*
 * $Id: smtp.pike,v 1.64 1998/09/29 18:34:25 grubba Exp $
 *
 * SMTP support for Roxen.
 *
 * Henrik Grubbström 1998-07-07
 */

constant cvs_version = "$Id: smtp.pike,v 1.64 1998/09/29 18:34:25 grubba Exp $";
constant thread_safe = 1;

#include <module.h>

inherit "module";

#define SMTP_DEBUG

/*
 * TODO:
 *
 * o Add possibility to disable relaying.
 *
 * o Better support for SIZE.
 *
 * o Add option to limit the size of accepted mail.
 *
 * o Code clean-up.
 */

/*
 * Provider module interface:
 *
 * smtp_rcpt:
 *	string|multiset(string) expn(string addr, object o);
 * 	string desc(string addr, object o);
 *	multiset(string) query_domain();
 *	int put(string sender, string user, string domain,
 * 	        object spoolfile, string csum, object o);
 *
 * smtp_filter:
 *	int check_size(object|mapping mail);
 *	int verify_sender(string sender);
 *	void async_verify_sender(string sender, function cb, mixed ... args);
 * 	int verify_recipient(string sender, string recipient, object o);
 * 	int classify_connection(string remoteip, int remoteport,
 * 	                        string remotehost);
 *	void async_classify_connection(object con, mapping con_info,
 *				       function cb, mixed ... args);
 *	int classify_address(string user, string domain);
 *
 * smtp_relay:
 * 	int relay(string sender, string user, string domain,
 * 	          object spoolfile, string csum, object o);
 *
 * NOTE: Modules need to handle the terminating '.' in domainnames.
 */

static class Mail {
  string id;
  int timestamp;
  object connection;

  string from;
  multiset(string) recipients = (<>);
  string contents;
  mapping extensions;
  int limit;


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

  void set_limit(int l)
  {
#ifdef SMTP_DEBUG
    roxen_perror("Size limit is %O\n", l);
#endif /* SMTP_DEBUG */
    limit = l;
  }

  void save()
  {
  }

  void create()
  {
    timestamp = time();
  }
};

static class do_multi_async
{
#ifdef THREADS
  static object lock = Thread.Mutex();
#endif /* THREADS */
  static array res = ({});
  static int count;
  static function callback;
  static array callback_args;

  static void low_callback(array|void r)
  {
#ifdef THREADS
    mixed key = lock->lock();
#endif /* THREADS */
    if (r && sizeof(r)) {
      res += r;
    }
    if (!--count) {
      callback(res, @callback_args);
    }
  }

  void create(array(function) func, array args, function cb, mixed ... cb_args)
  {
#ifdef SMTP_DEBUG
    roxen_perror(sprintf("do_multi_async(%O, %O, %O, %O)\n",
			 func, args, cb, cb_args));
#endif /* SMTP_DEBUG */
    if (!(count = sizeof(func))) {
      // Nothing to do...
      cb(res, @cb_args);
      destruct();
      return;
    }

    callback = cb;
    callback_args = cb_args;

    // This is an interresting way to call all the functions in the
    // array with the same arguments.
    func(@args, low_callback);
  }
};

static class Smtp_Connection {
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
  string remoteident;		// User according to ident.
  string remoteip;		// IP
  string remoteport;		// PORT
  string remotehost;		// Name from the IP.
  string remotename;		// Name given in HELO or EHLO.
  array(string) ident;
  object conf;
  object parent;
  string prot = "SMTP";

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

    if (!remotename && parent->query_polite() &&
	(!(< "EHLO", "HELO" >)[cmd])) {
      // Client is required to be polite.
      report_warning(sprintf("SMTP: Got command %O %O before EHLO or HELO "
			     "from %s@%s [%s]\n",
			     cmd, arg,
			     remoteident||"UNKNOWN", remotehost, remoteip));
      send(503, ({ "Expected EHLO or HELO command." }));
      return;
    }

    function f;
    if (f = this_object()["smtp_"+cmd]) {
      f(cmd, arg);
    } else if (command_help[cmd]) {
      // NOTE: RFC 821 4.3 states that 502 is not a legal reply
      //       to the following commands:
      //   HELO, MAIL, RCPT, DATA, RSET, NOOP, QUIT
      // But RFC 821 4.5.1 requires them to be implemented, so
      // they won't show up here anyway.
      report_notice(sprintf("SMTP: Command not implemented: %O\n", cmd));
      send(502, ({ sprintf("'%s': Command not implemented.", cmd) }));
    } else {
      report_warning(sprintf("SMTP: Unknown command: %O\n", cmd));
      send(500, ({ sprintf("'%s': Unknown command.", cmd) }));
    }
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
    return(Array.map(a, lower_case));
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

  void smtp_HELO(string helo, string args)
  {
    remotename = args;

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

  void smtp_EHLO(string ehlo, string args)
  {
    prot = "ESMTP";
    smtp_HELO("EHLO", args);
  }

  void smtp_EXPN(string mail, string args)
  {
    // Fake request id for logging purposes.
    mapping id = ([
      "method":"EXPN",
      "prot":prot,
      "remoteaddr":remoteip,
      "time":time(),
      "cookies":([]),
      "not_query":args,
    ]);

    if (!sizeof(args)) {
      conf->log(([ "error":400 ]), id);
      send(501, "Expected argument");
      return;
    }

    multiset orig = (<@do_parse_address(args)>);
    multiset m = parent->do_expn(orig, this_object());

    array result = ({});

    array rcpts = Array.filter(conf->get_providers("smtp_rcpt")||({}),
			       lambda(object o) { return(o->desc); });

    parent->update_domains();

    int forced_update;

    foreach(indices(m), string addr) {
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
      int local_addr = !domain || parent->handled_domains[domain];
      if (!local_addr && !forced_update) {
	// Check if it's a new domain.
	forced_update = 1;
	parent->update_domains(1);
	local_addr = parent->handled_domains[domain];
      }
      if (local_addr) {
	// Local address.
	if (domain) {
	  foreach(rcpts, object o) {
	    string l = o->desc(addr, this_object());
	    if (l) {
	      result += ({ sprintf("%O <%s>", l, addr) });
	      handled = 1;
	    }
	  }
	}
	if (!handled) {
	  foreach(rcpts, object o) {
	    string l = o->desc(user, this_object());
	    if (l) {
	      result += ({ sprintf("%O <%s>", l, addr) });
	      handled = 1;
	    }
	  }
	}
	if (!handled) {
	  id->not_query = addr;
	  conf->log(([ "error":404 ]), id);
	  send(550, ({ sprintf("<%s>... Unhandled recipient.", addr) }));
	  return;
	}
      } else {
	if (orig[addr]) {
	  // Relayed address.
	  // FIXME: Should check if relaying is allowed.
	  result += ({ "<" + addr + ">" });
	} else {
	  // Alias to remote account.
	  result += ({ "<" + addr + ">" });
	}
      }
    }

    conf->log(([ "error":200 ]), id);

    send(250, sort(result));
  }

  static string low_desc(string addr)
  {
#ifdef SMTP_DEBUG
    roxen_perror("SMTP: low_desc(%O)\n", addr);
#endif /* SMTP_DEBUG */

    string user;
    string domain;
    array arr = addr/"@";
    if (sizeof(arr) > 1) {
      user = arr[..sizeof(arr)-2]*"@";
      domain = arr[-1];
    } else {
      user = addr;
      domain = 0;
    }
    array descs = Array.filter(conf->get_providers("smtp_rcpt")||({}),
			       lambda(object o) { return(o->desc); });

    foreach(descs, object o) {
      string s;

      if (domain) {
	if (s = o->desc(addr, this_object())) {
	  return(s);
	}
      }
      if (s = o->desc(user, this_object())) {
	return(s);
      }
    }
  }

  void smtp_VRFY(string vrfy, string args)
  {
    // Fake request id for logging purposes.
    mapping id = ([
      "method":"VRFY",
      "prot":prot,
      "remoteaddr":remoteip,
      "time":time(),
      "cookies":([]),
      "not_query":args,
    ]);

    if (!sizeof(args)) {
      conf->log(([ "error":400 ]), id);
      send(501, "Expected argument");
      return;
    }

    array a = do_parse_address(args);

    array expns = Array.filter(conf->get_providers("smtp_rcpt")||({}),
			       lambda(object o) { return(o->expn); });
    
    parent->update_domains();

    int i;
    for(i=0; i < sizeof(a); i++) {
      string s = 0;

      string user;
      string domain;

      array arr = a[i]/"@";
      if (sizeof(arr) > 1) {
	user = arr[..sizeof(arr)-2]*"@";
	domain = arr[-1];
      } else {
	user = a[i];
	domain = 0;
      }

      if (domain && !parent->handled_domains[domain]) {
	// External address.
	s = "";
      } else {

	s = low_desc(a[i]);

	if (!s) {
	  if (domain) {
	    foreach(expns, object o) {
	      string|multiset m;
	      if (m = o->expn(a[i], this_object())) {
		if (stringp(m)) {
		  a[i] = m;

		  s = low_desc(a[i]);
		}
		if (!s) {
		  s = "";
		}
		break;
	      }
	    }
	  }
	}
	if (!s) {
	  foreach(expns, object o) {
	    string|multiset m;
	    if (m = o->expn(user, this_object())) {
	      if (stringp(m)) {
		a[i] = m;

		s = low_desc(a[i]);
	      }
	      if (!s) {
		s = "";
	      }
	      break;
	    }
	  }
	  if (!s) {
	    id->not_query = a[i];
	    conf->log(([ "error":404 ]), id);
	    send(550, sprintf("%s... User unknown", a[i]));
	    return;
	  }
	}
      }
      if (sizeof(s)) {
	a[i] = sprintf("%O <%s>", s, a[i]);
      } else {
	a[i] = "<" + a[i] + ">";
      }
    }

    conf->log(([ "error":200 ]), id);

    send(250, sort(a));
  }

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

    // Fake request id for logging purposes.
    mapping id = ([
      "method":"RSET",
      "prot":prot,
      "remoteaddr":remoteip,
      "time":time(),
      "cookies":([]),
      "not_query":args,
    ]);

    conf->log(([ "error":200 ]), id);

    send(250, "Reset ok.");
  }

  void smtp_MAIL(string mail, string args)
  {
    // Fake request id for logging purposes.
    mapping id = ([
      "method":"MAIL",
      "prot":prot,
      "remoteaddr":remoteip,
      "time":time(),
      "cookies":([]),
      "not_query":args,
    ]);

    do_RSET();
    
    current_mail = Mail();

    // Do some syntax checks first.

    int i = search(args, ":");
    if (i < 0) {
      conf->log(([ "error":400 ]), id);
      send(501);
      do_RSET();
      return;
    }

    string from_colon = args[..i];
    sscanf("%*[ ]%s", from_colon, from_colon);
    if (upper_case(from_colon) != "FROM:") {
      conf->log(([ "error":400 ]), id);
      send(501);
      do_RSET();
      return;
    }

    array a = (args[i+1..]/" ") - ({ "" });
	
    if (!sizeof(a)) {
      // Empty return address == bounce message.
      if (connection_class > 0) {
	connection_class = 0;
      }
      conf->log(([ "error":202 ]), id);
      send(250, ({ "Message accepted for local delivery." }));
      return;
    }

    // a[0] is the return address.
    // We will examine it later.

    current_mail->set_from(@do_parse_address(a[0]));
    id->not_query = current_mail->from;
	    
    // Check size limits.

    int limit = 0x7fffffff;	// MAXINT
    int hard = 1;		// hard limit initially.

    mapping fss = filesystem_stat(parent->query_spooldir());

    if (!fss) {
      id->method = "SPOOL";
      id->not_query = parent->query_spooldir();
      conf->log(([ "error":500 ]), id);
      send(452, "Spooldirectory not available. Try later.");
      do_RSET();
      return;
    }

    if (!zero_type(fss->favail) && (fss->favail < 10)) {
      id->method = "SPOOL";
      id->not_query = parent->query_spooldir();
      conf->log(([ "error":404 ]), id);
      send(452, "Out of inodes. Try later.");
      do_RSET();
      return;
    }

    foreach(conf->get_providers("smtp_filter")||({}), object o) {
      if (o->check_size) {
	int l = o->check_size(current_mail);
	if (l) {
	  if (l < 0) {
	    // Negative: Soft limit.
	    l = -l;
	    if (l < limit) {
	      hard = 0;
	      limit = l;
	    }
	  } else {
	    // Positive: Hard limit.
	    if (l < limit) {
	      hard = 1;
	      limit = l;
	    }
	  }
	}
      }
    }

    {
      // New scope to keep these variables local.
      float szfactor = parent->query_size_factor();

      int bsize = (fss->blocksize || 512);

      if (fss->bavail * szfactor <= (limit / bsize)) {
	if (fss->blocks * szfactor <= (limit / bsize)) {
	  limit = (int)(bsize * fss->blocks * szfactor);
	  hard = 1;
	} else {
	  limit = (int)(bsize * fss->bavail * szfactor);
	  hard = 0;
	}
      }
    }
		  
    current_mail->set_limit(limit);

    // Limit checks done.

    // Now check if there were any extensions.

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
		  
	    if (sz > limit) {
	      conf->log(([ "error":403 ]), id);
	      if (hard) {
		send(552, sprintf("Size %d exceeds hard limit %d.\n",
				  sz, limit));
	      } else {
		send(452, sprintf("Size %d exceeds soft limit %d.\n",
				  sz, limit));
	      }
	      return;
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

    // Now it's time to examine the return address.

    foreach(conf->get_providers("smtp_filter")||({}), object o) {
      // roxen_perror("Got SMTP filter\n");
      if (functionp(o->verify_sender) &&
	  o->verify_sender(current_mail->from)) {
	// Refuse connection.
#ifdef SMTP_DEBUG
	report_notice(sprintf("Sender %O refused.\n", current_mail->from));
#endif /* SMTP_DEBUG */
	conf->log(([ "error":401 ]), id);
	do_RSET();
	send(550);
	return;
      }
    }

    parent->update_domains();

    do_multi_async(Array.map(conf->get_providers("smtp_filter")||({}),
			     lambda(object o) {
			       return(o->async_verify_sender);
			     }) - ({ 0 }),
		   ({ current_mail->from }),
		   lambda(array res, mapping id) {
#ifdef SMTP_DEBUG
		     roxen_perror("SMTP: async_verify_sender_cb()\n");
#endif /* SMTP_DEBUG */
		     if (sizeof(res)) {
		       conf->log(([ "error":401 ]), id);
		       do_RSET();
		       send(550, res);
		     } else {
		       conf->log(([ "error":200 ]), id);
		       send(250);
		     }
		   }, id);
  }

  void smtp_RCPT(string rcpt, string args)
  {
    // Fake request id for logging purposes.
    mapping id = ([
      "method":"RCPT",
      "prot":prot,
      "remoteaddr":remoteip,
      "time":time(),
      "cookies":([]),
      "not_query":args,
    ]);

    if (!current_mail) {
      conf->log(([ "error":400 ]), id);
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
	  recipient = lower_case(do_parse_address(recipient)[0]);

	  id->not_query = recipient;

	  foreach(conf->get_providers("smtp_filter")||({}), object o) {
	    // roxen_perror("Got SMTP filter\n");
	    if (functionp(o->verify_recipient) &&
		o->verify_recipient(current_mail->from, recipient,
				    this_object())) {
	      // Refuse recipient.
#ifdef SMTP_DEBUG
	      report_notice(sprintf("Recipient %O refused.\n", recipient));
#endif /* SMTP_DEBUG */
	      conf->log(([ "error":403 ]), id);
	      send(550, sprintf("%s... Recipient refused", recipient));
	      return;
	    }
	  }

	  array a = recipient/"@";
	  string domain;
	  string user;

	  if (sizeof(a) > 1) {
	    domain = a[-1];
	    user = a[..sizeof(a)-2]*"@";
	  } else {
	    user = recipient;
	  }

	  int recipient_ok;

	  if ((!domain) || (parent->handled_domains[domain])) {
	    // Local address.

	    if (domain) {
	      // Full address check.
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
	    }
	    if (!recipient_ok) {
	      // Check if we have a default handler for this user.
	      foreach(conf->get_providers("smtp_rcpt")||({}), object o) {
		if (functionp(o->expn) &&
		    o->expn(user, this_object())) {
		  recipient_ok = 1;
		  break;
		}
		if (functionp(o->desc) &&
		    o->desc(user, this_object())) {
		  recipient_ok = 1;
		  break;
		}
	      }
	    }
	  } else {
	    // Remote address.

	    // Check if we allow relaying.

	    int address_class = 0x7fffffff;		// MAXINT

	    foreach(conf->get_providers("smtp_filter")||({}), object o) {
	      if (o->classify_address) {
		int ac = o->classify_address(user, domain);
		if (ac < address_class) {
		  address_class = ac;
		}
	      }
	    }

	    if (connection_class < address_class) {
#ifdef SMTP_DEBUG
	      report_notice(sprintf("SMTP: Relaying to address %s denied.\n",
				    recipient));
#endif /* SMTP_DEBUG */
	      conf->log(([ "error":405 ]), id);
	      send(550, ({ "Relaying denied." }));
	      return;
	    }
      
	    recipient_ok = 1;
	  }

	  if (!recipient_ok) {
#ifdef SMTP_DEBUG
	    report_notice(sprintf("SMTP: Unhandled recipient %O.\n",
				  recipient));
#endif /* SMTP_DEBUG */
	    conf->log(([ "error":404 ]), id);
	    send(550, sprintf("%s... Unhandled recipient.", recipient));
	    return;
	  }

	  // Relaying is allowed, so add the recipient.

	  conf->log(([ "error":200 ]), id);
	  current_mail->add_recipients((< recipient >));
	  send(250, sprintf("%s... Recipient ok.", recipient));
	  return;
	}
      }
    }
    conf->log(([ "error":400 ]), id);
    send(501);
  }

  // DATA handling

  void handle_DATA(string data)
  {
    // roxen_perror(sprintf("SMTP: %O\n", data));

    // Unquote the lines...
    // ie delete any initial period ('.') signs.
    // RFC 821 4.5.2.2
    data = replace(data, "\n.", "\n");
    if (data[0] == '.') {
      data = data[1..];
    }

    // Check that the mail doesn't exceed the size limit.
    if (sizeof(data) > current_mail->limit) {
      send(552);
      do_RSET();
      return;
    }

    // Add received-headers here.

    string received = sprintf("from %s (%s@%s [%s])\r\n"
			      "\tby %s (%s) with %s;\r\n"
			      "\t%s",
			      remotename, remoteident||"", remotehost||"",
			      remoteip,
			      localhost, roxen->version(), prot,
			      mktimestamp(current_mail->timestamp));

#ifdef SMTP_DEBUG  
    roxen_perror(sprintf("Received: %O\n", received));
#endif /* SMTP_DEBUG */

    data = "Received: " + received + "\r\n" + data;

    array res = parent->send_mail(data, current_mail, this_object());

    // Send the status code
    send(@res);

    // Make ready for the next mail.
    do_RSET();
  }

  void smtp_DATA(string data, string args)
  {
    if (!current_mail) {
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

  // Called when the connection has been idle for at
  // least timeout seconds.
  static void do_timeout()
  {
    catch {
      // Send a nice message.
      send(421, "Timeout");
    };
    catch {
      // Delayed disconnet.
      disconnect();
    };

    touch_time();	// We want to send the timeout message...
    _timeout_cb();	// Restart the timeout timer.

    // Force disconnection in timeout/2 time
    // if the other end doesn't read any data.
    call_out(::do_timeout, timeout/2);
  }

  static void con_class_done(array(string) reason, object con)
  {
    int classified;
    foreach(conf->get_providers("smtp_filter") ||({}), object o) {
      // roxen_perror("Got SMTP filter\n");
      if (functionp(o->classify_connection)) {
	int c = o->classify_connection(remoteip, remoteport, remotehost);

	classified = 1;
	if (c < 0) {
	  // Refuse connection.
#ifdef SMTP_DEBUG
	  report_notice(sprintf("Connection from %s [%s:%d] refused.\n",
				remotehost, remoteip, remoteport));
#endif /* SMTP_DEBUG */
	  reason += ({ "Connection Refused" });
	  break;
	} else if (!connection_class) {
	  connection_class = c;
	}
      }
    }
    if (!classified) {
      connection_class = 0x7fffffff;
    }

    if (sizeof(reason)) {
      // Log that we've disconnected.
      conf->log(([ "error":401, ]),
		([ "method":"CONNECT",
		   "not_query":sprintf("Access denied\n"
				       "%s",
				       reason * "\n"),
		   "prot":prot,
		   "remoteaddr":remoteip,
		   "time":time(),
		   "cookies":([]),]));
		   
      // Give a reason why we disconnect
      ::create(con, parent->query_timeout());
      send(421, ({
	sprintf("%s ESMTP %s; %s",
		gethostname(), roxen->version(),
		mktimestamp(time(1))),
      }) + reason);
      disconnect();
      // They have 30 seconds to read the message...
      call_out(destruct, 30, this_object());
      return;
    }

    ::create(con, parent->query_timeout());

    send(220, ({ sprintf("%s ESMTP %s; %s",
			 gethostname(), roxen->version(),
			 mktimestamp(time())) }));
  }

  static void got_remotehost(string h,
			     function|void callback, mixed ... args)
  {
    remotehost = h || remoteip;
    if (callback) {
      callback(@args);
    }
  }

  static void async_lookup_host(object con, mapping con_info,
				function cb, mixed ... args)
  {
    roxen->ip_to_host(con_info->remoteip, got_remotehost, cb, 0, @args);
  }

  static void got_remoteident(array(string) i,
			      function|void callback, mixed ... args)
  {
    ident = i;

    if ((sizeof(ident) >= 3) && ((ident[0] - " ") != "ERROR")) {
      remoteident = ident[2];
    }

    if (callback) {
      callback(@args);
    }
  }

  static void async_lookup_ident(object con, mapping con_info,
				 function cb, mixed ... args)
  {
    Protocols.Ident->lookup_async(con, got_remoteident, cb, 0, @args);
  }

  void create(object con_, object parent_, object conf_)
  {
    conf = conf_;
    parent = parent_;

    array(string) remote = con_->query_address()/" ";

    remoteip = remote[0];
    remoteport = (remote[1..])*" ";

    mapping con_info = ([
      "remoteip":remoteip,
      "remoteport":remoteport,
    ]);

    do_multi_async(({ async_lookup_host, async_lookup_ident }) +
		   Array.map(conf->get_providers("smtp_filter")||({}),
			     lambda(object o) {
			       return(o->async_classify_connection);
			     }) - ({ 0 }),
		   ({ con_, con_info }),
		   con_class_done, con_);
  }
}

static object conf;

static object port;

static void got_connection()
{
  object con = port->accept();

  Smtp_Connection(con, this_object(), conf);	// Start a new session.
}

static void init()
{
  int portno = QUERY(port) || Protocols.Ports.tcp.smtp;
  string host = 0; // QUERY(host);

  port = 0;
  object newport = Stdio.Port();
  object privs;

  if (portno < 1024) {
    privs = Privs("Opening port below 1024 for SMTP.\n");
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
    throw(({ sprintf("SMTP: Failed to bind to port %d\n", portno),
	     backtrace() }));
  }

  port = newport;
}

/*
 * Some glue code
 */

int query_polite()
{
  return(QUERY(polite));
}

int query_timeout()
{
  return(QUERY(timeout));
}

string query_spooldir()
{
  return(QUERY(spooldir));
}

float query_size_factor()
{
  return(((float)(QUERY(size_factor)))/100.0);
}

multiset do_expn(multiset in, object|void smtp)
{
#ifdef SMTP_DEBUG
  roxen_perror(sprintf("SMTP: Expanding %O\n", in));
#endif /* SMTP_DEBUG */

  multiset expanded = (<>);		// Addresses expanded ok.
  multiset done = (<>);			// Addresses that have been EXPN'ed.
  multiset to_do = copy_value(in);	// Addresses still left to expand.
    
  array expns = Array.filter(conf->get_providers("smtp_rcpt")||({}),
			     lambda(object o){ return(o->expn); });

  while (sizeof(to_do)) {
    foreach(indices(to_do), string addr) {
      done[addr] = 1;
      to_do[addr] = 0;
      int verbatim = 1;
      foreach(expns, object o) {
	string|multiset e = o->expn(addr, smtp);
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

multiset(string) handled_domains = (<>);

void update_domains(int|void force)
{
  if (force || !handled_domains || (!sizeof(handled_domains))) {
    // Update the table of locally handled domains.
    multiset(string) domains = (<>);
    foreach(conf->get_providers("smtp_rcpt")||({}), object o) {
      if (o->query_domain) {
	domains |= o->query_domain();
      }
    }

    // Ensure that both foo.domain.org and foo.domain.org. are in
    // the multiset.
    foreach(indices(domains), string d) {
      if (d[-1] == '.') {
	domains[d[..sizeof(d)-2]] = 1;
      } else {
	domains[d + "."] = 1;
      }
    }

    handled_domains = domains;
  }
}

static int counter;
static object open_spoolfile()
{
  string dir = QUERY(spooldir);
  int i;
  object o = Stdio.File();

  for (i = 0; i < 10; i++) {
    string spoolid = sprintf("%08x%08x%08x%08x",
			     getpid(), time(), gethrtime(), ++counter);
    
    string f = combine_path(dir, spoolid);

    if (o->open(f, "crwax")) {
#ifndef __NT__
      rm(f);
#endif /* !__NT__ */
      return(o);
    }
  }
  return(0);
}

/*
 * Send a mail
 *
 * data			is the mail to send.
 *
 * mail->from		is the MAIL FROM: address
 * mail->recipients	is an array(string) with recipients.
 *
 * smtp			is the Smtp_Connection from which the mail originates.
 */
array(int|string) send_mail(string data, object|mapping mail, object|void smtp)
{
  string csum = Crypto.sha()->update(data)->digest();

  // Fake request id for logging purposes.
  mapping id = ([
    "prot":"INTERNAL",
    "remoteaddr":"0.0.0.0",
    "time":time(),
    "cookies":([])
  ]);
  if (smtp) {
    id->prot = smtp->prot;
    id->remoteaddr = smtp->remoteip;
  }
  string fname = replace(MIME.encode_base64(csum), "/", ".");
  id->not_query = sprintf("From:%s;nrcpts:%d;%s",
			  mail->from, sizeof(mail->recipients),
			  fname);
  
  object spool = open_spoolfile();

  id->method = "SPOOL";

  if (!spool) {
    conf->log(([ "error":500, "len":sizeof(data) ]), id);
    report_error("SMTP: Failed to open spoolfile!\n");
    return(({ 550, "No spooler available" }));
  }

  if (spool->write(data) != sizeof(data)) {
    spool->close();
    conf->log(([ "error":404, "len":sizeof(data) ]), id);
    report_error("SMTP: Spooler failed. Disk full?\n");
    return(({ 452 }));
  }

  // Now it's time to actually deliver the message.

  update_domains();

  // Expand.
  multiset expanded = do_expn(mail->recipients, smtp);

  int any_handled = 0;
  int forced_update = 0;

  /* Do the delivery */
  id->method = "DELIVER";
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
    int local_addr = !domain || handled_domains[domain];
    if (!local_addr && !forced_update) {
      // Check if it's a new domain.
      forced_update = 1;
      update_domains(1);
      local_addr = handled_domains[domain];
    }
    if (local_addr) {
      // Local delivery.
      if (domain) {
	// Primary delivery.
	foreach(conf->get_providers("smtp_rcpt")||({}), object o) {
	  handled |= o->put(mail->from, user, domain, spool, csum, smtp);
	}
      }
      if (!handled) {
	// Fallback delivery.
	foreach(conf->get_providers("smtp_rcpt")||({}), object o) {
	  handled |= o->put(mail->from, user, 0, spool, csum, smtp);
	}
      }
    } else {
      // Remote delivery.
      foreach(conf->get_providers("smtp_relay")||({}), object o) {
	handled |= o->relay(mail->from, user, domain, spool, csum, smtp);
      }
    }
    id->not_query = sprintf("From:%s;To:%s;%s", mail->from, addr, fname);
    if (handled) {
      expanded[addr] = 0;
      any_handled = 1;

      // Mail accepted for delivery.
      conf->log(([ "error":200, "len":sizeof(data)]), id);
    } else {
      // Mail not accepted.
      conf->log(([ "error":400, "len":sizeof(data)]), id);
    }
  }

  if (!any_handled) {
    // None of the recipients accepted the message.
    report_notice("SMTP: Failed to spool mail.\n");
    return(({ 554 }));
  }

  // NOTE: After this point error-messages must be sent by mail.

  if (sizeof(expanded)) {
    // Partial success.
    roxen_perror(sprintf("The following recipients were unavailable:\n"
			 "%s\n", String.implode_nicely(indices(expanded))));

    // FIXME: Send bounce here.

    return(({ 250, "Partial failure. See bounce for details." }));
  } else {
    // Message received successfully.
#ifdef SMTP_DEBUG
    report_notice("SMTP: Mail spooled OK.\n");
#endif /* SMTP_DEBUG */
    return(({ 250 }));
  }
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
	   "SMTP protocol",
	   "Experimental module for receiving mail." });
}

array(string)|multiset(string)|string query_provides()
{
  return(< "smtp_protocol" >);
}

void create()
{
  defvar("port", Protocols.Ports.tcp.smtp, "SMTP port number",
	 TYPE_INT | VAR_MORE,
	 "Portnumber to listen to.<br>\n"
	 "Usually " + Protocols.Ports.tcp.smtp + ".\n");

  defvar("spooldir", "/var/spool/mqueue/", "Mail spool directory", TYPE_DIR,
	 "Directory to temporary keep incoming mail.");

  defvar("polite", 1, "Require EHLO/HELO", TYPE_FLAG | VAR_MORE,
	 "Require the client to be polite, and say EHLO/HELO before "
	 "accepting other commands.");

  defvar("timeout", 10*60, "Timeout", TYPE_INT | VAR_MORE,
	 "Idle time before connection is closed (seconds).<br>\n"
	 "Zero or negative to disable timeouts.");

  defvar("size_factor", 50, "Size percentage", TYPE_INT | VAR_MORE,
	 "Percentage of the free disk space a single mail may take.");
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
      report_error(sprintf("SMTP: Failed to initialize the server:\n"
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
  return(sprintf("smtp://%s:%d/", gethostname(), QUERY(port)));
}
