/*
 * $Id: smsrcpt.pike,v 1.5 1999/01/29 01:12:23 js Exp $
 *
 * A SMS module for the AutoMail system.
 *
 * Johan Schön, September 1998.
 */

#include <module.h>

inherit "module";


#define RCPT_DEBUG

constant cvs_version = "$Id: smsrcpt.pike,v 1.5 1999/01/29 01:12:23 js Exp $";

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
  defvar("outputstring", "Mail from: %s, Subject: %s, Mail body: %s",
	 "SMS Message description string" ,TYPE_STRING,"");
  defvar("strip_aao", 0,
	 "Convert åäö to aao" ,TYPE_FLAG,"");
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

string get_real_body(object msg)
{
  return ((msg->body_parts || ({ msg })) -> getdata() ) * "";
}

mapping decoded_headers(mapping heads)
{
  foreach(indices(heads), string w)
  {
    array(string) fusk0 = heads[w]/"=?";
    heads[w]=fusk0[0];
    foreach(fusk0[1..], string fusk)
    {
	string fusk2;
	string p1,p2,p3;
	if(sscanf(fusk, "%[^?]?%1s?%[^?]%s", p1,p2,p3, fusk) == 4)
	{
	  werror("dw: =?"+p1+"?"+p2+"?"+p3+"?=\n");
	  heads[w] += MIME.decode_word("=?"+p1+"?"+p2+"?"+p3+"?=")[0];
	}
	sscanf(fusk, "?=%s", fusk);
	heads[w] += fusk;
    }
  }
  return heads;
}


int put(string sender, string user, string domain,
	object mail, string csum, object o)
{
  roxen_perror("AutoMail SMS RCPT: put(%O, %O, %O, %O, %O, X)\n",
	       sender, user, domain, mail, csum);

  
  object clientlayer=conf->get_provider("automail_clientlayer");
  mail->seek(0);
  object msg=MIME.Message(mail->read());
  mapping headers=decoded_headers(msg->headers);
  werror("sms: headers: %O\n",headers);
  int res;
  object u = clientlayer->get_user_from_address(user+"@"+domain);
  object a = conf->get_provider("automail_admin");
  
  if(u && a->query_status(u->id,query_automail_name()))
  {
    string smsnumber=a->query_variable(u->id,query_automail_name(),"sms_number");
    if(smsnumber)
    {
      string res=sprintf(query("outputstring"),
			 headers->from||"",
			 headers->subject||"",
			 get_real_body(msg));
      if(query("strip_aao"))
	res=replace(res, "ÅÄÖåäö"/"", "AAOaao"/"");
      werror("sms: res: %O\n",res);
      Process.create_process( ({ "/usr/bin/sms",
				 smsnumber,
				 res }) );
      int customer_id=u->query_customer_id();
      clientlayer->add_charge_to("sms",customer_id);
    }
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


