inherit "common";
constant site_template = 1;
constant name = "Documentation site";
constant doc  = "A site with the online Roxen documentation.";

constant silent_modules = 
({
  "sqlfs",
  "indexfiles",
  "url_rectifier",
  "contenttypes",
});

constant modules = ({ });


void init_modules( Configuration c, RequestID id )
{
  c->find_module( "contenttypes#0" )
    ->set( "exts",
#"# This will include the defaults from a file.
# Feel free to add to this, but do it after the #include line if
# you want to override any defaults

#include <etc/extensions>
tag text/html
xml text/html
rad text/html
ent text/html" );
}
