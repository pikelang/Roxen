// This is a roxen module. (c) Informationsvävarna AB 1996.

inherit "module";
#include <module.h>

string cvs_version="$Id: auto_gzip.pike,v 1.1 1997/04/09 01:09:28 per Exp $";

mixed *register_module()
{
  return ({ 
    MODULE_FIRST,
    "Automatic sending of compressed files", 
    "This module implements a suggestion by Francesco Chemolli:<br>\n"
      "The modified filesystem should do\n"
      "about this:<br>\n"
      "-check if the browser supports on-the-fly decompression<br>\n"
      "-check if a precompressed file already exists.<BR>\n"
      "-if so, send a redirection to the precompressed file<p>\n"
      "\n"
      "So, no cost for compression, all URLs, content-types and such would "
      "remain vaild, no compression overhead and should be really simple "
      "to implement. Also, it would allow a site mantainer to "
      "choose WHAT to precompress and what not to.<p>"
      "This module acts as a filter, and it _will_ use one extra stat "
      "per access from browsers that support automatic decompression.",
      0,1
    });
}


mapping first_try(object id)
{
  if(id->supports->autogunzip &&
     (roxen->real_file(id->not_query + ".gz", id)
      && roxen->stat_file(id->not_query + ".gz", id)))
  {
    id->not_query += ".gz";
    return roxen->get_file( id  );
  }
}
