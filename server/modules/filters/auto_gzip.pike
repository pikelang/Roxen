// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.

inherit "module";
#include <module.h>

constant cvs_version="$Id: auto_gzip.pike,v 1.5 1998/11/18 04:54:13 per Exp $";
constant thread_safe=1;

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
  NOCACHE();
  if(id->supports->autogunzip &&
     (id->conf->real_file(id->not_query + ".gz", id)
      && id->conf->stat_file(id->not_query + ".gz", id)))
  {
    id->not_query += ".gz";
    return id->conf->get_file( id  );
  }
}
