/*
 * $Id: smsrcpt.pike,v 1.1 1998/09/28 03:37:24 js Exp $
 *
 * A LysKOM SMS module for the AutoMail system.
 *
 * Johan Schön, September 1998.
 */

#include <module.h>

inherit "module";


#define RCPT_DEBUG

constant cvs_version = "$Id: smsrcpt.pike,v 1.1 1998/09/28 03:37:24 js Exp $";

/*
 * Roxen glue
 */

array register_module()
{
  return({ MODULE_PROVIDER,
	   "AutoMail SMS recipient",
	   "SMS recipient module for the AutoMail system.",0,1 });
}

object conf;


void create()
{
  defvar("outputstring", "Mail from: %s, Subject: %s",
	 "SMS Message description string" ,TYPE_STRING,"");
}

object session;
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
  roxen_perror("AutoMail SMS RCPT: put(%O, %O, %O, %O, %O, X)\n",
	       sender, user, domain, mail, csum);

  
  object clientlayer=conf->get_provider("automail_clientlayer");
  object msg=MIME.Message();
  mapping headers=msg->parse_headers(clientlayer->read_headers_from_fd(mail))[0];
  
  int res;
  object u = clientlayer->get_user_from_address(user+"@"+domain);
  object a = conf->get_provider("automail_admin");
  if(u && a->query_status(u->id,query_automail_name()))
  {
    string smsnumber=a->query_variable(u->id,query_automail_name(),"sms_number");
    if(smsnumber)
      werror(Process.popen("/usr/bin/sms "+smsnumber+" '"+
			   sprintf(query("outputstring"),
				   headers->from,
				   headers->subject)+"'"));
  }
  return res;
}

multiset(string) query_domain()
{
  foreach(conf->get_providers("automail_clientlayer")||({}), object o) 
    return(o->list_domains());
}

// AutoMail Admin callbacks

string query_automail_title()
{
  return "Rcpt: SMS";
}

string query_automail_name()
{
  return "rcpt_sms";
}


array(array(string)) query_automail_variables()
{
  return ({ ({ "SMS number", "sms_number" })
	    });
}


