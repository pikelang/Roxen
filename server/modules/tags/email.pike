// This is a roxen module. Copyright © 2000 - 2001, Roxen IS.

// Todo:
//	- multiple Bcc recipients
//	- Docs
//	- more debug coloring :)

#define EMAIL_LABEL	"Email: "

constant cvs_version = "$Id: email.pike,v 1.19 2002/07/05 15:44:26 anders Exp $";

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
string revision = ("$Revision: 1.19 $"/" ")[1];

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

	string ftype, fenc, content_type, content_disp, content_id;

	// ------- file=filename type=application/octet-stream
	if(args->file)
	{
	  array s;
	  mapping got;

	  if((s = id->conf->stat_file(args->file, id)) && (s[ST_SIZE] > 0)) {
	    id->not_query = args->file;
	    got = id->conf->get_file(id);
	    if (!got)
	      RXML.run_error(EMAIL_LABEL + "Attachment:  file " +
			     Roxen.html_encode_string(args->file) +
			     " not exists.");
	  } else
	    RXML.run_error(EMAIL_LABEL + "Attachment:  file " +
			   Roxen.html_encode_string(args->file) +
			   " not exists or is empty.");

	  ftype = args->mimetype || got->type;
	  fenc  = args->mimeencoding || guess_file_encoding(aname, ftype);
	  body  = got->file->read();

	  got->file->close();

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

	  ftype = args->mimetype     || "text/plain";
	  fenc  = args->mimeencoding || "8bit";

	  // Converting bare LFs (QMail specials:)
	  if(query("CI_qmail_spec") && ftype == "test/plain")
	    body = (Array.map(body / "\r\n",
			      lambda(string el1) {
				return (replace(el1, "\n", "\r\n"));
			      })
		    )*"\r\n";
	}

	content_type = ftype + (aname ? "; name=\""+aname+"\"" : "");
	content_disp = ("attachment" +
			(aname ? "; filename=\""+aname+"\"" : ""));
	content_id   = args->cid || "nocid";

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
      if(addr)
        from = "\""+((from/" ")-({addr}))*" "+"\" <"+addr+">";

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

	// Subject
/*	if(zero_type(args["subject"]))
	  subject = Locale.Charset.encoder(chs)->clear()->feed(query("CI_nosubject"))->drain();*/
	subject = Locale.Charset.encoder(chs)->clear()->feed(args->subject||query("CI_nosubject"))->drain();
	subject = MIME.encode_word(({subject, chs}), "base64" );

	// Body
	body = Locale.Charset.encoder(chs)->clear()->feed(body)->drain();

	chs = ";charset=\""+chs+"\"";
     }

     if (arrayp(id->misc->_email_atts_) && sizeof(id->misc->_email_atts_)) {
       m=MIME.Message(body, ([ "MIME-Version":"1.0",
			     "content-type":(headers["CONTENT-TYPE"]||args->mimetype||"text/plain")
				+ chs,
			     "content-transfer-encoding":(headers["CONTENT-TRANSFER-ENCODING"]||"8bit"),
			   ]));
       error = catch(
         m=MIME.Message("", ([ "MIME-Version":"1.0", "subject":subject,
			     "from":nice_from_h(fromx),
			     "to":replace(tox, split, ","),
			     "content-type":"multipart/mixed",
			     "x-mailer":"Roxen's email, r"+revision
			   ]) + headers,
			({ m }) + id->misc->_email_atts_
         ));
       m_delete(id->misc,"_email_atts_");
     } else
     error = catch(
       m=MIME.Message(body, ([ "MIME-Version":"1.0", "subject":subject,
			     "from":nice_from_h(fromx),
			     "to":replace(tox, split, ","),
			     "content-type":(headers["CONTENT-TYPE"]||args->mimetype||"text/plain")
				+ chs,
			     "content-transfer-encoding":(headers["CONTENT-TRANSFER-ENCODING"]||"8bit"),
			     "x-mailer":"Roxen's email, r"+revision
			   ]) + headers)
     );

     if (error)
       RXML.run_error(EMAIL_LABEL+"MIME message processing error: "+Roxen.html_encode_string(error[0]));

     error = catch(o = Protocols.SMTP.client(query("CI_server_restrict") ? query("CI_server") : (args->server||query("CI_server"))));
     if (error)
       RXML.run_error(EMAIL_LABEL+"Couldn't connect to mail server. "+Roxen.html_encode_string(error[0]));

     catch(msglast = (string)m);

//werror(sprintf("D: send_mess: %O\n", (string)m));
     error = catch(o->send_message(only_from_addr(fromx), tox/split,
				   (string)m));
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
#if 1 //EMAIL_STATS
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

<attr name='subject' default='\"[ * No Subject * ]\"'
value=''><p>
 The subject line.
</p>
</attr>

<attr name='from' value='' default='(empty)'><p>
 The email address of sender.
</p>
</attr>

<attr name='to' value='' default='(empty)'><p>
 The list of recipient email address(es). Separator character can be
 defined by the 'separator' attribute.
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

<attr name='charset' value='' default='iso-8859-1'><p>
 The charset of the body.
</p>
</attr>


<ex-box>
<email from=\"foo@bar.com\" to=\"johny@pub.com|pity@bufet.com|ely@rest.com\"
separator=\"|\" charset=\"iso-8859-2\" server=\"mailhub.anywhere.org\" >
 This is the contents.
</email>
</ex-box>",

([

"header":#"<desc type='both'><p><short hide='hide'>
 Adds additional headers to the mail.

 </short>This subtag/container is designed for adding additional
 headers to the mail.</p>
</desc>

<attr name='name' value='string' required='required'><p>
 The name of the header. Standard headers are 'From:', 'To:', 'Cc:',
 'Bcc:' and 'Subject:'. However, there are no restrictions on how many
 headers are sent.</p>
</attr>

<attr name='value' value=''><p>
 The value of the header. This attribute is only used when using the
 singletag version of the tag. In case of the tag being used as a
 containertag the content will be the value.</p>
</attr>


<ex-box>
<email from=\"foo@bar.com\" to=\"johny@pub.com|pity@bufet.com|ely@rest.com\"
separator=\"|\" charset=\"iso-8859-2\" server=\"mailhub.anywhere.org\">

<header name=\"X-foo-header\" value=\"one two three\" />
<header name=\"Importance\">Normal</header>
<header name=\"X-MSMail-Priority\" value=\"Normal\" />
 This is the contents.
</email>
</ex-box>",

"signature":#"<desc tag='tag'><p><short hide='hide'>Adds a signature to the mail.
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
