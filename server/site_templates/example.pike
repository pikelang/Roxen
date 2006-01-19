inherit "common";
constant site_template = 1;

constant name = "Standard site, with example RXML pages";
constant doc  = "Standard Roxen site, with most of the commonly used modules. "
		"If you are a new Roxen user, or would like to start a fresh "
		"new site using the server to its full potential, use this "
		"template. This version of the template includes a few example "
                "pages. The source of said pages can be found in the "
                "'example_pages' directory in the 'server' directory";

constant modules = ({
  "contenttypes",
  "diremit",
  "directories",
  "gbutton",
  "graphic_text",
  "obox",
  "url_rectifier",
  "rxmlparse",
  "rxmltags",
  "filesystem",
  "tablist",
});


void init_modules( Configuration c, RequestID id )
{
  c->enable_module( "filesystem#0" );
  c->find_module( "filesystem#0" )->set( "searchpath", "example_pages" );
  c->find_module( "filesystem#0" )->set( "_priority", 1 );
}



