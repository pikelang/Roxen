/*
 * $Id: testrcpt.pike,v 1.4 1998/09/09 23:37:29 js Exp $
 *
 * A skeleton test RCPT module for the AutoMail system.
 *
 * Henrik Grubbström 1998-09-02
 */

#include <module.h>

inherit "module";

#define RCPT_DEBUG

constant cvs_version = "$Id: testrcpt.pike,v 1.4 1998/09/09 23:37:29 js Exp $";

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

mapping(string:multiset(string)|string) expn_tab = ([
  "grubba":(<"grubba@grubba.org">),
  "developers":(<"grubba", "zino", "js", "gurka">),
  "zino":"peter@bortas.org",
  "js":"js@idonex.se",
]);

mapping(string:string) desc_tab = ([
  "grubba@grubba.org":"Henrik Grubbström",
  "peter@bortas.org":"Peter Bortas",
  "js@idonex.se":"Johan Schön",
]);

/*
 * SMTP_RCPT callbacks
 */

string|multiset(string) expn(string addr, object o)
{
  roxen_perror("RCPT: expn(%O, X)\n", addr);

  string a = get_addr(addr);

  return(expn_tab[a]);
}

string desc(string addr)
{
  roxen_perror("RCPT: desc(%O)\n", addr);

  string n = desc_tab[addr];

  if (n) {
    return(sprintf("%O <%s>", n, addr));
  }
  return(0);
}

void put(multiset(string) recipients, string mailid)
{
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



