// This is a roxen module. Copyright (c) 2000, Roxen IS

// Todo:
//	- checking 'valid' email addresses
//	- multiple Bcc recipients
//	- Docs
//	- more debug coloring :)
//

#define EMAIL_LABEL	"Email: "

constant cvs_version = "$Id: email.pike,v 1.3 2001/02/06 15:11:00 hop Exp $";

constant thread_safe=1;

#include <module.h>
inherit "module";

// ------------------------ Setting the defaults -------------------------

void create()
{
  set_module_creator("Honza Petrous <hop@roxen.com>");

  // Default
  defvar("CI_server", "localhost", "Default: Mail server",
         TYPE_STRING | VAR_INITIAL,
         "The default mail server will be used if no '<i>server</i>' "
         "attribute is given to the tag.");
  defvar("CI_from", "", "Default: Sender name",
         TYPE_STRING,
         "The default sender name will be used if no '<i>from</i>' "
         "attribute is given to the tag.");
  defvar("CI_to", "", "Default: Recipient names",
         TYPE_TEXT_FIELD,
         "The default recipient names (one name per line) will be "
         "used if no '<i>to</i>' "
         "attribute is given to the tag.");
  defvar("CI_split", ",", "Default: Recipient name list character separator",
         TYPE_STRING,
         "The default recipient name list character separator "
         "will be used if no '<i>separator</i>' "
         "attribute is given to the tag.");
  defvar("CI_charset", "iso-8859-1", "Default: Charset",
         TYPE_STRING|VAR_MORE,
         "The default charset will be used if no '<i>charset</i>' "
         "attribute is given to the tag.<br>"
         "Note: Used only if charset is unknown (defined in filesystem module, mostly.");
  defvar("CI_mimeencoding", "base64", "Default: MIME encoding",
         TYPE_STRING|VAR_MORE,
         "The default MIME encoding for attachment will be used if no '<i>mimeencoding</i>' "
         "attribute is given to the subtag &lt;attachment /&gt;.<br>"
         "Note: Used only if Content type module isn't loaded.");
  defvar("CI_nosubject", "[ * No Subject * ]", "Default: Subject line",
         TYPE_STRING,
         "The default subject line will be used if no '<i>subject</i>' "
         "attribute is given to the tag.");
  defvar("CI_headers", "", "Default: Additional headers",
         TYPE_TEXT_FIELD,
         "Additional headers (one header '<i>name=value</i>' pair per line) "
	 "will be added. "
         "");

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

class TagEmail {
  inherit RXML.Tag;

  constant name  = "email";

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

	if(args->name && args->value)
	  id->misc["_email_headers_"] += ([ upper_case(args->name) : (string)(args->value) ]);
	else {
	  // converting bare LFs (QMail specials:)
	  if(query("CI_qmail_spec")) {
	    content = replace(content, "\r", "");
	    content = replace(content, "\n", "");
	  }
	  id->misc["_email_headers_"] += ([ upper_case(args->name) : (string)content ]);
	}

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

	// ------- file=filename type=application/octet-stream
	if(args->file) {
	  string ftype;
	  string fenc;
	  array s;
	  mapping got;

	  if((s = id->conf->stat_file(args->file, id)) && (s[ST_SIZE] > 0)) {
	    id->not_query = args->file;
	    got = id->conf->get_file(id);
	    if (!got)
	      RXML.run_error(EMAIL_LABEL+"Attachment:  file "+Roxen.html_encode_string(args->file)+" not exists.");
	  } else
	    RXML.run_error(EMAIL_LABEL+"Attachment:  file "+Roxen.html_encode_string(args->file)+" not exists or is empty.");

	  ftype = args->mimetype || got->type;
	  body = got->file->read();
	  got->file->close();

	  if(!stringp(aname) || !sizeof(aname))
	    aname=(args->file/"/")[-1];

	  fenc = args->mimeencoding || guess_file_encoding(aname, ftype);

	  error = catch(
	  m=MIME.Message(body, ([ 
			       "content-type":(ftype + (sizeof(aname) ? ";name=\"" + aname + "\"": "")),
			       "content-transfer-encoding":fenc,
			       "content-disposition":"attachment"
			       //"content-disposition":(sizeof(aname)? "attachment; filename=\"" + aname + "\"": "attachment")
			     ]))
	  );
	  if (error)
	    RXML.run_error(EMAIL_LABEL+"Attachment: MIME message processing error: "+Roxen.html_encode_string(error[0]));

	  id->misc["_email_atts_"] += ({ m });

	  return 0;
	} //file

	if(args->href) { // href=url

	  //Protocols.HTTP.get_url_data( f, 0, hd );
	  return 0;
	}

	// ---------- we assume container with text and type "text/plain"
	// converting bare LFs (QMail specials:)

	if(query("CI_qmail_spec"))
	  body = (Array.map(body / "\r\n", lambda(string el1) { return (replace(el1, "\n", "\r\n")); }))*"\r\n";

	error = catch(
	m=MIME.Message(body, ([ 
			     "content-type":(sizeof(aname) ? "text/plain; name=\"" + aname + "\"": "text/plain"),
			     "content-transfer-encoding":"8bit",
			     "content-disposition":(sizeof(aname)? "attachment; filename=\"" + aname + "\"": "attachment")
			   ]))
	);
	if (error)
	  RXML.run_error(EMAIL_LABEL+"Attachment: MIME message processing error: "+Roxen.html_encode_string(error[0]));

	id->misc["_email_atts_"] += ({ m });
	
	return 0;
      }

      int do_iterate;

    }
  } // TagAttachment

  RXML.TagSet internal = RXML.TagSet("TagEmail.internal", ({ TagAttachment(), TagMailheader(), TagSignature() }));

  class Frame {
    inherit RXML.Frame;

    RXML.TagSet additional_tags = internal;

    string colorize_parts(string message) {

#define HEADER_ST "<font color=\"green\">"
#define HEADER_E "</font>"

      string rv;

      rv = replace(message, "\r\nFrom: ", "\r\n"+HEADER_ST+"From: "+HEADER_E);
      rv = replace(message, "\r\nTo: ", "\r\n"+HEADER_ST+"To: "+HEADER_E);

      return(rv);
    }

    array do_return(RequestID id) {

      object m, o;
      string body = content || "";
      string subject;
      string fromx;
      string tox, split = args->separator || query("CI_split");
      string chs = "";
      mixed error;
      mapping headers = ([]);


     if(stringp(id->misc->_email_sign_))
	body += "\n-- \n" + id->misc->_email_sign_;
     if(mappingp(id->misc->_email_headers_))
	headers = id->misc->_email_headers_;
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
     tox = args->to || headers->TO || ((replace(query("CI_to"),"\r","")/"\n")*split);
     if (!tox || sizeof(tox)<1)
       RXML.run_error(EMAIL_LABEL+"Recipient address is missing!");

      subject = args->subject || headers->SUBJECT || query("CI_nosubject");
      fromx = args->from || headers->FROM || query("CI_from");

     // converting bare LFs (QMail specials:)
     if(query("CI_qmail_spec"))
       body = (Array.map(body / "\r\n", lambda(string el1) { return (replace(el1, "\n", "\r\n")); }))*"\r\n";

     // charset
     chs = args->charset || id->misc->input_charset || query("CI_charset");
     //if(!stringp(chs) || !sizeof(chs))
     //	id->misc->input_charset;

     // UTF8 -> dest. charset
     if(sizeof(chs)) {
	if(zero_type(args["subject"]))
	  subject = Locale.Charset.encoder(chs)->clear()->feed(query("CI_nosubject"))->drain();
	subject = MIME.encode_word(({subject, chs}), "base64" );
	chs = ";charset=\""+chs+"\"";
     }

     error = catch(
       m=MIME.Message(body, ([ "MIME-Version":"1.0", "subject":subject,
			     "from":fromx,
			     "to":replace(tox, split, ","),
			     "content-type":"text/plain" + chs,
			     "content-transfer-encoding":"8bit",
			     "x-mailer":"Roxen's email, v1.6"
			   ]) + headers)
     );
     if (error)
       RXML.run_error(EMAIL_LABEL+"MIME message processing error: "+Roxen.html_encode_string(error[0]));

     if (arrayp(id->misc->_email_atts_) && sizeof(id->misc->_email_atts_))
       error = catch(
         m=MIME.Message("", ([ "MIME-Version":"1.0", "subject":subject,
			     "from":fromx,
			     "to":replace(tox, split, ","),
			     "content-type":"multipart/mixed",
			     "x-mailer":"Roxen's email, v1.6"
			   ]) + headers,
			({ m }) + id->misc->_email_atts_
         ));

     error = catch(o = Protocols.SMTP.client(query("CI_server_restrict") ? query("CI_server") : (args->server||query("CI_server"))));
     if (error)
       RXML.run_error(EMAIL_LABEL+"Couldn't connect to mail server. "+Roxen.html_encode_string(error[0]));

     catch(msglast = (string)m);

     error = catch(o->send_message(fromx, tox/split, (string)m));
     if (error)
       RXML.run_error(EMAIL_LABEL+Roxen.html_encode_string(error[0]));

     o->close();
     o = 0;

     //itterate log
     mails += ({ m->headers + ([ "length" : (string)(sizeof((string)m)) ]) });

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
#if EMAIL_STATS
    rv += "<table>\n";
    rv += "<tr ><th>From</th><th>To</th><th>Size</th></tr>\n";
    foreach(mails, mapping m)
      rv += "<tr ><td>"+(m->from||"[N/A]")+"</td><td>"+(m->to||"[default]")+"</td><td>"+m->length+"</td></tr>\n";
    rv += "</table>\n";
#else
    ; // xxx
#endif
  }
  return rv;
}

// Some constants to register the module in the RXML parser.

constant module_type = MODULE_PARSER;
constant module_name = "E-mail module";
constant module_doc  = "Adds an extra container tag &lt;email&gt; "
  " &lt;/email&gt;  and subtags &lt;attachment/&gt, &lt; header /&gt; "
  " and &lt;signature /&gt; that are supposed to send MIME compliant"
  " mail to mail server by (E)SMTP protocol.";


