/*
 * $Id: verify_addr.pike,v 1.2 1998/09/19 14:17:24 grubba Exp $
 *
 * Support for RBL (Real-time Blackhole List).
 *
 * Henrik Grubbström 1998-09-17
 */

#include <module.h>
inherit "module";

constant cvs_version="$Id: verify_addr.pike,v 1.2 1998/09/19 14:17:24 grubba Exp $";
constant thread_safe=1;

// #define RBL_DEBUG

/*
 * Globals
 */

static object dns;

static int total;
static int accepted;
static int denied;

/*
 * Module interface functions
 */

array register_module()
{
  return({ MODULE_PROVIDER,
	   "SMTP FROM verification",
	   "Attempts to verify that the address specified "
	   "in the MAIL FROM: command is valid.",
	   0, 1
  });
}

array(string)|multiset(string)|string query_provides()
{
  return(< "smtp_filter" >);
}

string status()
{
  return(sprintf("<b>MAIL FROM requests</b>: %d<br>\n"
		 "<b>Accepted</b>: %d<br>\n"
		 "<b>Denied</b>: %d<br>\n",
		 total, accepted, denied));
}

/*
 * Callback functions
 */

// NOTE: The calling conventions make the two first arguments have
// different order between got_a() and got_mx().
static void got_a(string domain, array a, function cb, mixed ... args)
{
  if (!a) {
    // Neither MX nor A record for the domain.
    // Access denied!
    denied++;
    cb(({ sprintf("DNS domain %O does not resolve.", domain) }), @args);
    return;
  }
  accepted++;
  cb(0, @args);
}

static void got_mx(array(string) mx, string domain,
		   function cb, mixed ... args)
{
#ifdef SMTP_DEBUG
  roxen_perror(sprintf("SMTP FROM: got_mx(%O, %O, %O, %O)\n",
		       mx, domain, cb, args));
#endif /* SMTP_DEBUG */
  if (!mx) {
    // No MX record for the domain.
    // Check if there is an A record.
    // FIXME: Ought to be done in parallel with the MX lookup.
    dns->host_to_ip(domain, got_a, cb, args);
    return;
  }
  accepted++;
  cb(0, @args);
}

/*
 * smtp_filter interface functions:
 */

void async_verify_sender(string sender, function cb, mixed ... args)
{
  if (!dns) {
    dns = Protocols.DNS.async_client();
  }

  total++;

  if (sender == "") {
    // Bounce.
    accepted++;
    cb(0, @args);
    return;
  }

  array a = sender/"@";
  if (sizeof(a) > 2) {
    // Bad from address.
    denied++;
    cb(({ sprintf("Reverse path %O uses an unsupported address format.",
		  sender) }), @args);
    return;
  } else if ((sizeof(a) == 1) || (a[1] == "")) {
    // Bad from address.
    denied++;
    cb(({ sprintf("Reverse path %O does not contain a domainname.", sender) }),
       @args);
    return;
  } else if (a[0] == "") {
    // Bad from address.
    denied++;
    cb(({ sprintf("Reverse path %O does not contain a username.", sender) }),
       @args);
    return;
  }

  dns->get_mx(a[1], got_mx, a[1], cb, @args);
}
