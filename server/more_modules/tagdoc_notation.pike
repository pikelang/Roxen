// This is a roxen module. Copyright © 2001 - 2009, Roxen IS.

#include <module.h>
inherit "module";

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_name = "TagDoc Notation exemplifier";
constant module_type = MODULE_TAG;
constant module_doc  = "This module only demonstrates how tagdoc is "
  "layouted in the final manual.";

// string simpletag_example_tag (string n, mapping m, string c, RequestID id) {
//   return "";
// }

TAGDOCUMENTATION;
constant tagdoc = ([
  "example-tag": ({ #"<desc cont='cont'><p>This is how the tag documentation
 looks like. This tag has been flagged as a container tag, i.e. you can
 put content into it like this: &lt;example-tag&gt;content&lt;/example-tag&gt;.
 A tag may also be tagged as a tag-only tag, i.e. you may only write it as
 &lt;example-tag/&gt;.</p></desc>

<attr name='age' value='number' required='required'><p>
  This is the documentation of the 'age' attribute to the <tag>example-tag</tag>.
  In this case the attribute accepts a number, e.g. &lt;example-tag age='42'&gt;&lt;/example-tag&gt;.
  This attribute is required. If it doesn't exists in the tag you will get an RXML parse error.
</p></attr>

<attr name='sort' value='up|down' default='up'><p>
  This is the documentation of the 'sort' attribute. The sort attribute may have either the value
  'up' or the value 'down'. If the attribute is omitted, the tag will assume the value 'up'.
</p></attr>", ([
  "internal":#"<desc tag='tag'><p>This is an internal tag to <tag>example-tag</tag>, which means
    that it is only available inside the <tag>example-tag</tag>. Below is an example of how
    tag usage examples looks like. These may be a single box just showing how to write the tag
    or it could be a double box showing both the code and the result.</p>

<ex type='box'>
<example-tag><internal/></example-tag>
</ex>
</desc>",

  "&_.ent;":#"<desc ent='ent'><p>This entity is an internal entity of the <tag>example-tag</tag>
    and only available inside it, just like <tag>internal</tag>.</p></desc>"
  ])
  })
]);

