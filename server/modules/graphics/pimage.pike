string cvs_version="$Id: pimage.pike,v 1.3 1997/10/05 01:23:26 grubba Exp $";

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

    void draw_image()
    {
      if(!img) return;
      if(strlen(buffer))
      {
	buffer = buffer[my_fd->write(buffer)..];
	return;
      }
      if(toggle == 1)
      {
	toggle = 0;
	my_fd->set_blocking();
	call_out(my_fd->set_nonblocking,img->anim_delay,lambda(){},draw_image,done);
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
      buffer="HTTP/1.0 200 Ok\r\nContent-Type: image/gif\r\n\r\n"+img->do_gif_begin();
      my_fd->set_nonblocking(lambda(){}, draw_image, done);
    }
  }

  inherit Image;
  inherit "roxenlib";

  object id;
  
  class myimage
  {
    inherit "http";
    float anim_delay;
    function animator;
    object image;
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

    string do_gif_add()
    {
      if(time()-last_drawn < (int)anim_delay) return last_add;
      mixed d = draw(0);
      if(d)
      {
	if(objectp(d))
	  last_add = d->gif_add();
	else
	  last_add = d;
	last_drawn = time();
	return last_add;
      }
    }

    string m_gif_begin;
    string do_gif_begin()
    {
      if(m_gif_begin) return m_gif_begin;
      return m_gif_begin=draw(1)->gif_begin();
    }
    
    string tag(mapping m)
    {
      if(m->notrans) bg=0;
      if(!image) return "<img src=\"$BASE\" alt=\"\" "
		   "align=\""+(m->align||"baseline")+"\">";
      return ("<img src=\"$BASE\" alt=\"\" width="+
	      image->xsize()+" height="+image->ysize()+" align=\""
	      +(m->align||"baseline")+"\">");
    }

    mixed handle(object id)
    {
      if(animator)
      {
	Animation(id, this_object());
	return http_pipe_in_progress();
      }
      if(ci) { image=0; return ci; }
      if(bg)
	return (ci=http_string_answer(image->togif(@bg), "image/gif"));
      return (ci=http_string_answer(image->togif(), "image/gif"));
    }

    class FunctionCall
    {
      function f; object img;
      void `()(mixed ... args)
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
      if(image && (f = image[q])) return FunctionCall(f, this_object());
      return this_object()[q];
    }
    
    void create(array (int) b, object i, float|void delay,
		function|void anim,mixed|void st)
    {
      bg = b; animator = anim; state = st; image = i; anim_delay = delay;
    }
  }

  private static array (int) to_color(mixed in)
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
	object image = Image.image(302,24,  255, 255, 255), i2;
	object text = (get_font("lucida",32,0,0,0,0.0,0.0)->
		       write(percent==100?"Done":percent+"%")
		       ->scale(0.5));
      
	image=image->paste_alpha_color(text,0,0,0,
				       (image->xsize()/2-text->xsize()/2),
				       (image->ysize()/2-text->ysize()/2));
	
	i2 = Image.image(3*percent+3, 28, 0x11,0x33,0x77);
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
      object c = Image.image((int)w,(int)h);
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
    object m = get_font(font, 32, 0, 0, 0, 0, 0, 0)->write(text);
    return myimage(bg(),image(m->xsize(),m->ysize(),@bg)
		   ->paste_alpha_color(m,@to_color(fg)));
  }

  object PPM(string fname)
  {
    string q = Stdio.read_bytes(fname);
    if(!q) q = roxen->try_get_file(dirname(id->not_query)+fname,id);
    if(!q) throw("Unknown PPM image '"+fname+"'");
    mixed g = Gz;
    if (g->inflate) {
      catch {
	q = g.inflate()->inflate(q);
      };
    }
    return myimage(bg(),image()->fromppm(q));
  }

  object Roxen( )
  {
    return PPM( "roxen-images/roxen.ppm" );
  }

  object Dial( )
  {
    return PPM( "roxen-images/urtavla.ppm" );
  }
  
  object Image(int xs, int ys, mixed bgc)
  {
    return myimage(bg(),image(xs,ys,@to_color(bgc)));
  }
  
}

mapping compiled = ([]);

array register_module()
{
  return ({ MODULE_LOCATION | MODULE_PARSER,
	      "Pike Image Module",
	      "This module adds a new tag, &lt;pimage&gt;&lt;/pimage&gt;, which "
	      "draws an image from some pike-code. <p> "
	      "There are several predefined images-constructors: <p>"
	      "Clock( delay, background_image ); Animated clock-gif.<br>"
	      "Progress( callback_function ); Animated progress bar.<br>"
	      "PPM( \"file_name\" ); Loads a PPM file.<br>"
	      "Image(xs,ys, bg_color ); Simple (cleared) image<br>"
	      "Text( \"font\", \"string\", fg_color, bg_color ); <br>"
	      "Draws some text..<br>", 0, 1 });
}

void create()
{
  defvar("location", "/pimages/", "Mountpoint", TYPE_LOCATION|VAR_MORE,
	 "The URL-prefix for the pike image module.");
}


mixed find_file(string f, object id)
{
  return compiled[(int)f]->handle(id);
}

string do_replace(string in, int id)
{
  return replace(in, "$BASE", query("location")+id);
}

object compile(string c, object id)
{
  werror("compile...\n");
  add_constant("__PRIVATE_TO_PIMAGE_Constructors", Constructors);
  string pre =
    "#include <config.h>\n"
    "#include <roxen.h>\n"
    "inherit __PRIVATE_TO_PIMAGE_Constructors;\n"
    "void create(object i){ id=i; }\n"
    "\n";
  if(search(c, "draw")) pre += c;
  else pre += "object draw() { "+c+" };";
  return compile_string(pre, roxen->real_file(id->not_query,id))(id)->draw();
}

string tag_pimage(string t, mapping m, string contents, object rid)
{
  // Hohum. Here we go.
  int id = hash(contents);
  if(!m->nocache && compiled[id]) return do_replace(compiled[id]->tag(m), id);
  return do_replace((compiled[id]=compile(contents, rid))->tag(m), id);
}

string query_location() { return query("location"); }

mapping query_container_callers()
{
  return ([ "pimage":tag_pimage, ]);
}
