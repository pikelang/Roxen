/*
 * $Id: automailrcpt.pike,v 1.6 1998/09/21 15:44:55 js Exp $
 *
 * A RCPT module for the AutoMail system.
 *
 * Henrik Grubbström 1998-09-02
 */

#include <module.h>

inherit "module";

#define RCPT_DEBUG

constant cvs_version = "$Id: automailrcpt.pike,v 1.6 1998/09/21 15:44:55 js Exp $";

/*
 * Roxen glue
 */

array register_module()
{
  return({ MODULE_PROVIDER|MODULE_EXPERIMENTAL,
	   "AutoMail SMTP recipient",
	   "RCPT module for the AutoMail system." });
}

object conf;

void create()
{
}

void start(int i, object c)
{
  if (c) {
    conf = c;
  }
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
 * SMTP_RCPT callbacks
 */

string|multiset(string) expn(string addr, object o)
{
  roxen_perror("AutoMail RCPT: expn(%O, X)\n", addr);

  // No alias support in the clientlayer.
  return(0);
}

string desc(string addr, object o)
{
  roxen_perror("AutoMail RCPT: desc(%O)\n", addr);

  addr = get_addr(addr);

  string addr2;

  if (addr[-1] == '.') {
    addr2 = addr[..sizeof(addr)-2];
  } else {
    addr2 = addr + ".";
  }

  foreach(conf->get_providers("automail_clientlayer")||({}), object o) {
    object u = o->get_user_from_address(addr) ||
      o->get_user_from_address(addr2);

    if (u) {
      return(u->query_name()||"");
    }
  }
}

int put(string sender, string user, string domain,
	object mail, string csum, object o)
{
  roxen_perror("AutoMail RCPT: put(%O, %O, %O, %O, %O, X)\n",
	       sender, user, domain, mail, csum);

  if (!domain) {
    return(0);
  }

  string addr = user + "@" + domain;

  string addr2;
  if (domain[-1] == '.') {
    addr2 = user + "@" + domain[..sizeof(domain)-2];
  } else {
    addr2 = addr + ".";
  }

  int res;
  foreach(conf->get_providers("automail_clientlayer")||({}), object o) {
    object u = o->get_user_from_address(addr) ||
      o->get_user_from_address(addr2);

    if (u && conf->get_provider("automail_admin")->
	query_status(u->id,query_automail_name()))
    {
      u->get_incoming()->create_mail_from_fd(mail);
      res = 1;
    }
  }

  return(res);
}

multiset(string) query_domain()
{
  foreach(conf->get_providers("automail_clientlayer")||({}), object o) {
    return(o->list_domains());
  }
}

// AutoMail Admin callbacks

string query_automail_title()
{
  return "Rcpt: AutoMail Database";
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



