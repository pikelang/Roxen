/*
 * $Id: testrcpt.pike,v 1.7 1998/09/12 21:30:43 grubba Exp $
 *
 * A skeleton test RCPT module for the AutoMail system.
 *
 * Henrik Grubbström 1998-09-02
 */

#include <module.h>

inherit "module";

#define RCPT_DEBUG

constant cvs_version = "$Id: testrcpt.pike,v 1.7 1998/09/12 21:30:43 grubba Exp $";

/*
 * Roxen glue
 */

array register_module()
{
  return({ MODULE_PROVIDER|MODULE_EXPERIMENTAL,
	   "SMTP Test recipient",
	   "Experimental RCPT module for the AutoMail system." });
}

void create()
{
}

array(string)|multiset(string)|string query_provides()
{
  return (< "smtp_rcpt","automail_rcpt" >);
}

/*
 * Helper functions
 */

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
 * Some tables
 */

static mapping(string:multiset(string)|string) expn_tab = ([
  "grubba":(<"grubba@grubba.org">),
  "developers":(<"grubba", "zino", "js", "gurka">),
  "zino":"peter@bortas.org",
  "gazonk@foobar.se":"js@idonex.se",
]);

static mapping(string:string) desc_tab = ([
  "grubba@idonex.se":"Henrik Grubbström (Idonex)",
  "grubba":"Henrik Grubbström",
  "peter":"Peter Bortas",
  "js":"Johan Schön",
]);

static multiset(string) handled_domains = (<
  "foobar.se", "grubba.org", "bortas.org", "idonex.se",
>);

/*
 * SMTP_RCPT callbacks
 */

string|multiset(string) expn(string addr, object o)
{
  roxen_perror("RCPT: expn(%O, X)\n", addr);

  string a = get_addr(addr);

  return(expn_tab[a]);
}

string desc(string addr, object o)
{
  roxen_perror("RCPT: desc(%O)\n", addr);

  return(desc_tab[addr]);
}

int put(string sender, string user, string domain, string mailid, object o)
{
  roxen_perror("RCPT: put(%O, %O, %O, %O, X)\n",
	       sender, user, domain, mailid);
  return 0;
}

multiset(string) query_domain()
{
  return handled_domains;
}

// AutoMail Admin callbacks

string query_automail_title()
{
  return "Rcpt: Database";
}

string query_automail_name()
{
  return "rcpt_db";
}

array(array(string)) query_automail_variables()
{
  return ({ ({ "Phone number", "phone_number" }),
	    ({ "SMS number", "sms_number" })
	    });
}



