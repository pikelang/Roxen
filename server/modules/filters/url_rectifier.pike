// This is a roxen module. Copyright © 1999 - 2000, Roxen IS.
// This module implements an IE5/Macintosh fix; if no file is found, assume
// the url is UTF-8 or Macintosh encoded.

string cvs_version = "$Id: url_rectifier.pike,v 1.13 2001/03/30 14:49:24 jhs Exp $";
inherit "module";
#include <request_trace.h>
constant thread_safe = 1;

int unsuccessful = 0;
array(string) encodings = ({ "utf-8", "macintosh", "iso-2022" });
mapping(string:int) redirs = ([]);
mapping(string:function) decoders = ([]);

void start()
{
  foreach( encodings, string enc )
    if( enc == "utf-8" )
      decoders[ enc ] = utf8_to_string;
    else
      decoders[ enc ]= Roxen._charset_decoder(Locale.Charset.decoder(enc))->decode;
}

constant module_type = MODULE_LAST;
constant module_name = "URL Rectifier";
constant module_doc  = "If no file is found, assume the url is "
  "UTF-8 or Macintosh encoded and try again.";

string status()
{
  int successful = sizeof(redirs)?`+(@values(redirs)):0;
  int all = successful + unsuccessful;
  return sprintf( "<p><b>%d%%</b> (%d out of %d) of all "
		  "potential 404:s were saved by this module.</p>"
		  "<table><tr><th>Encoding</th><th>Caught</th></tr>\n"
		  "%{<tr><td>%s</td><td>%d</td></tr>\n%}"
		  "</table>",
		  (all ? 100*successful/all : 0), successful, all,
		  sort((array)redirs) );
}

mapping last_resort(object id)
{
  function decode;
  string iq;
  int tries;
  foreach(encodings, string encoding)
  {
    decode = decoders[ encoding ];
    if( !catch( iq = decode( id->not_query ) ) &&
	(iq != id->not_query) )
    {
      TRACE_ENTER("Decoding request as " + encoding + " turns " +
		  id->not_query + " into " + iq + ".\n", 0);
      object id2 = id->clone_me();
      id2->decode_charset_encoding( decode );
      mapping q = id->conf->get_file( id2 );
      if( q )
      {
	TRACE_LEAVE("Wee! Document found!\n");
	redirs[encoding]++;
	return q;
      }
      TRACE_LEAVE((tries ? "Rats" : "Nope") +
		  ", that didn't quite cut it" +
		  (tries++ ? " either" : "") + ".\n");
    }
  }
  unsuccessful++;
}
