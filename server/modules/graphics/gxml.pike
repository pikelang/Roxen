// This is a roxen module. Copyright © 2001 - 2009, Roxen IS.
//
#include <module.h>
inherit "module";
//<locale-token project="mod_gxml">_</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_gxml",X,Y)
// end of the locale related stuff

constant thread_safe=1;

constant cvs_version = "$Id$";
constant module_type = MODULE_TAG;

LocaleString module_name = _(1,"Graphics: GXML tag");
LocaleString module_doc  = _(2,"Provides the tag <tt>&lt;gxml&gt;</tt>.");

roxen.ImageCache the_cache;

int do_ext;

void create()
{
  defvar("ext", Variable.Flag(0, VAR_MORE,
			      "Append format to generated images",
			      "Append the image format (.gif, .png, "
			      ".jpg, etc) to the generated images. "
			      "This is not necessary, but might seem "
			      "nicer, especially to people who try "
			      "to mirror your site."));
}

void start()
{
  the_cache = roxen.ImageCache( "gxml", generate_image );
  do_ext = query("ext");  
}

void stop()
{
  destruct(the_cache);
}

void flush_cache() {
  the_cache->flush();
}

mapping(string:function) query_action_buttons()
{
  return ([ _(3,"Clear Cache"):flush_cache ]);
}

string status() {
  array s=the_cache->status();
  return sprintf(_(4,"<b>Images in cache:</b> %d images<br />\n"
                   "<b>Cache size:</b> %s"),
		 s[0], Roxen.sizetostring(s[1]));
}

Image.Layer|mapping generate_image(mapping a, mapping node_tree, RequestID id)
{
  LazyImage.clear_cache();
  LazyImage.LazyImage image = LazyImage.decode(node_tree);
  array|mapping ll = image->run(0, id);
  LazyImage.clear_cache();
  if (mappingp(ll))
    return ll;
  
  mapping e;
  if( a->size )
  {
    string gl;
    if( sscanf( a->size, "layers(%s)", gl ) )
      e = LazyImage.layers_extents( LazyImage.find_layers( gl, ll ) );
    else if( sscanf( a->size, "layers-id(%s)", gl ) )
      e = LazyImage.layers_extents( LazyImage.find_layers_id( gl, ll ) );
    else
    {
      e = ([]);
      if( sscanf( a->size, "(%d,%d)-(%d,%d)", e->x, e->y, e->x1, e->y1 ) != 4)
	if( sscanf( a->size, "%d,%d", e->x1, e->y1 ) != 2)
	  e = LazyImage.layers_extents( ll );;
    }
  } else
    e = LazyImage.layers_extents( ll );
  
  // Crop to the left so that 0,0 is uppmost left corner.
  // return Image.lay( ll, e->x0, e->y0, e->x1, e->y1 );

  // Combine layers.
  return Image.lay( ll );
}


mapping find_internal( string f, RequestID id )
{
  // Remove file exensions
  sscanf (f, "%[^./]", f);
  return the_cache->http_file_answer( f, id );
}

array(RXML.Tag) gxml_find_builtin_tags(  )
{
  return map(glob("GXML*", indices( this_object() )), ::`[])();
}



#define STACK_PUSH(X) id->misc->gxml_stack->push( X )
#define STACK_POP()   id->misc->gxml_stack->pop( )
#define TMP_PUSH(X) id->misc->gxml_tmp_stack->push( X )
#define TMP_POP()   id->misc->gxml_tmp_stack->pop( )

#define COMBI_LI( X,Y )                                                 \
class GXML##X								\
{									\
  inherit RXML.Tag;							\
  constant name = LazyImage.X.operation_name;				\
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;			\
									\
  class Frame								\
  {									\
    inherit RXML.Frame;							\
    array do_enter( RequestID id )					\
    {									\
      TMP_PUSH( STACK_POP() );						\
      STACK_PUSH(0);							\
    }									\
									\
    array do_return( RequestID id )					\
    {									\
      if (content && result_type->decode_charrefs)			\
        content = result_type->decode_charrefs(content);		\
      Y;                                                                \
      LazyImage.LazyImage i = TMP_POP();				\
      LazyImage.LazyImage ii = STACK_POP();				\
      if( ii && i )							\
	STACK_PUSH(LazyImage.join_images(i->ref(), LazyImage.new(LazyImage.X,\
							  ii->ref(),args)));\
      else								\
	STACK_PUSH( LazyImage.new(LazyImage.X,ii||i,args) );		\
    }									\
  }                                                                     \
}

#define SIMPLE_LI(X) COMBI_LI(X,/*nichts*/)
#define CONTENT_LI(X,Y) COMBI_LI(X,args->Y=content)
#define CONTENT_LI_WITH_CI(X,Y,Z) COMBI_LI(X,args->Y=Z(content))

class GXMLPush
{
  inherit RXML.Tag;
  constant name = "push";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;

  class Frame
  {
    inherit RXML.Frame;
    array do_enter( RequestID id )
    {
      TMP_PUSH( STACK_POP() );
      STACK_PUSH(0);
    }

    array do_return( RequestID id )
    {
      LazyImage.LazyImage i = TMP_POP();
      LazyImage.LazyImage ii = STACK_POP();
      STACK_PUSH( (ii||i)->ref() );
      STACK_PUSH( i );
    }
  }
}

class GXMLStackDup
{
  inherit RXML.Tag;
  constant name = "stack-dup";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;

  class Frame
  {
    inherit RXML.Frame;
    array do_return( RequestID id )
    {
      catch {
	LazyImage.LazyImage i = STACK_POP();
	STACK_PUSH( i );
	STACK_PUSH( i );
      };
      parse_error("Too few elements on stack\n");
    }
  }
}

class GXMLStackSwap
{
  inherit RXML.Tag;
  constant name = "stack-swap";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;

  class Frame
  {
    inherit RXML.Frame;
    array do_return( RequestID id )
    {
      catch {
	LazyImage.LazyImage i = STACK_POP();
	LazyImage.LazyImage j = STACK_POP();
	STACK_PUSH( i );
	STACK_PUSH( j );
      };
      parse_error("Too few elements on stack, need 2 to run stack-swap\n");
    }
  }
}

class GXMLClearStack
{
  inherit RXML.Tag;
  constant name = "stack-clear";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;

  class Frame
  {
    inherit RXML.Frame;
    array do_return( RequestID id )
    {
      LazyImage.LazyImage i;
      catch( i = STACK_POP() );
      id->misc->gxml_stack->reset();
      STACK_PUSH( i );
    }
  }
}

class GXMLMerge
{
  inherit RXML.Tag;
  constant name = "merge";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;

  class Frame
  {
    inherit RXML.Frame;

    array do_enter( RequestID id )
    {
      catch
      {
	TMP_PUSH( STACK_POP() );
	return 0;
      };
      parse_error("Popping beyond end of stack\n");
    }
    
    array do_return( RequestID id )
    {
      LazyImage.LazyImage a = TMP_POP();
      LazyImage.LazyImage b = STACK_POP();
      if( a && b )
	STACK_PUSH( LazyImage.join_images( a, b ) );
      else
	STACK_PUSH( a||b );
      return 0;
    }
  }
}

class GXMLPopDup
{
  inherit RXML.Tag;
  constant name = "merge-dup";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;

  class Frame
  {
    inherit RXML.Frame;

    array do_enter( RequestID id )
    {
      catch
      {
	TMP_PUSH( STACK_POP() );
	LazyImage.LazyImage b = STACK_POP();
	STACK_PUSH( b ); STACK_PUSH( b );
	return 0;
      };
      parse_error("Popping beyond end of stack\n");
    }
    
    array do_return( RequestID id )
    {
      LazyImage.LazyImage a = TMP_POP();
      LazyImage.LazyImage b = STACK_POP();
      if( a && b )
	STACK_PUSH( LazyImage.join_images( a->ref(), b ) );
      else
	STACK_PUSH( a||b );
      return 0;
    }
  }
}

class GXMLPopReplace
{
  inherit RXML.Tag;
  constant name = "pop";

  class Frame
  {
    inherit RXML.Frame;
    array do_return( RequestID id )
    {
      catch
      {
	STACK_POP();
	return 0;
      };
      parse_error("Popping beyond end of stack\n");
    }
  }
}

string parse_coordinates( string from )
{
  Parser.HTML p = Parser.HTML();
  string res = "";
  p->xml_tag_syntax( 2 );
  p->add_container( "c", lambda(Parser.HTML p, mapping a, string c) {
			   res += (String.trim_all_whites(a->x)+","+
				   String.trim_all_whites(a->y)+",");
			   return c;
	           } );
  p->feed( from )->finish();
  return res[..strlen(res)-2];
}

string parse_coordinate_system( string from )
{
  return from;
}

CONTENT_LI_WITH_CI(Polygone,coordinates,parse_coordinates);
CONTENT_LI_WITH_CI(Line,coordinates,parse_coordinates);

CONTENT_LI(Text,text);
CONTENT_LI(CoordinateSystem,data);
CONTENT_LI(Legend,labels);

SIMPLE_LI(LoadImage);
SIMPLE_LI(SelectLayers);
SIMPLE_LI(ReplaceAlpha);
SIMPLE_LI(SetLayerMode);
SIMPLE_LI(MoveLayer);
SIMPLE_LI(NewLayer);

SIMPLE_LI(Crop);
SIMPLE_LI(Blur);
SIMPLE_LI(GreyBlur);
SIMPLE_LI(Expand);
SIMPLE_LI(Scale);
SIMPLE_LI(Shadow);
SIMPLE_LI(Rotate);


SIMPLE_LI(Gamma);
SIMPLE_LI(Invert);
SIMPLE_LI(Grey);
SIMPLE_LI(Color);
SIMPLE_LI(Clear);
SIMPLE_LI(MirrorX);
SIMPLE_LI(MirrorY);
SIMPLE_LI(HSV2RGB);
SIMPLE_LI(RGB2HSV);
SIMPLE_LI(Distance);
SIMPLE_LI(SelectFrom);


array(string|RXML.Tag) builtin_tags = gxml_find_builtin_tags();

protected class InternalTagSet
{
  inherit RXML.TagSet;

  protected class GXTag
  {
    inherit RXML.Tag;
    string name;
    int flags;
    RXML.Type content_type;
    program Frame;
    
    void create(string _name, RXML.Tag parent)
    {
      name=_name;
      flags=parent->flags|RXML.FLAG_DONT_REPORT_ERRORS;
      content_type = parent->content_type;
      Frame = parent->Frame;
    }
  }

  protected array(RXML.Tag) gxml_make_tags()
  {
    Configuration conf = my_configuration();
    if(!conf)
      // Add moudule can instanciate a roxen module without a configuration.
      return ({ });

    mapping from = conf->rxml_tag_set->get_plugins("gxml");
    return builtin_tags + map (indices (from),
			       lambda (string tn) {
				 return GXTag( tn, from[tn] );
			       });
  }

  protected int in_changed = 0;

  void changed()
  {
    if (in_changed) return;
    in_changed = 1;
    clear();
    add_tags (gxml_make_tags());
    in_changed = 0;
    ::changed();
  }

  protected void create()
  {
    ::create (this_module(), "gxml");
    changed();
  }
}

protected RXML.TagSet internal_tag_set = InternalTagSet();

class TagGXML
{
  inherit RXML.Tag;
  constant name = "gxml";
  constant flags = RXML.FLAG_SOCKET_TAG|RXML.FLAG_DONT_REPORT_ERRORS;

#define V(X) ("$["+X+"]")
  class LayersVars
  {
    inherit RXML.Scope;

    constant is_RXML_encodable = 1;

    mixed `[] (string var, void|RXML.Context ctx,
	       void|string scope_name, void|RXML.Type type)
    {
      string scope;
      if (sscanf(scope_name, "%*s.layers.%s", scope) == 2)
	return V("layers."+scope+"."+var);
      return this_object();
    }

    int _encode() {return 0;}
    void _decode (int dummy) {}
  }
    mapping make_guides_mapping( string v )
    {
      mapping res = ([]);
      for( int i = 1; i<100; i++ )
      {
	res[""+i] = V("guides."+v+"."+i);
	res[""+(-i)] = V("guides."+v+"."+(-i));
      }
      return res;
    }
    mapping gxml_vars =
    ([
      "guides":([
	"v": make_guides_mapping("v"),
	"x": make_guides_mapping("v"),

	"h": make_guides_mapping("h"),
	"y": make_guides_mapping("h"),
      ]),
      "image":([
	"left":V("image.l"),  "l":V("image.l"),
	"right":V("image.r"), "r":V("image.r"),
	"top":V("image.t"),   "t":V("image.t"),
	"width":V("image.w"), "w":V("image.w"),
	"height":V("image.h"),"h":V("image.h"),
      ]),
      "layer":([
	"left":V("layer.l"),  "l":V("layer.l"),
	"right":V("layer.r"), "r":V("layer.r"),
	"top":V("layer.t"),   "t":V("layer.t"),
	"width":V("layer.w"), "w":V("layer.w"),
	"height":V("layer.h"),"h":V("layer.h"),
      ]),
      "layers":LayersVars(),
    ]);
#undef V

  class Frame 
  {
    inherit RXML.Frame;
    constant scope_name = "gxml";
    mapping vars = gxml_vars;
    RXML.TagSet additional_tags = internal_tag_set;

    array do_enter( RequestID id )
    {
//       if( id->misc->gxml_stack )
// 	parse_error("Recursive gxml tags not supported\n" );
      LazyImage.clear_cache();
      id->misc->gxml_stack = ADT.Stack();
      id->misc->gxml_stack->push( 0 );
      id->misc->gxml_tmp_stack = ADT.Stack();
    }

    array do_return( RequestID id )
    {
      // The image is now in the top of id->misc->gxml_stack, hopefully.
      LazyImage.LazyImage i;
      if( catch( i = STACK_POP() ) )
      {
	LazyImage.clear_cache();
	parse_error("Popping out of stack\n");
      }
      LazyImage.clear_cache();
      if( !catch( STACK_POP() ) )
	tag_debug("Elements left on stack after end of rendering.\n");

      m_delete( id->misc, "gxml_stack" );
      m_delete( id->misc, "gxml_tmp_stack" );
      
      if( !i )
	parse_error( "No image\n");

      int timeout = Roxen.timeout_dequantifier(args);

      mapping my_args = ([
	"quant":     args->quant,
	"crop":      args->crop,
	"format":    args->format,
	"maxwidth":  args->maxwidth,
	"maxheight": args->maxheight,
	"scale":     args->scale,
	"dither":    args->dither,
	"gamma":     args->gamma,
	"size":      args->size,
	"background":args->background, // Compatibility
      ]);
      foreach( glob( "*-*", indices(args)), string n )
	my_args[n] = args[n];

      string src_filename = m_delete(args, "filename");
      mapping res_args = args - my_args;
      mapping node_tree = i->encode();
      // werror("Node tree: %O\n", node_tree);
      string key = the_cache->store( ({ my_args, node_tree }), id, timeout);

      string ext = "";
      if(do_ext)
	ext = "." + (my_args->format || "png");
      
      res_args->src = query_internal_location() + key +
	((src_filename && sizeof(src_filename))? "/" + Roxen.http_encode_url(src_filename) : "") + ext;
      int no_draw = !id->misc->generate_images;
      if( mapping size = the_cache->metadata( key, id, no_draw, timeout ) )
      {
	res_args->width = size->xsize;
	res_args->height = size->ysize;
      }

      if( !args->url ) 
	result = Roxen.make_tag( "img", res_args, !res_args->noxml );
      else
	result = res_args->src;
    }
  }
}

mapping tagdocumentation()
{
  Stdio.File file=Stdio.File();
  if(!file->open(__FILE__,"r")) return 0;
  mapping doc = compile_string("#define manual\n"+file->read(), __FILE__)->tagdoc;
  doc["gxml"][0] += the_cache->documentation();
  // Generate examples
  string ex = "";
  foreach (Array.transpose(({Image.Layer()->available_modes(),
			     Image.Layer()->descriptions()})),
	   [string mode,string desc])
  {
    ex += sprintf(#"<p><b>%s</b></p><p>%s<br/>
<ex-html>
<div style='background-image: url(\"/internal-roxen-squares\"); width: 480px;'>
  <gxml true-alpha='' format='png'>
    <load-image src='/internal-roxen-bottom-layer' />
    <set-layer-mode mode='%[0]s'>
      <load-image src='/internal-roxen-top-layer' />
    </set-layer-mode>
  </gxml>
</div>
</ex-html></p>",
		  mode, Roxen.html_encode_string(desc));
  }
  string s = doc["gxml"][1]["set-layer-mode"][..<7] + ex + "</attr>"; 
  doc["gxml"][1]["set-layer-mode"] = s;
  return doc;
}

#ifdef manual
constant tagdoc = ([
  "gxml": ({ #"<desc type='cont'><p><short>Manipulates images in different ways
    using layers.</short></p><p>It is possible to make much more advanced
    manipulation using <tag>gtext</tag><tag>/gtext</tag> than with for instance
    <tag>cimg/</tag>. It is possible to pass attributes, such as the alt 
    attribute, to the resulting tag by including them in the gxml tag.</p></desc>
    <attr name='url'><p>
      Instead of generating a <tag>img</tag> return the url to the generated
      image.
    </p></attr>
    <attr name='noxml'><p>
      Don't self close the generated <tag>img</tag>.
    </p></attr>

    <attr name='filename' value='string'><p>
      Works like the <i>filename</i> attribute to <tag>cimg/</tag>.</p>
    </attr>

<h1>Timeout</h1>

<p>The generated image will by default never expire, but
in some circumstances it may be pertinent to limit the
time the image and its associated data is kept. Its
possible to set an (advisory) timeout on the image data
using the following attributes.</p>

<attr name='unix-time' value='number'><p>
Set the base expiry time to this absolute time.</p><p>
If left out, the other attributes are relative to current time.</p>
</attr>

<attr name='years' value='number'><p>
Add this number of years to the time this entry is valid.</p>
</attr>

<attr name='months' value='number'><p>
Add this number of months to the time this entry is valid.</p>
</attr>

<attr name='weeks' value='number'><p>
Add this number of weeks to the time this entry is valid.</p>
</attr>

<attr name='days' value='number'><p>
Add this number of days to the time this entry is valid.</p>
</attr>

<attr name='hours' value='number'><p>
Add this number of hours to the time this entry is valid.</p>
</attr>

<attr name='beats' value='number'><p>
Add this number of beats to the time this entry is valid.</p>
</attr>

<attr name='minutes' value='number'><p>
Add this number of minutes to the time this entry is valid.</p>
</attr>

<attr name='seconds' value='number'><p>
Add this number of seconds to the time this entry is valid.</p>
</attr>", ([
    "&_.layers.{name}.l;" : #"<desc type='entity'><p>
      Position of the left side of the layer <i>name</i>.
      </p></desc>",
    "&_.layers.{name}.t;" : #"<desc type='entity'><p>
      Position of the top side of the layer <i>name</i>.
      </p></desc>",
//     "&_.layers.{name}.r;" : #"<desc type='entity'><p>
//       Position of the right side of the layer <i>name</i>.
//       </p></desc>",
//     "&_.layers.{name}.b;" : #"<desc type='entity'><p>
//       Position of the bottom side of the layer <i>name</i>.
//       </p></desc>",
    "&_.layers.{name}.w" : #"<desc type='entity'><p>
      Width of the layer <i>name</i>.
      </p></desc>",
    "&_.layers.{name}.h" : #"<desc type='entity'><p>
      Height of layer <i>name</i>.
      </p></desc>",
    "load-image" : #"<desc type='tag'><p>Load an image from disk.</p></desc>
      <attr name='src' value='url' required=''><p>
        The path to the indata file.
      </p></attr>
      <attr name='tile'><p>
        If the layer which the image is loaded into is larger than the image
        itself then tile the image.
      </p></attr>",
    "select-layers" : #"<desc type='tag'><p>Select a list of layers to be
      rendered.</p></desc>
      <attr name='include' value='glob'></attr>
      <attr name='include-id' value='layer-id'></attr>
      <attr name='exclude' value='glob'></attr>
      <attr name='exclude-id' value='layer-id'></attr>",
    "text" : #"<desc type='cont'><p>Render text onto the specified layer or,
      if no layer is specified, onto a new layer.</p></desc>
      <attr name='layers-id' value='layer-id'><p>
        Layer to render the text to.
      </p></attr>
      <attr name='layers' value='glob'><p>
        Layer to render the text to.
      </p></attr>
      <attr name='name' value='string'><p>Name of the new layer.</p></attr>
      <attr name='font' value='string'><p>
	Selects which font to use. You can get a list of all available fonts
	by using the list fonts task in the administration interface, or by
	using the <xref href='../output/emit_fonts.tag' /> plugin.</p>
      </attr>

      <attr name='fontsize' value='number'><p>
	Selects which size of the font that should be used.</p>
      </attr>
      <attr name='color' value='color'><p>
	Sets the text color. 
      </p></attr>
      <attr name='x' value='number'></attr>
      <attr name='y' value='number'></attr>
      <attr name='modulate-alpha'><p>
	The text will be used to modulate the alpha channel of the specified
	layer.
      </p></attr>
      <attr name='replace-alpha'><p>
	Almost the same as the modulate-alpha attribute but replaces the whole
	alpha channel of the specified layer.
      </p></attr>",
    "replace-alpha" : #"<desc type='both'><p>Replace the alpha channel of the
      specified layer(s) with either the alpha channel from another layer or a
      group of layers or a color.</p></desc>
      <attr name='layers' value='glob'><p>
        Layer to replace alpha.
      </p></attr>
      <attr name='layers-id' value='layer-id'><p>
        Layer to replace alpha.
      </p></attr>
      <attr name='from' value='layer'><p>
        Layer to copy alpha channel from.
      </p></attr>
      <attr name='from-id' value='layer-id'><p>
        Layer to copy alpha channel from.
      </p></attr>
      <attr name='color' value='color'><p>
        Create alpha channel from the given color in the layer.
      </p></attr>",
    "shadow" : #"<desc type='both'><p>Creates a new layer which contains the
      shadow of the specified layers.</p>
      <ex>
<gxml format='png' true-alpha='1' background-color='white'>
  <shadow xoffset='3' yoffset='3' soft='3' color='blue'>
    <text name='foo' color='white'>Hello World!</text>
  </shadow>
</gxml>
      </ex></desc>
      <attr name='layers' value='glob'><p>
	Layer to create shadow for.
      </p></attr>
      <attr name='layers-id' value='layer-id'><p>
	Layer to create shadow for.
      </p></attr>
      <attr name='xoffset' value='number'><p>
        How much to the right of the specified layer the shadow will fall.
      </p></attr>
      <attr name='yoffset' value='number'><p>
	How much below the specified layer the shadow will fall.
      </p></attr>
      <attr name='soft' value='number'><p>
        How blurred the shadow should be.
      </p></attr>
      <attr name='color' value='color'><p>
        Color of the shadow.
      </p></attr>",
    "set-layer-mode" : #"<desc type='both'><p>Set layer mode.</p></desc>
      <attr name='mode' value='mode' default='normal'><p>
        Mode is one of these:</p>
        <xtable>
          <row><h>variable</h><h>Meaning</h></row>
          <row><c><p>L</p></c><c><p>The active layer</p></c></row>
          <row><c><p>S</p></c>
	    <c><p>The source layer (the sum of the layers below)</p></c></row>
          <row><c><p>D</p></c>
	    <c><p>The destintion layer (the result)</p></c></row>
          <row><c><p>Xrgb</p></c>
	    <c><p>Layer red (<b>Xr</b>), green (<b>Xg</b>) or blue
              channel (<b>Xb</b>) </p></c></row>
          <row><c><p>Xhsv</p></c>
	    <c><p>Layer hue (<b>Xh</b>), saturation (<b>Xs</b>) or
              value channel (<b>Xv</b>) (virtual channels)</p></c></row>
          <row><c><p>Xhls</p></c>
	    <c><p>Layer hue (<b>Xh</b>), lightness channel (<b>Xl</b>) or
	      saturation (<b>Xs</b>) (virtual channels)</p></c></row>
          <row><c><p>aX</p></c>
	    <c><p>Layer alpha, channel in layer alpha</p></c></row>
        </xtable>
        <i>All channels are calculated separately, if nothing else is
           specified.</i>
        <p><b>Bottom layer:</b></p>
        <p><ex-html>
          <gxml true-alpha='' format='png'>
            <new-layer xsize='480' ysize='80' transparent=''>
              <load-image src='/internal-roxen-squares' tiled='yes' />
            </new-layer>
            <load-image src='/internal-roxen-bottom-layer' />
          </gxml>
        </ex-html></p>
        <p><b>Top layer:</b></p>
        <p><ex-html>
          <gxml true-alpha='' format='png'>
            <new-layer xsize='480' ysize='80' transparent=''>
              <load-image src='/internal-roxen-squares' tiled='yes' />
            </new-layer>
            <load-image src='/internal-roxen-top-layer' />
          </gxml>
        </ex-html></p>
      </attr>",
    "move-layer" : #"<desc type='both'><p>Moves the specified layer(s).
      </p></desc>
      <attr name='layers' value='glob'><p>Layer to be moved.</p></attr>
      <attr name='layers-id' value='layer-id'><p>Layer to be moved.</p></attr>
      <attr name='x' value='number'><p>
        Move the layer along the x-axis.
      </p></attr>
      <attr name='y' value='number'><p>
        Move the layer along the y-axis.
      </p></attr>
      <attr name='absolute'><p>
        If this attribute is set then <att>x</att> and <att>y</att> will be
        absolute coordinates instead of relative.
      </p></attr> ",
    "new-layer" : #"<desc type='tag'><p>Create a new empty layer.</p></desc>
      <attr name='xsize' required=''><p>Width of layer.
      </p></attr>
      <attr name='ysize' required=''><p>Height of layer.
      </p></attr>
      <attr name='color' value='color' default='black'></attr>
      <attr name='transparent'><p>If the layer should be fully transparent. 
        Default is a fully opaque layer.
      </p></attr>
      <attr name='mode' value='mode' default='normal'><p>Sets the mode for
        the new layer. See <tag>set-layer-mode</tag>.
      </p></attr> ",
    "crop" : #"<desc type='both'><p>Crop the specified layer(s).
      </p><ex>
<gxml>
  <crop x='25' y='50' width='100' height='100'>
    <load-image src='/internal-roxen-testimage' />
  </crop>
</gxml>
      </ex></desc>
      <attr name='layers' value='glob'><p>
        Layer to crop.
      </p></attr>
      <attr name='layers-id' value='layer-id'><p>
        Layer to crop.
      </p></attr>
      <attr name='x' value='number' required=''><p>
        How far from the left the layer should be cropped.
      </p></attr>
      <attr name='y' value='number' required=''><p>
        How far from the top the layer should be cropped.
      </p></attr>
      <attr name='width' value='number'><p>Width of the cropped layer.
      </p></attr>
      <attr name='height' value='number'><p>Height of the cropped layer.
      </p></attr>",
    "scale" : #"<desc type='both'><p>Scale the specified layer(s).</p></desc>
      <attr name='layers' value='glob'><p>
        Layer to scale.
      </p></attr>
      <attr name='layers-id' value='layer-id'><p>
        Layer to scale.
      </p></attr>
      <attr name='mode' value='{absolute, relative}' default='absolute'><p>
        If mode is set to \"relative\", the <att>width</att> and 
        <att>height</att> will be given as percentages of the original width 
        and height.
      </p></attr>
      <attr name='width' value='{pixels, percentage}'><p>
        Set the width of the scaled layer. If <att>height</att> is not set or
        set to 0, the aspect ratio will be perserved.
      </p></attr>
      <attr name='height' value='{pixels, percentage}'><p>
        Set the height of the scaled layer. If <att>width</att> is not set or
        set to 0, the aspect ratio will be perserved.
      </p></attr>
      <attr name='max-width' value='xsize'><p>
        If height is larger than 'ysize', scale height to 'ysize' while keeping
        aspect.
      </p></attr>
      <attr name='max-height' value='ysize'><p>
        If height is larger than 'ysize', scale height to 'ysize' while keeping
        aspect.
      </p></attr>",
    "rotate" : #"<desc type='both'><p>Rotate the specified layer(s)</p></desc>
      <attr name='layers' value='glob'><p>Layer to rotate</p></attr>
      <attr name='layers-id' value='layer-id'><p>Layer to rotate</p></attr>
      <attr name='degrees' value='degrees' required=''><p>Number of degrees to
        rotate the layer(s)
      </p></attr>",
    "grey-blur" : #"<desc type='both'><p>Same as <tag>blur</tag> but
      up to three times faster. Works only for greyscale images though.
      </p></desc>
      <attr name='layers' value='glob'><p>Layer to blur.</p></attr>
      <attr name='layers-id' value='layer-id'><p>Layer to blur.</p></attr>
      <attr name='times' value='number' default='1'><p>
        Number of times to blur the image.
      </p></attr>
      <attr name='what' value='{image, alpha}' default='image'><p>
        Set <att>what</att> to 'alpha' if you want to blur the alpha channel.
      </p></attr>",
    "blur" : #"<desc type='both'><p>Blur either the specified layers.</p>
        <ex>
<gxml format='jpg'>
  <load-image src='/internal-roxen-testimage' />

  <move-layer x='&_.layers.Background.w;' absolute=''>
    <blur>
      <load-image src='/internal-roxen-testimage' />
    </blur>
  </move-layer>

  <move-layer x='&_.layers.Background.w;*2' absolute=''>
    <blur radius='5' times='2'>
      <load-image src='/internal-roxen-testimage' />
    </blur>
  </move-layer>
</gxml>
        </ex>
      </desc>
      <attr name='layers' value='glob'><p>Layer to blur.</p></attr>
      <attr name='layers-id' value='layer-id'><p>Layer to blur.</p></attr>
      <attr name='radius' value='r' default='3'><p>
        Set radius <i>r</i> for the blur. The default value is optimized and
        thus significantly faster than the other cases.
      </p></attr>
      <attr name='times' value='n' default='1'><p>
        Blur the image <i>n</i> number of times.
      </p></attr>
      <attr name='what' value='{image, alpha}' default='image'><p>
        Set <att>what</att> to 'alpha' if you want to blur the alpha channel.
      </p></attr>",
    "gamma" : #"<desc type='both'><p>Adjust the gamma of a layer.</p></desc>
      <attr name='layers' value='glob'><p>Layer to work on</p></attr>
      <attr name='layers-id' value='layers-id'><p>Layer to work on</p></attr>
      <attr name='gamma'></attr>
      <attr name='what' values='{image, alpha, both}'><p>
        Whether to work on the alpha channels or image data or both.
      </p></attr>",
    "invert" : #"<desc type='both'><p>Invert the colors and/or alpha of a layer.
      </p>
      <ex>
<gxml format='jpeg'>
  <invert>
    <load-image src='/internal-roxen-testimage' />
  </invert>
</gxml>
      </ex>
      </desc>
      <attr name='layers' value='glob'><p>Layer to work on</p></attr>
      <attr name='layers-id' value='layers-id'><p>Layer to work on</p></attr>
      <attr name='what' values='{image, alpha, both}'><p>
        Whether to work on the alpha channels or image data or both.
      </p></attr>",
    "grey" : #"<desc type='both'><p>Make the layer greyscale.</p>
      <ex>
<gxml format='jpeg'>
  <grey>
    <load-image src='/internal-roxen-testimage' />
  </grey>
</gxml>
      </ex>
      </desc>
      <attr name='layers' value='glob'><p>Layer to work on</p></attr>
      <attr name='layers-id' value='layers-id'><p>Layer to work on</p></attr>
      <attr name='what' values='{image, alpha, both}'><p>
        Whether to work on the alpha channels or image data or both.
      </p></attr>",
    "clear" : #"<desc type='both'><p>Clear layer to a given color.</p></desc>
      <attr name='layers' value='glob'><p>Layer to work on</p></attr>
      <attr name='layers-id' value='layers-id'><p>Layer to work on</p></attr>
      <attr name='what' values='{image, alpha, both}'><p>
        Whether to work on the alpha channels or image data or both.
      </p></attr>
      <attr name='color' value='color' default='black'><p>
        Color to clear layer to.
      </p></attr>",
    "mirror-x" : #"<desc type='both'><p>Mirror layer along the X-axis.
      </p></desc>
      <attr name='layers' value='glob'><p>Layer to work on</p></attr>
      <attr name='layers-id' value='layers-id'><p>Layer to work on</p></attr>
      <attr name='what' values='{image, alpha, both}'><p>
        Whether to work on the alpha channels or image data or both.
      </p></attr>",
    "mirror-y" : #"<desc type='both'><p>Mirror layer along the Y-axis.
      </p></desc>
      <attr name='layers' value='glob'><p>Layer to work on</p></attr>
      <attr name='layers-id' value='layers-id'><p>Layer to work on</p></attr>
      <attr name='what' values='{image, alpha, both}'><p>
        Whether to work on the alpha channels or image data or both.
      </p></attr>",
    "hsv-to-rgb" : #"<desc type='both'><p>Convert layer from HSV to RGB color
        model.
      <ex>
<gxml format='jpg'>
  <load-image src='/internal-roxen-testimage' />
  <text color='white'>Original</text>
  <move-layer x='&_.layers.Background.w;'>
    <hsv-to-rgb>
      <load-image src='/internal-roxen-testimage'/>
    </hsv-to-rgb>
    <text color='white'>HSV to RGB</text>
  </move-layer>
  <move-layer x='&_.layers.Background.w;*2'>
    <rgb-to-hsv>
      <load-image src='/internal-roxen-testimage' />
    </rgb-to-hsv>
    <text color='white'>RGB to HSV</text>
  </move-layer>
</gxml>
      </ex>
      </p></desc>
      <attr name='layers' value='glob'><p>Layer to work on</p></attr>
      <attr name='layers-id' value='layers-id'><p>Layer to work on</p></attr>
      <attr name='what' values='{image, alpha, both}'><p>
        Whether to work on the alpha channels or image data or both.
      </p></attr>",
    "rgb-to-hsv" : #"<desc type='both'><p>Convert layer from RGB to HSV color
        model.
      <ex>
<gxml format='jpg'>
  <load-image src='/internal-roxen-testimage' />
  <text color='white'>Original</text>
  <move-layer x='&_.layers.Background.w;'>
    <hsv-to-rgb>
      <load-image src='/internal-roxen-testimage'/>
    </hsv-to-rgb>
    <text color='white'>HSV to RGB</text>
  </move-layer>
  <move-layer x='&_.layers.Background.w;*2'>
    <rgb-to-hsv>
      <load-image src='/internal-roxen-testimage' />
    </rgb-to-hsv>
    <text color='white'>RGB to HSV</text>
  </move-layer>
</gxml>
      </ex>
      </p></desc>
      <attr name='layers' value='glob'><p>Layer to work on</p></attr>
      <attr name='layers-id' value='layers-id'><p>Layer to work on</p></attr>
      <attr name='what' values='{image, alpha, both}'><p>
        Whether to work on the alpha channels or image data or both.
      </p></attr>",
    "color-distance" : #"<desc type='both'><p>Makes an grey-scale image, 
        for alpha-channel use.</p>
      <p>The given value (or current color) is used for coordinates in the
        color cube. Each resulting pixel is the distance from this point to the
        source pixel color, in the color cube, squared, rightshifted 8 steps:
      </p>
      <ex-box>
        p - pixel color
        o - given color
        d - destination pixel
        d.red=d.blue=d.green=((o.red-p.red)²+(o.green-p.green)²+(o.blue-p.blue)²)>>8
      </ex-box>
      <ex>
        <gxml format='jpeg'>
          <load-image src='/internal-roxen-testimage' />
          <text color='white'>Original</text>
        </gxml>
        <gxml format='jpeg'>
          <color-distance color='red'>
            <load-image src='/internal-roxen-testimage'/>
          </color-distance>
          <text color='white'>Red</text>
        </gxml>
        <gxml format='jpeg'>
          <color-distance color='green'>
            <load-image src='/internal-roxen-testimage' />
          </color-distance>
          <text color='black'>Green</text>
        </gxml>
        <gxml format='jpeg'>
          <color-distance color='blue'>
            <load-image src='/internal-roxen-testimage' />
          </color-distance>
          <text color='black'>Blue</text>
        </gxml>
      </ex></desc>
      <attr name='layers' value='glob'><p>Layer to work on</p></attr>
      <attr name='layers-id' value='layers-id'><p>Layer to work on</p></attr>
      <attr name='what' values='{image, alpha, both}'><p>
        Whether to work on the alpha channels or image data or both.
      </p></attr>",
    "color" : #"<desc type='both'><p>Clear layer to a given color.</p>
        <ex>
<gxml format='jpeg'>
  <color color='#FF0077'>
    <load-image src='/internal-roxen-testimage' />
  </color>
</gxml>
        </ex>
      </desc>
      <attr name='layers' value='glob'><p>Layer to work on</p></attr>
      <attr name='layers-id' value='layers-id'><p>Layer to work on</p></attr>
      <attr name='what' values='{image, alpha, both}'><p>
        Whether to work on the alpha channels or image data or both.
      </p></attr>
      <attr name='color' value='color' default='black'><p>
        Color to colorize image with.
      </p></attr>",
    "select-from" : #"<desc type='both'><p>Makes an grey-scale image, for 
      alpha-channel use.</p>
      <p>This is very close to a floodfill.</p>
      <ex>
<gxml format='png' true-alpha=''>
   <load-image src='/internal-roxen-testimage' />
   <set-layer-mode mode='multiply'>
    <select-from x='200' y='100' edge-value='150' what='image'>
      <load-image src='/internal-roxen-testimage' />
    </select-from>
  </set-layer-mode>
</gxml>
      </ex></desc>
      <attr name='layers' value='glob'><p>Layer to work on</p></attr>
      <attr name='layers-id' value='layers-id'><p>Layer to work on</p></attr>
      <attr name='what' values='{image, alpha, both}'><p>
        Whether to work on the alpha channels or image data or both.
      </p></attr>
      <attr name='x' value='number'></attr>
      <attr name='y' value='number'><p>Originating pixel in the image</p></attr>
      <attr name='edge-value' value='{0-255}' default='30'><p>
        Tolerance level of how much the current pixels color may different from
        the originating pixel's.</p>
      <ex-html>
        <emit source='values' scope='values'
              values='4,8,16,32,64,128,255' split=','> 
          <gxml format='png' true-alpha=''>
            <select-from x='100' y='100' 
			 edge-value='&values.value;' what='image'>
	      <load-image src='/internal-roxen-testimage' />
	    </select-from>
            <text color='green' 
                  fontsize='16'
                  x='3' y='3'>x: 100, y: 100\nedge-value: &values.value;</text>
          </gxml>
        </emit>
      </ex-html></attr>",
    "expand" : #"<desc type='both'><p>Expand the layer(s) to the size of the
      whole image.</p></desc>
      <attr name='layers' value='glob'><p>Layer to expand.</p></attr>
      <attr name='layers-id' value='layers-id'><p>Layers to expand.</p></attr>",
    "poly" : ({ #"<desc type='cont'><p>Creates a polygone, either as a new layer
      or by modifying the alpha of the given layer(s).</p>
      <ex>
<gxml format='png' true-alpha=''>
  <shadow soft='10'>
    <poly layers='*'>
      <c x='&_.layers.Background.w;/2' y='0' />
      <c x='&_.layers.Background.w;' y='&_.layers.Background.h;/2' />
      <c x='&_.layers.Background.w;/2' y='&_.layers.Background.h;' />
      <c x='0' y='&_.layers.Background.h;/2' />
      <load-image src='/internal-roxen-testimage' />
    </poly>
  </shadow>
</gxml>
      </ex>
      </desc>
      <attr name='layers' value='glob'><p>Layer to work on.</p></attr>
      <attr name='layers-id' value='layers-id'><p>Layer to work on.</p></attr>
      <attr name='name' value='string'><p>Name of the new layer, if a new layer
        is created.</p></attr>
      <attr name='coordinate-system' value='x0,y0-x1,y1'><p>Sets up a coordinate
        system of the same size as the layer it will apply to.</p>
        <ex>
<gxml format='png' true-alpha=''>
  <shadow soft='10'>
    <poly xsize='150' ysize='115' color='orange' coordinate-system='0,0-3,2.5'>
      <c x='0'   y='2.5' />
      <c x='3'   y='2.5' />
      <c x='3'   y='0.9' />
      <c x='2.2' y='0.9' />
      <c x='2.2' y='0'   />
      <c x='1.5' y='0'   />
      <c x='1.5' y='0.9' />
      <c x='1.3' y='0.9' />
      <c x='1.3' y='1.5' />
      <c x='2.2' y='1.5' />
      <c x='2.2' y='1.9' />
      <c x='0.8' y='1.9' />
      <c x='0.8' y='0'   />
      <c x='0'   y='0'   />
    </poly>
    <move-layer x='135' y='100'>
      <poly xsize='15' ysize='15' color='orange' coordinate-system='0,0-1,1'>
        <c x='0' y='0' />
        <c x='1' y='0' />
        <c x='1' y='1' />
        <c x='0' y='1' />
      </poly>
    </move-layer>
  </shadow>
</gxml>
        </ex>
      </attr>
      <attr name='xsize' value='width in pixels'><p>Width of the new layer, 
        if a new layer is created.</p></attr>
      <attr name='ysize' value='height in pixels'><p>Height of the new layer, 
        if a new layer is created.</p></attr>
      <attr name='xoffset' value='px'></attr>
      <attr name='yoffset' value='px'></attr>
      <attr name='color' value='color'><p>Color of the new polygon.</p></attr>
      <attr name='opacity' value='percent'><p>Opacity of the polygon. Will not
        be less than <att>base-opacity</att>.</p></attr>
      <attr name='base-opacity' value='percent'><p>Opacity for the whole layer.
      </p></attr>", ([
      "c" : #"<desc type='tag'><p>Coordinate of a vertex in the polygon.</p>
        </desc>
        <attr name='x' value='number'></attr>
        <attr name='y' value='number'></attr>",
		]),
    }),
    "line" : ({ #"<desc type='cont'><p>Draws a line, either as a new layer
      or by modifying the alpha of the given layer(s).</p>
      <ex>
<gxml format='png' true-alpha=''>
  <shadow soft='10'>
    <line xsize='152' ysize='127' color='orange' width='3'>
      <c x='1'   y='1'   />
      <c x='151' y='1'   />
      <c x='151' y='81'  />
      <c x='111' y='81'  />
      <c x='111' y='126' />
      <c x='76'  y='126' />
      <c x='76'  y='81'  />
      <c x='66'  y='81'  />
      <c x='66'  y='51'  />
      <c x='111' y='51'  />
      <c x='111' y='31'  />
      <c x='41'  y='31'  />
      <c x='41'  y='126' />
      <c x='1'   y='126' />
      <c x='1'   y='1'   />
    </line>
    <line xsize='152' ysize='127' color='orange' width='3'>
       <c x='136' y='111' />
       <c x='151' y='111' />
       <c x='151' y='126' />
       <c x='136' y='126' />
       <c x='136' y='111' />
    </line>
  </shadow>
</gxml>
      </ex>
      </desc>
      <attr name='layers' value='glob'><p>Layer to work on.</p></attr>
      <attr name='layers-id' value='layers-id'><p>Layer to work on.</p></attr>
      <attr name='name' value='string'><p>Name of the new layer, if a new layer
        is created.</p></attr>
      <attr name='coordinate-system' value='x0,y0-x1,y1'><p>Sets up a coordinate
        system of the same size as the layer it will apply to. This is useful
        e.g. if you want to draw graphs</p>
        <ex>
<gxml format='png' true-alpha=''>
  <shadow soft='10'>
    <line color='red' width='3' xsize='600' ysize='150' 
        coordinate-system='2000,0.0-2010,2.0'>
      <c x='2000' y='1.2' />
      <c x='2001' y='1.8' />
      <c x='2002' y='0.8' />
      <c x='2003' y='0.003' />
      <c x='2004' y='0.3' />
      <c x='2005' y='0.5' />
      <c x='2006' y='1.0' />
      <c x='2007' y='0.8' />
      <c x='2008' y='1.3' />
      <c x='2009' y='1.8' />
      <c x='2010' y='2.7' />
    </line>
  </shadow>
</gxml>
        </ex>
      </attr>
      <attr name='xsize' value='width in pixels'><p>Width of the new layer, 
        if a new layer is created.</p></attr>
      <attr name='ysize' value='height in pixels'><p>Height of the new layer, 
        if a new layer is created.</p></attr>
      <attr name='xoffset' value='px'></attr>
      <attr name='yoffset' value='px'></attr>
      <attr name='color' value='color'><p>Color of the new line.</p></attr>
      <attr name='cap' value='{butt, projecting, round}' default='butt'><p>
        Choose which \"cap\" to use when drawing the line. This will what the 
        ends of the line will look like.
        </p><ex>
<gxml format='png' true-alpha='1'>
  <text fontsize='10' x='5' y='3'>Butt:</text>
  <line xsize='220' ysize='120' width='20'  cap='butt' color='red'>
    <c x='15' y='25' />
    <c x='205' y='25' />
  </line>
  <line xsize='220' ysize='120' width='1'  color='black'>
    <c x='15' y='25' />
    <c x='205' y='25' />
  </line>

  <text fontsize='10' x='5' y='38'>Projecting:</text>
  <line xsize='320' ysize='120' width='20'  cap='projecting' color='green'>
    <c x='15' y='60' />
    <c x='205' y='60' />
  </line>
  <line xsize='220' ysize='120' width='1'  color='black'>
    <c x='15' y='60' />
    <c x='205' y='60' />
  </line>
  
  <text fontsize='10' x='5' y='73'>Round:</text>
  <line xsize='220' ysize='120' width='20'  cap='round' color='blue'>
    <c x='15' y='95' />
    <c x='205' y='95' />
  </line>
  <line xsize='220' ysize='120' width='1'  color='white'>
    <c x='15' y='95' />
    <c x='205' y='95' />
  </line>
</gxml>
        </ex>
      </attr>
      <attr name='join' value='{bevel, miter, round}' default='miter'><p>
        How to join several connected lines.</p>
        <ex>
<gxml format='png' true-alpha='1'>
  <text fontsize='10' x='5' y='3'>Bevel:</text>
  <line xsize='80' ysize='80' width='20'  join='bevel' cap='round' color='red'>
    <c x='20' y='30' />
    <c x='50' y='30' />
    <c x='50' y='60' />
  </line>

  <move-layer x='80' absolute=''>
    <text fontsize='10' x='5' y='3'>Miter:</text>
    <line xsize='80' ysize='80' width='20'  join='miter' cap='round' color='green'>
      <c x='20' y='30' />
      <c x='50' y='30' />
      <c x='50' y='60' />
    </line>
  </move-layer> 
  
  <move-layer x='160' absolute=''>
    <text fontsize='10' x='5' y='3'>Round:</text>
    <line xsize='80' ysize='80' width='20'  join='round' cap='round' color='blue'>
      <c x='20' y='30' />
      <c x='50' y='30' />
      <c x='50' y='60' />
    </line>
  </move-layer> 
</gxml>
        </ex>
      </attr>
      <attr name='opacity' value='percent'><p>Opacity of the line. Will not
        be less than <att>base-opacity</att>.
      </p></attr>
      <attr name='base-opacity' value='percent'><p>Opacity for the whole layer.
      </p></attr>", ([
      "c" : #"<desc type='tag'><p>Coordinate of a point in the line.</p>
        </desc>
        <attr name='x' value='number'></attr>
        <attr name='y' value='number'></attr>",
      ]),
    }),
    "coordinate-system" : ({ #"<desc type='cont'><p>Draws a coordinate system
      that can be used to make your own diagrams.</p>
      <ex>
<gxml format='png' true-alpha='' size='layers(coordinate-system*)'>
  <new-layer color='white' xsize='32' ysize='32' tiled='1' />
  <shadow  layers='coordinate-system*' soft='1'>
    <coordinate-system xsize='700' ysize='500'  color='black'>
      <data>
        <y start='1.0' end='2.0'>

        <labels start='1.0' end='2.1' step='0.2' format='%2.1f'
          font='Haru' fontsize='12'  />
        <labels start='1.1' end='2.1' step='0.2' format='%2.1f'
          font='Haru' fontsize='9'  />

        <ticks start='1.0' end='2.0' step='0.01' width='1' length='6' />
        <ticks start='1.0' end='2.0' step='0.1'  width='1'  length='8' />
        <ticks start='1.0' end='2.1' step='0.2'  width='2'  length='10' />
      </y>
  
      <x start='1992' end='2001'>
         <labels start='1992' end='2000' step='1' format='%d'
                 font='Haru' fontsize='12' />
         <ticks start='1992' end='2001.1' step='1/12' width='1' length='6' />
         <ticks start='1992' end='2001.1' step='1/3'  width='1' length='8' />
         <ticks start='1992' end='2001.1' step='1'    width='2' length='10' />
      </x>
      <frame color='darkred' width='2' />
    </data>
   
    <shadow soft='3' xoffse='1' yoffset='3'>
      <line color='orange' xsize='700' ysize='500' width='4'
          coordinate-system='1992,1.0-2001,2.0'>
       <c x='1992'  y='1.0' />
       <c x='1994'  y='1.8' />
       <c x='2000.5'  y='1.2' />
      </line>
   
      <line color='red' xsize='700' ysize='500' width='4'
          coordinate-system='1992,1.0-2001,2.0'>
        <c x='1992'  y='1.5' />
        <c x='1994'  y='1.6' />
        <c x='2000.5'  y='1.8' />
      </line>

      <line color='darkgreen' xsize='700' ysize='500' width='4'
          coordinate-system='1992,1.0-2001,2.0'>
        <c x='1992'  y='1.8' />
        <c x='1998'  y='1.0' />
        <c x='2000.5'  y='1.8' />
      </line>
    </shadow>
    <shadow soft='6'>
      <legend fontsize='12' border='black' bgcolor='white' fgcolor='black' 
              background='100%' square-border='black' font='Haru'>
        <label color='orange'>Sugar</label>
        <label color='red'>Spice</label>
        <label color='darkgreen'>Everything nice</label>
      </legend>
    </shadow>
  </coordinate-system></shadow>
</gxml>
      </ex></desc>
  <attr name='xsize' value='width in pixels' required=''><p>Width of the generated image.</p></attr>
  <attr name='ysize' value='height in pixels' required=''><p>Height of the generated image.</p></attr>
  <attr name='color' value='color' default='black'><p>Set the color for 
    coordinate system and its labels.</p>
    <ex>
<gxml>
  <new-layer color='white' xsize='32' ysize='32' tiled='1' />
  <coordinate-system xsize='30' ysize='30'>
    <data>
      <y start='0.0' end='2.0'>
        <labels start='0.0' end='2.0' step='1' fontsize='10' format='%1.1f'/>
        <ticks  start='0.0' end='2.1' step='1'  width='1'  length='4' />
      </y>
      <x start='0.0' end='2.0'>
        <labels start='0.0' end='2.0' step='1' fontsize='10' format='%d'/>
        <ticks  start='0.0' end='2.1' step='1'  width='1'  length='4' />
      </x>
      <frame width='2' />
    </data>
  </coordinate-system>
</gxml>
    </ex>
  </attr>
  <attr name='mode' value='mode' default='normal'><p>Sets the mode for
    the new layer. See <tag>set-layer-mode</tag>.</p>
  </attr>", ([
    "data" : ({ #"<desc type='cont'><p>Used for tags used to describe the 
      coordinate system.</p></desc>", ([
	"frame" : #"<desc type='tag'><p>Draw a frame for the coordinate
	  system.</p>
          <ex>
<gxml format='png' true-alpha='1'>
  <new-layer xsize='32' ysize='32' color='white' tiled='1' />
  <coordinate-system xsize='200' ysize='100' transparent='1'  >
    <data>
      <frame width='1' color='darkblue' />
      <y start='1' end='16' />
    </data>
  </coordinate-system>
</gxml>
	  </ex></desc>
	  <attr name='width' value='width in pixels' default='2'><p>
	    Width of the frame.
	  </p></attr>
	  <attr name='color' value='color'><p>Color of the frame.
	  </p></attr>
	  <attr name='name' value='name of the layer'
	        default='coordinate-system.frame'><p>Name of the new layer that
	    frame is drawn in.
	  </p></attr>
	  <attr name='mode' value='layer mode'><p>Sets the layer mode.
	  </p></attr>",
	"x" : ({ #"<desc type='cont'><p>Contains tags about how to draw the
	  x-axis.</p></desc>
          <attr name='start' value='number' default='0'><p>
	    Start of the x-axis.
	  </p></attr>
          <attr name='end' value='number' default='1'><p>
	    End of the x-axis.
	  </p></attr>", ([
	    "labels" : #"<desc type='both'><p>Labels to put along the x axis.
              You can either set all your labels yourself in the tag content
	      separated by newlines. The first label will be put at the position
	      of <att>start</att> and then use <att>step</att> to calculate the
              subsequent positions until <att>end</att> is reached.</p>
	      <p>If you don't want to explicitly write all your labels yourself
              then you can use <att>format</att> to automatically generate
	      labels.</p>
              <ex>
<gxml format='png' true-alpha='1'>
  <new-layer color='white' xsize='32' ysize='32' tiled='1' />
  <coordinate-system xsize='400' ysize='300' transparent='1'  fontsize='12' font='Haru'>
    <data>
      <x start='0' end='6'>
        <labels start='0.5' end='4.5' step='1' rotate='90'>
	  Hokkaido Nippon Ham Fighters
	  Fukuoka Softbank Hawks
	  Tohoku Rakuten Golden Eagles
	  Saitama Seibu Lions
	  Orix Buffaloes
        </labels>
        <labels start='5.5' end='6' step='1' color='red' rotate='90'>
	  Chiba Lotte Marines
	</labels>
      </x>
      <y start='1' end='16'>
        <labels start='1' end='16' step='1' format='%1.2f' />
      </y>
      <frame width='2' />
    </data>
  </coordinate-system>
</gxml>
              </ex></desc>
	      <attr name='start' value='number' required=''><p>
		The first number in the sequence of labels along the x-axis.
              </p></attr>
	      <attr name='end' value='number' required=''><p>
		The last number in the sequense of labels along the x-axis.
              </p></attr>
	      <attr name='step' value='number' required=''><p>
		How many steps to do between each number.
              </p></attr>
	      <attr name='format' value='sprintf format'><p>This sets how the
		generated labels should be outputted. It is possible to set how
		many digits should be used and even if you want the output to be
		hexadecimal, octal or binary. The format used is the same as
		used by <xref href='../variable/sprintf.tag' /></p>
		<p>This attribute is required if no content is given to 
		<tag>labels</tag>.</p>
                <ex>
<gxml format='png' true-alpha='1'>
  <new-layer color='white' xsize='32' ysize='32' tiled='1' />
  <coordinate-system xsize='500' ysize='200' font='haru' fontsize='10'>
    <data>
      <frame width='2' />
      <x start='0' end='16'>
        <labels start='1' end='16' step='1' format='0x%02X' />
      </x>
      <y start='0' end='100'>
	<labels start='0' end='100' step='20' format='%d %%' />
      </y>
    </data>
  </coordinate-system>
</gxml>
	      </ex></attr>
	      <attr name='font' value='font'><p>Font to use for the labels.
	      </p></attr>
              <attr name='fontsize' value='fontsize'><p>Fontsize.
	      </p></attr>
              <attr name='rotate' value='degree'><p>Rotate the the label this
		much.
	      </p></attr>
	      <attr name='color' value='color'><p>Color of the labels.
	      </p></attr>",
	    "ticks" : #"<desc type='tag'><p>Draw lines that denote the scale.
	      This tag works in much the same way as <tag>labels</tag>.
              </p>
              <ex>
<gxml format='png' true-alpha='1'>
  <new-layer color='white' xsize='32' ysize='32' tiled='1'/>
  <coordinate-system xsize='400' ysize='300' transparent='1'>
    <data>
      <x start='0' end='100'>
        <ticks start='1' end='100' step='1' width='1' length='6' />
        <ticks start='10' end='101' step='10' width='2' length='10' />
      </x>
      <y start='1' end='16'>
        <ticks start='1' end='16' step='1' width='1' length='6' />
      </y>
      <frame width='2' />
    </data>
  </coordinate-system>
</gxml>
              </ex></desc>
	      <attr name='start' value='number' required=''><p>
		The first position to draw a marker on.
              </p></attr>
	      <attr name='end' value='number' required=''><p>
		The last position to draw markers.
              </p></attr>
	      <attr name='step' value='number' required=''><p>
		How many steps between each marker.
              </p></attr>
	      <attr name='width' value='width in pixels' required=''><p>
		Thickness of the marker.
	      </p></attr>
	      <attr name='lenght' value='lenght in pixels' required=''><p>
		Lenght of the marker.
	      </p></attr>",
		]),
	      }),
	"y" : ({ #"<desc type='cont'><p>Contains tags about how to draw the 
	  y-axis.</p></desc>
          <attr name='start' value='number' default='0'><p>
	    Start of the y-axis.
	  </p></attr>
          <attr name='end' value='number' default='1'><p>
	    End of the y-axis.
	  </p></attr>", ([
	    "labels" : #"<desc type='both'><p>Labels to put along the y-axis.
              This tag works the same as the corresponding tag for 
	      <tag>x</tag>.</p></desc>
	      <attr name='start' value='number' required=''><p>
		The first number in the sequence of labels along the y-axis.
              </p></attr>
	      <attr name='end' value='number' required=''><p>
		The last number in the sequense of labels along the y-axis.
              </p></attr>
	      <attr name='step' value='number' required=''><p>
		How many steps to do between each number.
              </p></attr>
	      <attr name='format' value='sprintf format'><p>This sets how the
		generated labels should be outputted. It is possible to set how
		many digits should be used. The format used is the same as used
		by <xref href='../variable/sprintf.tag' /></p>
		<p>This attribute is required if no content is given to 
		<tag>labels</tag>.</p>
	      </attr>
	      <attr name='font' value='font'><p>Font to use for the labels.
	      </p></attr>
              <attr name='fontsize' value='fontsize'><p>Fontsize.
	      </p></attr>
              <attr name='rotate' value='degree'><p>Rotate the the label this
		much.
	      </p></attr>
	      <attr name='color' value='color'><p>Color of the labels.
	      </p></attr>",
	    "ticks" : #"<desc type='tag'><p>Draw lines that denote the scale.
	      This tag works in much the same way as <tag>labels</tag>.
              </p></desc>
	      <attr name='start' value='number' required=''><p>
		The first position to draw a marker on.
              </p></attr>
	      <attr name='end' value='number' required=''><p>
		The last position to draw markers.
              </p></attr>
	      <attr name='step' value='number' required=''><p>
		How many steps between each marker.
              </p></attr>
	      <attr name='width' value='width in pixels' required=''><p>
		Thickness of the marker.
	      </p></attr>
	      <attr name='lenght' value='lenght in pixels' required=''><p>
		Lenght of the marker.
	      </p></attr>",
	      ]),
	    }),
	  ]),
	}),
      ]),
    }),
    "legend" : ({ #"<desc type='cont'><p>This tag draws a legend which could be
      useful e.g. when drawing diagrams.</p>
      <ex>
<gxml format='png' true-alpha='1'>
  <shadow soft='6'>
    <legend fontsize='12' border='black' bgcolor='white' fgcolor='black' 
	    background='100%'
	    square-border='black' font='Haru'>
      <label color='lightblue'>Mac OS X</label>
      <label color='red'>Red Hat Enterprise Linux</label>
      <label color='darkblue'>Solaris</label>
      <label color='green'>Windows</label>
    </legend>
  </shadow>
</gxml>
      </ex></desc>
      <attr name='columns' value='positive integer' default='2'><p>
	How many columns to use in the legend.
      </p></attr>
      <attr name='bgcolor' value='color' default='white'><p>Background color.
      </p></attr>
      <attr name='fgcolor' value='color' default='black'><p>Text and border
        color.
      </p></attr>
      <attr name='font' value='font name'><p>Font to use.
      </p></attr>
      <attr name='fontsize' value='fontsize'><p>Fontsize.
      </p></attr>
      <attr name='square-border' value='color'><p>Color of the border around
	each color key in the legend.
      </p></attr>
      <attr name='border' value='color'><p>Draws a border around the legend in
	the given color.
      </p></attr>
      <attr name='background' value='percent'><p>Sets opacity of the legend.</p>
      <ex>
<gxml format='png' true-alpha='1'>
  <load-image src='/internal-roxen-squares' tiled='1'/>
    <shadow soft='5' color='white'>
    <legend fontsize='12' border='black' bgcolor='white' text='black' fgcolor='red' 
             background='60%' font='Haru' >
      <label color='lightblue'>Mac OS X</label>
      <label color='red'>Red Hat Enterprise Linux</label>
      <label color='darkblue'>Solaris</label>
      <label color='green'>Windows</label>
    </legend>
   </shadow>
</gxml>
      </ex></attr>
      <attr name='name' value='string' default='values'><p>Set this name of the
	new layer.
      </p></attr>
", ([
      "label" : #"<desc type='cont'><p>Defines a key in the legend.</p></desc>
        <attr name='color'><p>Color of the key.</p></attr>",
	]),
      }),
    ]),
  }),
]);
#endif
