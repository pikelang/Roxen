inherit "module";
#include <module.h>

constant module_unique = 1;
constant module_name = "Tags: Static Resource Server";
string module_doc = 
  #"
<p>This module can help you improve browser caching of semi-static
resources (Javascript files, CSS, images etc. that may change every
once in a while) by: 
  <ol> 
    <li>Setting a far-future Expires HTTP header, as described by <a href=\"http://developer.yahoo.com/performance/rules.html#expires\">Yahoo!</a></li>
    <li>Injecting a variable part in the resource URL that changes whenever the linked resource file changes</li> 
  </ol> 
</p> 

<p>These two features combined will make sure that the resource files are browser-cached for as long as possible while avoiding overcaching.</p>
";

constant module_type = MODULE_FILTER | MODULE_TAG;

constant expire_time = 86400*365; // One year.

constant default_process_tags = ([ "link"   : "href",
				   "script" : "src" ]);

void create(Configuration conf)
{
  defvar("process_tags",
         Variable.Mapping(default_process_tags, 0,
			  "Tags to process",
			  "The tags to process and the corresponding "
			  "attribute that refers an external resource."));
}

class TagServeStaticResources
{
  inherit RXML.Tag;
  constant name = "serve-static-resources";

  string mangle_resource_urls(string s, RequestID id)
  {
    mapping process_tags = query("process_tags");
    Parser.HTML parser = Parser.HTML();
    parser->xml_tag_syntax(0);

    function process_tag = lambda(Parser.HTML p, mapping args)
    {
      string tag_name = p->tag_name();
      string attr_name = process_tags[tag_name];
      string link = args[attr_name];
      if(link && sizeof (link) && link[0] == '/') {
	array(int)|Stdio.Stat st =
	  id->conf->try_stat_file(link, id);

	if(st) {
	  if(arrayp(st))
	    st = Stdio.Stat(st);

	  string varystr = sprintf("mtime=%d", st->mtime);

	  args[attr_name] =
	    Roxen.add_pre_state(link, (< "cache-forever", varystr >));
	  return ({ Roxen.make_tag(tag_name, args, has_suffix (tag_name, "/"),
				   1) });
	}
      }
      return 0;
    };

    foreach(process_tags; string tag_name; string attr_name) {
      parser->add_tag(tag_name, process_tag);
      parser->add_tag(tag_name + "/", process_tag);
    }

    parser->ignore_unknown (1);
    string res = parser->finish(s)->read();
    parser = 0;
    process_tag = 0;
    return res;
  };

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      result = mangle_resource_urls(content || "", id);
    }
  }
}

mapping|void filter(mapping res, RequestID id)
{
  if (!res) return;

  if(id->prestate["cache-forever"]) {
    if (res->extra_heads) {
      m_delete(res->extra_heads, "cache-control");
      m_delete(res->extra_heads, "Cache-Control");
      m_delete(res->extra_heads, "expires");
      m_delete(res->extra_heads, "Expires");
    }

    RAISE_CACHE(expire_time);

    id->misc->vary = (<>);
    return res;
  }
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc = ([
  "serve-static-resources":#"<desc type='tag'><p><short>Specifies a block of tags referring static resources.</short> Wrap this tag around your block of static resource referring tags.</p>
<ex-box>
<serve-static-resources>
  <link rel=\"stylesheet\" href=\"/index.css\"/>
  <script type=\"text/javascript\" src=\"/index.js\"/>
</serve-static-resources>
</ex-box>
<p>Note: Only local absolute paths will be processed, i.e. they have to begin with a '/'.</p>
</desc>"
]);
#endif // manual