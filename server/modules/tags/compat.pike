inherit "module";
inherit "roxenlib";
#include <module.h>

thread_safe=1;

array register_module()
{
  return ({
    MODULE_PARSER,
    "Compatibility RXML tags",
    "Adds support for old (deprecated) RXML tags.",
    0,1
  });
}

// Changes the parsing order by first parsing it's contents and then
// morphing itself into another tag that gets parsed. Makes it possible to
// use, for example, tablify together with sqloutput.
string tag_preparse( string tag_name, mapping args, string contents,
		     object id )
{
  id->conf->api_functions()->old_rxml_warning[0](id, "preparse tag","preparse attribute");
  return make_container( args->tag, args - ([ "tag" : 1 ]),
			 parse_rxml( contents, id ) );
}

mapping query_container_callers()
{
  return ([ 
    "preparse":tag_preparse 
  ]);
}
