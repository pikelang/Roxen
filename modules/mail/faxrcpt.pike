/*
 * $Id: faxrcpt.pike,v 1.7 1999/01/29 01:12:21 js Exp $
 *
 * A FAX module for the AutoMail system.
 *
 * Johan Schön, September 1998.
 */

#include <module.h>

inherit "module";

#define RCPT_DEBUG

constant cvs_version = "$Id: faxrcpt.pike,v 1.7 1999/01/29 01:12:21 js Exp $";

/*
 * Roxen glue
 */

array register_module()
{
  return({ MODULE_PROVIDER,
	   "AutoMail Fax recipient",
	   "LysKOM Fax module for the AutoMail system.",0,1 });
}

object conf;


void create()
{
  defvar("lineslimit", 100,
	 "Lines limit" ,TYPE_INT,"");

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

#define courier_10              "\033(s0p0b0s0t10H"
#define line_16                 "\033(s0p0b0s3t16.6H"
#define helvetica_8             "\033(s1p0b0s4t8V"
#define helvetica_10            "\033(s1p0b0s4t10V"
#define helvetica_12            "\033(s1p0b0s4t12V"
#define helvetica_10_italics 	"\033(s1p0b1s4t10V"
#define helvetica_12_italics 	"\033(s1p0b1s4t12V"
#define helvetica_10_bold 	"\033(s1p3b0s4t10V"
#define helvetica_14_bold 	"\033(s1p3b0s4t12V"
#define helvetica_14_bold 	"\033(s1p3b0s4t14V"
#define times_10_bold           "\033(s1p3b1s4t10V"
#define times_12_italics 	"\033(s1p3b1s4t12V"
#define times_10_bold 	        "\033(s1p3b0s5t10V"
#define times_12_bold 	        "\033(s1p3b0s5t12V"
#define times_14_bold 	        "\033(s1p3b0s5t14V"
#define times_8                 "\033(s1p0b0s5t8V"
#define times_10                "\033(s1p0b0s5t10V"
#define times_12                "\033(s1p0b0s5t12V"

string get_real_body(object msg)
{
  return ((msg->body_parts || ({ msg })) -> getdata() ) * "";
}

string fontify_mail(mapping headers, string body)
{
  string s=helvetica_14_bold+"New mail\n\n";
  s+=times_12_bold+"From: "+times_12+(headers->from||"Unknown")+"\n";
  s+=times_12_bold+"To: "+times_12+(headers->to||"Unknown")+"\n";
  s+=times_12_bold+"Date: "+times_12+(headers->date||"Unknown")+"\n";
  s+=times_12_bold+"Subject: "+times_12+headers->subject+"\n\n";
  s+=courier_10;
  if(sizeof(body/"\n")>query("lineslimit"))
    s+=((body/"\n")[..query("lineslimit")-1])*"\n"+"\n"+times_12_bold+"[truncated]";
  else
    s+=body;
  return s+"\n";
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
  roxen_perror("AutoMail Fax RCPT: put(%O, %O, %O, %O, %O, X)\n",
	       sender, user, domain, mail, csum);
  
  object clientlayer=conf->get_provider("automail_clientlayer");
  mail->seek(0);
  string x=mail->read();
  object msg=MIME.Message(x);
  mapping headers=decoded_headers(msg->headers);
//   werror("Fax: x: %O\n",x);
//   werror("headers: %O\n",headers);
//   werror("real_body: %O\n",get_real_body(msg));
  int res;
  object u = clientlayer->get_user_from_address(user+"@"+domain);
  object a = conf->get_provider("automail_admin");
  if(u && a->query_status(u->id,query_automail_name()))
  {
    string fn="/tmp/fax"+time()+random(1000000);
    Stdio.File(fn,"rwct")->write( fontify_mail(headers,get_real_body(msg)) );
    string faxnumber=a->query_variable(u->id,query_automail_name(),"fax_number");
    if(faxnumber)
    {
      Process.popen("/usr/bin/faxlogon");
      Process.popen("/usr/bin/faxsend '"+Process.sh_quote(faxnumber)+"' "+fn);
      int customer_id=u->query_customer_id();
      clientlayer->add_charge_to("fax",customer_id);
    }
    rm(fn);
  }
  return res;
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
  return "Rcpt: Fax";
}

string query_automail_name()
{
  return "rcpt_fax";
}


array(array(string)) query_automail_variables()
{
  return ({ ({ "Fax number", "fax_number" })
	    });
}


