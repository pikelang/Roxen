/*
 * $Id: lyskomrcpt.pike,v 1.1 1999/01/29 01:12:23 js Exp $
 *
 * A LysKOM module for the AutoMail system.
 *
 * Johan Schön, January 1999.
 */

#include <module.h>

inherit "module";

#define RCPT_DEBUG

constant cvs_version = "$Id: lyskomrcpt.pike,v 1.1 1999/01/29 01:12:23 js Exp $";

/*
 * Roxen glue
 */

array register_module()
{
  return({ MODULE_PROVIDER,
	   "AutoMail LysKOM recipient",
	   "LysKOM module for the AutoMail system.",0,1 });
}

object conf;


void create()
{
  defvar("komserver", "kom.idonex.se",
	 "LysKOM server hostname" ,TYPE_STRING,"");
  defvar("komport", 4894,
	 "LysKOM port number" ,TYPE_INT|VAR_MORE,"");
  defvar("komuser", "Brevbäraren",
	 "LysKOM login username" ,TYPE_STRING,"");
  defvar("kompassword", "ghop45",
	 "LysKOM password" ,TYPE_STRING,"");

}

object session;
void start(int i, object c)
{
  if (c) {
    conf = c;
     werror("LysKOM: Session(): %O\n",(session=LysKOM.Session(query("komserver"),query("komport"))));
     array(object) myids=session->lookup_person(query("komuser"));
     if(sizeof(myids)==1)
     {
       if(myids[0])
       {
	 werror("LysKOM: myid: %O", myids[0]);
	 werror("LysKOM: kompassword: %O",query("kompassword"));
	 werror("LysKOM: login: %O\n",session->login(myids[0],query("kompassword")));
       }
     }
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

  array(object) conferences = session->lookup_conferance(replace(addr/"@","."," "),1);
  return (< @(conferences->realname) >);
}

string desc(string addr, object o)
{
  roxen_perror("AutoMail RCPT: desc(%O)\n", addr);

  addr = get_addr(addr);

  foreach( session->lookup_conferance(replace(addr/"@","."," "),1), object conference )
    return conference->realname;
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

array(object) get_confs(string list)
{
  array(string) addresses = Array.map(list/",", get_addr);
  array confs = ({ });
  foreach(addresses, string addr)
    confs += ({ @session->lookup_conferance(replace(addr/"@","."," "),1) });
  return confs;
}


int put(string sender, string user, string domain,
	object mail, string csum, object o)
{
  roxen_perror("AutoMail LysKOM RCPT: put(%O, %O, %O, %O, %O, X)\n",
	       sender, user, domain, mail, csum);
  
  mail->seek(0);
  string x=mail->read();
  object msg=MIME.Message(x);
  mapping headers=decoded_headers(msg->headers);

  int res;

  string in_reply_to=headers["in-reply-to"];
  int comment_to;
  sscanf(in_reply_to,"<%*d.%d@",comment_to);
  session->create_text(sprintf("[%s] %s",
			       headers->from,
			       headers->subject),
		       get_real_body(msg),
		       get_confs(headers->to),
		       get_confs(headers->cc),
		       comment_to,
		       0,
		       0);
  return 1;
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
  return "Rcpt: LysKOM";
}

string query_automail_name()
{
  return "rcpt_lyskom";
}


array(array(string)) query_automail_variables()
{
  return ({ });
}


