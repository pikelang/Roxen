// This is a roxen module. Copyright © 2001, Roxen IS.
//
#include <module.h>
inherit "module";

constant thread_safe=1;

constant cvs_version = "$Id: gxml.pike,v 1.23 2002/07/03 14:54:26 per Exp $";
constant module_type = MODULE_TAG;
constant module_name = "Graphics: GXML tag";
constant module_doc  = "Provides the tag <tt>&lt;gxml&gt;</tt>.";

roxen.ImageCache the_cache;

void start()
{
  the_cache = roxen.ImageCache( "gxml", generate_image );
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
		 s[0]/2, Roxen.sizetostring(s[1]));
}

mapping(string:LazyImage.LazyImage) images = ([]);
Image.Layer generate_image( mapping a, string hash, RequestID id )
{
  array ll;
  if( !images[ hash ] )
    error( "Oops! This was not what we expected.\n" );

  ll = m_delete(images,hash)->run( );

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
  return Image.lay( ll, e->x0, e->y0, e->x1, e->y1 );
}


mapping find_internal( string f, RequestID id )
{
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


SIMPLE_LI(Gamma);
SIMPLE_LI(Invert);
SIMPLE_LI(Grey);
SIMPLE_LI(Color);
SIMPLE_LI(MirrorX);
SIMPLE_LI(Rotate);
SIMPLE_LI(MirrorY);
SIMPLE_LI(HSV2RGB);
SIMPLE_LI(RGB2HSV);
SIMPLE_LI(Distance);
SIMPLE_LI(SelectFrom);


array(string|RXML.Tag) builtin_tags = gxml_find_builtin_tags();

class TagGXML
{
  inherit RXML.Tag;
  constant name = "gxml";
  constant flags = RXML.FLAG_SOCKET_TAG|RXML.FLAG_DONT_REPORT_ERRORS;

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

  static mapping last_from;
  static array(RXML.Tag) last_result;
  static array(RXML.Tag) gxml_make_tags( function get_plugins )
  {
    mapping from = ([]);
    catch( from = get_plugins() );

    if( from == last_from )
      return last_result;

    array(RXML.Tag) result = ({});
    foreach( indices(from), string tn )
      result += ({ GXTag( tn, from[tn] ) });

    result += builtin_tags;
    
    last_from = from;
    return last_result = result;
  }
  

#define V(X) ("$["+X+"]")
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
    ]);
#undef V

  RXML.TagSet internal;

  class Frame 
  {
    inherit RXML.Frame;
    constant scope_name = "gxml";
    mapping vars = gxml_vars;
    RXML.TagSet additional_tags = internal;

    array do_enter( RequestID id )
    {
      if (!internal)
	additional_tags = internal =
	  RXML.TagSet(this_module(), "gxml",
		      gxml_make_tags( get_plugins ));
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

      mapping aa = args;
      string ind;
      mapping a2 = aa+([]);

      m_delete( a2, "src" );
      m_delete( a2, "align" );
      m_delete( a2, "border" );
      aa->src = query_internal_location()+
	(ind=the_cache->store(({a2,i->hash()}),id));

      a2 = ([]);
      a2->src = aa->src;
      if( aa->align )  a2->align = aa->align;
      if( aa->border ) a2->border = aa->border;

      images[ i->hash() ] = i;
      the_cache->http_file_answer( ind, id );
      if( mapping size = the_cache->metadata( ind, id ) )
      {
	aa->width = size->xsize;
	aa->height = size->ysize;
      }
      m_delete(images,i->hash()); 

      if( !args->url )
	result = Roxen.make_tag( "img", a2, 1 );
      else
	result = a2->src;
    }
  }
}
