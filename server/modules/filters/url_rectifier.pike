// This module implements an IE5/Macintosh fix; if no file is found, assume
// the url is UTF-8 or Macintosh encoded.

string cvs_version = "$Id: url_rectifier.pike,v 1.7 2000/02/10 04:54:17 nilsson Exp $";
#include <module.h>
inherit "module";
inherit "roxenlib";

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
      decoders[ enc ]= _charset_decoder(Locale.Charset.decoder(enc))->decode;
}

constant module_type = MODULE_LAST;
constant module_name = "URL Rectifier";
constant module_doc  = "If no file is found, assume the url is "
  "UTF-8 or Macintosh encoded and try again.";

string status()
{
  int successful = `+(@values(redirs)), all = successful + unsuccessful;
  return sprintf( "<p><b>%d%%</b> (%d out of %d) of all "
		  "potential 404:s were saved by this module.</p>"
		  "<table><tr><th>Encoding</th><th>Caught</th></tr>\n"
		  "%{<tr><td>%s</td><td>%d</td></tr>\n%}"
		  "</table>",
		  (all ? 100*successful/all : 0), successful, all,
		  sort((array)redirs) );
}

#define DECODE(what, encoding) decoders[ encoding ](what)

mapping last_resort(object id)
{
  function decode;
  string iq;
  foreach(encodings, string encoding)
  {
    decode = decoders[ encoding ];
    if( !catch( iq = decode( id->not_query ) ) &&
	(iq != id->not_query) )
    {
      object id2 = id->clone_me();
      id2->decode_charset_encoding( decode );
      mapping q = id->conf->get_file( id2 );
      if( q )
      {
	redirs[encoding]++;
	return q;
      }
    }
  }
  unsuccessful++;
}
