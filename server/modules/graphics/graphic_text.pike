constant cvs_version="$Id: graphic_text.pike,v 1.190 1999/11/28 02:52:24 nilsson Exp $";
constant thread_safe=1;

#include <config.h>
#include <module.h>
#include <stat.h>
inherit "module";
inherit "roxenlib";

#ifndef VAR_MORE
#define VAR_MORE	0
#endif /* VAR_MORE */


// ------------------- Module registration ---------------------

array register_module()
{
  return ({ MODULE_PARSER,
	    "Graphics text",
	    "Generates graphical texts.",
	    0, 1
         });
}

void create()
{
  defvar("colorparse", 1, "Parse tags for document colors", TYPE_FLAG,
	 "If set, parse the specified tags for document colors.");

  defvar("colorparsing", ({"body", "td", "layer", "ilayer", "table"}),
	 "Tags to parse for color",
	 TYPE_STRING_LIST,
	 "Which tags should be parsed for document colors? "
	 "This will affect documents without gtext as well as documents "
	 "with it, the parsing time is relative to the number of parsed "
	 "tags in a document. You have to reload this module or restart "
	 "roxen for changes of this variable to take effect.", 0,
	 lambda(){return !query("colorparse");});

  defvar("colormode", 1, "Normalize colors in parsed tags", TYPE_FLAG,
	 "If set, replace 'roxen' colors (@c,m,y,k etc) with "
	 "'netscape' colors (#rrggbb). Setting this to off will lessen the "
	 "performance impact of the 'Tags to parse for color' option quite"
	 " dramatically. You can try this out with the &lt;gauge&gt; tag.",
	 0,  lambda(){return !query("colorparse");});

  defvar("deflen", 300, "Default maximum text-length", TYPE_INT|VAR_MORE,
	 "The module will, per default, not try to render texts "
	 "longer than this. This is a safeguard for things like "
	 "&lt;gh1&gt;&lt;/gh&gt;, which would otherwise parse the"
	 " whole document. This can be overrided with maxlen=... in the "
	 "tag.");

  defvar("ext", 0, "Append .fmt (gif, jpeg etc) to all images",
	 TYPE_FLAG|VAR_MORE,
	 "Append .gif, .png, .gif etc to all images made by gtext. "
         "Normally this will only waste bandwidth");
}


// ------------------- The actual graphics routines ----------------------

#define MAX(a,b) ((a)<(b)?(b):(a))
#define MIN(a,b) ((a)<(b)?(a):(b))

static private mapping (int:array(array(int))) matrixes = ([]);
array (array(int)) make_matrix(int size)
{
  if(matrixes[size]) return matrixes[size];
  array res;
  int i;
  int j;
  res = allocate(size, allocate)(size);
  for(i=0; i<size; i++)
    for(j=0; j<size; j++)
      res[i][j] = (int)MAX((float)size/2.0-sqrt((size/2-i)*(size/2-i) + (size/2-j)*(size/2-j)),0);
  return matrixes[size] = res;
}

object blur(object img, int amnt)
{
  img->setcolor(0,0,0);
  img = img->autocrop(amnt, 0,0,0,0, 0,0,0);

  for(int i=0; i<amnt; i++)
    img = img->apply_matrix( make_matrix((int)sqrt(img->ysize()+20)));
  return img;
}

object outline(object on, object with,
		       array (int) color, int radie, int x, int y)
{
  int steps=10;
  for(int j=0; j<=steps; j++)
    on->paste_alpha_color(with, @color,
			  (int)(0.5+x-(sin((float)j/steps*3.145*2)*radie)),
			  (int)(0.5+y-(cos((float)j/steps*3.145*2)*radie)));
  return on;
}

constant white = ({ 255,255,255 });
constant lgrey = ({ 200,200,200 });
constant grey = ({ 128,128,128 });
constant black = ({ 0,0,0 });
constant wwwb = ({ lgrey,lgrey,grey,black });

object bevel(object in, int width, int|void invert)
{
  int h=in->ysize();
  int w=in->xsize();

  object corner = Image.Image(width+1,width+1);
  object corner2 = Image.Image(width+1,width+1);
  object pix = Image.Image(1,1);

  for(int i=-1; i<=width; i++) {
    corner->line(i,width-i,i,-1, @white);
    corner2->setpixel(width-i, width-i, @white);
    in->paste_alpha(pix, 185, w - width + i+1, h - width + i+1);
  }

  if(!invert)
  {
    in->paste_alpha(Image.Image(width,h-width*2,@white), 160, 0, width);
    in->paste_alpha(Image.Image(width,h-width*2,@black), 128, in->xsize()-width, width);
    in->paste_alpha(Image.Image(w-width,width,@white), 160, 0, 0);
    in->paste_alpha(Image.Image(w-width,width,@black), 128, width, in->ysize()-width);
  } else  {
    corner=corner->invert();
    corner2=corner2->invert();
    in->paste_alpha(Image.Image(width,h-width*2,@black), 160, 0, width);
    in->paste_alpha(Image.Image(width,h-width*2,@white), 128, in->xsize()-width, width);
    in->paste_alpha(Image.Image(w-width,width,@black), 160, 0, 0);
    in->paste_alpha(Image.Image(w-width,width,@white), 128, width, in->ysize()-width);
  }

  in->paste_mask(corner, corner->color(95,95,95), in->xsize()-width,-1);
  in->paste_mask(corner, corner->invert()->color(128,128,128),
		 in->xsize()-width,-1);
  in->paste_mask(corner, corner->color(95,95,95), -1, in->ysize()-width);
  in->paste_mask(corner, corner->invert()->color(128,128,128),
                 -1, in->ysize()-width);
  corner=0;
  in->paste_mask(corner2, corner2->color(70,70,70), -1, -1);

  corner2 = pix = 0;
  return in;
}

object make_text_image(mapping args, object font, string text, RequestID id)
{
  if( args->encoding )
    text = roxen.decode_charset(args->encoding,text);
  object text_alpha=font->write(@(text/"\n"));
  int xoffset=0, yoffset=0;

  if(!text_alpha->xsize() || !text_alpha->ysize())
    text_alpha = Image.Image(10,10, 0,0,0);

  if(int op=((((int)args->opaque)*255)/100)) // Transparent text...
    text_alpha=text_alpha->color(op,op,op);

  int txsize=text_alpha->xsize();
  int tysize=text_alpha->ysize(); // Size of the text, in pixels.

  int xsize=txsize; // image size, in pixels
  int ysize=tysize;

  if(args->bevel)
  {
    xoffset += (int)args->bevel;
    yoffset += (int)args->bevel;
    xsize += ((int)args->bevel)*2;
    ysize += ((int)args->bevel)*2;
  }

  if(args->spacing)
  {
    xoffset += (int)args->spacing;
    yoffset += (int)args->spacing;
    xsize += ((int)args->spacing)*2;
    ysize += ((int)args->spacing)*2;
  }

  if(args->yspacing)
  {
    yoffset += (int)args->yspacing;
    ysize += ((int)args->yspacing)*2;
  }

  if(args->shadow)
  {
    xsize+=((int)(args->shadow/",")[-1])+2;
    ysize+=((int)(args->shadow/",")[-1])+2;
  }

  if(args->bshadow)
  {
    xsize+=(int)args->bshadow+3;
    ysize+=(int)args->bshadow+3;
  }

  if(args->fadein)
  {
    xsize+=6;
    ysize+=6;
    xoffset+=3;
    yoffset+=3;
  }

  if(args->move)
  {
    int dx,dy;
    sscanf(args->move, "%d,%d", dx, dy);
    xoffset += dx;
    yoffset += dy;
  }

  if(args->ghost)
  {
    int howmuch=(int)args->ghost;
    xsize+=howmuch*2+10;
    xoffset += 3;
    ysize+=howmuch*2+10;
  }

  if(args->xspacing)
  {
    xoffset += (int)args->xspacing;
    xsize += ((int)args->xspacing)*2;
  }

  if(args->border)
  {
    xoffset += (int)args->border;
    yoffset += (int)args->border;
    xsize += ((int)args->border)*2;
    ysize += ((int)args->border)*2;
  }

  array (int) bgcolor = parse_color(args->bg);
  array (int) fgcolor = parse_color(args->fg);

  object background,foreground;

  if(args->texture)
  {
    object t = roxen.load_image(args->texture,id);
    if( t )
    {
      foreground = t;
      if(args->tile)
      {
	object b2 = Image.Image(xsize,ysize);
	for(int x=0; x<xsize; x+=foreground->xsize())
	  for(int y=0; y<ysize; y+=foreground->ysize())
	    b2->paste(foreground, x, y);
	foreground = b2;
      } else if(args->mirrortile) {
	object b2 = Image.Image(xsize,ysize);
	object b3 = Image.Image(foreground->xsize()*2,foreground->ysize()*2);
	b3->paste(foreground,0,0);
	b3->paste(foreground->mirrorx(),foreground->xsize(),0);
	b3->paste(foreground->mirrory(),0,foreground->ysize());
	b3->paste(foreground->mirrorx()->mirrory(),foreground->xsize(),
		  foreground->ysize());
	foreground = b3;
	for(int x=0; x<xsize; x+=foreground->xsize())
	{
	  for(int y=0; y<ysize; y+=foreground->ysize())
	    if(y%2)
	      b2->paste(foreground->mirrory(), x, y);
	    else
	      b2->paste(foreground, x, y);
	  foreground = foreground->mirrorx();
	}
	foreground = b2;
      }
    } else
      werror("Failed to load image for "+args->texture+"\n");
  }
  int background_is_color;
  if(args->background &&
     ((background = roxen.load_image(args->background, id)) ||
      (sizeof(args->background)>1 &&
       (background=Image.Image(xsize,ysize,
                               @(parse_color(args->background[1..]))))
       && (background_is_color=1))))
  {
    object alpha;
    if(args->alpha && (alpha = roxen.load_image(args->alpha,id)) && background_is_color)
    {
      xsize=MAX(xsize,alpha->xsize());
      ysize=MAX(ysize,alpha->ysize());
      if((float)args->scale)
	alpha=alpha->scale(1/(float)args->scale);
      background=Image.Image(xsize,ysize, @(parse_color(args->background[1..])));
    }

    if((float)args->scale >= 0.1 && !alpha)
      background = background->scale(1.0/(float)args->scale);

    if(args->tile)
    {
      object b2 = Image.Image(xsize,ysize);
      for(int x=0; x<xsize; x+=background->xsize())
	for(int y=0; y<ysize; y+=background->ysize())
	  b2->paste(background, x, y);
      background = b2;
    } else if(args->mirrortile) {
      object b2 = Image.Image(xsize,ysize);
      object b3 = Image.Image(background->xsize()*2,background->ysize()*2);
      b3->paste(background,0,0);
      b3->paste(background->mirrorx(),background->xsize(),0);
      b3->paste(background->mirrory(),0,background->ysize());
      b3->paste(background->mirrorx()->mirrory(),background->xsize(),
		background->ysize());
      background = b3;
      for(int x=0; x<xsize; x+=background->xsize())
      {
	for(int y=0; y<ysize; y+=background->ysize())
	  if(y%2)
	    b2->paste(background->mirrory(), x, y);
	  else
	    b2->paste(background, x, y);
	background = background->mirrorx();
      }
      background = b2;
    }
    xsize = MAX(xsize,background->xsize());
    ysize = MAX(ysize,background->ysize());

    if(alpha)
      background->paste_alpha_color(alpha->invert(),@bgcolor);

    switch(lower_case(args->talign||"left")) {
    case "center":
      xoffset = (xsize/2 - txsize/2);
      yoffset = (ysize/2 - tysize/2);
      break;
    case "right":
      xoffset = (xsize - txsize);
      break;
    case "left":
    }
  } else
    background = Image.Image(xsize, ysize, @bgcolor);

  if(args->border)
  {
    int b = (int)args->border;
    background->setcolor(@parse_color((args->border/",")[-1]));

    for(--b;b>=0;b--)
    {
      // upper left -- upper right
      background->line(b,b, xsize-b-1, b);
      // lower left -- lower right
      background->line(b,ysize-b-1, xsize-b-1, ysize-b-1);
      // upper left -- lower left
      background->line(b,b,   b, ysize-b-1);
      // upper right -- lower right
      background->line(xsize-b-1,b, xsize-b-1, ysize-b-1);
    }
  }

  background->setcolor(@bgcolor);

  int xs=background->xsize(), ys=background->ysize();

  if( args->rescale )
  {
    xs = txsize;
    ys = tysize;
  }

  if(args->size) { xs=(int)args->size; ys=(int)(args->size/",")[-1]; }
  if(args->xsize) xs=(int)args->xsize;
  if(args->ysize) ys=(int)args->ysize;

  if( xs != background->xsize() ||
      ys != background->ysize() )
  {
    if(!args->rescale)
      background = background->copy(0,0,xs-1,ys-1);
    else
      background = background->scale(xs, ys);
  }

  if(args->turbulence)
  {
    array (float|array(int)) arg=({});
    foreach((args->turbulence/";"),  string s)
    {
      array q= s/",";
      if(sizeof(q)<2) args+=({ ((float)s)||0.2, ({ 255,255,255 }) });
      arg+=({ ((float)q[0])||0.2, parse_color(q[1]) });
    }
    background=background->turbulence(arg);
  }

  if(args->bevel)
    background = bevel(background,(int)args->bevel,!!args->pressed);

  if(args->textbox) // Draw a text-box on the background.
  {
    int alpha,border;
    string bg;
    alpha = (int)args->textbox;
    sscanf(args->textbox, "%*[^,],%s", bg);
    sscanf(bg,"%s,%d", bg,border);
    background->paste_alpha(Image.Image(txsize+border*2,tysize+border*2,
				  @parse_color(bg)),
			    255-(alpha*255/100),xoffset-border,yoffset-border);
  }

  if(args->ghost)
  { // Francesco..
    array(string) a = (args->ghost/",");
    if (sizeof(a) < 2) {
      // Bad argument.
    } else {
      int sdist = (int)(a[0]);
      int bl=(int)(a[1]);
      array(int)clr=parse_color(a[-1]);
      int j;
      object ta = text_alpha->copy();
      for (j=0;j<bl;j++)
	ta=ta->apply_matrix(({
	  ({6,7,7,7,6}),({7,8,8,8,7}),({7,8,8,8,7}),({7,8,8,8,7}),({6,7,7,7,6})
	}));
      background->paste_alpha_color(ta,@clr,xoffset+sdist,yoffset+sdist);
      fgcolor=bgcolor;
    }
  }

  if(args->shadow)
  {
    int sd = ((int)args->shadow+10)*2;
    int sdist = ((int)(args->shadow/",")[-1])+2;
    object ta = text_alpha->copy();
    ta = ta->color(256-sd,256-sd,256-sd);
    array sc = parse_color(args->scolor||"black");
    background->paste_alpha_color(ta,sc[0],sc[1],sc[2],
				  xoffset+sdist,yoffset+sdist);
  }

  if(args->bshadow)
  {
    int sdist = (int)(args->bshadow)+1;
    int xs,ys;
    xs = text_alpha->xsize()+sdist*2+4;
    ys = text_alpha->ysize()+sdist*2+4;
    object ta = Image.Image(xs+sdist*2,ys+sdist*2);
    array sc = parse_color(args->scolor||"black");

    ta->paste_alpha_color(text_alpha,255,255,255,sdist,sdist);
    ta = blur(ta, MIN((sdist/2),1))->color(256,256,256);

    background->paste_alpha_color(ta,sc[0],sc[1],sc[2],
				  xoffset+sdist,yoffset+sdist);
  }

  if(args->glow)
  {
    int amnt = (int)(args->glow/",")[-1]+2;
    array (int) blurc = parse_color((args->glow/",")[0]);
    background->paste_alpha_color(blur(text_alpha, amnt),@blurc,
				  xoffset-amnt, yoffset-amnt);
  }

  if(args->chisel)
    foreground=text_alpha->apply_matrix(({ ({8,1,0}),
					   ({1,0,-1}),
					   ({0,-1,-8}) }),
					128,128,128, 15 )
      ->color(@fgcolor);

  if(!foreground)  foreground=Image.Image(txsize, tysize, @fgcolor);
  if(args->textscale)
  {
    string c1="black",c2="black",c3="black",c4="black";
    sscanf(args->textscale, "%s,%s,%s,%s", c1, c2, c3, c4);
    foreground->tuned_box(0,0, txsize,tysize,
			  ({parse_color(c1),parse_color(c2),parse_color(c3),
			      parse_color(c4)}));
  }
  if(args->outline)
    outline(background, text_alpha, parse_color((args->outline/",")[0]),
	    ((int)(args->outline/",")[-1])+1, xoffset, yoffset);

  if(args->textbelow)
  {
    array color = parse_color(args->textbelow);

    background->setcolor( @color );
    int oby = background->ysize();
    background = background->copy(0,0,
				  max(background->xsize()-1,
				      foreground->xsize()-1),
				  background->ysize()-1
				  +foreground->ysize());
    background->paste_mask( foreground, text_alpha,
			    (background->xsize()-foreground->xsize())/2,
			    oby );
  } else
    background->paste_mask(foreground, text_alpha, xoffset, yoffset);

  foreground = text_alpha = 0;

  if(args->rotate)
  {
    string c;
    if(sscanf(args->rotate, "%*d,%s", c)==2)
       background->setcolor(@parse_color(c));
    else
       background->setcolor(@bgcolor);
    background = background->rotate((float)args->rotate);
  }

  if(args->crop) background = background->autocrop();
  return background;
}


// -------------------- Image cache functions --------------------

roxen.ImageCache image_cache;

void start(int|void val, object|void conf)
{
  image_cache = roxen.ImageCache( "gtext", draw_callback );
}

constant nbsp = iso88591["&nbsp;"];
constant replace_from = indices( iso88591 )+ ({"&ss;","&lt;","&gt;","&amp;",});
constant replace_to   = values( iso88591 ) + ({ nbsp, "<", ">", "&", });

#define simplify_text( from ) replace(from,replace_from,replace_to)

mixed draw_callback(mapping args, string text, RequestID id)
{
  array err;
  mixed data;
  int elapsed;
  string orig_text = text;
  object img;

  if( objectp( text ) )
  {
    if( !args->text )
      error("Failed miserably to find a text to draw. That's not"
	    " good.\n");
    id = (object)text;
    text = args->text;
  }

  if(!args->verbatim) // typographically correct...
  {
    text = replace(text, nbsp, " ");
    text = simplify_text( text );
    string res="",nspace="",cspace="";
    foreach(text/"\n", string line)
    {
      cspace="";nspace="";
      foreach(line/" ", string word)
      {
        string nonum;
        if(strlen(word) &&
           (nonum = replace(word,
                            ({"1","2","3","4","5","6","7","8","9","0","."}),
                            ({"","","","","","","","","","",""}))) == "") {
          cspace=nbsp+nbsp;
          if((strlen(word)-strlen(nonum)<strlen(word)/2) &&
             (upper_case(word) == word)) {
            word=((word/"")*nbsp);
          }
        } else if(cspace!="") {
          cspace=" ";
        }
        res+=(nspace==cspace?nspace:" ")+word;

        if(cspace!="")   nspace=cspace;
        else    	   nspace=" ";
      }
      res+="\n";
    }
    text=replace(res[..strlen(res)-2], ({"!","?",": "}),({ nbsp+"!",nbsp+"?",nbsp+": "}));
    text=replace(replace(replace(text,({". ",". "+nbsp}),
                                 ({"\000","\001"})),".","."+nbsp+nbsp),
                 ({"\000","\001"}),({". ","."+nbsp}));
  }

  if( args->afont )
    data = resolve_font(args->afont+" "+(args->font_size||32));
  else
  {
    if(!args->nfont) args->nfont = args->font;
    int bold, italic;
    if(args->bold) bold=1;
    if(args->light) bold=-1;
    if(args->black) bold=2;
    if(args->italic) italic=1;
    data = get_font(args->nfont||"default",
                    (int)args->font_size||32,bold,italic,
                    lower_case(args->talign||"left"),
                    (float)(int)args->xpad, (float)(int)args->ypad);
  }

  if (!data)
    error("gtext: No font!\n");

  // Fonts and such are now initialized.
  img = make_text_image(args,data,text,id);

  // Now we have the image in 'img', or nothing.

  if( !args->scroll && !args->fadein )
  {
    if(!args->notrans)
    {
      array (int) bgcolor = parse_color(args->bg);
      object alpha;
      alpha = img->distancesq( @bgcolor );
      alpha->gamma( 8 );
      return ([ "img":img, "alpha":alpha ]);
    }
    return img;
  }

  if(args->fadein)
  {
    int amount=2, steps=10, delay=10, initialdelay=0, ox;
    string res = img->gif_begin();
    sscanf(args->fadein,"%d,%d,%d,%d", amount, steps, delay, initialdelay);
    if(initialdelay)
    {
      object foo=Image.Image(img->xsize(),img->ysize(),@parse_color(args->bg));
      res += foo->gif_add(0,0,initialdelay);
    }
    for(int i = 0; i<(steps-1); i++)
    {
      object foo=img->clone();
      foo = foo->apply_matrix(make_matrix(( (int)((steps-i)*amount))));
      res += foo->gif_add(0,0,delay);
    }
    res+= img->gif_add(0,0,delay);
    res += img->gif_end();
    data = ({ res, ({ img->xsize(), img->ysize() }) });
  }
  else
  {
    int len=100, steps=30, delay=5, ox;
    string res = img->gif_begin() + img->gif_netscape_loop();
    sscanf(args->scroll, "%d,%d,%d", len, steps, delay);
    img=img->copy(0,0,(ox=img->xsize())+len-1,img->ysize()-1);
    img->paste(img, ox, 0);
    for(int i = 0; i<steps; i++)
    {
      int xp = i*ox/steps;
      res += img->copy(xp, 0, xp+len, img->ysize(),
                       @parse_color(args->bg))->gif_add(0,0,delay);
    }
    res += img->gif_end();
    data = ({ res, ({ len, img->ysize() }) });
  }

  return
  ([
    "data":data[0],
    "meta":
    ([
      "xsize":data[1][0],
      "ysize":data[1][1],
      "type":(args->format?id->conf->type_from_filename("x."+args->format):"image/gif"),
    ])
  ]);
}

mapping find_internal(string f, object rid)
{
  if( strlen(f)>4 && query("ext") && f[-4]=='.') // Remove .ext
    f = f[..strlen(f)-5];
  if( strlen(f) && f[0]=='$' )
  {
    array id_text = f/"/";
    if( sizeof(id_text)==2 )
    {   // It's a gtext-id
      string second_key = roxen->argcache->store( (["":id_text[1]]) );
      return image_cache->http_file_answer( id_text[0][1..] +"$"+ second_key, rid );
    }
  }
  return image_cache->http_file_answer( f, rid );
}


// -------------- helpfunctions to gtext tags and containers -----------------

constant filearg=({"background","texture","magic-texture","magic-background","magic-bg","alpha"});
constant textarg=({"afont",
		   "alpha",
		   "bevel",
		   "bg",
		   "black",
		   "bold",
		   "border",
		   "bshadow",
		   "chisel",
		   "crop",
		   "encoding",
		   "fadein",
		   "fg",
		   "fs",
		   "font",
		   "font_size",
                   "format",
		   "ghost",
		   "glow",
		   "italic",
		   "light",
		   "mirrortile",
		   "more",
		   "narrow",
		   "nfont",
		   "notrans",
		   "opaque",
		   "outline",
		   "pressed",
		   "quant",
		   "rescale",
		   "rotate",
		   "scale",
		   "scolor",
		   "scroll",
		   "shadow",
		   "size",
		   "spacing",
		   "talign",
		   "tile",
		   "textbox",
		   "textbelow",
		   "textscale",
		   "turbulence",
		   "verbatim",
		   "xpad",
		   "xsize",
		   "xspacing",
		   "ypad",
		   "ysize",
		   "yspacing"
});

mapping mk_gtext_arg(mapping arg, RequestID id) {

  mapping defines=id->misc->defines;
  mapping p=([]); //Picture rendering arguments.

  foreach(filearg, string tmp)
    if(arg[tmp]) {
      p[tmp]=fix_relative(arg[tmp],id);
      m_delete(arg,tmp);
    }

  foreach(textarg, string tmp)
    if(arg[tmp]) {
      p[tmp]=arg[tmp],id;
      m_delete(arg,tmp);
    }

  if(defines->fg && !p->fg) p->fg=defines->fg;
  if(defines->bg && !p->bg) p->bg=defines->bg;
  if(defines->nfont && !p->nfont) p->nfont=defines->nfont;
  if(defines->afont && !p->afont) p->afont=defines->afont;
  if(defines->font &&  !p->font) p->font=defines->font;
  if(defines->bold && !p->bold) p->bold=defines->bold;
  if(defines->italic && !p->italic) p->italic=defines->italic;
  if(defines->black && !p->black) p->black=defines->black;
  if(defines->narrow && !p->narrow) p->narrow=defines->narrow;

  return p;
}

string fix_text(string c, mapping m, RequestID id) {

  if(m->nowhitespace)
  {
    sscanf(c,"%*[ \n\r\t]%s",c);
    sscanf(reverse(c),"%*[ \n\r\t]%s",c);
    c=reverse(c);
    m_delete(m, "nowhitespace");
  }

  if(!m->noparse && !m->preparse)
    c = parse_rxml(c, id);
  else {
    m_delete(m, "noparse");
    m_delete(m, "preparse");
  }

  c = c[..(((int)m->maxlen||QUERY(deflen))-1)];
  m_delete(m, "maxlen");

  return c;
}


// ----------------- gtext tags and containers -------------------

string tag_gtext_url(string t, mapping arg, string c, RequestID id) {
  c=fix_text(c,arg,id);
  mapping p=mk_gtext_arg(arg,id);
  if(arg->href && !p->fg) p->fg=id->misc->defines->link||"#0000ff";
  string ext="";
  if(query("ext")) ext="."+(p->format || "gif");
  if(!arg->short)
    return query_internal_location()+image_cache->store( ({p,c}), id )+ext;
  else
    return "+"+image_cache->store( ({p,c}), id )+ext;
}

string tag_gtext_id(string t, mapping arg, RequestID id) {
  mapping p=mk_gtext_arg(arg,id);
  if(arg->href && !p->fg) p->fg=id->misc->defines->link||"#0000ff";
  if(!arg->short)
    return query_internal_location()+"$"+image_cache->store(p, id)+"/";
  else
    return "+"+image_cache->store(p, id )+"/";
}

string tag_graphicstext(string t, mapping arg, string c, RequestID id)
{
  mapping defines=id->misc->defines;
  if((c-" ")=="") 
    return "";

  c=fix_text(c,arg,id);
  mapping p=mk_gtext_arg(arg,id);

  string ext="";
  if(query("ext")) ext="."+(p->format || "gif");

  string lp="%s", url="", ea="";

  int input;
  if(arg->submit)
  {
    input=1;
    m_delete(arg,"submit");
  }

  if(!arg->noxml) { arg["/"]="/"; m_delete(arg, "noxml"); }
  if(!arg->border) arg->border=arg->border||"0";

  if(arg->href)
  {
    url = arg->href;
    lp = make_container("a",arg,"%s"); //This anchor might have some extra args.
    if(!p->fg) p->fg=defines->link||"#0000ff";
    m_delete(arg, "href");
  }

  if(arg->split)
  {
    string res="",split=arg->split;
    if(lower_case(split)=="split") split=" ";
    m_delete(arg,"split");
    c=replace(c, "\n", " ");
    int setalt=!arg->alt;
    foreach(c/split-({""}), string word)
    {
      string fn = image_cache->store( ({ p, word }),id );
      mapping size = image_cache->metadata( fn, id, 1 );
      if(setalt) arg->alt=word;
      arg->src=query_internal_location()+fn+ext;
      if( size )
      {
        arg->width  = (string)size->xsize;
        arg->height = (string)size->ysize;
      }
      res+=make_tag( "img", arg )+" ";
    }
    return sprintf(lp,res);
  }

  string num = image_cache->store( ({ p, c }), id );
  mapping size = image_cache->metadata( num, id, 1 );
  if(!arg->alt) arg->alt=replace(c,"\"","'");

  arg->src=query_internal_location()+num+ext;
  if(size) {
    arg->width=size->xsize;
    arg->height=size->ysize;
  }

  if(arg->magic)
  {
    string magic=replace(arg->magic,"'","`");
    m_delete(arg,"magic");

    if(!arg->fg) p->fg=defines->alink||"#ff0000";
    if(p->bevel) p->pressed=1;

    if(arg->fuzz) p->glow = arg->fuzz!="fuzz"?arg->fuzz:p->fg;
    if(arg["magic-bg"]) p->background = p["magic-bg"];
    m_delete(p,"fuzz");
    m_delete(p,"magic-bg");

    foreach(glob("magic-*", indices(arg)), string q)
    {
      p[q[6..]]=arg[q];
      m_delete(arg, q);
    }

    string num2 = image_cache->store( ({ p, c }),id );
    size = image_cache->metadata( num2, id );
    if(size) {
      arg->width=MAX(arg->xsize,size->xsize);
      arg->height=MAX(arg->ysize,size->ysize);
    }

    if(!id->supports->images) return sprintf(lp,arg->alt);

    string sn="i"+defines->mi++;
    if(!id->supports->netscape_javascript) {
      return (!input)?
        ("<a "+ea+"href=\""+url+"\">"+make_tag("img",arg+(["name":sn]))+"</a>"):
        make_tag("input",arg+(["type":"image"]));
    }

    arg->name=sn;
    string res="<script>\n";
    if(!defines->magic_java)
      res += "function i(ri,hi,txt)\n"
        "{\n"
        "  document.images[ri].src = hi.src;\n"
        "  setTimeout(\"top.window.status = '\"+txt+\"'\", 100);\n"
	"}\n";
    defines->magic_java="yes";

    return
      res+
      " "+sn+"l = new Image("+arg->width+", "+arg->height+");"+sn+"l.src = \""+arg->src+"\";\n"
      " "+sn+"h = new Image("+arg->width+", "+arg->height+");"+sn+"h.src = \""+query_internal_location()+num2+ext+"\";\n"
      "</script>"+
      "<a "+ea+"href=\""+url+"\" "+
      (input?"onClick='document.forms[0].submit();' ":"")
      +"onMouseover=\"i('"+sn+"',"+sn+"h,'"+(magic=="magic"?url:magic)+"'); return true;\"\n"
      "onMouseout=\"top.window.status='';document.images['"+sn+"'].src = "+sn+"l.src;\">"
      +make_tag("img",arg)+"</a>";
  }

  if(input)
    return make_tag("input",arg+(["type":"image"]));

  return sprintf(lp,make_tag("img",arg));
}

array(string) tag_gh(string t, mapping m, string c, RequestID id) {
  int i;
  if(sscanf(t, "%s%d", t, i)==2 && i>1)
    m->scale = (string)(1.0 / ((float)i*0.6));
  for(i=2; i<10; i++)
    if(m[(string)i])
    {
      m->scale = (string)(1.0 / ((float)i*0.6));
      break;
    }
  if(!m->valign) m->valign="top";
 return ({ "<p>"+tag_graphicstext("",m,c,id)+"<br>" });
}

array(string) tag_anfang(string t, mapping m, string c, RequestID id) {
  if(!m->align) m->align="left";
  return ({ "<br clear=\"left\">"+tag_graphicstext("",m,c[0..0],id)+c[1..] });
}


// ------------ Wiretap code to find HTML-colours ---------------------

inline string ns_color(array (int) col)
{
  if(!arrayp(col)||sizeof(col)!=3)
    return "#000000";
  return sprintf("#%02x%02x%02x", col[0],col[1],col[2]);
}

string|array (string) tag_body(string t, mapping args, RequestID id, object file,
			       mapping defines)
{
  int cols,changed;
  if(args->bgcolor||args->text||args->link||args->alink
     ||args->background||args->vlink)
    cols=1;

#define FIX(Y,Z,X) do{if(!args->Y || args->Y==""){if(cols){defines->X=Z;args->Y=Z;changed=1;}}else{defines->X=args->Y;if(QUERY(colormode)&&args->Y[0]!='#'){args->Y=ns_color(parse_color(args->Y));changed=1;}}}while(0)

  if(!search((id->client||({}))*"","Mosaic"))
  {
    FIX(bgcolor,"#bfbfbf",bg);
    FIX(text,   "#000000",fg);
    FIX(link,   "#0000b0",link);
    FIX(alink,  "#3f0f7b",alink);
    FIX(vlink,  "#ff0000",vlink);
  } else {
    FIX(bgcolor,"#c0c0c0",bg);
    FIX(text,   "#000000",fg);
    FIX(link,   "#0000ee",link);
    FIX(alink,  "#ff0000",alink);
    FIX(vlink,  "#551a8b",vlink);
  }
  if(changed && QUERY(colormode))
    return ({make_tag("body", args) });
}

string|array(string) tag_fix_color(string tagname, mapping args, RequestID id,
				   object file, mapping defines)
{
  int changed;

  if(!id->misc->colors)
    id->misc->colors = ({ ({ defines->fg, defines->bg, tagname }) });
  else
    id->misc->colors += ({ ({ defines->fg, defines->bg, tagname }) });
#undef FIX
#define FIX(X,Y) if(args->X && args->X!=""){defines->Y=args->X;if(QUERY(colormode) && args->X[0]!='#'){args->X=ns_color(parse_color(args->X));changed = 1;}}

  FIX(bgcolor,bg);
  FIX(text,fg);
  FIX(color,fg);
#undef FIX

  if(changed && QUERY(colormode))
    return ({ make_tag(tagname, args) });
  return 0;
}

string|void pop_color(string tagname,mapping args,RequestID id,object file,
		 mapping defines)
{
  array c = id->misc->colors;
  if(!c ||!sizeof(c))
    return;

  int i;
  tagname = tagname[1..];

  for(i=0;i<sizeof(c);i++)
    if(c[-i-1][2]==tagname)
    {
      defines->fg = c[-i-1][0];
      defines->bg = c[-i-1][1];
      break;
    }
  c = c[..sizeof(c)-i-2];
  id->misc->colors = c;
}


// --------------- tag and container registration ----------------------

mapping query_tag_callers()
{
  mapping tags = ([ "gtext-id":tag_gtext_id ]);
  if(query("colorparse"))
    foreach(query("colorparsing"), string t)
    {
      switch(t)
      {
       case "body":
	 tags[t] = tag_body;
	 break;
       default:
	 tags[t] = tag_fix_color;
	 tags["/"+t]=pop_color;
      }
    }
  return tags;
}

mapping query_container_callers()
{
  return ([ "anfang":tag_anfang,
            "gtext-url":tag_gtext_url, "gh":tag_gh,
	    "gh1":tag_gh, "gh2":tag_gh,
	    "gh3":tag_gh, "gh4":tag_gh,
	    "gh5":tag_gh, "gh6":tag_gh,
	    "gtext":tag_graphicstext ]);
}
