/* This is -*- pike -*- code */
/* Standard roxen module header -------------------------------- */
#include <module.h>
inherit "module";
inherit "roxenlib";
inherit Regexp : regexp;

constant cvs_version = 
"$Id: mailtags.pike,v 1.24 1998/11/26 04:49:56 per Exp $";

constant thread_safe = 1;


/* Some defines to cheer up our day ---------------------------- */

#define UID id->misc->_automail_user

#ifdef DEBUG
# undef DEBUG
#endif

#ifdef MODULE_DEBUG
# define DEBUG(X) if(debug) werror X ;
#else
# define DEBUG(X) 
#endif

/* Prototypes ----------------------------------------------------- */
#define WANT_CLIENTINIT
#include "clientlayer.h"

class SMTPRelay
{
  void send_message(string from, multiset(string) rcpt,
		    string message, string|void csum);

  /* Semi private */
  void bounce(mapping msg, string code, array(string) text, 
	      string last_command);
  int relay(string from, string user, string domain,
	    Stdio.File mail, string csum, object o);
};




/* Globals ---------------------------------------------------------*/

static MIME.Message mymesg = MIME.Message();
static roxen.Configuration conf;
static int debug, secure;
static mapping (string:User) uid_cache = ([]);


/* These should be constants, but they cannot be ------------------- */
static mapping _login = http_auth_required( "E-Mail" );
static string scroll_down = Image.GIF.encode(arrow(1));
static string scroll_up   = Image.GIF.encode(arrow(0));


/* Roxen module glue ---------------------------------------------- */
/* These functions are arranged in calling order. ----------------- */

void create()
{
  defvar("debug", 0, "Debug", TYPE_FLAG, 
	 "If this flag is set, debugging output might be added for some"
	 " tags. Also, more sanity checks will be done");

  defvar("security_level", "high", "Security level", 
	 TYPE_STRING_LIST|VAR_MORE,
	 "The level of security verification to do.<p>"
	 "high:  All checks. It should be impossible to read mail"
	 " that is not yours, same goes for list of mail etc.<p>"
	 "mail: Only the ownership of mail will be checked.<p>"
	 "low: Only checks that will not generate extra SQL queries"
	 " will be done. This saves CPU, but the cost is high. A smart and"
	 " resourcefull user could read all mail.",
	 ({ "high", "mail", "low"}));

  defvar("location", "/mailextras/", "Location", TYPE_LOCATION|VAR_MORE, "");

  regexp::create("^(.*)((http://|https://|ftp:/|news:|wais://|mailto:"
		 "|telnet:)[^ \n\t\012\014\"<>|\\\\]*[^ \r\n\t\012\014"
		 "\"<>|\\\\.,(){}?'`*])");
}

array register_module()
{
  return ({ MODULE_PARSER|MODULE_PROVIDER|MODULE_LOCATION,
	    "Automail HTML client",
	    "This module adds quite a few new tags for Automail email "
	    "handling. This module talks to the AutoMail client layer module",
	    0,1 });
}

mapping query_tag_callers()
{
  return common_callers(  "tag_" );
}

mapping query_container_callers()
{
  return common_callers(  "container_" );
}

string query_provides()
{
  return "automail_htmlmail";
}


void start(int q, roxen.Configuration c)
{
  if(!c)
  {
    report_debug("start called without configuration\n");
    return;
  }  
  conf = c;
  report_notice("AutoMail HTML Client added to the '"+c->query_name()+
		"' configuration.\n");

  if(!init_clientlayer( c ))
    report_error("AutoMail HTML Client init failed!\n");

  debug = query("debug");
  
  if(query("security_level") == "high")
    secure=2;
  else if(query("security_level") == "mail")
    secure=1;
  else
    secure=0;
}
mapping find_file(string f, object id)
{
  array path = f/"/";
  switch(path[0])
  {
   case "scroll":
     return ([ "type":"image/gif", 
	       "data":Image.GIF.encode(bevel1(Image.image(15,250,192,182,162)->
		       paste(bevel(Image.image(11,max((int)path[1]*5,10))),
				     2,((int)path[2]*5))))
     ]); 

   case "scroll_up":
     return ([ "type":"image/gif", "data":scroll_up ]);

   case "scroll_down":
     return ([ "type":"image/gif", "data":scroll_down ]);
  }
}

/* Utility functions ---------------------------------------------- */




object bevel1(object from)
{
  from->line(0,0,from->xsize()-1, 0, 0, 0, 0);
  from->line(1,1,from->xsize()-2, 1, 100, 90, 80);

  from->line(0,0,0,from->ysize()-1, 0, 0, 0);
  from->line(1,1,1,from->ysize()-2, 100, 90, 80);

  from->line(from->xsize()-1,from->ysize()-1,from->xsize()-1,0, 250, 240, 220);
  from->line(from->xsize()-1,from->ysize()-1, 0,from->ysize()-1, 
	     250, 240, 220);
  return from;
}

object bevel(object from)
{
  from->line(0,0,from->xsize()-1, 0, 250, 240, 220);
  from->line(1,1,from->xsize()-2, 1, 200, 180, 160);
  from->line(0,0,0,from->ysize()-1, 250, 240, 220);
  from->line(1,1,1,from->ysize()-1, 250, 240, 160);
  from->box(2,2,from->xsize()-3, from->ysize()-2, 192, 182, 100);
  return from;
}

static string get_date( string from )
{
  mapping h = extended_headers(([ "date":from ]));
  return h->reldate-" ago";
}

static array move(array in, int dx, int dy)
{
  array out = copy_value(in);
  for(int i=0;i<sizeof(in);i+=2)
  {
    out[i]+=dx;
    out[i+1]+=dy;
  }
  return out;
}

static Image.image arrow(int flip)
{
  array poly = 
  ({
    7.5,2,
    13,13,
    2,13,
    7.5,2
  });
  Image.image o = Image.image(15,15,192,182,162);
  o->setcolor( 250,240,220 );
  o->polyfill(move(poly, -1, -1));
  o->polyfill(move(poly, -1, 0));
  o->polyfill(move(poly, 0, -1));
  o->setcolor( 0,0,0 );
  o->polyfill(move(poly, 1, 1));
  o->polyfill(move(poly, 0, 1));
  o->polyfill(move(poly, 1, 0));
  o->setcolor( 192,182,100 );
  o->polyfill(move(poly, 0, 0));
  return bevel1(flip?o->mirrory():o);
}

// For multipart/alternative
static int type_score( MIME.Message m )
{
  return (m->type == "text") + ((m->subtype == "html")*2) + 
         (m->type=="multipart")*2;
}

// for multipart/related tags with a href
static mixed internal_odd_tag_href(string t, mapping args, 
				   string url, string pp )
{
  int pno;
  if(args->href && sscanf(args->href, "cid:part%d", pno))
  {
    args->href = replace(url, "#part#", pp+"/"+(string)pno);
    return ({ make_tag(t, args ) });
  }
}

// for multipart/related tags with a src
static mixed internal_odd_tag_src(string t, mapping args, 
				  string url, string pp )
{
  int pno;
  if(args->src && sscanf(args->src, "cid:part%d", pno))
  {
    args->src = replace(url, "#part#", pp+"/"+(string)pno);
    return ({ make_tag(t, args ) });
  }
}

// for text/enriched
class Tag
{
  string tn;

  string `()(string t, mapping m, string c)
  {
    if(tn == "pre")
      c = replace(c-"\r", "\n\n", "\n");
    return make_container( tn, m, html_encode_string(c) );
  }

  void create(string _tn)
  {
    tn = _tn;
  }
}

static string highlight_enriched( string from, object id )
{
  string a, b, c;
  while(sscanf(from, "%s<<%s>%s", a, b, c)==3)
    from = a+"&lt;"+b+"&gt;"+c;
  
  from = parse_html( describe_body(from,0,1), ([ ]), 
		     ([ 
		       "nofill":Tag("pre"),
		       "bold":Tag("b"),
		     ]));

  from = replace(from-"\r","\n>","<br>&gt;");
  return replace(from, "\n\n", "\n<br>\n");
}

// Returns a time_t in UTC, given a year, month, date hour minute
// second and timezone (as a string).
static int gettime( int year, string month, int date, int hour, 
		    int minute, int second, string tz )
{
  int houradd;
  int minuteadd;
  sscanf(tz[1..2], "%d", houradd);
  sscanf(tz[3..4], "%d", minuteadd);
  if(tz[0]=='+')
  {
    houradd = -houradd;
    minuteadd = -minuteadd;
  }
  hour += houradd;
  minute += minuteadd;
  if(minute < 0)
  {
    hour--;
    minute += 60;
  }
  if( minute >= 60 )
  {
    hour++;
    minute -= 60;
  }
  if(hour < 0)
  {
    date--;
    hour+=24;
  }
  if(hour >= 24)
  {
    date++;
    hour-=24;
  }
  if(year > 1900) year -= 1900;

  mapping mt=([]);
  mt->year = year;
  mt->mon = MONTHS[month];
  mt->mday = date;
  mt->hour = hour;
  mt->min = minute;
  mt->sec = second;
  // We do not care about date being out of range. mktime() can handle 
  // that automatically.
  
  mapping lt = localtime(time());
  return mktime( mt )-lt->timezone+(lt->isdst?3600:0);
}

// FIXME: This one might be to inexact right now. It looks rather
// nice, though.
static string describe_time_period( int amnt )
{
  if(amnt < 0) return "some time";
  amnt/=60;
  if(amnt < 120) return amnt+" minutes";
  amnt/=60;
  if(amnt < 48) return amnt+" hours";
  amnt/=24;
  if(amnt < 60) return amnt+" days";
  amnt/=(365/12);
  if(amnt < 30) return amnt+" months";
  amnt/=12;
  return amnt+" years";
}

// Add some extra headers to a headers mapping.
// Currently only adds a 'reldate' header.

static mapping extended_headers( mapping from )
{
  from = copy_value( from );
  if(from->date)
  {
    int when;
    int date, year, hour, minute, second;
    string month, tz;

    // Fri, 11 Sep 1998 22:59:18 +0200 (MET DST)
    // Sun, 13 Sep 1998 22:05:06 +0200
    if(sscanf(from->date, 
	      "%*s, %d %s %d %d:%d:%d %s", 
	      date, month, year, hour, minute, second, tz ) == 8)
    {
      if(catch(when = gettime( year, month, date, hour, minute, second, tz )))
      {
	from->reldate="Impossible date; year>2386 or year<1940";
	when=0;
      }
    }

    // 10 Sep 1998 21:51:35 -0700
    if(sscanf(from->date, 
	      "%d %s %d %d:%d:%d %s", 
	      date, month, year, hour, minute, second, tz ) == 7)
      if(catch(when = gettime( year, month, date, hour, minute,
			       second, tz )))
      {
	from->reldate="Impossible date; year>2386 or year<1940";
	when=0;
      }

    if(when) 
    {
      int delay = time() - when;
      from->reldate = describe_time_period( delay )+" ago";
    }
  }
  if(!from->reldate)
    from->reldate="Unknown (unparsable date)";
  return from;
}

// For email highlighting. Makes links of all URLs matching the regexp.
// All email addresses should probably be highlighted as well. I'll
// save that for some other time or function.
//
static string fix_urls(string s)
{
  string *foo;
  if(foo=regexp::split(s))
    return fix_urls(foo[0])+
      "<a target=Remote href=\""+foo[1]+"\">"+foo[1]+"</a>"+
      fix_urls(s[strlen(foo[0])+strlen(foo[1])..0x7fffffff]);
  return s;
}


// FIXME: This should be configurable on a per-user level.
// Currently it's rather static, and only looks good on a white
// background.
//
static string quote_color_for( int level )
{
  switch(level)
  {
   case 1: return "#dd0000";
   case 2: return "darkred";
   case 3: return "darkblue";
   case 4: return "#005500";
   default: return "#0077ee";
  }
}

// Highlight the body of a text/plain message.
// Not really nessesary for this module, and the colors are somewhat
// to hardcoded for my taste, but it does look _much_ better when the
// message is highlighted.
//

static string highlight_emp( string from )
{
  if(strlen(from) > 75)
    from = sprintf("%*-=s\n", 75, from);
// *foo*  -> bold
// /foo/  -> italic 
// _foo_  -> underline 
  string a, b, c;
  while(sscanf(from, "%s *%[^*\n]*%s", a, b, c) == 3)
    from = a+"<b> "+b+"</b>"+c;
//   while(sscanf(from, "%s /%[^*\n]/ %s", a, b, c) == 3)
//     from = a+" <i>"+b+"</i> "+c;
  while(sscanf(from, "%s_%[^*\n]_%s", a, b, c) == 3)
    from = a+"<u>"+replace(b, "_", " ")+"</u>"+c;
  return from;
}


static string describe_body(string bdy, mapping m, int|void nofuss)
{
  int br;
  string res="";
  if(!nofuss)
  {
    if(!m->freeform) 
      res = "<pre>";
    else  
      br = 1;
  }

  string ql;
  int lq, cl;
  foreach(bdy/"\n", string line)
  {
    int quote = 0;
    string q = replace(line, ({" ","|"}), ({"",">"}));
    if(!lq && sscanf(q, "%[>]", ql))
      quote = strlen(ql);

    if(!strlen(line))
    {
      if(br) res += "<br>";
      res += "\n";
      continue;
    }
    if(quote!=cl)
    {
      if(cl)
	res += "</font>";
      if(quote)
	res += "<font color="+quote_color_for(quote)+" size=-1>";
      cl=quote;
    }
    if(!lq && (q=="--" || q=="---"))
    {
      res+=(br?"<pre>":"") + "<font color=darkred>";
      br=0;
      lq=1;
    }
    res += highlight_emp((nofuss ? line : html_encode_string(line))+"\n");
    if(br) res +="<br>";
  }
  if(lq || cl)
    res += "</font>";
  if(!br) res += "</pre>";
  return res;
}

static string highlight_mail(string from, object id)
{
  return describe_body( from, id->variables );
}

static mapping common_callers( string prefix )
{
  mapping tags = ([]);
  foreach(glob(prefix+"*",indices(this_object())), string s)
  {
    if(!debug && search( s, "debug") != -1)
      continue;
    tags[replace(s[strlen(prefix)..], "_", "-")] = this_object()[s];
  }

  DEBUG(( "Tags for %s is %s\n",prefix,
	  String.implode_nicely(sort(indices(tags)))));
  return tags;
}

static mapping parse_headers( string foo )
{
  return mymesg->parse_headers( foo )[0];
}

static mapping make_flagmapping(multiset from)
{
  return mkmapping( Array.map(indices(from), lambda(string s) {
					       return "flag_"+s;
					     }),
		    ({"set"})*sizeof(from));
}

static string login(object id)
{
  string force = ("Permission denied");

  if(!clientlayer) 
    init_clientlayer( conf );

  if(!clientlayer)
    return "Internal server error";

  if(!id->realauth) 
  {
    id->misc->defines[" _extra_heads"] = _login->extra_heads;
    id->misc->defines[" _error"] = _login->error;
    return force;
  }

  if(!UID)
  {
    if(!(UID = uid_cache[ id->realauth ]))
    {
      UID = clientlayer->get_user(  @(id->realauth/":") );
      if(!UID) 
      {
	id->misc->defines[" _extra_heads"] = _login->extra_heads;
	id->misc->defines[" _error"] = _login->error;
	return force;
      }
      uid_cache[ id->realauth ] = UID;
    }
  }
}

static SMTPRelay get_smtprelay()
{
  catch {
    module_dependencies( conf, ({ "smtprelay" }) );
    return conf->get_providers( "smtp_relay" )[ 0 ];
  };
  error("Failed to lookup the smptrelay module!\n");
}

static string send_mail_from_mid( string mid, multiset to, object id )
{
  string from = tag_mail_userinfo("",(["email":1]),id);
  
  string body = 
    tag_mail_body( "", ([ "mail":mid ]), id );
  
  return get_smtprelay()->send_message( from, to, body );
}


constant actions = 
({
  ({ "delete", "Delete mail", 0 }),
  ({ "next", "Reply to the sender", 0 }),
  ({ "reply", "Move to next mail", 0 }),
  ({ "followup", "Reply to all", 0 }),
  ({ "previous", "Move to previous mail", 1 }),
  ({ "show_unread", "Go to mailbox page and show unread mail", 1 }),
  ({ "show_all", "Go to mailbox page and show all mail", 1 }),
  ({ "select_matching", "Select all mail matching filter", 0 }),
  ({ "select_none", "Unselect all mail", 0 }),
});

static string describe_action( string foo )
{
  foreach(actions, array a)
    if(foo == a[0]) 
      return a[1];

  if(sscanf(foo, "move_mail_to_%s", foo))
    return "Move mail to the mailbox '"+foo+"'";

  if(sscanf(foo, "select_mail_like_%s", foo))
    return "Select all mail with headers matching '"+foo+"'";

  if(sscanf(foo, "copy_mail_to_%s", foo))
    return "Copy mail to the mailbox '"+foo+"'"; 

  if(sscanf(foo, "bounce_mail_to_%s", foo))
    return "Forward mail to the email address '"+foo+"'"; 

  return 0;
}

static string describe_button( array b )
{
  if(sizeof(b) == 2)
    return "";
  return String.implode_nicely(Array.map(sort(indices(b[2])),
					 describe_action));
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

static int filter_mail_list( Mail m, object id )
{
  if(id->variables->mail_match
     &&!sizeof(glob("*"+lower_case(id->variables->mail_match)+"*",
		    Array.map(values(m->decoded_headers()),lower_case))))
    return 0;

  if(m->flags()->deleted)
    return 0;
  if(m->flags()->read && !id->variables->listall)
    return 0;
  if(id->variables->listselected && !id->misc->flagged[ m->id ])
    return 0;

  return 1;
}



static string trim_from( string from )
{
  string q;
  from = replace(from||"No sender", "\\\"", "''");
  if(sscanf(from, "%*s\"%s\"%*s", q)==3) if(strlen(q)) return q;
  if(sscanf(from, "\"%s\"<%*s@%*s>", q)) if(strlen(q)) return q;
  if(sscanf(from, "%s<%*s@%*s>", q)) if(strlen(q)) return q;
  if(sscanf(from, "(\"%s\")%*s@%*s", q)) if(strlen(q)) return q;
  if(sscanf(from, "(%s)%*s@%*s", q)) if(strlen(q)) return q;
  if(sscanf(from, "%*s@%*s(\"%s\")", q)==3) if(strlen(q)) return q;
  if(sscanf(from, "%*s@%*s(%s)", q)==3) if(strlen(q)) return q;
  return (from-"<")-">";
}



static string trim_subject( string from )
{
  string a,b;
  string ofrom = from||"No subject";
  if(from == "0") from = "No subject";
  if(sscanf(from, "%s[%*s]%s", a, b)==3)
  {
    from = a+b;
    if(!strlen(from-" "))
      from = ofrom;
  }
  return from[..40];
}


static multiset trim_mail_addresses(multiset from)
{
  multiset res = (<>);
  DEBUG(("Trimming mail addresses. Input is: %O\n", from));
  foreach(indices(from), string r)
  {
    string emil;
    string u,h;
    if(sscanf( r, "%*s<%s@%s>", u, h) == 3)
      emil = u+"@"+h;
    else if(sscanf( r, "%*s\"%s@%s\"", u, h) == 3)
      emil = u+"@"+h;
    else if(sscanf( r, "%*s%[^ ]@%[^ ]", u, h) == 3)
      emil = u+"@"+h;
    else
      emil = r;
    res[emil]=1;
  }
  DEBUG(("result of trim is: %O\n", res));
  return res;
}

/* Tag functions --------------------------------------------------- */

string container_mailbox_has_mail( string t, mapping args, 
				   string contents, object id )
{
  if(!UID->get_mailbox( args->box ) || 
     !sizeof(UID->get_mailbox( args->box )->mail()))
  {
    return "<false>";
  }
  return contents+"<true>";
}

string tag_mail_trim_address_list( string t, mapping args, object id )
{
  // FIXME: remove duplicated from address lists pointed to by
  // indices(args)
  return "";
}

//
// <send-mail-by-id mail_id=...>
//
string tag_send_mail_by_id( string t, mapping args, object id )
{
  DEBUG(("Sending a mail..\n"));

  MIME.Message m;
  args->mail = (args->mail/"\0")[0];

  m = MIME.Message(tag_mail_body("",args,id));

  string from = tag_mail_userinfo("",(["email":1]),id);
  multiset to = (mkmultiset( ((m->headers->cc||"") / ",")-({""})) |
		 mkmultiset( ((m->headers->to||"") / ",")-({""})) );
  m_delete(m->headers, "bcc");

  to = trim_mail_addresses( to );

  m->headers->organization = tag_mail_userinfo("",(["org":1]),id);
  if(UID->get("amhc_signature") && strlen(UID->get("amhc_signature")))
  {
    if(m->body_parts)
      m->body_parts[0]->setdata(m->body_parts[0]->getdata()
				+"\n-- \n"+UID->get("amhc_signature"));
    else
      m->setdata(m->getdata()+"\n-- \n"+UID->get("amhc_signature"));
  }
  get_smtprelay()->send_message( from, to, (string)m );
  return "";
}

// 
// <mail-set-flag name=... [clear]>
//
string tag_mail_set_flag( string t, mapping args, object id )
{
  Mail mail = clientlayer->get_cache_obj( clientlayer->Mail, 
					  id->variables->mail_id );
  if(!mail || mail->user != UID )
    return "";
  if(args->clear)
    mail->clear_flag( args->name );
  else
    mail->set_flag( args->name );
}

//
// <mail-mailboxid mailbox=... [create]>
//
string tag_mail_mailboxid( string t, mapping args, object id )
{
  if(!args->mailbox) return (string)0;
  if(args->create) 
    return (string)UID->get_or_create_mailbox( args->mailbox )->id;
  return (string)UID->get_mailbox( args->mailbox )->id;
}


// <new-outgoing-mail>
// Returns: A mailid usable for a new outgoing mail.
// This mail is created in the 'drafts' outbox.
//
string tag_new_outgoing_mail( string t, mapping args, object id )
{
  foreach(UID->get_drafts()->mail(), Mail m)
  {
    if(!m->flags()->am_edited)
      return m->id;
  }
  return UID->get_drafts()->create_mail_from_data( "Subject: No subject\r\n"
						   "To: Nobody\r\n\r\n"
						   "From: You\r\n\r\n" )->id;
}

//
// <mail-show-attachments> 
// Nowdays includes the former <mail-edit-attachments>.
//
string tag_mail_show_attachments( string t, mapping args, object id )
{
  MIME.Message M = id->misc->_message;

  if(!M) return "<input type=submit name=add_attachment value=\"New Attachment\">";

  foreach(glob("delete_part_*", indices(id->variables)), string v)
  {
    int partno;
    sscanf(v, "delete_part_%d", partno);
    m_delete(id->variables, v);
    array q;
    if(M->body_parts)
    {
      q = M->body_parts[..partno-1] + M->body_parts[partno+1..];
      if(sizeof(q)==1)
      {
	M->body_parts = 0;
	M->headers |= q[0]->headers;
	M->setdata( q[0]->getdata() );
      } else {
	M->body_parts = q;
	M->type = "multipart";
	M->subtype = "mixed";
      }
    }
    id->misc->_mail->change( M );
    return "";
  }

  if(id->variables->attach_file)
  {
    if(!M->body_parts)
    {
      M = MIME.Message( 0,
			M->headers,
			({MIME.Message("Content-Type: text/plain; "
				       "charset=iso-8859-1\r\n\r\n"+
				       M->getdata()) }));
      M->type = "multipart";
      M->subtype = "mixed";
      foreach(indices(M->body_parts[0]->headers), string h)
	if(!sscanf(h, "content%*s"))
	  m_delete(M->body_parts[0]->headers, h);
    }
    MIME.Message m;
    string t=conf->type_from_filename(id->variables["attach_file.filename"]);
    m = MIME.Message(id->variables->attach_file, (["content-type":t]));
    m->setencoding( "base64" );
    m->setdisp_param("filename",id->variables["attach_file.filename"]);
    M->body_parts += ({ m });
    m_delete(id->variables, "attach_file");
    id->misc->_message = M;
    if(id->misc->_mail)
      id->misc->_mail->change( M );
  }

  if(args->show)
  {
    string res=("<table cellpadding=3 cellspacing=0 border=0>"
		"<tr bgcolor=black><td align=left bgcolor=black><font "
		"color=white><b>Filename</td><td align=right "
		"bgcolor=black><b><font color=white align=right>Content type</td>"
		"<td bgcolor=black align=right><b><font color=white>Size"
		"</td><td bgcolor=black>Delete</td></tr>");
    if(!M->body_parts)
      res="No attachments<br>";
    // We do not (currently) support multipart attachments (or, rather,
    // we do, but there is no easy way to edit them right now)
    else
    {
      for(int i=1; i<sizeof(M->body_parts); i++)
      {
	object m = M->body_parts[ i ];
	res += ("<tr bgcolor=white><td><a target=Display href=display.html?mail="+
		id->variables->mail_id+"&part="+i+"&name="+m->get_filename()
		+">"+m->get_filename()+"</a></td><td align=right>"+
		m->type+"/"+m->subtype+"</td><td align=right>"+
		sizeof(m->getdata())/1024+"Kb"+
		"</td><td><font size=-1><input type=submit name=delete_part_"+i+
		" value=Delete></font>");
      }
      res += "</table>";
    }

    if(id->variables->add_attachment)
      res += "File to attach: <input type=file name=attach_file>"
	"<input type=submit value=Ok>";
    else
      res+="<input type=submit name=add_attachment value=\"New Attachment\">";
    m_delete(id->variables, "add_attachment");
    return res;
  }
  return "";
}

//
// <-compose-mail> and <-decompose-mail> are used without any
// arguments or contents to modify the current mail using the contents 
// of id->variables.
//
//  Automatic headers:
//   from
//   date
//   message-id
//   x-mailer
//
//  Headers taken from variables:
//   to
//   cc
//   bcc
//   subject
//   
//  Body taken from 'body', if multipart, this modifies part 0.
//  Content type of mail body segment is per default text/plain;
//  encoding is 8bit; charset is iso-8859-1, the type and charset can
//  be modified using 'content-type' and 'content-charset' variables.
//
string tag__compose_mail( string t, mapping args, object id )
{
  MIME.Message m;
  id->variables->mail_id = (id->variables->mail_id/"\0")[0];
  m = (id->misc->_message ||
       MIME.Message(tag_mail_body("",(["mail":id->variables->mail_id]),id)));


  if(id->variables->references)
    if(strlen(id->variables->references))
      m->headers->references = id->variables->references;

  if(id->variables->to)
    if(strlen(id->variables->to))
      m->headers->to = id->variables->to;

  if(id->variables->cc)
    if(strlen(id->variables->cc))
      m->headers->cc = id->variables->cc;
    else
      m_delete(m->headers, "cc");

  if(id->variables->subject)
    if(strlen(id->variables->subject))
      m->headers->subject = id->variables->subject;

  if(id->variables->bcc)
    if(strlen(id->variables->bcc))
      m->headers->bcc = id->variables->bcc;
    else
      m_delete(m->headers, "bcc");

//   if(id->variables->

  m->headers->from=html_decode_string(tag_mail_userinfo("",
							(["address":1]),id));
  m->headers["Content-Transfer-Encoding"] = "8bit";
  m->headers->date = mktimestamp( time() );

  m->headers["mime-version"] = "1.0";
  m->headers["message-id"] = ("<\""+tag_mail_userinfo("",(["email":1]),id)+
			      time()+gethrtime()+"\"@"+gethostname()+">");

  m->headers["x-mailer"] = roxen->version()+" Automail HTML client";
  if(id->variables->body)
  {
    string ct="text/plain", cs="iso-8859-1";
    if(id->variables["content-type"])
      ct = id->variables["content-type"];
    if(id->variables["content-charset"])
      cs = id->variables["content-charset"];
    if(m->body_parts)
    {
      m->body_parts[0]->setdata(id->variables->body);
      m->body_parts[0]->headers["content-type"] = ct+"; charset="+cs;
      m->body_parts[0]->headers->lines=
	(string)sizeof(id->variables->body/"\n");
    }
    else
    {
      m->headers->lines = (string)sizeof( id->variables->body/"\n" );
      m->headers["content-type"] = ct+"; charset="+cs;
      m->setdata( id->variables->body );
    }
  }  

  Mail mid = clientlayer->get_cache_obj( clientlayer->Mail, 
					 id->variables->mail_id );
  if(!mid) return "CANNOT GET MAIL '"+id->variables->mail_id+"'\n";
  id->misc->_message = m;
  id->misc->_mail =  mid;
  mid->set_flag("am_editable");
  mid->set_flag("am_edited");
  mid->change( m );
  return "";
}

// <-decompose-mail>
// Set variables from the contents of a mail.
// More or less the reverse of <-compose-mail>
//
string tag__decompose_mail( string t, mapping args, object id )
{
  MIME.Message m;
  id->variables->mail_id = (id->variables->mail_id/"\0")[0];
  m = (id->misc->_message ||

       MIME.Message(tag_mail_body("",(["mail":id->variables->mail_id]),id)));
  id->variables->to = m->headers->to||"";
  id->variables->subject = m->headers->subject||"No subject";
  id->variables->cc = m->headers->cc||"";
  id->variables->bcc = m->headers->bcc||"";
  if(m->body_parts)
    id->variables->body = m->body_parts[0]->getdata();
  else
    id->variables->body = m->getdata();
  id->misc->_message = m;
  return "";
}

//
// <mail-index>: Returns the index of the mail in the mailbox.
// This could be faster..
//
string tag_mail_index( string t, mapping args, object id )
{
  Mailbox mbox;
  foreach( UID->mailboxes(), Mailbox m )
    if(m->id == (int)id->variables->mailbox_id )
    {
      mbox = m;
      break;
    }
  
  int ind;
  array(Mail) mail = mbox->mail();
  if( ((int)id->variables->index < sizeof(mail) )
      && mail[ (int)id->variables->index ]->id ==
      id->variables->mail_id )
    ind = (int)id->variables->index;
  else
    if(id->variables->mail_id)
      ind = search(mail->id, id->variables->mail_id);
  
  if(ind == -1) return "?";
  return (string)(sizeof(mail)-ind);
}

// <show-mail-user-buttons>
//   #id# #name# #desc#
// </show-mail-user-buttons>
//
string container_show_mail_user_buttons( string tag, mapping args, 
					 string contents, object id )
{
#ifdef UIDPARANOIA
  if(!UID) return "";
#endif
  array b = UID->get( "html_buttons" );
  if(!b || !sizeof(b)) return "No user defined buttons<br>";
  array vars = ({});

  for(int i=0; i<sizeof(b); i++)
  {
    vars += ({ 
      ([
	"id":(string)i,
	"name":(sizeof(b[i])>2?b[i][0]:
		((b[i][0][1]=='b'?"Newline":"Space"))),
	"desc":describe_button( b[i] ),
      ]) 
    });
  }
  return do_output_tag( args, vars, contents, id );
}

//
// <mail-userinfo firstname> --> First name
// <mail-userinfo lastname>  --> Last name
// <mail-userinfo email>     --> email address
// <mail-userinfo address>   --> Real Name <email@address>
// <mail-userinfo>           --> Real Name
//
// More to come, probably.
//
string tag_mail_userinfo( string tag, mapping args, object id )
{
#ifdef UIDPARANOIA
  if(!UID) return "";
#endif
  string t = UID->get( "amhc_realname" )||UID->query_name();
  string e = UID->get( "amhc_email" )||(id->realauth/":")[0];
  if(args->email)
    return e;

  if(args->organization || args->org)
  {
    return UID->get( "amhc_org" )||UID->query_organization();
  }

  if(args->address)
    return t + " &lt;" + e + "&gt;";

  if(args->firstname)
  {
    array q = t/" "-({""});
    return q[..sizeof(q)-2]*" ";
  }
  if(args->lastname)
  {
    array q = t/" "-({""});
    return q[-1];
  }
  return t;
}


//
// <mail-if-address-book>
//   ..rxml code..
// </mail-if-address-book>
//
//  Returns true if the user has a address book.
//
string container_mail_if_address_book( string tag, mapping args,
				       string contents, object id )
{
#ifdef UIDPARANOIA
  if(!UID) return "";
#endif
  if( !UID->get( "addressbook" ) ) return "<false>";
  return contents+"<true>";
}

//
//    <mail-address-book quote=$ variable=to>
//      <option $selected$ value='$email:quote=stag$'>$name$
//    </mail-address-book>
//
string container_mail_address_book( string tag, mapping args, 
				    string contents, object id )
{
#ifdef UIDPARANOIA
  if(!UID) return "";
#endif

  array vars = ({});

  //
  // ({
  //    ({
  //        email,
  //        name,
  //        .. optional, reserved for future use ..
  //    })
  //  })
  //
  array book = UID->get( "addressbook" ) || ({});

  
  foreach(book, array b)
  {
    vars += ({ 
      ([
	"name":b[1],
	"email":b[0],
	"selected":(id->variables[args->variable]==b[0]?"selected":"")
      ]),
    });
  }

  return do_output_tag( args, vars, contents, id );
}

//
// <delete-mail mail=id>
// Please note that this function only removes a reference from the
// mail, if it is referenced by e.g. other clients, or is present in
// more than one mailbox, the message on disk will not be deleted.
//
string tag_delete_mail(string tag, mapping args, object id)
{
#ifdef UIDPARANOIA
  if(!UID) return "";
#endif
  Mail mid = clientlayer->get_cache_obj( clientlayer->Mail, args->mail );
  if(mid && mid->user == UID )
    mid->mailbox->remove_mail( mid );
  return "";
}

//
// <mail-body mail=id>
// Returns the _raw_ body.
// Not currently used except for internaly from mail_body_part and a
// few other tag functions. Might be removed before this is finished.
//
string tag_mail_body(string tag, mapping args, object id)
{
#ifdef UIDPARANOIA
  if(!UID) return "";
#endif
  Mail mail = clientlayer->get_cache_obj( clientlayer->Mail, args->mail );
  if(mail && mail->user == UID )
    return mail->body( );
  error("No body for mail_id: "+args->mail+"\n");
}


//
// <mail-verify-login>
//  .. page ...
// </mail-verify-login>
//
string container_mail_verify_login(string tag, mapping args, string
				   contents, object id)
{
  if(string res = login(id))
    return res+"<false>";
  return contents;
}

//
// <list-mailboxes>
//  #name# #id# #unread# #read# #mail#
// </list-mailboxes>
//
string container_list_mailboxes(string tag, mapping args, string contents, 
				object id)
{
  string res;
#ifdef UIDPARANOIA
  if(!UID) return "";
#endif
  UID->get_incoming();
//   UID->get_drafts();

  array(mapping) vars = ({});
  foreach(UID->mailboxes(), Mailbox m)
    vars += ({ ([
      "_mb":m,
      "name":m->name,
      "id":m->id,
    ]) });

  sort(vars->name, vars);

  array tmp = ({});
  mixed ic;
  foreach(vars, mapping v)
    switch(v->name)
    {
     case "drafts":
     case "sent":
     case "deleted":
       tmp = tmp + ({ v });
       break;
     default:
       tmp = ({ v }) + tmp;
       break;
     case "incoming":
       ic = v;
    }
  vars = ({ ic }) + tmp;

  if(!args->quick)
  {
    foreach(vars, mapping v)
    {
      v->mail = (string)sizeof(v->_mb->mail());
      v->unread = (string) v->_mb->num_unread();
      v->read = (string)((int)v->mail - (int)v->unread);
      m_delete(v, "_mb");
    }
  }

  // This is slightly confusing for the user..
#if 0
  foreach(vars, mapping v)
    if(v->mail == "0") 
      vars -= ({ v });
#endif

  return do_output_tag( args, vars, contents, id );
}

//
// <mail-next>
// <mail-next previous>
//  Assumes mailid is id->variables->mail_id
//
string tag_mail_next( string tag, mapping args, object id )
{
  Mailbox mbox;
  array(Mail) mail;
  int i;
  int start;

#ifdef UIDPARANOIA
  if(!UID) return "";
#endif
  
  foreach( UID->mailboxes(), Mailbox m )
    if(m->id == (int)id->variables->mailbox_id )
    {
      mbox = m;
      break;
    }
  if(!mbox) return "No mailbox!\n";

  //   mail = Array.filter(mbox->mail(), filter_mail_list, id);
  // This _must_ be faster. This does not scale well enough!
  // So. Let's apply the filter one mail at a time instead.
  // That should be slightly faster..
  mail = mbox->mail();

  if( ((int)id->variables->index < sizeof(mail))
      && mail[ (int)id->variables->index ]->id == id->variables->mail_id)
    start = (int)id->variables->index;
  else
    if(id->variables->mail_id)
      start = search(mail->id, id->variables->mail_id);

//   werror("index is now: %d (%s) %O\n", start, 
// 	 (string)id->variables->index,
// 	 id->variables);

  if(args->previous)
  {
    for(i = start-1; i>=0; i--)
      if(filter_mail_list( mail[i],id ) )
      {
	start = i;
	break;
      }
  } 
  else
  {
    for(i = start+1; i<sizeof(mail); i++)
      if(filter_mail_list( mail[i],id ) )
      {
	start = i;
	break;
      }
//     if(start != i)
//       for(i = 0; i<start; i++)
// 	if(filter_mail_list( mail[i],id ) )
// 	{
// 	  start = i;
// 	  break;
// 	}
  }

//   werror("index after: %d\n", start);
  if(start >= sizeof(mail))
    start = sizeof(mail)-1;
//   werror("adjusted index: %d\n", start);
  if(start < 0)
    start = 0;

  id->variables->index = (string)start;
  if(sizeof(mail)>start)
    return mail[ start ]->id;
  return "NOPE";
}

string tag_mail_random_number_variable( string t, mapping args, object id )
{
  mapping a = ([ ]);
  a->type = "hidden";
  a->name = args->var;
  a->value = (abs(gethrtime())+"-"+abs(time())+"-"+random(0x7ffffffff));
  return make_tag( "input", a );
}

//  <mail-make-hidden>
//    returns a <input type=hidden value=""> for all variables in
//    id->variables except a few chosen ones.
//    Somewhat specific to the current html pages...
//    This might not be all that desireable, really.
//
string tag_mail_make_hidden( string tag, mapping args, object id )
{
  mapping q = copy_value(id->variables);
  string res = "";

  q->i = (string)time() + (string)gethrtime();
  m_delete(q, "qm");   m_delete(q, "col"); m_delete(q, "gtextid");
  m_delete(q, "mailbox_id"); m_delete(q, "mail_match"); 
  m_delete(q, "gtextid"); m_delete(q, "gtextid&selected;"); 
  m_delete(q, "gtextidselected"); 
//   werror("current: %O\n", q);
  id->variables->some_number=(abs(gethrtime())+""+abs(time())+
                              ""+random(0x7ffffffff));
  foreach( indices(q), string v )
  {
    mapping w = ([ "type":"hidden" ]);
    w->name = (string)v;
    w->value = (string)q[v];
    res += make_tag( "input", w )+"\n";
  }
  return res;
}

//
//  <process-move-actions>
//
//  Handles all 'move' actions, i.e, actions with a destination
//  included in their name.  The move actions are:
//
//  move_mail_to_MBOX.x         move the mail (copy+delete)
//  copy_mail_to_MBOX.x         copy the mail
//  bounce_mail_to_EMAIL.x      forward the mail to an external mbox
//
string tag_process_move_actions( string tag, mapping args, object id )
{
  if(!id->variables->mail_id)
    return "";
#ifdef UIDPARANOIA
  if(!UID) return "";
#endif
  foreach( glob("bounce_mail_to*.x", indices(id->variables)), 
	   string v )
  {
    string to;
    sscanf(v, "bounce_mail_to_%s.x", to);
    if(id->variables->mail_id)
      send_mail_from_mid( id->variables->mail_id, (< to >), id );
  }

  foreach( glob("copy_mail_to_*.x", indices(id->variables)), string v)
  {
    string mbox;
    m_delete(id->variables, v);
    m_delete(id->variables, replace(v, ".x", ".y"));

    sscanf(v, "copy_mail_to_%s.x", mbox);

    if(mbox)
    {
      Mailbox m = UID->get_or_create_mailbox( mbox );
      if(id->variables->mail_id)
      {
	id->variables["next.x"]="1";
	Mail mid = 
	  clientlayer->get_cache_obj(clientlayer->Mail,
				     id->variables->mail_id);
	if(!mid)
	  return "Unknown mail to copy!\n";
	m->add_mail( mid );
// 	mid->mailbox->remove_mail( mid );
      }
    } else
      return "Unknown mailbox to copy to!\n";
  }
  foreach( glob("move_mail_to_*.x", indices(id->variables)), string v)
  {
    string mbox;
    m_delete(id->variables, v);
    m_delete(id->variables, replace(v, ".x", ".y"));

    sscanf(v, "move_mail_to_%s.x", mbox);
    DEBUG(("move "+id->variables->mail_id+" to "+mbox+"\n"));
    if(mbox)
    {
      Mailbox m = UID->get_or_create_mailbox( mbox );
      id->variables["next.x"]="1";
      Mail mid = 
	clientlayer->get_cache_obj(clientlayer->Mail,
				   id->variables->mail_id);
      if(!mid)
	return "Unknown mail to move!\n";
      m->add_mail( mid );
      if(mid->mailbox != m )
	mid->mailbox->remove_mail( mid );
    } else
      return "Unknown mailbox to move to!\n";
  }

}


// 
//  <process-user-buttons>
//    Check all user_button_ID.x variables, and if one is set, set the 
//    variables matching the actions to be performed for that user
//    button.  This is nowdays the only buttons present on the page,
//    there are no hardcoded buttons.
//
string tag_process_user_buttons( string tag, mapping args, object id )
{
#ifdef UIDPARANOIA
  if(!UID) return "";
#endif
  array b = UID->get( "html_buttons" );

  if(!b) return "";

  foreach( glob("user_button_*.x", indices(id->variables)), string v)
  {
    int i;
    sscanf( v, "user_button_%d.x", i );
    m_delete(id->variables, v);
    m_delete(id->variables, replace(v, ".x", ".y"));

    if(i > -1 && i < sizeof(b))
      foreach(indices( b[ i ][ 2 ] ), string q)
	id->variables[ q+".x" ] = "1";
  }
  return "";
}

//
// <user-buttons type=type>
//
//  display all user buttons. Also, if no buttons are defined, default 
//  to <previous> <next>  <reply> <followup>  <delete>
//  
//  This tag assumes there is a <gbutton name=... value=...> tag.
//  value is the title, and name is the name of the variable to be
//  set, without ".x". (e.g, 'previous' instead of 'previous.x')
//
string tag_user_buttons( string tag, mapping args, object id )
{
#ifdef UIDPARANOIA
  if(!UID) return "";
#endif
  // A button is:
  //    ({ /* one button... */
  //      "title",
  //      (< when >),    /* From: "mail", "mailbox", "global" */
  //      (< "action", "action", .. >) /* List of atom actions. */
  //    }),
  //  
  //   There are also separators:
  //
  //   ({ "<br>",(< "when" >)}),
  //   ({ " ", (< "when" >) }),
  //
  // The configuration interface for this will be rather complex...
  // I do like this idea, though.
  //
  // Example: ({ "->archive, next",
  //             (< "mail" >),
  //             (< "move_mail_to_archived", "next_unread" >),
  //          })
  //  
  //  The move_mail_to_XXX action is rather special, you can have
  //  anything for XXX, it's used as the mailbox to move the mail to.
  // 
  //  This function only creates the buttons, it does not do the
  //  actions. Most of the actions, actually, all actions except
  //  move_mail_to_XXX, which is handled slightly differently, are
  //  handled from RXML.

  array b = UID->get( "html_buttons" );

  if(!b || !sizeof(b))
  {
    b = ({
      ({
	"Previous",
	(< "mail" >),
	(< "next" >),
      }),
      ({
	"Next",
	(< "mail" >),
	(< "previous" >),
      }),
      ({
	" &nbsp; ",
	(< "mail" >),
      }),
      ({
	"Reply to sender",
	(< "mail" >),
	(< "reply" >),
      }),
      ({
	"Reply to all",
	(< "mail" >),
	(< "followup" >),
      }),
      ({
	" &nbsp; ",
	(< "mail" >),
      }),
      ({
	"Delete",
	(< "mail","mailbox" >),
	(< "move_mail_to_Deleted" >),
      }),
      ({
	" &nbsp; ",
	(< "mailbox" >),
      }),
      ({
	"Select all",
	(< "mailbox" >),
	(< "select_matching" >),
      }),
      ({
	"Unselect all",
	(< "mailbox" >),
	(< "select_none" >),
      }),
    });
    UID->set( "html_buttons", b );
  }

  if(!id->variables->mail_id)
    if(id->variables->mailbox_id)
      args->type =  "mailbox";
    else
      args->type =  "global";
  else
    args->type =  "mail";

  string res = "";
  if(!b)
    return "";
//   werror("%O\n", b);
  for(int i = 0; i<sizeof(b); i++)
    if( b[i][ 1 ][ args->type ] )
    {
      if(sizeof(b[i])==2)
	res += b[i][0];
      else
      {
	mapping a = 
	([
	  "name":"user_button_"+i,
	  "value":b[i][0],
	]);
	res += make_tag( "gbutton", a );
      }
    }
  return res;
}

//
//  <mail-scrollbar num=... start=... page=...>
//   num is the total number of items, start is the starting item, and 
//   page is the height of a 'page' of items.
// 
//   Create a vertical scrollbar with buttons for up and down, and a
//   clickable tray in between them.
//
//   I have found no way to make this thing scale according to the
//   available space for the throgh, so I make it 300 pixels high,
//   which should be enough for most fonts.
//
string tag_mail_scrollbar( string tag, mapping args, object id )
{
  float len = (float)args->num;
  float start = ((int)args->start)/len;
  float page = ((int)args->page)/len;
  
  return ("<input border=0 type=image name=scroll_up width=15 height=15 src="+
	  query_location()+"scroll_up><br>"+
	  "<input border=0 type=image name=scroll_goto height=300 width=15 src="+
	  query_location()+"scroll/"+(int)(page*50)+"/"+(int)(start*50)+
	  "><br>"
	  "<input border=0 type=image name=scroll_down width=15 height=15 src="+
	  query_location()+"scroll_down><br>");
}

#define MAIL_PER_PAGE 12
//
// <list-mail-quick mailbox=id>
//
//  Hardcoded (fast) email listing function for the current RXML
//  client.
//
//  This one gives
//  <tr><td>flags checkbox</td><td>subject</td><td>from</td><td>when</td></tr>
//  for each mail in the mailbox matching the current filter.
//
// <formoutput quote=$>
//   <table width=100% cellpadding=0 cellspacing=0 
//  	 bgcolor=darkred cellspacing=0 border=0><tr><td width=100%>
//   <table width=100% cellpadding=2 cellspacing=1
//  	 bgcolor=white cellspacing=0 border=0>
//   <tr bgcolor=black>
//      <td><font color=white>Flag</td>
//      <td><font color=white>Subject</td>
//      <td><font color=white>From</td>
//      <td><font color=white>Age</td>
//      <td width=15><img src=/internal-roxen-unit width=1 height=1></td>
//   </tr>
//   <list-mail-quick mailbox=$mailbox_id$>
//   </table></td></tr></table>
// </formoutput>
// 
// 
array(string) tag_list_mail_quick( string tag, mapping args, object id )
{
  string res;
  Mailbox mbox;

  if(!UID) return ({});
  foreach( UID->mailboxes(), Mailbox m )
    if(m->id == (int)args->mailbox )
    {
      mbox = m;
      break;
    }

  if(!mbox)
    return ({"Invalid mailbox id"});

  string res="";

  mapping q= copy_value(id->variables);
  q->i = (string)time() + (string)gethrtime();
  m_delete(q, "qm");   m_delete(q, "col"); m_delete(q, "gtextid");
  m_delete(q, "gtextid&selected;");
  string link="?mail_id=#id#&";
  
  // Handle the selection
  // This could be faster, but this should be good enough.
  multiset flagged = id->misc->flagged;
//   werror("Initial: %O\n", flagged);
//   // remove all visible flags.
//   foreach((id->variables->toclear||"")/","-({""}), string s)
//     flagged[s]=0;

//   werror("to clear: %O\n", id->variables->toclear);
//   m_delete(id->variables, "toclear");
//   m_delete(q, "toclear");
//   werror("Cleared: %O\n", flagged);

//   foreach(glob("mail_flag_*", indices(q)), string f)
//   {
//     m_delete(id->variables, f);
//     m_delete(q, f);
//     sscanf(f, "mail_flag_%s", f);
//     flagged[f]=1;
//   }

//   werror("Marked: %O\n", flagged);
//   //
//   // Now we have the 'flagged' list. Time to add it to the mailbox
//   // section, for safe keeping.
//   id->misc->flaged = flagged;
//   mbox->set( "ht_select", flagged );
//   //

  foreach(sort(indices(q)), string v)
    if(q[v] != "0")
      link += v+"="+http_encode_url( (string)q[v] )+"&";
  q = ([ "href":fix_relative(link[ .. strlen(link)-2 ], id) ]);

  link = "<td><HIGHLIGHT>"+make_tag("a", q);

  string bg;
  int q;
  array(Mail) mail = mbox->mail();
  string pre="";
  string post="";

  mail = reverse(Array.filter(mail, filter_mail_list, id));


  if(sizeof(mail) > MAIL_PER_PAGE)
  {
    int start;
    if(id->misc->mail_goto_rel)
    {
      start=(int)(sizeof(mail)*id->misc->mail_goto_rel/100.0-MAIL_PER_PAGE/2);
    }
    else
      start = (int)id->variables->mail_list_start;

    if(start > sizeof(mail)-MAIL_PER_PAGE)
      start = sizeof(mail)-MAIL_PER_PAGE;

    if(start < 0)
      start = 0;
    mapping m = ([]);
    pre = ("<td width=15 rowspan="+MAIL_PER_PAGE+">"+
	   "<mail-scrollbar start="+start+" page="+MAIL_PER_PAGE+
	   " num="+sizeof(mail)+"></td>");
    mail = mail[ start .. start+MAIL_PER_PAGE-1 ];
    id->variables->mail_list_start = (string)start;
  } else
    pre = "<td width=15 rowspan="+sizeof(mail)+">&nbsp; </td>";
  int first_line;
  string extra, toclear="";
  foreach(mail, Mail m)
  {
    toclear += m->id+",";
    string f = replace(link,({"<HIGHLIGHT>","#id#"}),({
      m->flags()->read?"":"<b>",m->id}));
    mapping h = m->decoded_headers();
    //    if(h->subject && h->from)
    {
      if(first_line++)
	extra="";
      else
	extra = pre;

      res += `+("<tr bgcolor=#f2f2ff>",
		"<td align=right>",
		m->flags()->read?"":"<new-mail-flag>",
		"<input type=checkbox name=mail_flag_"+m->id+" ",
		flagged[ m->id ]?"checked></td>":"></td>",
		f,
		html_encode_string(trim_subject(h->subject)),
		"</td>",
		f,
		html_encode_string(trim_from(h->from)),
		"</td>",
		f,
		"<nobr>"+get_date( h->date )+"</nobr>",
		"</td>",
		extra,
		"</tr>\n");
    }
  }
  return ({ "<input type=hidden name=toclear value=\""+
	    toclear[..strlen(toclear)-2]+"\">",res });
}

// 
//  <new-mail-flag>: Show a flag indicating that this mail is not read 
//  yet. Currently, this is a ugly image.
//
string tag_new_mail_flag( string tag, mapping args, object id )
{
  return "<img src=new.gif>"; // FIXME
}


//
// <process-mail-actions>
// 
//  list_boxes              zap mail_id, zap mailbox_id
//  list_unread             zap mail_id, zap listall
//  list_all                zap mail_id, set listall=1
//  list_match              zap mail_id
//  list_clear_match        zap mail_id, zap list_match
//  delete                  <delete-mail mail=#mail_id#> and next
//  scroll_down             list_start+=MAIL_PER_PAGE
//  scroll_up               list_start-=MAIL_PER_PAGE
//  scroll_goto             misc->mail_goto_rel = pct
//  next                    mail_id=<mail-next>
//  previous                mail_id=<mail-next previous>
//
string tag_process_mail_actions( string tag, mapping args, object id )
{
  foreach(glob("list_*.x", indices(id->variables)), string v)
  {
    m_delete(id->variables, v);
    m_delete(id->variables, (v-".x")+".y");
    m_delete(id->variables, "mail_id");
    switch(v-".x")
    {
     case "list_boxes":
       m_delete(id->variables, "mailbox_id");
       break;
     case "list_unread":
       m_delete(id->variables, "listall");
       m_delete(id->variables, "listselected");
       break;
     case "list_all":
       id->variables->listall = "1";
       m_delete(id->variables, "listselected");
       break;
     case "list_selected":
       id->variables->listall = "1";
       id->variables->listselected = "1";
       break;
     case "list_match":
       break;
     case "list_clear_match":
       m_delete(id->variables, "mail_match");
       break;
    }
  }

  if(id->variables->mail_id)
  {
    if(id->variables["reply.x"])
    {
      return "<redirect to='reply.html?mail_id="+
	     id->variables->mail_id+"'>";
    }

    if(id->variables["followup.x"])
    {
      return 
	("<redirect to='reply.html?followup=1&mail_id="+
	 id->variables->mail_id+"'>");
    }

    if(id->variables["delete.x"])
      tag_delete_mail( "delete", ([ "mail":id->variables->mail_id ]), id );

    if(id->variables["next.x"])
    {
//       werror("next "+id->variables->mail_id+" = ");
      id->variables->mail_id = tag_mail_next(tag,([]),id);
//       werror(id->variables->mail_id+"\n");
    }
    else if(id->variables["previous.x"])
      id->variables->mail_id = tag_mail_next(tag,(["previous":"1"]),id);
  } else {
    if(id->variables["scroll_down.x"])
    {
      m_delete(id->variables, "scroll_down.x");
      m_delete(id->variables, "scroll_down.y");
      id->variables->mail_list_start
	=(string)((int)id->variables->mail_list_start+MAIL_PER_PAGE);
    } else if(id->variables["scroll_up.x"]) {
      m_delete(id->variables, "scroll_up.x");
      m_delete(id->variables, "scroll_up.y");
      id->variables->mail_list_start
	=(string)((int)id->variables->mail_list_start-MAIL_PER_PAGE);
      if((int)id->variables->mail_list_start < 0)
	id->variables->mail_list_start = 0;
    } else if(id->variables["scroll_goto.x"]) {
      id->misc->mail_goto_rel=((int)id->variables["scroll_goto.y"])/3;
      m_delete(id->variables, "scroll_goto.x");
      m_delete(id->variables, "scroll_goto.y");
    }

    if(id->variables->mailbox_id)
    {
      Mailbox mbox;
      // This is somewhat recursive.. :-)
      //
      // Do the action for all selected mail.
      //
      // THIS MUST BE LAST IN THIS ELSE
      //
      // Handle the selection
      // This could be faster, but this should be good enough.
      foreach( UID->mailboxes(), Mailbox m )
	if(m->id == (int)id->variables->mailbox_id )
	{
	  mbox = m;
	  break;
	}

      multiset flagged = mbox->get( "ht_select" )||(<>);
      foreach(indices(flagged), string f)
	if(!mbox->get_mail_by_id(f))
	  flagged[f]=0;
      foreach((id->variables->toclear||"")/","-({""}), string s)
	flagged[s]=0;

      m_delete(id->variables, "toclear");

      foreach(glob("mail_flag_*", indices(id->variables)), string f)
      {
	m_delete(id->variables, f);
	sscanf(f, "mail_flag_%s", f);
	flagged[f]=1;
      }
      string clear_match;
      // This was the normal seleciton code. Some specials:
      //
      foreach(glob("select_mail_like_*.x", indices(id->variables)),
	      string v)
      {
	m_delete(id->variables, v);
	m_delete(id->variables, (v-".x")+".y");
	sscanf(v, "select_mail_like_%s.x", v);
	clear_match=id->variables->mail_match||"";
	id->variables->mail_match = v;
	id->variables["select_matching.x"]=1;
      }
      if(id->variables["select_matching.x"])
      {
	m_delete(id->variables, "select_matching.x");
	m_delete(id->variables, "select_matching.y");
	array mail = mbox->mail();
	mail = Array.filter(mail, filter_mail_list, id);
	if(clear_match)
	{
	  id->variables->mail_match = clear_match;
	  if(clear_match == "")
	    m_delete(id->variables, "clear_match");
	}
	flagged = mkmultiset( mail->id );
      } else if(id->variables["select_none.x"]) {
	m_delete(id->variables, "select_all.x");
	m_delete(id->variables, "select_all.y");
	flagged = (<>);
      }
      id->misc->flagged = flagged;
      mbox->set( "ht_select", flagged );

      mapping ov = copy_value(id->variables);
      foreach( indices(flagged), string mail)
      {
// 	werror("Do multiple actions, current: "+mail+"\n");
	id->variables = copy_value(ov);
	id->variables->mail_id = mail;
	id->variables->noclear = 1;
	DEBUG(("Move..."));
	tag_process_move_actions( tag, args, id );
	m_delete(id->variables, "next.x");
	DEBUG(("Normal..."));
	tag_process_mail_actions( tag, args, id );
	DEBUG(("Ok\n"));
      }
      m_delete(id->variables,"noclear");
      m_delete(id->variables,"mail_id");
    }
  }
  if(!id->variables->noclear)
    foreach(glob("*.x", indices(id->variables)), string v)
    {
      //   	  werror("var: " + v + "\n");
      m_delete(id->variables, v);
      m_delete(id->variables, replace(v, ".x", ".y"));
    }
  return "";
}

//
// <list-mail mailbox=id>
//   #subject# #from# etc.
// </list-mail>
//
//  See <list-mail-quick>
string container_list_mail( string tag, mapping args, string contents, 
			     object id )
{
  string res;
  Mailbox mbox;

  int start = (int)args->start;
  int num = (int)args->num;

#ifdef UIDPARANOIA
  if(!UID) return "";
#endif
  foreach( UID->mailboxes(), Mailbox m )
    if(m->id == (int)args->mailbox )
    {
      mbox = m;
      break;
    }

  if(!mbox)
    return "Invalid mailbox id";
  
  if(!num) num = 1000;
  
  array variables = ({ });
  array m = mbox->mail();
  if(start < 0)
    start = sizeof(m)+start;
  foreach(m[start-1..start+num-2], Mail m)
    variables += ({ (["id":m->id]) |
		    m->decoded_headers()   | 
		    make_flagmapping( m->flags() ) });
  return do_output_tag( args, variables, contents, id );
}


//  <container-mail-a variable1=value1 ...>
//
//  Create a <a href=..> pointing to the current page with a lot of
//  forms variables set
//
string container_mail_a( string tag, mapping args, string c, object id )
{
  mapping q= copy_value(id->variables);
  q |= args;
  q->i = (string)time() + (string)gethrtime();
  m_delete(q, "fg");   m_delete(q, "bg");
  m_delete(q, "font"); m_delete(q, "link");
  m_delete(q, "gtextid"); m_delete(q, "gtextid&selected;"); 
  m_delete(q, "gtextidselected"); 
  string link="?";
  
  foreach(sort(indices(q)), string v)
    if(q[v] && (q[v] != "0"))
      link += v+"="+http_encode_url( q[v] )+"&";
  q = ([ "href":fix_relative(link[ .. strlen(link)-2 ], id) ]);
  if(tag == "gtext")
  {
    q->magic = "magic";
    q->bg = "#ddeeff";
    q->fg = "black";
    q->scale = "0.5";
    return make_container("gtext", q, c );
  }
  return make_container("a", q, c );
}

//
// <amail-user-variable variable=... [set=to]>
//
//  Get the value of one user variable.
//
string tag_amail_user_variable( string tag, mapping args, object id )
{
  mixed res;
#ifdef UIDPARANOIA
  if(!UID) return "";
#endif
  if( args->set )
    return UID->set( "amhc_"+args->variable, args->set );
  else
    return (string)(UID->get( "amhc_"+args->variable ) || args["default"]);
}

//
// <mail-body-part mail=id part=num>
//
// Part 0 is the non-multipart part of the mail.
// If part > the available number of parts, part 0 is returned.
// MIME.Message last_mail_mime;
// string last_mail;
//
string tag_mail_body_part( string tag, mapping args, object id )
{
  MIME.Message m;

  if(mixed q = login( id )) 
    return q;

//   if(args->mail == last_mail)
//     m = last_mail_mime;
//   else
    m = MIME.Message( tag_mail_body( tag, args, id ) );


  if(args->part == "xface")
  {
    id->misc->moreheads = ([ "Content-type":"image/gif",
			     "Content-disposition":"inline; "
			     "filename=\"xface.gif"]);
    return Image.GIF.encode( Image.XFace.decode( m->headers["x-face"] )->scale(0.8)->gamma(0.8) );
  } else {
    mixed res;
    object p;
    foreach( (array(int))(args->part / "/" - ({""})), int p )
    {
      if(m->body_parts && sizeof(m->body_parts) > p )
	m = m->body_parts[ p ];
    }
    p=m;
    id->misc->moreheads = ([ "Content-type":p->type+"/"+p->subtype,
			     "Content-disposition":"inline; "
			     "filename=\""+replace(args->name,"\"","\\\"")+
			     "\""]);
    return p->getdata();
  }
}

//
// <mail-body-parts mail=id
//             binary-part-url=URL
//	            (default not_query?mail=#mail#&part=#part#&name=#name#)
//             image-part-format='...#url#...'
//                  (default <a href='#url#'><img src='#url#'>
//                           <br>#name# (#type#)<br></a>)
//             binary-part-format='...#url#...'
//                  (default <a href='#url#'>Binary data #name# (#type#)</a>)
//             html-part-format='...#data#...'
//                  (default <table><tr><td>#data#</td></tr></table>)
//             text-part-format='...#data#...'>
//                  (default #data#)
//    full mime-data
// </mail-body-parts>
//
array(string) container_mail_body_parts( string tag, mapping args,
					 string contents, object id)
{
  return ({ low_container_mail_body_parts( tag, args, contents, id, 0 ) });
}

string low_container_mail_body_parts( string tag, mapping args, 
				      string|object contents, 
				      object id, string|void partpre)
{
  if(!stringp(partpre)) partpre="";
  if(id->prestate->raw) return "<pre>"+html_encode_string(contents)+"</pre>";

  MIME.Message msg;
//   if(stringp(contents) && args->mail == last_mail)
//   {
//     msg = last_mail_mime;
//   }
//   else
  {
    array r;
    r = catch {
      msg = objectp(contents)?contents:MIME.Message( contents );
    };
//     werror(msg->type+"/"+msg->subtype+"\n");
//     if(msg && sizeof(msg->headers["content-type"]/"\n")>1)
//     {
//       // This is probably a "normal" sendmail bug message. *¤(#¤
//       // we have to verify this somewhat...
      
//     }
    if(!msg)
    {
      string delim, presumed_contenttype = " text/plain";
      if(sscanf(contents, "%*s--NeXT-Mail%s\n",delim) == 2)
	delim = "NeXT-Mail"+delim;

      sscanf(lower_case(contents), "%*s\ncontent-type:%s\n", 
	     presumed_contenttype);

      if(sscanf(contents, "%*s\r\n\r\n%s", contents)!=2)
	sscanf(contents, "%*s\n\n%s", contents);

      catch {
	if(delim)
	  msg = MIME.Message("Content-type: multipart/mixed; boundary="+delim+"\r\n\r\n"+contents);
	else 
	  msg = MIME.Message("Content-type:"+presumed_contenttype+
			     "\r\n\r\n"+contents);
      };
      if(!msg)
	return "Illegal mime message: "+r[0]+"\n <pre>"+
	  html_encode_string((string)contents)+"</pre>";
    }
//     if(stringp(contents))
//     {
//       last_mail = args->mail;
//       last_mail_mime = msg;
//     }
  }

  string html_part_format = (args["html-part-format"] || 
			     "<table><tr><td>#data#</td></tr></table>");

  string text_part_format = (args["text-part-format"] || "#data#");

  string binary_part_format = (args["binary-part-format"] || 
			     "<a href='#url#'>#name# (#type#)"
			       "</a>");

  string image_part_format = (args["image-part-format"] || 
			     "<a href='#url#'><img border=0 src='#url#'>"
			      "<br>#name# (#type#)<br></a>");

  string binary_part_url = (fix_relative(args["binary-part-url"]
					 ||"display.html?mail=#mail#"
					 "&part=#part#&name=#name#",id));

  string res="";

  if(msg->body_parts)
  {
    int i;
    if(msg->subtype != "alternative" && msg->subtype != "related")
    {
      foreach(msg->body_parts, object msg)
      {
	if(msg->body_parts)
	{
	  res += low_container_mail_body_parts( tag, args, msg, id,
					    partpre+"/"+i );
	} 
	else if(msg->type == "message" && msg->subtype == "rfc822") 
	{
	  res += "<font size=-1>"+
	    replace(text_part_format, "#data#",
		    low_container_mail_body_parts(tag,args,
					  MIME.Message(msg->getdata()),
						  id,partpre+"/"+i))+
	    "</font>";
	}
	else if(msg->type == "text")
	{
	  if(msg->subtype == "html")
	    res += replace( html_part_format, "#data#", msg->getdata() );
	  else if(msg->subtype == "enriched")
	    res += replace( html_part_format, 
			    "#data#", 
			    highlight_enriched(msg->getdata(),id) );
	  else
	    res += replace( text_part_format, "#data#", 
			    highlight_mail(msg->getdata(),id));
	} 
	else 
	{
	  string format;
	  if(msg->type == "image") 
	    format = image_part_format;
	  else
	    format = binary_part_format;

	  mapping q = ([ "#url#":replace(binary_part_url,
					 ({"#mail#", "#part#","#name#" }),
					 ({ args->mail,partpre+"/"+(string)i, 
					    http_encode_string(msg->
							       get_filename()
						       ||"unknown name")
					 })),
			 "#name#":html_encode_string(msg->get_filename()
						     ||"unknown name"),
			 "#type#":html_encode_string(msg->type+"/"
						     +msg->subtype),
	  ]);
	  res += replace( format, indices(q), values(q) );
	}
	i++;
      }
    }
    else 
    {
      if(msg->subtype == "alternative")
      {
	object m = msg->body_parts[0];
	int p=1;
	foreach(msg->body_parts[1..], object msg)
	{
	  if( type_score( msg ) > type_score( m ) )
	  {
	    i = p;
	    m = msg;
	  }
	  p++;
	}
	res += low_container_mail_body_parts(tag,args,m,id,partpre+"/"+i);
      } 
      else 
      {
	if( msg->body_parts[0]->type != "text" ||
	    msg->body_parts[0]->subtype != "html" )
	  res += low_container_mail_body_parts( tag, args, 
					    msg->body_parts[0], 
					    id, partpre+"/0" );
	else 
	{	
	  string data =  msg->body_parts[0]->getdata();
	  data = parse_html(data, ([ "a":internal_odd_tag_href,
				     "img":internal_odd_tag_src,
				     "object":internal_odd_tag_src,
				     "embed":internal_odd_tag_src,
	  ]), ([]), replace(binary_part_url, ({"#mail#","#name#"}), 
			    ({args->mail, args->mail+".gif"})),partpre);

	  res += replace( html_part_format, "#data#", data );
	}
      }
    }
  } 
  else 
  {
    if(msg->type == "text")
    {
      if(msg->subtype == "html")
	res += replace( html_part_format, "#data#", msg->getdata() );
      else if(msg->subtype == "enriched")
	res += replace( html_part_format, 
			"#data#", 
			highlight_enriched(msg->getdata(),id) );
      else
	res += replace( text_part_format, "#data#", 
			highlight_mail(msg->getdata(),id));
    } 
    else 
    {
      string format;
      if(msg->type == "image") 
	format = image_part_format;
      else
	format = binary_part_format;
	
      mapping q = ([ "#url#":replace(binary_part_url,
				     ({"#mail#", "#part#", "#name#" }),
				     ({ args->mail, "/0", "#name#" })),
		     "#name#":html_encode_string(msg->get_filename())||"0.a",
		     "#type#":html_encode_string(msg->type+"/"+msg->subtype),
      ]);
      res += replace( format, indices(q), values(q) );
    }
  }
  return res;
}

//
// <debug-import-mail-from-dir dir=... [to=mbox]>
//  Guess. :-)
//
string tag_debug_import_mail_from_dir( string tag, mapping args,
				       object id )
{
  if(!debug) return "Debug is not enabled!\n";

#ifdef UIDPARANOIA
  if(!UID) return "";
#endif
  Mailbox incoming = UID->get_incoming();

  if(args->to)
    incoming = UID->get_or_create_mailbox( args->to );

  string res = "Importing from "+args->dir+"<p>\n";
  foreach(sort(((array(int))get_dir( args->dir ))-({0})), int file)
    if(file_stat( args->dir+"/"+file )[ 1 ] > 0)
    {
      Mail m =
	incoming->create_mail_from_fd( Stdio.File( args->dir+"/"+file,"r" ) );
      if(args->mark) m->set_flag( args->mark );
      res+="<br>"+file+"\n";
    }
  return res;
}

//
// <mail-xface>xfacetext</mail-xface>
//
string container_mail_xface( string tag, mapping args, 
			     string contents, object id )
{
  if(strlen(contents))
  {
    args->src =
      fix_relative("display.html?part=xface&mail="+id->variables->mail_id+
		   "&name=xface.gif", id);
    return make_tag( "img", args );
  }
}

//
// <get-mail mail=id>
//   #subject# #from# #body# etc.
// </get-mail>
//
// NOTE: Body contains the headers. See <mail-body-parts>
//
string container_get_mail( string tag, mapping args, 
			   string contents, object id )
{
  string res;
  Mail mid;

  while(!mid) 
  {
    mid = clientlayer->get_cache_obj( clientlayer->Mail, args->mail );
    if(!mid)
    {
      string om = args->mail;
      args->mail = tag_mail_next("",([]),id);
      if(mid == "NOPE")
      {
	m_delete(id->variables->mail_id);
	return "<p>No more mail<p>";
      }
      if(args->mail == om)
      {
	m_delete(id->variables,"mail_id");
	return "<p>No more mail<p>";
      }
    }
  }
#ifdef UIDPARANOIA
  if(!UID) return "";
#endif
  if(!mid->flags()->noread)
    mid->set_flag( "read" );

  if(mid && mid->user == UID)
  {
    return do_output_tag( args,
			  ({ (mymesg->parse_headers(mid->body())[0])
			     |make_flagmapping(mid->flags())
			     |extended_headers(mid->decoded_headers())
			     |([ "body":mid->body() ])
			     |args }),
			  contents, id );
  }
  return "Permission denied.";
}
