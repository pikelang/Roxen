// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.

// Todo:
//	- Docs
//	- more debug coloring :)

#define EMAIL_LABEL	"Email: "

constant cvs_version = "$Id$";

constant thread_safe=1;

#include <module.h>
inherit "module";

// ------------------------ Setting the defaults -------------------------

void create(Configuration conf)
{
  set_module_creator("Honza Petrous <hop@roxen.com>");

  // Default
  defvar("CI_server", "localhost", "Defaults: Mail server",
         TYPE_STRING | VAR_INITIAL,
         "The default mail server will be used if no '<i>server</i>' "
         "attribute is given to the tag.");
  defvar("CI_from", "", "Defaults: Sender name",
         TYPE_STRING,
         "The default sender name will be used if no '<i>from</i>' "
         "attribute is given to the tag.");
  defvar("CI_from_envelope", "", "Defaults: SMTP Envelope sender e-mail",
	 TYPE_STRING, #"\
The default envelope sender address that will be used if no
'<i>envelope-from</i>' attribute is given to the tag.

<p>This email will be used for the SMTP envelope. That is extremly
helpful if you are sending out emails on behalf of a third party. If
empty and there is no '<i>envelope-from</i>' attribute, the sender
from the mail's MIME headers will be taken.");
  defvar("CI_to", "", "Defaults: Recipient names",
         TYPE_TEXT_FIELD,
         "The default recipient names (one name per line) will be "
         "used if no '<i>to</i>' "
         "attribute is given to the tag.");
  defvar("CI_split", ",", "Defaults: Recipient name list character separator",
         TYPE_STRING,
         "The default recipient name list character separator "
         "will be used if no '<i>separator</i>' "
         "attribute is given to the tag.");
  defvar("CI_charset", "iso-8859-1", "Defaults: Charset",
         TYPE_STRING|VAR_MORE,
         "The default charset will be used if no '<i>charset</i>' "
         "attribute is given to the tag.<br>"
         "Note: Used only if charset is unknown (defined in filesystem module, mostly.");
  defvar("CI_mimeencoding", "base64", "Defaults: MIME encoding",
         TYPE_STRING|VAR_MORE,
         "The default MIME encoding for attachment will be used "
	 "for <i>file</i> attachments "
	 "if no '<i>mimeencoding</i>' "
         "attribute is given to the subtag &lt;attachment /&gt;.<br>"
         "Note: Used only if Content type module isn't loaded.");
  defvar("CI_nosubject", "[ * No Subject * ]", "Defaults: Subject line",
         TYPE_STRING,
         "The default subject line will be used if no '<i>subject</i>' "
         "attribute is given to the tag.");
  defvar("CI_headers", "", "Defaults: Additional headers",
         TYPE_TEXT_FIELD,
         "Additional headers (one header '<i>name=value</i>' pair per line) "
	 "will be added. "
         "");

  defvar("mbox_file",
	 conf && combine_path(conf->query("LogFile"), "../email.mbox"),
	 "Mbox file", TYPE_STRING,
         "Log e-mail messages to this mbox format file. This is "
	 "useful to find messages that may have been lost. Undelivered "
	 "messages may have the header X-Roxen-Email-Error included.");
  defvar ("mbox_file_errors_only", 1, "Log undelivered messages only",
	  TYPE_FLAG,
	  "Log only e-mail messages which the system knows will not be "
	  "delivered. Beware! All undelivered messages may not always be "
	  "logged.");
  
  // etc
  defvar ("CI_qmail_spec",1, "Qmail specials",
         TYPE_FLAG|VAR_MORE,
         "Setting this will allow connect to QMail and other mail servers "
         "which restrict access for mails with 'bare LFs'.<br>"
	 "More info at <a href=\"http://cr.yp.to/docs/smtplf.html\">"
	 "http://cr.yp.to/docs/smtplf.html</a>.");

  // Security
  defvar ("CI_server_restrict",0, "Security: Mail server restricted",
         TYPE_FLAG|VAR_MORE,
         "Setting this disable using '<i>server</i>' attribute "
         "and access is restricted to ones defined in default section. "
	 "");
  defvar ("CI_header_restrict",0, "Security: Restrict main headers",
         TYPE_FLAG|VAR_MORE,
         "Setting this disable changing 'main' headers by &lt;header /&gt; "
         "tag. Restricted will be '<i>From:, To:, Subject:, MIME-type</i>'. "
	 "");
  defvar ("CI_verbose_status",1, "Security: Verbose status",
         TYPE_FLAG|VAR_MORE,
         "Setting this enable more detailed status of processed mails "
	 "");

}

array mails = ({}), errs = ({});
string msglast = "";
string revision = ("$Revision: 1.52 $"/" ")[1];

class TagEmail {
  inherit RXML.Tag;

  constant name  = "email";

  RXML.Type content_type =
    (float) my_configuration()->query ("compat_level") >= 3.4 ?
    RXML.t_text (RXML.PXml) :
    RXML.t_xml (RXML.PXml);

  // It says that the resulting code has the type "any" and
  // should be parsed once by the XML-parser.
  array(RXML.Type) result_types = ({ RXML.t_any(RXML.PXml) });

  // Subtag <header />
  class TagMailheader {
    inherit RXML.Tag;
    constant name = "header";

    class Frame {
      inherit RXML.Frame;

      array do_return(RequestID id) {

	string value;
	if(args->name && args->value)
	  value = args->value;
	else {
	  value = (string)content;
	  // converting bare LFs (QMail specials:)
	  if(query("CI_qmail_spec")) {
	    value = replace(value, "\r", "");
	    value = replace(value, "\n", "");
	  }
	}
	if (!id->misc["_email_headers_"])
	  id->misc["_email_headers_"] = ([]);
	string header_name = upper_case(args->name);
	if (id->misc["_email_headers_"][header_name])
	  id->misc["_email_headers_"][header_name] += ","+value;
	else
	  id->misc["_email_headers_"][header_name] = value;

        return 0;
      }

    }

  } // TagMailheader

  // Subcontainer <signature />
  class TagSignature {
    inherit RXML.Tag;
    constant name = "signature";

    class Frame {
      inherit RXML.Frame;

      array do_return(RequestID id) {

	// converting bare LFs (QMail specials:)
	if(query("CI_qmail_spec"))
	  content = (Array.map(content / "\r\n", lambda(string el1) { return (replace(el1, "\n", "\r\n")); }))*"\r\n";
	if(content[..1] == "\r\n")
	  content = content[2..];
	 
	id->misc["_email_sign_"] = (string)content;

        return 0;
      }

    }

  } // TagSignature

  // Subtag/subcontainer <attachment /> .. 
  class TagAttachment {
    inherit RXML.Tag;
    constant name = "attachment";

    class Frame {
      inherit RXML.Frame;

      private string guess_file_encoding(string aname, string ftype) {

	string fenc = query("CI_mimeencoding"); //default

	switch ((ftype/"/")[0]) {
	  case "application": // application/*
		fenc = "quoted-printable";
		break;
	  case "image": // image/*
		fenc = "base64";
		break;
	}
	return(fenc);
      }

      array do_return(RequestID id) {
	object m;
	mixed error;
	string aname = args->name, body = content;

	string ftype, fenc, content_type, content_disp, content_id;

	// ------- file=filename type=application/octet-stream
	if(args->file)
	{
	  array s;
	  int|string got;
	  mapping res = ([]);

	  if((s = id->conf->stat_file(args->file, id)) && (s[ST_SIZE] > 0)) {
	    got = id->conf->try_get_file(args->file, id, 0, 0, 0, res);
	    if (intp(got))
	      RXML.run_error(EMAIL_LABEL + "Attachment:  file " +
			     Roxen.html_encode_string(args->file) +
			     " not exists.");
	  } else
	    RXML.run_error(EMAIL_LABEL + "Attachment:  file " +
			   Roxen.html_encode_string(args->file) +
			   " not exists or is empty.");

	  ftype = args->mimetype || res->type;
	  fenc  = args->mimeencoding || guess_file_encoding(aname, ftype);
	  body  = got;

	  if(!stringp(aname) || !sizeof(aname))
	    aname=(args->file/"/")[-1];
	}
	else if(args->href)
	{
	  //Protocols.HTTP.get_url_data( f, 0, hd );
	  return 0;

	}
	else
	{
	  // We assume container with text (and default type "text/plain")
	  string|array(string) guess_mimetype =
	    aname && id->conf->type_from_filename(aname);
	  if (arrayp(guess_mimetype))
	    guess_mimetype = guess_mimetype[0];
	  ftype = args->mimetype     || guess_mimetype || "text/plain";
	  fenc  = args->mimeencoding || "8bit";

	  // Converting bare LFs (QMail specials:)
	  if(query("CI_qmail_spec") && ftype == "text/plain")
	    body = (Array.map(body / "\r\n",
			      lambda(string el1) {
				return (replace(el1, "\n", "\r\n"));
			      })
		    )*"\r\n";
	}
	
	content_type = ftype + (aname ? "; name=\""+aname+"\"" : "");
	content_disp = ((args->disposition || "attachment") +
			(aname ? "; filename=\""+aname+"\"" : ""));

	//  Decide on suitable charset. If data is wide string we use UTF-8,
	//  otherwise nothing.
	if (String.width(body) > 8) {
	  content_type += "; charset=utf-8";
	  body = string_to_utf8(body);
	}
	
	//  Use "nocid" for first attachment (backwards compatibility)
	//  but counter-based strings for subsequent attachments.
	if (args->cid)
	  content_id = args->cid;
	else {
	  int nocid_counter = id->misc["_email_nocid_"]++;
	  content_id =
	    nocid_counter ? sprintf("cid_%05d", nocid_counter) : "nocid";
	}
	
	error = catch {
	  m = MIME.Message(body,
			   ([ 
			     "content-type"              : content_type,
			     "content-transfer-encoding" : fenc,
			     "content-disposition"       : content_disp,
			     "content-id"                : content_id,
			   ]));
	    };
	if (error)
	  RXML.run_error(EMAIL_LABEL +
			 "Attachment: MIME message processing error: " +
			 Roxen.html_encode_string(error[0]));

	id->misc["_email_atts_"] += ({ m });
	
	return 0;
      }

      int do_iterate;

    }
  } // TagAttachment

  // This tag set can probably be shared, but I don't know for sure. /mast
  RXML.TagSet internal = RXML.TagSet(this_module(), "email", ({ TagAttachment(), TagMailheader(), TagSignature() }));

  class Frame {
    inherit RXML.Frame;

    RXML.TagSet additional_tags = internal;

    string nice_from_h(string fromx) {
      string from = String.trim_all_whites(fromx);
      string addr;

      foreach(from/" ", string el)
        if(search(el, "@") > 0)
	  addr = el;
      if(addr && search(addr, "<") == -1) {
	string name = ((from/" ")-({addr}))*" ";
	if (sizeof(name-" "))
	  from = "\""+name+"\" <"+addr+">";
	else
	  from = addr;
      }
      return from;
    }

    string only_from_addr(string fromx) {
      foreach(Array.map(fromx/" ", String.trim_all_whites), string from1)
        if(search(from1, "@") > 0)
	  return from1;
      return String.trim_all_whites(fromx);
    }

    string colorize_parts(string message) {

#define HEADER_ST "<font color=\"green\">"
#define HEADER_E "</font>"

      string rv;

      rv = replace(message, "\r\nFrom: ", "\r\n"+HEADER_ST+"From: "+HEADER_E);
      rv = replace(message, "\r\nTo: ", "\r\n"+HEADER_ST+"To: "+HEADER_E);

      return(rv);
    }
    
    void log_message(string from, string message, void|mixed error)
    {
      string mbox_file = query("mbox_file");
      if(mbox_file && sizeof(mbox_file) &&
	 (!query("mbox_file_errors_only") || error))
      {
	string date = Calendar.ISO.Second()->format_smtp();
	string body = replace(message, "\r\nFrom ", "\r\n>From ");
	string error_msg;
	if(error)
	  catch { error_msg = (string)error; };
	if(error && !error_msg)
	  error_msg = sprintf("%O", error);
	if(stringp(error_msg))
	  body = "X-Roxen-Email-Error: " +
		 (replace(error_msg, "\r", "")/"\n" - ({ "" }))*"\n  " +
		 "\n" + body;
	Stdio.append_file(roxen_path(mbox_file),
			  sprintf("From %s %s\n%s\n\n",
				  from, date,
				  replace(body, ({ "\r", "\n" }),
					  ({ "", "\n" }))));
      }
    }

    void log_rxml_run_error(string from, mixed message, mixed error)
    {
      string m;
      if(message)
	catch { m = (string)message; };
      log_message(from, (m || "\r\n\r\n*** Unknown message ***"), 
		  EMAIL_LABEL + error);
      if (sscanf(args["error-variable"] || "", "%s.%s", 
		 string scope, 
		 string name) == 2)
	RXML.user_set_var(name, error, scope);
      
      RXML_CONTEXT->misc[" _ok"] = 0;
      RXML.run_error(EMAIL_LABEL + Roxen.html_encode_string(error));
    }
    
    array do_return(RequestID id) {
      
      object m, o;
      string body = content || "";
      string subject;
      string fromx;
      string tox, split = args->separator || query("CI_split");
      string ccx;
      string bccx;
      string chs = "";
      mixed error;
      mapping headers = ([]);

      RXML_CONTEXT->misc[" _ok"] = 1;

     if(stringp(id->misc->_email_sign_))
	body += "\n-- \n" + m_delete(id->misc, "_email_sign_");
     if(mappingp(id->misc->_email_headers_))
	headers = m_delete(id->misc, "_email_headers_");
     if(sizeof(query("CI_headers")))
	foreach(((string)query("CI_headers")/"\r\n"), string line) 
	  if (stringp(line) && sizeof(line)) {
	    string hname = (line/"=")[0];
	    string hval = (sizeof(line/"=")>1?(((line/"=")[1..])*""):"");

	    //by default we don't allow replacing standard headers
	    if(query("CI_header_restrict")) {
	      switch (upper_case(hname)) {
	        case "TO":
	        case "FROM":
	        case "SUBJECT":
	        case "MIME-VERSION":
	        case "X-MAILER": // my little own ;-)
	          break;
	        default: headers += ([ hname : hval ]);
	      }
	    } else
		headers += ([ hname : hval ]);
	  }

     if(query("CI_header_restrict")) {
	foreach(({"TO","FROM","SUBJECT","MIME-VERSION","X-MAILER"}), string h)
	  headers -= ([ h : "" ]);
     }
     
     if(!stringp(split) || !sizeof(split))
	split = "\0"; //default 
     tox = args->to || headers->TO ||
       ((replace(query("CI_to"),"\r","")/"\n")*split);

     if (args->cc)
       ccx = args->cc;
     if (headers->CC)
       ccx = (ccx?ccx+",":"") + headers->CC;
     if (ccx) {
       headers->CC = ccx;
     }
     if (args->bcc)
       bccx = args->bcc;
     if (headers->BCC)
       bccx = (bccx?bccx+",":"") + headers->BCC;
     // Our SMTP.Client should remove any BCC header, but it does not parse
     // headers at all so we have to do it here.
     m_delete(headers, "BCC");

      subject = args->subject || headers->SUBJECT || query("CI_nosubject");
      fromx = args->from || headers->FROM || query("CI_from");
      string from = only_from_addr(fromx);
     
      string env_from = args["envelope-from"];
      if (!env_from || !sizeof (env_from)) {
	env_from = query ("CI_from_envelope");
	if (!sizeof (env_from))
	  env_from = from;
      }

     // converting bare LFs (QMail specials:)
     if(query("CI_qmail_spec"))
       body = Array.map(body / "\r\n",
			lambda(string el1) {
			  return (replace(el1, "\n", "\r\n")); }
			)*"\r\n";

     // charset
     chs = args->charset || id->misc->input_charset || query("CI_charset");
     //if(!stringp(chs) || !sizeof(chs))
     //	id->misc->input_charset;

     // UTF8 -> dest. charset
     if(sizeof(chs))
     {
       Charset.Encoder enc;
       if (mixed err = catch (enc = Charset.encoder (chs)))
	 if (has_prefix (describe_error (err), "Unknown character encoding"))
	   parse_error ("Unknown charset %O.\n", chs);
	 else
	   throw (err);
       
       // Subject
       // Only encode the subject if it contains non us-ascii (7-bit) characters.
       if (String.width(subject) != 8 || string_to_utf8(subject) != subject)
       {
	 string s_chs = chs;
	 if (catch {
	     subject = enc->feed(subject)->drain();
	   }) {
	   s_chs = "utf-8";
	   subject = string_to_utf8(subject);
	 }
	 string subject_b = MIME.encode_word(({subject, s_chs}), "base64");
	 string subject_qp = MIME.encode_word(({subject, s_chs}), "quoted-printable");

	 // Use quoted printable if it is shorter because it is
	 // significantly easier to read in clients not supporting
	 // encoded subjects.
	 if(sizeof(subject_b) < sizeof(subject_qp))
	   subject = subject_b;
	 else
	   subject = subject_qp;
       }

       // Body
       if (catch {
	   body = enc->clear()->feed(body)->drain();
	 }) {
	 chs = "utf-8";
	 body = string_to_utf8(body);
       }
       chs = ";charset=\""+chs+"\"";
     }

     string fenc =
       headers["CONTENT-TRANSFER-ENCODING"] || args->mimeencoding || "8bit";

     if (arrayp(id->misc->_email_atts_) && sizeof(id->misc->_email_atts_))
     {
       m = MIME.Message(body,
			([ "MIME-Version" : "1.0",
			   "content-type" : ( (headers["CONTENT-TYPE"] ||
					       args->mimetype ||
					       "text/plain") +
					      chs ),
			   "content-transfer-encoding" : fenc,
			]));
       error = catch {
	 m=MIME.Message("",
			([ "MIME-Version" : "1.0",
			   "subject"      : subject,
			   "from"         : nice_from_h(fromx),
			   "to"           : replace(tox, split, ","),
			   "date"         : Calendar.ISO.Second()->
		                              format_smtp(), 
			   "content-type" : (args["main-mimetype"] ||
					     "multipart/mixed"),
			   "x-mailer"     : "Roxen's email, r"+revision
			]) + headers,
			({ m }) + id->misc->_email_atts_ );
       };
       m_delete(id->misc,"_email_atts_");
     } else
       error = catch {
	 m = MIME.Message(body,
			  ([ "MIME-Version" : "1.0",
			     "subject"      : subject,
			     "from"         : nice_from_h(fromx),
			     "to"           : replace(tox, split, ","),
			     "date"         : Calendar.ISO.Second()->
			                        format_smtp(),
			     "content-type" : ( (headers["CONTENT-TYPE"] ||
						 args->mimetype ||
						 "text/plain") +
						chs ),
			     "content-transfer-encoding" : fenc,
			     "x-mailer"     : "Roxen's email, r"+revision
			  ]) + headers );
       };

     if (error)
       log_rxml_run_error(from, m,
			  "MIME message processing error: "+
			  error[0]);

     error = catch {
       o = Protocols.SMTP.Client(query("CI_server_restrict") ?
				 query("CI_server") :
				 (args->server || query("CI_server")));
     };
     if (error)
       log_rxml_run_error(from, m,
			  "Couldn't connect to mail server. "+
			  error[0]);

     catch(msglast = (string)m);

     array(string) to = tox / split;
     if (ccx)  to |= ccx / split;
     if (bccx) to |= bccx / split;
     string message = (string)m;
     to -= ({""});

     if (!sizeof(to))
       log_rxml_run_error(from, message,
			  "Recipient address is missing!");
     
     error = catch(o->send_message(env_from, to, message));
     if (error)
       log_rxml_run_error(from, message,
			  error[0]);

     o->close();
     o = 0;

     log_message(from, message);
     
     //iterate log
     mails += ({ m->headers + ([ "length" : (string)(sizeof((string)m)), "date" : Calendar.Second()->format_time() ]) });

     if (id->misc->debug)
       //result = ("\n<!-- debug output --><pre>\n"+Roxen.html_encode_string(colorize_parts((string)m))+"\n</pre><!-- end of debug output -->\n");
       result = ("\n<!-- debug output --><pre>\n"+(colorize_parts((string)m))+"\n</pre><!-- end of debug output -->\n");
       // FIXME: encode to UTF8!
     else
       result = "";

      return 0;
    } // --- do_return

    int do_iterate;
  } // --- Frame
  
}

string status() {
  string rv = "";
  
  rv =  "<h2>Mail processed</h2>\n";
  rv += (sizeof(mails) ? ("Total: <b>" + (string)(sizeof(mails)) + "</b>") : "No mail") + "<br>\n";
  if(query("CI_verbose_status") && sizeof(mails)) {
#if 1 //EMAIL_STATS
    rv += "<table>\n";
    rv += "<tr ><th>Date</th><th>From</th><th>To</th><th>Size</th></tr>\n";
    foreach(mails, mapping m)
      rv += "<tr><td>"+(m->date||"")+"</td> <td>" +
	  (replace((m->from||"[N/A]"),",",", ")) +
	  "</td> <td>"+(m->to||"[default]")+"</td> <td>"+m->length+"</td></tr>\n";
    rv += "</table>\n";
#else
    ; // xxx
#endif
  }
  return rv;
}

// Some constants to register the module in the RXML parser.

constant module_type = MODULE_PARSER;
constant module_name = "Tags: E-mail module";
constant module_doc  = "Adds an extra container tag &lt;email&gt; "
  " &lt;/email&gt;  and subtags &lt;attachment/&gt, &lt; header /&gt; "
  " and &lt;signature /&gt; that are supposed to send MIME compliant"
  " mail to mail server by (E)SMTP protocol.";


TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=(["email":({ #"
<desc type='cont'><p><short></short>

The <tag>email</tag> sends MIME compliant mail to a mail server
using the (E)SMTP protocol. The content is sent as raw text

Attribute default values can be changed within the <i>E-mail
module's</i> administration interface.</p>
</desc>

<attr name='server' value='URL' default='localhost'><p> The hostname
of the machine that operates the mail server.  </p>
</attr>

<attr name='subject' default='[ * No Subject * ]'
value=''><p>
 The subject line.
</p>
</attr>

<attr name='from' value=''><p>
 The email address of sender. Values on the form <tt>John Doe foo@bar.com</tt>
 renders a From: header like <tt>From: \"John Doe\" &lt;foo@bar.com&gt;</tt>.
 If the value contains a '&lt;' the value is left unaltered.
</p>
</attr>

<attr name='envelope-from' value=''><p>
 The email address of sender to use on the SMTP envelope. Values on the form <tt>John Doe foo@bar.com</tt>
 renders a From: header like <tt>From: \"John Doe\" &lt;foo@bar.com&gt;</tt>.
 If the value contains a '&lt;' the value is left unaltered.
</p>
</attr>

<attr name='to' value=''><p>
 The list of recipient email address(es). Separator character can be
 defined by the 'separator' attribute.
</p>
</attr>

<attr name='cc' value=''><p>
 The list of carbon copy recipient email address(es).
 Separator character can be defined by the 'separator' attribute.
</p>
</attr>

<attr name='bcc' value=''><p>
 The list of blind carbon copy recipient email address(es).
 Separator character can be defined by the 'separator' attribute.
</p>
</attr>

<attr name='separator' value='' default=','><p>
 The separator character for the recipient list.
</p>
</attr>

<attr name='mimetype' value='MIME type'><p>
 Overrides the MIME type of the body.
</p>
</attr>

<attr name='main-mimetype' value='MIME type'><p>
 Overrides the MIME type of the enclosing message when attachments are
 used. Default is 'multipart/mixed' but it might be useful to set
 this to 'multipart/related' when sending HTML mail with inlined
 images. Note that HTML mails should use either <tt>quoted-printable</tt>
 or <tt>base64</tt> transfer encoding to ensure that you don't exceed the
 SMTP line length maximum.
</p>
</attr>

<attr name='mimeencoding' value='MIME encoding'><p>
 Sets the MIME encoding of the message. Typical values are <tt>8bit</tt>,
 <tt>quoted-printable</tt> and <tt>base64</tt>.</p>
</attr>

<attr name='charset' value='' default='iso-8859-1'><p>
 The charset of the body and subject. The body will be encoded in utf-8
 if it was not possible to encode the text in the supplied charset. The subject
 will be unencoded if possible otherwise encoded with the supplied charset
 or encoded in utf-8 if it was not possible to encode the text in the supplied
 charset.
</p>
</attr>

<attr name='error-variable' value='RXML variable'>
  <p>
    An RXML variable to store a potential error message in. 
  </p>
</attr>

<ex-box>
<email from=\"foo@bar.com\" to=\"johny@pub.com|pity@bufet.com|ely@rest.com\"
separator=\"|\" charset=\"iso-8859-2\" server=\"mailhub.anywhere.org\" 
error-variable=\"var.error\">
 This is the contents.
</email>
<else>
  Failed to send email: &var.error;
</else>
</ex-box>",

([

"header":#"<desc type='both'><p><short hide='hide'>
 Adds additional headers to the mail.

 </short>This subtag/container is designed for adding additional
 headers to the mail.</p>
 <p>By default replacing standard headers is not allowed.</p>
</desc>

<attr name='name' value='string' required='required'><p>
 The name of the header. Standard headers are 'From', 'To', 'Cc',
 'Bcc' and 'Subject'. However, there are no restrictions on how many
 headers are sent.</p>
</attr>

<attr name='value' value=''><p>
 The value of the header. This attribute is only used when using the
 singletag version of the tag. In case of the tag being used as a
 containertag the content will be the value. The 'Bcc' and
 'Cc' headers can contain multiple addresses separated by
 ',' or the string in the split attribute of <tag>email</tag>.</p>
</attr>


<ex-box>
<email from=\"foo@bar.com\" to=\"johny@pub.com|pity@bufet.com|ely@rest.com\"
separator=\"|\" charset=\"iso-8859-2\" server=\"mailhub.anywhere.org\">

<header name=\"Bcc\">joe@bar.com|jane@foo.com</header>
<header name=\"X-foo-header\" value=\"one two three\" />
<header name=\"Importance\">Normal</header>
<header name=\"X-MSMail-Priority\" value=\"Normal\" />
 This is the contents.
</email>
</ex-box>",

"signature":#"<desc tag='cont'><p><short hide='hide'>Adds a signature to the mail.
 </short>This container is designed for adding a signature to the
 mail.</p></desc>

<ex-box>
<email from=\"foo@bar.com\" to=\"johny@pub.com|pity@bufet.com|ely@rest.com\"
separator=\"|\" charset=\"iso-8859-2\" server=\"mailhub.anywhere.org\">

<header name=\"X-foo-header\" value=\"one two three\" />
<header name=\"Importance\">Normal</header>
<header name=\"X-MSMail-Priority\" value=\"Normal\" />
 This is the contents.

<signature>
-------------------
John Doe
Roxen Administrator
</signature>
</email>
</ex-box>",

"attachment":#"<desc type='both'><p><short hide='hide'>
 Adds attachments to the mail.</short>This tag/subcontainer is
 designed for adding attachments to the mail.</p>

 <p>There are two different kinds of attachments; file and inline.
 File attachments require the <i>file</i> attribute while inline
 attachments are written inline. Inline attachments can for instance
 be a text or a binary (e.g. output from a database).</p>

<ex-box><email from=\"foo@bar.com\" to=\"johny@pub.com|pity@bufet.com|ely@rest.com\"
separator=\"|\" charset=\"iso-8859-2\" server=\"mailhub.anywhere.org\">

<header name=\"X-foo-header\" value=\"one two three\" />
<header name=\"Importance\">Normal</header>
<header name=\"X-MSMail-Priority\" value=\"Normal\" />
 This is the contents.

<attachment file=\"/images/hello.gif\" />
<attachment file=\"/excel/p_123.xls\" name=\"partners.xls\" />

<attachment name=\"partners.txt\" >
      company1        1.2345  abc
      company2        2.345   ix
      company8        3.4567  az
</attachment>
</email></ex-box>

</desc>

<attr name='file' value='path'><p>
 The path to the file in the virtual filesystem. If this attribute is
 omitted it is assumed that the attachment is a text attachment.</p>
</attr>

<!--
 Not implemented yet.
<attr name='href' value='URL'>
 Similar to <i>file</i> but used when the attachment is located
 elsewhere, i.e. \"somewhere on the Net\".
</attr>
-->

<attr name='name' value='filename'><p>
 The filename. When sending a file attachment this name is what the
 reciever will see in his/hers list of attachment, not the original
 filename. If omitted, the original name will be used. This attribute
 is required when sending inline text or binary attachments.</p>
</attr>

<attr name='disposition' value='Content-disposition'><p>
 The MIME content-disposition to use for the attachment.
 The default disposition is \"attachment\".
</p>
</attr>

<attr name='cid' value='Content-ID'><p>
 The content-id to use for the attachment.
 The default id is \"nocid\" for the first attachment without custom
 content-id (for backwards compatibility), and a counter-based string for
 subsequent attachments.
</p>
</attr>

<attr name='mimetype' value='MIME type'><p>
 Sets the MIME type of the file. Since MIME type is set by the
 <i>Content types</i> module this setting seldom needs to be
 used.</p>
</attr>

<attr name='mimeencoding' value='MIME encoding'><p>
 Sets the MIME encoding of the file. If omitted the <i>E-mail
 module's</i> default setting within the <webserver /> Administration
 interface might be used if it's a <i>file</i> attachment.</p>
</attr>"

   ])
 })
]);
#endif
