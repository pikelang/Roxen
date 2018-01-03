// This is a roxen module. Copyright © 1997 - 2009, Roxen IS.
// Makes a tab list like the one in the config interface.

constant cvs_version="$Id$";
constant thread_safe=1;

#include <module.h>
inherit "module";

constant module_type = MODULE_TAG;
constant module_name = "Graphics: Tab list";
constant module_doc = 
#"Provides the <tt>&lt;tablist&gt;</tt> tag that is used to draw tab lists.
It requires the <i>GButton</i> module.";

/*
 * Functions
 */

TAGDOCUMENTATION
#ifdef manual
constant tagdoc=(["tablist":({ #"
<desc type='cont'><p><short>
<tag>tablist</tag> produces graphical navigationtabs.</short> For
example, the Administration interface for <webserver /> uses tablists
for easier administration.</p>

<p>The <tag>tablist</tag> tag is by design a wrapper for the <xref
href='gbutton.tag' /> tag, i.e. it inherits all <tag>gbutton</tag>
attributes. Also, the <tag>tab</tag> tag is in turn a wrapper for
<tag>tablist</tag> meaning that all attributes which may be given to
<tag>tablist</tag> may also be used in <tag>tab</tag>. Those
attributes given to <tag>tablist</tag> has a global effect on the
tablist, while the same attributes given to a <tag>tab</tag> only will
have a local effect, thus overriding the globally given attribute.</p>

<p>All contents inside <tag>tablist</tag> except for the
<tag>tab</tag> tags will be discarded. <tag>taglist</tag> is used in
this way to make it possible for tabs to look different when they are
for instance first or last in the tablisting.</p>

<p>The <xref href='../variable/define.tag' /> tag can be used to
globally define the tablist <i>fgcolor</i> (foreground color). The
define, <xref href='../variable/define.tag'>&lt;define
name=\"fgcolor\"&gt;</xref>, declared prior to the <tag>tablist</tag>
tag, will be sent as an extra argument to <tag>gbutton</tag>.
</p>

<ex><tablist>
<tab selected='selected'>Information</tab>
<tab>Settings</tab>
</tablist></ex>
</desc>

<attr name='frame-image' value='' default='/internal-roxen-tabframe'>
<p>A layered Photoshop (PSD) or Gimp (XCF) image which portrays the
tab's appearance. Descriptions of the different layers follows below.
If a <tag>define
name=\"frame-image\"</tag>Image_path<tag>/define</tag> definition is
set that image will be the default value instead of
<tt>/internal-roxen-tabframe</tt>. </p>
</attr>

<attr name='selcolor' value='color' default='white'>
<p>This attribute sets the backgroundcolor for the image. The effect
of this attribute is only shown when the attribute \"selected\" has
been set. If a <tag>define
name=\"selcolor\"</tag>colordefinition<tag>/define</tag> definition is
set that color will be the default value instead of <tt>white</tt>.</p>
</attr>

<attr name='seltextcolor' value='color' default='black'>
<p>This attribute sets the textcolor for the image. The effect of this
attribute is only shown when the attribute \"selected\" has been set.
If a <tag>define
name=\"seltextcolor\"</tag>colordefinition<tag>/define</tag>
definition is set that color will be the default value instead of
<tt>black</tt>. If this definition is not present, the attribute
\"textcolor\", the definition \"textcolor\" and finally the color
\"black\" will be tested.</p>
</attr>

<attr name='dimcolor' value='color' default='#003366'>
<p>This attribute sets the backgroundcolor for the image. The effect
of this attribute is only shown when the attribute \"selected\" has
<i>not</i> been set. If a <tag>define
name=\"dimcolor\"</tag>colordefinition<tag>/define</tag> definition is
set that color will be the default value instead of <tt>#003366</tt> .
</p>
</attr>

<attr name='textcolor' value='color' default='white'>
<p>This attribute sets the textcolor for the image. The effect of this
attribute is only shown when the attribute \"selected\" has <i>not</i>
been set. If a <tag>define
name=\"textcolor\"</tag>colordefinition<tag>/define</tag> definition
is set that color will be the default value instead of <tt>white</tt>
.</p>
</attr>",

(["tab":#"<desc type='cont'><p><short>

<tag>tab</tag> defines the layout and function for each and one of the
tabs in the tablisting.</short> <tag>tab</tag> inherits all attributes
available to <tag>tablist</tag>, hence all attributes available to
<xref href='gbutton.tag' /> tag may be used with the <tag>tab</tag>
tag. For instance, the attribute <i>href</i> is very useful when using
<tag>tab</tag> and a part of <xref href='gbutton.tag' />. For more
information about <tag>gbutton</tag> attributes, see its
documentation.</p>

<p>The contents of the <tag>tab</tag> is the tabs text.</p>

<p>Below follows a listing of the attributes unique to the
<tag>tab</tag> tag. Also, a listing of how imagelayers may be used is
presented.</p>
</desc>


<attr name='selected' value=''>
<p>Using this attribute the layer \"selected\" in the image will be
shown in the generated image. If this attribute has not been given the
layer \"unselected\" will be shown in the generated image.</p>
</attr>


<attr name='alt' value='text' default='the tags content'>
<p>This attribute sets the alt-text for the tab. By default the
alt-text is fetched from the content between the
<tag>tab</tag>...<tag>/tab</tag>.</p>
</attr>

<h1>Image Layers</h1>

<p>These lists shows the function of the different image layers as
well as how one layer from each group may be combined. </p>

<list type=\"dl\">
<item name=\"Layer Position\">
 <p>Position layers are the layername prefix.</p>
 <list type=\"dl\">

  <item name=\"first\"><p>A layer with this prefix is only shown for
  the <i>first</i> <tag>tab</tag> tag inside the <tag>tablist</tag>
  tag.</p> </item>

  <item name=\"last\"><p>A layer with this prefix is only shown for
  the <i>last</i> <tag>tab</tag> tag inside the <tag>tablist</tag>
  tag.</p> </item>
 </list>
</item>

<item name=\"Layer Focus\">
 <p>Focus layers are the middle part of the layername.</p>

 <list type=\"dl\">

  <item name=\"selected\"><p>This layer is only shown when the
  attribute <i>selected</i> has been set. </p></item>

  <item name=\"unselected\"><p>This layer is only shown when the
  attribute <i>selected</i> has <i>not</i> been set. </p></item>
 </list>
</item>

<item name=\"Layer Type\">
 <p>Type layers are the layername suffix.</p>

 <list type=\"dl\">

  <item name='[nothing, i.e. \"\"]'><p>This layer is inserted above
  all layers in the image, closest to the viewer that is, if lower
  layers are considered to further in inside the monitor.</p>
 </item>

 <item name=\"mask\"><p>This layer should be transparent where the tab
 is supposed to be transparent. The only thing that is retrieved from
 this layer is the mask; any graphical content here will be thrown
 away.</p></item>

 <item name=\"frame\"><p>The framelayer contains the various graphical
 elements fromwhich the frame around the button is built. This layer
 will always be run in \"Multiply\" mode, regardless of what mode it
 was previously set to. \"Multiply\" adjusts the framelayers
 brightness, i.e. Value (\"V\" in HSV), without affecting the
 colorcomponents, i.e. Hue and Saturation (\"HS\" in HSV).</p></item>

 <item name=\"background\"><p>This layer will be put beneath the
 <i>frame</i> layer and the printed text.</p></item>

 <item name=\"left\"><p>This layer is put on the left side of the
 of the generated image, thus increasing the width of the
 images left side.</p></item>

 <item name=\"right\"><p>This layer is put on the right side of the
 of the generated image, thus increasing the width of the
 images right side.</p></item>

 <item name=\"above\"><p>This layer will be shown above the other
 parts of the generated image, thus increasing the height of the
 images top.</p></item>

 <item name=\"below\"><p>This layer will be shown below the other
 parts of the generated image, thus increasing the height of the
 images base.</p></item>

 </list>
</item>
</list>

<h1>Handling layers</h1>

<p>The <i>Position</i>- and <i>Focus</i>-layers give instructions on
<i>when</i> the layer is used while the <i>Type</i>-layers indicates
its <i>function</i>.</p>

<xtable>
<row><h>Position</h><h>Focus</h><h>Type</h></row>
<row><c><p>\"\"</p></c><c><p>\"\"</p></c><c><p>\"\"</p></c></row>
<row><c><p>first</p></c><c><p>selected</p></c><c><p>background</p></c></row>
<row><c><p>last</p></c><c><p>unselected</p></c><c><p>mask</p></c></row>
<row><c><p>&nbsp;</p></c><c><p>&nbsp;</p></c><c><p>frame</p></c></row>
<row><c><p>&nbsp;</p></c><c><p>&nbsp;</p></c><c><p>left</p></c></row>
<row><c><p>&nbsp;</p></c><c><p>&nbsp;</p></c><c><p>right</p></c></row>
<row><c><p>&nbsp;</p></c><c><p>&nbsp;</p></c><c><p>above</p></c></row>
<row><c><p>&nbsp;</p></c><c><p>&nbsp;</p></c><c><p>below</p></c></row>
</xtable>

<p>These three layertypes can be combined into all possible
permutations. The order in the name is always <i>Position Focus
Type</i>, each type separated by a space. If one or two of the three
layertypes is left out, the layer will be shown regardless the extra
criterias that might be choosen. For instance, \"selected frame\" will
be shown for the \"first\" and \"last\" tabs as well as for the ones
in between the two, given that the tab has been marked as
\"selected\".</p>

<p>None of these layers are strictly necessary, as long as there
exists at least one layer of the type \"background\" or \"frame\". If
all \"mask\"-layers are left out, the mask will primary be the
framelayer and secondly the backgroundlayer, if the framelayer is not
available.</p>" ])
			    })
		]);

#endif

void start(int num, Configuration conf)
{
  module_dependencies(conf, ({ "gbutton" }) );
}

void add_layers( mapping m, string lay )
{
  foreach( ({"","background-","mask-","frame-","left-","right-",
             "above-","below-" }), string s )
  {
    string ind="extra-"+s+"layers", l;
    if( strlen( s ) )
      l = lay+" "+(s-"-");
    else
      l = lay;
    if( m[ind] )
      m[ind]+=","+l;
    else
      m[ind] = l;
  }
}

class TagTablist {
  inherit RXML.Tag;
  constant name = "tablist";

  class TagTab {
    inherit RXML.Tag;
    constant name = "tab";

    class Frame {
      inherit RXML.Frame;

      array do_return(RequestID id) {
	string fimage;
	mapping d = id->misc->tablist_args;

	if(args["frame-image"])
	  fimage = Roxen.fix_relative( args["frame-image"], id );
	else if(d["frame-image"])
	  fimage = Roxen.fix_relative( d["frame-image"], id );
	else if(id->misc->defines["tab-frame-image"])
	  fimage = Roxen.fix_relative( id->misc->defines["tab-frame-image"], id );
	else
	  //  We need an absolute path or else gbutton will "fix" this according
	  //  to the path in the request...
	  fimage = "/internal-roxen-tabframe";
  
	mapping gbutton_args = d|args;

	gbutton_args["frame-image"] = fimage;

	if( args->selected  ) {
	  add_layers( gbutton_args, "selected" );
	  gbutton_args->bgcolor = args->selcolor || d->selcolor || "white";
	  gbutton_args->textcolor = (args->seltextcolor || d->seltextcolor ||
				     args->textcolor || d->textcolor ||
				     id->misc->defines->fgcolor ||
				     id->misc->defines->theme_fgcolor ||
				     "black");
	} else {
	  add_layers( gbutton_args, "unselected" );
	  gbutton_args->bgcolor =  args->dimcolor || d->dimcolor || "#003366";
	  gbutton_args->textcolor = (args->textcolor || d->textcolor || "white");
	}
	m_delete(gbutton_args, "selected");
	m_delete(gbutton_args, "dimcolor");
	m_delete(gbutton_args, "seltextcolor");
	m_delete(gbutton_args, "selcolor");
	m_delete(gbutton_args, "result");

	if (args->alt) {
	  gbutton_args->alt = args->alt;
	  m_delete(args, "alt");
	} else
	  gbutton_args->alt = "/" + content + "\\";

	id->misc->tablist_result += ({ ({gbutton_args,content}) });
	return 0;
      }
    }
  }

  // This tag set can probably be shared, but I don't know for sure. /mast
  RXML.TagSet internal =
    RXML.TagSet(this_module(), "tablist", ({ TagTab() }) );

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = internal;

    array do_enter(RequestID id) {
      id->misc->tablist_args = args;
      id->misc->tablist_result = ({});
    }

    array do_return(RequestID id) {
      array(array) result = id->misc->tablist_result;
      if(!sizeof(result))
	return 0;

      if( result[0][0]->selected )
	add_layers( result[0][0], "first selected" );
      else
	add_layers( result[0][0], "first unselected" );
      add_layers( result[0][0], "first" );
      if( result[-1][0]->selected )
	add_layers( result[-1][0], "last selected" );
      else
	add_layers( result[-1][0], "last unselected" );
      add_layers( result[-1][0], "last" );

      return map( result, lambda( array q ) {
			    return RXML.make_tag ("gbutton",q[0],q[1]);
			  } );
    }
  }
}
