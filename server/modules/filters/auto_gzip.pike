// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.

inherit "module";

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_FIRST;
constant module_name = "Automatic sending of compressed files";
constant module_doc  = "This module implements a suggestion by Francesco Chemolli:<br />\n"
  "The modified filesystem should do\n"
  "about this:<br />\n"
  "<ul><li>check if the browser supports on-the-fly decompression</li>\n"
  "<li>check if a precompressed file already exists.</li>\n"
  "<li>if so, send a redirection to the precompressed file</li></ul>\n"
  "<p>So, no cost for compression, all URLs, content-types and such would "
  "remain vaild, no compression overhead and should be really simple "
  "to implement. Also, it would allow a site mantainer to "
  "choose WHAT to precompress and what not to."
  "This module acts as a filter, and it <i>will</i> use one extra stat "
  "per access from browsers that support automatic decompression.</p>";

mapping first_try(RequestID id) {

  if(id->supports->autogunzip &&
     id->conf->real_file(id->not_query + ".gz", id)
     && id->conf->stat_file(id->not_query + ".gz", id))
  {
    id->not_query += ".gz";
    return id->conf->get_file( id  );
  }

  return 0;
}
