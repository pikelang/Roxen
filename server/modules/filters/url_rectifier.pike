// This module implements a IE5 fix, if no file is found, assume
// the url is UTF-8 encoded.

string cvs_version = "$Id: url_rectifier.pike,v 1.1 1999/08/06 04:10:10 per Exp $";
#include <module.h>
inherit "module";

int redirs, pothelp;

array (mixed) register_module()
{
  return ({ MODULE_LAST, "De-UTF8", 
            "If no file is found, assume the url is "
	    "UTF-8 encoded and try again.",
	     0, 1 });
}

string status()
{
  return sprintf("<b>%d</b> out of <b>%d</b> UTF-8 encoded URLs found",
                 redirs, pothelp);
}

object decoder = Locale.Charset.decoder( "utf-8" );

mapping last_resort(object id)
{
  string iq = id->not_query;
  if( !catch( iq = decoder->clear()->feed( iq )->drain() ) &&
      (iq != id->not_query) )
  {
    object id2 = id->clone_me();
    id2->not_query = iq;
    mapping q =  id->conf->get_file( id2 );

    pothelp++;
    if( q )
    {
      redirs++;
      return q;
    }
  }
}
