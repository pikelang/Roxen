/*
 * $Id: lyskomrcpt.pike,v 1.3 1999/03/23 13:53:09 peter Exp $
 *
 * A LysKOM module for the AutoMail system.
 *
 * Johan Schön, January 1999.
 */

#include <module.h>

inherit "module";

#define RCPT_DEBUG

constant cvs_version = "$Id: lyskomrcpt.pike,v 1.3 1999/03/23 13:53:09 peter Exp $";

/*
 * Roxen glue
 */

array register_module()
{
  return({ MODULE_PROVIDER,
	   "AutoMail LysKOM recipient and relayer",
	   "LysKOM module for the AutoMail system.",0,1 });
}

object conf;


void create()
{
  defvar("smtpserver", "y.idonex.se",
	 "SMTP server to use" ,TYPE_STRING,"");
  defvar("handledomain", "kom.idonex.se",
	 "Handle this domain" ,TYPE_STRING,"");
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
    if(!i)
    {
     werror("LysKOM: Session(): %O\n",(session=LysKOM.Session(query("komserver"),query("komport"))));
     array(object) myids=session->lookup_person(query("komuser"));
     if(sizeof(myids)==1)
     {
       if(myids[0])
	 werror("LysKOM: login: %O\n",session->login(myids[0],query("kompassword")));
       call_out(check_queue,0.25);
     }
    }
  }
}

void stop()
{
  if(session)
    session->close();
}
array(string)|multiset(string)|string query_provides()
{
  return (< "smtp_rcpt","automail_rcpt" >);
}

constant weekdays = ({ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"});
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


void check_queue()
{
  while(session->async_queue->size())
  {
    object msg = session->async_queue->read();
    if(msg->code==0)
    {
      object db=conf->get_provider("sql")->sql_object();
      object text=LysKOM.Abstract.Texts(session)[msg->text_no];

      int sent=0;
      foreach(text->comment_to->text_no, int commented)
      {
	string to=(db->query("select address from kom_receivers where type='to' "
			     "and id='"+commented+"'")->address)*", ";
	string cc=(db->query("select address from kom_receivers where type='cc' "
			     "and id='"+commented+"'")->address)*", ";
	string from_simple="c"+text->author->conf_no+"@"+query("handledomain");
	string from=text->author->realname+" <"+from_simple+">";
	string subject=text->subject;
	sscanf(subject,"[%*s] %s",subject);
	string message_id=sprintf("<%d@%s>",msg->text_no,query("handledomain"));
	string in_reply_to;
	mapping headers=(["mime-version":"1.0",
			"subject":subject,
			"from":from,
			"to":to,
			"cc":cc,
			"message-id": message_id,
			"date":mktimestamp(time()),
			"content-type":
			"text/plain;charset=iso-8859-1",
			"content-transfer-encoding":"8bit"]);
	array a=db->query("select message_id from message_ids where kom_id="+commented);
	if(sizeof(a))
	  headers["in-reply-to"]=a[0]->message_id;
	string message=(string)MIME.Message(text->body,
					    headers);
	Protocols.SMTP.client()->
	  send_message(from_simple,
		       Array.map( (((to||"")/", ")+((cc||"")/", ")) - ({ "" }),
				  get_addr),
		       message);
	db->query("insert into message_ids (kom_id,message_id) values ('"+
		  msg->text_no+"','"+message_id+"')");

	session->send_message(text->author,
			      "Message sent:\n\n"
			      "To: "+to+"\n"
			      "Cc: "+cc);
	sent=1;
      }
      if(!sent)
	session->send_message(text->author,"No sender found!");
    }
  }
  call_out(check_queue,0.25);
}

/*
 * Helper functions
 */

string get_addr(string addr)
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
  return a*"";
}

string remove_trailing_dot(string in)
{
  if(in[-1]=='.')
    in=in[..sizeof(in)-2];
  return in;
}

/*
 * SMTP_RCPT callbacks
 */

string|multiset(string) expn(string addr, object o)
{
  roxen_perror("AutoMail RCPT: expn(%O, X)\n", addr);
  addr=remove_trailing_dot(addr);

  if(sscanf(addr,sprintf("c%%*d@%s",query("handledomain"))))
    return addr;

  if(sscanf(addr,sprintf("%%*s@%s",query("handledomain")))<1)
    return 0;
  
  array(object) conferences = session->lookup_conference(replace((addr/"@")[0],
								 "."," "),1);
  return (< @Array.map(conferences->conf_no,lambda(int conf_no, string handledomain)
					    {
					      return sprintf("c%d@%s",conf_no,handledomain);
					    },query("handledomain"))
  >);
}

string desc(string addr, object o)
{
  roxen_perror("AutoMail RCPT: desc(%O)\n", addr);
  addr=remove_trailing_dot(addr);
  int conf_no;
  if(!sscanf(addr,"c%d@",conf_no))
    return 0;

  if(sscanf(addr,sprintf("%%*s@%s",query("handledomain")))<1)
    return 0;
  
  object conference=LysKOM.Abstract.Conferences(session)[conf_no];
  if(conference)
    return conference->name;
  else
    return 0;
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

  if(lower_case(domain)!=query("handledomain"))
    return 0;
  mail->seek(0);
  string x=mail->read();
  object msg=MIME.Message(x);
  mapping headers=decoded_headers(msg->headers);

  int res;
  array(int) comment_to = ({ });
  array(string) comment_to_ids = Array.map( ( ((headers["in-reply-to"]||"")/", ")+
					  ((headers["references"]||"")/", "))
					- ({ "" }), get_addr);

  object db=conf->get_provider("sql")->sql_object();
  foreach(comment_to_ids, string comment_to_id)
  {
    array a=db->query("select kom_id from message_ids where message_id='<"+
		      db->quote(comment_to_id)+">'");
    if(sizeof(a))
      comment_to += ({ (int)a[0]->kom_id });
  }
    
  int conf_no;
  sscanf(user,"c%d",conf_no);
  if(!conf_no) return 1;
  object conference=LysKOM.Abstract.Conferences(session)[conf_no];

  object db=conf->get_provider("sql")->sql_object();
 
  int id = session->create_text(sprintf("[%s] %s",
					headers->from||"",
					headers->subject||""),
				get_real_body(msg)-"\r",
				conference,
				({ }),
				comment_to,
				0,
				0);

  if(headers["message-id"])
    db->query("insert into message_ids (kom_id,message_id) values ('"+
	      id+"','"+db->quote(headers["message-id"])+"')");

  if(headers->to)
    foreach(headers->to/",", string to)
      if(search(to,query("handledomain"))==-1)
	db->query("insert into kom_receivers (id,type,address) "
		  "values ('"+id+"','to','"+db->quote(to)+"')");
  if(headers->from)
    foreach(headers->from/",", string from)
      db->query("insert into kom_receivers (id,type,address) "
		"values ('"+id+"','to','"+db->quote(from)+"')");
  if(headers->cc)
    foreach(headers->cc/",", string cc)
      db->query("insert into kom_receivers (id,type,address) "
		"values ('"+id+"','cc','"+db->quote(cc)+"')");
  return 1;
}

multiset(string) query_domain()
{
  return (< query("handledomain") >);
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


