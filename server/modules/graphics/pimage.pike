// This is a roxen module. Copyright © 1997 - 2009, Roxen IS.

string cvs_version="$Id$";

#include <module.h>
inherit "module";
inherit "roxenlib";

class Constructors
{
  class Animation
  {
    object img, my_fd;
    string buffer="", oi;
    int toggle;

    void done()
    {
      img = 0; buffer = 0; my_fd = 0;
    }

    int first;
    void draw_image()
    {
      if(!img) return;
      if(strlen(buffer))
      {
	buffer = buffer[my_fd->write(buffer)..];
	return;
      }
      if(!first)
      {
	buffer=img->first_frame();
	if(buffer) buffer = buffer[my_fd->write(buffer)..];
	oi = buffer;
	first++;
	return;
      }
      if(toggle == 1)
      {
	toggle = 0;
	my_fd->set_blocking();
	call_out(my_fd->set_nonblocking,img->anim_delay,
		 lambda(){},draw_image,done);
      } else {
	toggle = 1;
	buffer=img->do_gif_add();
	if(buffer == oi) buffer=0;
	oi = buffer;
	if(buffer) buffer = buffer[my_fd->write(buffer)..];
	else
	{
	  call_out(draw_image, img->anim_delay);
	  buffer="";
	  toggle=0;
	}
      }
    }


    void create(object id, object image)
    {
      my_fd = id->my_fd;
      id->do_not_disconnect = 1;
      img = image;
      buffer="HTTP/1.0 200 Ok\r\nContent-Type: image/gif\r\n\r\n"+
	img->do_gif_begin();
      my_fd->set_nonblocking(lambda(){}, draw_image, done);
    }
  }

  inherit "roxenlib";

  object id;

  class myimage
  {
    float anim_delay;
    function animator;
    object image;
    object alpha;
    mixed state;
    mapping ci;
    array(int) bg;

    object draw(int|void q)
    {
      if(animator) return animator( q, state );
      return image;
    }

    int last_drawn;
    string last_add;

    inherit "html";
    
    string do_gif_add()
    {
      if(time()-last_drawn < (int)anim_delay) return last_add;
      mixed d = draw(0);
      if(d)
      {
	if(objectp(d))
	  last_add = Image.GIF.render_block(d, Image.Colortable(d),0,0,0,25);
	else
	  last_add = d;
	last_drawn = time();
// 	werror("gif_add returned: "+last_add+"\n");
	return last_add;
      }
    }

    string m_gif_begin;
    string do_gif_begin()
    {
      if(m_gif_begin) return m_gif_begin;
      object i = draw(1);
      return m_gif_begin = Image.GIF.header_block(i->xsize(),i->ysize(),
						  Image.Colortable(i));
    }

    string first_frame()
    {
      mixed ff = draw(2);
      if(stringp(ff)) return ff;
      if(!ff) return "";
      return Image.GIF.render_block(ff,Image.Colortable(ff),0,0,0,25);
    }

    string tag(mapping m)
    {
      if(m->notrans) bg=0;
      if(!image) return "<img src=\"$BASE\" alt=\"\" "
		   "align=\""+(m->align||"baseline")+"\" />";
      return ("<img src=\"$BASE\" alt=\"\" width="+
	      image->xsize()+" height="+image->ysize()+" align=\""
	      +(m->align||"baseline")+"\" />");
    }

    mixed handle(object id)
    {
      if(animator)
      {
	Animation(id, this_object());
	return http_pipe_in_progress();
      }
      if(ci) { image=0; return ci; }
#if constant(Image.GIF) && constant(Image.GIF.encode)
      if (alpha)
	return (ci=http_string_answer(Image.GIF.encode_trans(image,alpha),
				      "image/gif"));
      else if (bg)
	return (ci=http_string_answer(Image.GIF.encode_trans(image,@bg),
				      "image/gif"));
      return (ci=http_string_answer(Image.GIF.encode(image), "image/gif"));
#else
      return (ci=http_string_answer(Image.PNG.encode(image), "image/png"));
#endif
    }

    class FunctionCall
    {
      function f; object img;
      mixed `()(mixed ... args)
      {
	mixed res=f(@args);
	return (objectp(res)&&(img->image=res))?img:res;
      }
      void create(function m_f, object m_img)
      {
	f=m_f;
	img=m_img;
      }
    }

    mixed `->(string q)
    {
      function f;
//       trace(1);
      if(image && (f = image[q])) return FunctionCall(f, this_object());
      return predef::`[](this_object(),q);
    }

    void create(mapping(string:object)|array (int) b, void|object i, float|void delay,
		function|void anim,mixed|void st)
    {
      if (mappingp(b)) {
	image = b->image;
	alpha = b->alpha;
      } else {
	bg = b;
	image = i;
      }
      if (delay)
	anim_delay = delay;
      if (anim)
	animator = anim;
      if (st)
	state = st;
    }
  }

  private array (int) to_color(mixed in)
  {
    if(stringp(in)) return parse_color(in);
    return ({ in, in, in });
  }

  class ProgressIMG
  {
    function get_progress;
    int old_progress = -1;

    object draw_progress(object image, mixed state)
    {
      int percent = get_progress(state);
      if(percent != old_progress)
      {
	old_progress=percent;
	object image = Image.Image(302,24,  255, 255, 255), i2;
	object text = (get_font("lucida",32,0,0,0,0.0,0.0)->
		       write(percent==100?"Done":percent+"%")
		       ->scale(0.5));

	image=image->paste_alpha_color(text,0,0,0,
				       (image->xsize()/2-text->xsize()/2),
				       (image->ysize()/2-text->ysize()/2));
	
	i2 = Image.Image(3*percent+3, 28, 0x11,0x33,0x77);
	i2= i2->paste_alpha_color(text,255,255,255,
				  (image->xsize()/2-text->xsize()/2),
				  (image->ysize()/2-text->ysize()/2));
 	image = image->paste(i2);
	return image;
      }
    }

    void create(function cb)
    {
      get_progress = cb;
    }
  }


  class ClockIMG
  {
    object background;
    array foreground;
    int time_offset, len;
    int xs, ys;

    object cursor_h, cursor_m;

    object make_cursor(int len, int hour)
    {
      float w=len*2.0, h=len/5.0, mp, h2, w2;
      if(hour) w*=0.7;
      object c = Image.Image((int)w,(int)h);
      mp = (w2 = w/2.0)+w2/2.0; h2 = h/2.0;
      c->setcolor( 255, 255, 255 );
      c->polygone( ({ w2,h2-2, mp,0, w,h2, mp,h, w2, h2+2, w2-8, h2}));
      c->setcolor( 0, 0, 0 );
      return c->rotate(90);
    }

    void paste_centered(object on, object item)
    {
      on->paste_alpha_color(item->color(80,80,80),
			    0,0,0,xs-item->xsize()/2+1,  ys-item->ysize()/2+3);
      on->paste_alpha_color(item->color(0,30,40),
			    0,0,0,xs-item->xsize()/2-2,  ys-item->ysize()/2);
      on->paste_alpha_color(item,@foreground,xs-item->xsize()/2-1,ys-item->ysize()/2+1);
    }


    object draw()
    {
      mapping lt = localtime(time()+time_offset );
      object new = background->copy();
      lt->min  += lt->sec / 60.0;
      lt->hour += lt->min / 60.0;
      paste_centered(new,cursor_h->rotate(-(lt->hour/12.0)*360.0));
      paste_centered(new,cursor_m->rotate(-(lt->min/60.0)*360.0));
      return new;
    }

#define MIN(x,y) ((x)<(y)?(x):(y))
    void create(int t_offset,object bg,string fg,array(int)|void center, int|void len)
    {
      if(!fg) fg="black";
      foreground = parse_color(fg);
      background = bg;
      time_offset = t_offset;
      if(!center) center = ({ bg->xsize()/2, bg->ysize()/2 });
      if(!len) len = MIN(center[0], center[1]);
      xs = center[0];
      ys = center[1];
      cursor_h = make_cursor(len,1);
      cursor_m = make_cursor(len,0);
    }
  }

  array (int) bg()
  {
    if(id->misc->defines) return parse_color(id->misc->defines->bg);
    return ({ 0xcc, 0xcc, 0xcc });
  }

  object Clock( float|int delay, int offset, object background, string fg,
		int|void xs, int|void ys, int|void len, mixed|void state )
  {
    if(background->image) background = background->image;
    if(xs && !ys)
      len = background->xsize()/2-xs;
    return myimage(bg(),0, (float)delay,
		   ClockIMG(offset,background,fg,xs&&ys?({xs,ys}):0, len)->draw,state);
  }

  object Anim( function cb, float delay, mixed|void state )
  {
    return myimage(bg(),0, delay+0.01, cb, state);
  }

  object Progress( function cb, mixed|void state )
  {
    return myimage(bg(),0, 0.3, ProgressIMG(cb)->draw_progress, state);
  }

  object Text(string font, string text, mixed fg, mixed bg)
  {
    object m = resolve_font( font )->write(text);
    return myimage(bg(),Image.Image(m->xsize(),m->ysize(),@bg)
		   ->paste_alpha_color(m,@to_color(fg)));
  }

  object load( string fname )
  {
    return myimage( bg(), roxen.load_image( fname, id) );
  }

  object load_alpha( string fname )
  {
    return myimage( roxen.low_load_image( fname, id) );
  }

  object PPM(string fname)
  {
    string q = Stdio.read_bytes(fname);
    if(!q) q = id->conf->try_get_file(dirname(id->not_query)+fname,id);
    if(!q) error ("Unknown PPM image '"+fname+"'");
#if constant(Gz)
    mixed g = Gz;
    if (g->inflate) {
      catch {
	q = g->inflate()->inflate(q);
      };
    }
#endif
    return myimage(bg(),Image.ANY.decode(q));
  }

  object Roxen( )
  {
    return load( "roxen-images/roxen.png" );
  }

  object Dial( )
  {
    return load( "roxen-images/urtavla.png" );
  }

  object PImage(int xs, int ys, mixed bgc)
  {
    return myimage(bg(),Image.Image(xs,ys,@to_color(bgc)));
  }

}

mapping compiled = ([]);

constant module_type = MODULE_TAG;
constant module_name = "Graphics: Pike image generator";
constant module_doc  = 
#"Provides two tags, <tt>&lt;gclock&gt;</tt> and <tt>&lt;pimage&gt;</tt>.
<tt>&lt;gclock&gt;</tt> draws animated clocks, while &lt;pimage&gt; draws 
an image from pike-code. 
<p>There are several predefined images-constructors to use within pimage:
<br><tt>Clock( delay, time_offset, background_image );</tt>
Animated clock gif.
<br><tt>Progress( callback_function )</tt>
Animated progress bar.
<br><tt>load( \"file_name\" )</tt>
Loads an image file.
<br><tt>load_alpha( \"file_name\" )</tt>
Loads an image and keeps alpha channel information.
<br><tt>PPM( \"file_name\" )</tt>
Loads an image file (compability method).
<br><tt>PImage(xs, ys, bg_color )</tt>
Create a simple, cleared image
<br><tt>Text( \"font\", \"string\", fg_color, bg_color )</tt>
Draw some text.";

void create()
{
  defvar("pimage", 0, "Enable the <pimage> tag", TYPE_FLAG,
	 "If set, the &lt;pimage&gt; tag will be available for use. This "
	 "tag has the same security implications as the &lt;pike&gt; tag. "
	 "If not set, only the &lt;gclock&gt; tag, which doesn't share these "
	 "security implication, will be available.");
}


mixed find_internal(string f, object id)
{
  return compiled[(int)f]->handle(id);
}

string do_replace(string in, int id)
{
  return replace(in, "$BASE", query_internal_location()+id);
}

object compile(string c, object id)
{
//   werror("compile...\n");
  add_constant("__PRIVATE_TO_PIMAGE_Constructors", Constructors);
  string pre =
    "#include <config.h>\n"
    "#include <roxen.h>\n"
    "inherit __PRIVATE_TO_PIMAGE_Constructors;\n"
    "void create(object i){ id=i; }\n"
    "\n";
  if(search(c, "draw")!=-1) pre += "#0 tag_contents\n" + c;
  else pre += "#0 tag_contents\nobject draw() { "+c+" };";
  return compile_string(pre, "whatever")(id)->draw();
}

string tag_pimage(string t, mapping m, string contents, object rid)
{
  // Hohum. Here we go.
  int id = hash(contents);
  if(!m->nocache && compiled[id]) return do_replace(compiled[id]->tag(m), id);
  return do_replace((compiled[id]=compile(contents, rid))->tag(m), id);
}

constant DANGEROUS_FROM = ({ "\"", "\\" });
constant DANGEROUS_TO   = ({  "", "" });

string tag_glock(string t, mapping m, object rid)
{
  string face;
  if(m->help)
    return ("<b>&lt;gclock [dial=<i>ppm-file</i>]&gt;</b> Draws a graphical clock");
  if(m->dial){ m->face = m->dial; m_delete(m, face); }
  if(!m->face)
    face = "Dial()";
  else
  {
    switch(lower_case(m->face))
    {
     case "default":  face = "Dial()";  break;
     case "roxen":  face = "Roxen()";  break;
     default:
       face = "load(\""+replace(m->face,DANGEROUS_FROM,DANGEROUS_TO)+"\")";
    }
  }
  m_delete(m, "face");

  return tag_pimage("pimage", m,
		    sprintf("object draw() {\n"
			    "  return Clock(30,%d,%s,\"%s\",%d);\n"
			    "}\n",(int)m->offset,face,
			    replace(m->handcolor||"black",
				    DANGEROUS_FROM,DANGEROUS_TO),
			    (int)m->handoffset+50), rid);
}

mapping query_container_callers()
{
  return ([ "pimage":tag_pimage, ]);
}

mapping query_tag_callers()
{
  return ([
    "gclock":tag_glock,
  ]);
}
