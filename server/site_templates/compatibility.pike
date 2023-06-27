inherit "common";
constant site_template = 1;

constant name = "Compatibility site";
constant doc  = "Roxen 1.3 compatibility site. Of interest primarily for "
                "earlier Roxen users who have an old-style RXML site and "
                "want to use it right away, source files unmodified.";

constant modules = ({
  "rxmlparse",
  "rxmltags",
  "contenttypes",
  "directories",
  "graphic_text",
  "url_rectifier",
  "obox",
  "compat",
  "gbutton",
  "tablist",
  "filesystem",
});

void init_modules( Configuration c, RequestID id )
{
  c->find_module( "graphic_text#0" )->set("colorparse",1 );
}
