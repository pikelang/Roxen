// This is a ChiliMoon module. Copyright © 2001, Roxen IS.
//
#include <module.h>
#include <stat.h>
inherit "module";

constant thread_safe=1;

constant cvs_version = "$Id: gxml.pike,v 1.29 2004/06/04 08:33:17 _cvs_stephen Exp $";
constant module_type = MODULE_TAG;
constant module_name = "Graphics: GXML tag";
constant module_doc  = "Provides the tag <tt>&lt;gxml&gt;</tt>.";

core.ImageCache the_cache;

void start()
{
  the_cache = core.ImageCache( "gxml", generate_image );
}

void flush_cache() {
  the_cache->flush();
}

mapping(string:function) query_action_buttons()
{
  return ([ "Clear cache":flush_cache ]);
}

string status() {
  array s=the_cache->status();
  return sprintf( "<b>Images in cache:</b> %d images<br />\n"
		  "<b>Cache size:</b> %s",
		 s[0], String.int2size(s[1]));
}

Image.Layer generate_image( mapping a, mapping node_tree, RequestID id )
{
  LazyImage.clear_cache();
  LazyImage.LazyImage image = LazyImage.decode(node_tree);
  array ll = image->run(0, id);
  LazyImage.clear_cache();
  
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
  return the_cache->http_file_answer( f, id );
}

array(RXML.Tag) gxml_find_builtin_tags(  )
{
  return map(glob("GXML*", indices( this )), ::`[])();
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
  return res[..sizeof(res)-2];
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

static class InternalTagSet
{
  inherit RXML.TagSet;

  static class GXTag
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

  static array(RXML.Tag) gxml_make_tags()
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

  static int in_changed = 0;

  void changed()
  {
    if (in_changed) return;
    in_changed = 1;
    clear();
    add_tags (gxml_make_tags());
    in_changed = 0;
    ::changed();
  }

  static void create()
  {
    ::create (this_module(), "gxml");
    changed();
  }
}

static RXML.TagSet internal_tag_set = InternalTagSet();

class TagGXML
{
  inherit RXML.Tag;
  constant name = "gxml";
  constant flags = RXML.FLAG_SOCKET_TAG|RXML.FLAG_DONT_REPORT_ERRORS;

#define V(X) ("$["+X+"]")
  class LayersVars
  {
    inherit RXML.Scope;
    mixed `[] (string var, void|RXML.Context ctx,
	       void|string scope_name, void|RXML.Type type)
    {
      string scope;
      if (sscanf(scope_name, "%*s.layers.%s", scope) == 2)
	return V("layers."+scope+"."+var);
      return this;
    }
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
	"top":V("image.r"),   "t":V("image.t"),
	"width":V("image.w"), "w":V("image.w"),
	"height":V("image.h"),"h":V("image.h"),
      ]),
      "layer":([
	"left":V("layer.l"),  "l":V("layer.l"),
	"right":V("layer.r"), "r":V("layer.r"),
	"top":V("layer.r"),   "t":V("layer.t"),
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

      mapping res_args = args - my_args;
      mapping node_tree = i->encode();
      // werror("Node tree: %O\n", node_tree);
      string key = the_cache->store( ({ my_args, node_tree }), id);
      res_args->src = query_internal_location() + key;
      int no_draw = !id->misc->generate_images;
      if( mapping size = the_cache->metadata( key, id, no_draw ) )
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
