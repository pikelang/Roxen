// This is a roxen module. Copyright © 1999 - 2000, Roxen IS.
//
#include <module.h>
inherit "module";
//<locale-token project="mod_gxml">_</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_gxml",X,Y)
// end of the locale related stuff

constant thread_safe=1;

constant cvs_version = "$Id: gxml.pike,v 1.2 2001/04/02 10:26:32 per Exp $";
constant module_type = MODULE_TAG;

LocaleString module_name = _(0,"Graphics: GXML Image processing tags");
LocaleString module_doc  = _(0,"Provides the tag <tt>&lt;gxml&gt;</tt>.");

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
  return ([ _(0,"Clear cache"):flush_cache ]);
}

string status() {
  array s=the_cache->status();
  return sprintf(_(0,"<b>Images in cache:</b> %d images<br />\n"
                   "<b>Cache size:</b> %s"),
		 s[0]/2, Roxen.sizetostring(s[1]));
}

mapping(string:LazyImage.LazyImage) images = ([]);
array(Image.Layer) generate_image( mapping a, string hash, RequestID id )
{
  if( images[hash] )
    return m_delete(images,hash)->run( );
  else
    error( "Oops! This was not what we expected.\n" );
}


mapping find_internal( string f, RequestID id )
{
  return the_cache->http_file_answer( f, id );
}

array(RXML.Tag) gxml_find_builtin_tags(  )
{
  return map(glob("GXML*", indices( this_object() )), ::`[])();
}



#define SIMPLE_LI( X )   						\
class GXML##X								\
{									\
  inherit RXML.Tag;							\
  constant name = LazyImage.X.operation_name;	  		        \
									\
  class Frame								\
  {									\
    inherit RXML.Frame;							\
    array do_return( RequestID id )					\
    {									\
        id->misc->gxml_image = LazyImage.new(LazyImage.X,		\
					     id->misc->gxml_image,	\
					     args );			\
    }									\
  }									\
}

#define CONTENT_LI( X,Y )   						\
class GXML##X								\
{									\
  inherit RXML.Tag;							\
  constant name = LazyImage.X.operation_name;	  		        \
									\
  class Frame								\
  {									\
    inherit RXML.Frame;							\
    array do_return( RequestID id )					\
    {									\
      args->Y = content;                                                \
      id->misc->gxml_image = LazyImage.new(LazyImage.X,		        \
					     id->misc->gxml_image,	\
					     args );			\
    }									\
  }									\
}

class GXMLPush
{
  inherit RXML.Tag;
  constant name = "push";

  class Frame
  {
    inherit RXML.Frame;
    array do_enter( RequestID id )
    {
      id->misc->gxml_stack->push( id->misc->gxml_image );
      id->misc->gxml_image = 0;
    }
    array do_return( RequestID id )
    {
      LazyImage.LazyImage i = id->misc->gxml_stack->pop();
      if( id->misc->gxml_image )
	id->misc->gxml_stack->push( id->misc->gxml_image->ref() );
      else
	id->misc->gxml_stack->push( i->ref() );
      id->misc->gxml_image = i;
    }
  }
}

class GXMLDup
{
  inherit RXML.Tag;
  constant name = "dup";

  class Frame
  {
    inherit RXML.Frame;
    array do_return( RequestID id )
    {
      LazyImage.LazyImage i = id->misc->gxml_stack->pop();
      id->misc->gxml_stack->push( i );
      id->misc->gxml_stack->push( i );
    }
  }
}

class GXMLClear
{
  inherit RXML.Tag;
  constant name = "clear";

  class Frame
  {
    inherit RXML.Frame;
    array do_return( RequestID id )
    {
      id->misc->gxml_image = 0;
    }
  }
}

class GXMLClearStack
{
  inherit RXML.Tag;
  constant name = "clear-stack";

  class Frame
  {
    inherit RXML.Frame;
    array do_return( RequestID id )
    {
      id->misc->gxml_stack->reset();
    }
  }
}

class GXMLPop
{
  inherit RXML.Tag;
  constant name = "pop";

  class Frame
  {
    inherit RXML.Frame;

    array do_enter( RequestID id )
    {
      catch
      {
	LazyImage.LazyImage i = id->misc->gxml_image ;
	id->misc->gxml_image  = id->misc->gxml_stack->pop();
	id->misc->gxml_stack->push( i );
	return 0;
      };
      RXML.parse_error("Popping beyond end of stack\n");
    }
    
    array do_return( RequestID id )
    {
      LazyImage.LazyImage b = id->misc->gxml_stack->pop();
      id->misc->gxml_image = LazyImage.join_images(b,id->misc->gxml_image);
      return 0;
    }
  }
}

class GXMLPopDup
{
  inherit RXML.Tag;
  constant name = "pop-dup";

  class Frame
  {
    inherit RXML.Frame;

    array do_enter( RequestID id )
    {
      catch
      {
	LazyImage.LazyImage i = id->misc->gxml_image;
	id->misc->gxml_image  = id->misc->gxml_stack->pop();
	id->misc->gxml_stack->push( id->misc->gxml_image );
	id->misc->gxml_stack->push( i );
	return 0;
      };
      RXML.parse_error("Popping beyond end of stack\n");
    }
    
    array do_return( RequestID id )
    {
      LazyImage.LazyImage b = id->misc->gxml_stack->pop();
      id->misc->gxml_image = LazyImage.join_images(b,id->misc->gxml_image);
      return 0;
    }
  }
}

class GXMLPopReplace
{
  inherit RXML.Tag;
  constant name = "pop-replace";

  class Frame
  {
    inherit RXML.Frame;
    array do_return( RequestID id )
    {
      catch
      {
	id->misc->gxml_image = id->misc->gxml_stack->pop();
	return 0;
      };
      RXML.parse_error("Popping beyond end of stack\n");
    }
  }
}

CONTENT_LI(Text,text);

SIMPLE_LI(LoadImage);
SIMPLE_LI(SelectLayers);
SIMPLE_LI(ReplaceAlpha);
SIMPLE_LI(SetLayerMode);
SIMPLE_LI(MoveLayer);
SIMPLE_LI(NewLayer);

array(string|RXML.Tag) builtin_tags = gxml_find_builtin_tags();

class TagGXML
{
  inherit RXML.Tag;
  constant name = "gxml";
  constant flags = RXML.FLAG_SOCKET_TAG;

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
      flags=parent->flags;
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
  

  class Frame 
  {
    inherit RXML.Frame;

    RXML.TagSet additional_tags=RXML.TagSet("TagGXML.internal",
					    gxml_make_tags( get_plugins ));


    array do_enter( RequestID id )
    {
      if( id->misc->gxml_image )
	RXML.parse_error("Recursive gxml tags not supported\n" );
      id->misc->gxml_stack = ADT.Stack();
    }

    array do_return( RequestID id )
    {
      // The image is now in id->misc->gxml_image, hopefully.
      LazyImage.LazyImage i = id->misc->gxml_image;

      werror("%O\n", i->run() );
      
      if( !i ) RXML.parse_error( "No image\n");

      mapping aa = args;
      string ind;
      mapping a2 = aa+([]);

      m_delete( a2, "src" );
      m_delete( a2, "align" );
      m_delete( a2, "border" );
      aa->src = query_internal_location()+
	(ind=the_cache->store(({a2,i->hash()}),id));
      images[ i->hash() ] = i;

      a2 = ([]);
      a2->src = aa->src;
      if( aa->align )  a2->align = aa->align;
      if( aa->border ) a2->border = aa->border;

      if( mapping size = the_cache->metadata( ind, id ) )
      {
	aa->width = size->xsize;
	aa->height = size->ysize;
      }
      if( !args->url )
	result = Roxen.make_tag( "img", a2, 1 );
      else
	result = a2->src;

      m_delete( id->misc, "gxml_stack" );
      m_delete( id->misc, "gxml_image" );
    }
  }
}
