// This module implements an IE5/Macintosh fix; if no file is found, assume
// the url is UTF-8 or Macintosh encoded.

string cvs_version = "$Id: deutf8.pike,v 1.2 1999/08/14 13:31:18 jhs Exp $";
#include <module.h>
inherit "module";

int unsuccessful = 0;
array(string) encodings = ({ "utf-8", "macintosh" });
mapping(string:int) redirs = mkmapping( encodings, allocate(sizeof(encodings)) );
mapping(string:object) decoders = mkmapping( encodings,
					     Array.map(encodings,
						       Locale.Charset.decoder) );

array (mixed) register_module()
{
  return ({ MODULE_LAST, "De-UTF8", // Perhaps a bit misleading nowadays?
            "If no file is found, assume the url is "
	    "UTF-8 or Macintosh encoded and try again.",
	     0, 1 });
}

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

#define DECODE(what, encoding) decoders[encoding]->clear()->feed( what )->drain()

mapping last_resort(object id)
{
  function decode;
  string iq;
  foreach(encodings, string encoding)
    if( !catch( iq = DECODE( id->not_query, encoding ) ) &&
	(iq != id->not_query) )
    {
      decode = lambda(string s) { return DECODE(s, encoding); };
      object id2 = id->clone_me();
      id2->not_query = iq;
      id2->config = mkmultiset(Array.map( (array)id2->config, decode ));
      //id2->raw_url = DECODE(id2->raw_url, encoding);
      // Perhaps we should fix this too (%NN-quoted characters as
      // well), but it really isn't right IMHO.              /jhs
      id2->prestate = mkmultiset(Array.map( (array)id2->prestate, decode ));
      id2->variables = (mapping)(Array.map( (array)id2->variables,
					    lambda(array p)
					    { return Array.map(p, decode); } ));
      mapping q = id->conf->get_file( id2 );

      if( q )
      {
	redirs[encoding]++;
	return q;
      }
    }
  unsuccessful++;
}
