constant cvs_version="$Id: graphic_text.pike,v 1.156 1999/02/12 00:52:06 grubba Exp $";
constant thread_safe=1;

#include <module.h>
#include <stat.h>
inherit "module";
inherit "roxenlib";

#ifndef VAR_MORE
#define VAR_MORE	0
#endif /* VAR_MORE */

static private int loaded;
int args_restored = 0;

static private string doc()
{
  return !loaded?"":replace(Stdio.read_bytes("modules/tags/doc/graphic_text")
			    ||"", ({ "{", "}" }), ({ "&lt;", "&gt;" }));
}

array register_module()
{
  return ({ MODULE_LOCATION | MODULE_PARSER,
	    "Graphics text",
	    "Generates graphical texts.<p>"
	    "See <tt>&lt;gtext help&gt;&lt;/gtext&gt;</tt> for "
	    "more information.\n<p>"+doc(),
	    0, 1
         });
}


array (string) list_fonts()
{
  array fnts;
  catch(fnts = get_dir("fonts/32/") - ({".",".."}));
  if(!fnts)
  {
    return ({});
  }
  return fnts;
}

void create()
{
  defvar("cache_dir", "../gtext_cache", "Cache directory for gtext images",
	 TYPE_DIR,
	 "The gtext tag saves images when they are calculated in this "
	 "directory.");
  
  defvar("cache_age", 48, "Cache max age",

	 TYPE_INT,

	 "If the images in the cache have not been accessed for this "
	 "number of hours they are removed.");


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

  defvar("location", "/gtext/", "Mountpoint", TYPE_LOCATION|VAR_MORE,
	 "The URL-prefix for the graphic characters.");

  defvar("cols", 16, "Default number of colors per image", TYPE_INT_LIST,
	 "The default number of colors to use. 16 seems to be enough. "
	 "The size of the image depends on the number of colors",
	 ({ 1,2,3,4,5,6,7,8,10,16,32,64,128,256 }));

  defvar("gif", 0, "Append .gif to all images", TYPE_FLAG|VAR_MORE,
	 "Append .gif to all images made by gtext. Normally this will "
	 "only waste bandwidth");


#ifdef TYPE_FONT
  // compatibility variables...
  defvar("default_size", 32, 0, TYPE_INT,0,0,1);
  defvar("default_font", "urw_itc_avant_garde-demi-r",0,TYPE_STRING,0,0,1);
#else
  defvar("default_size", 32, "Default font size", TYPE_INT_LIST,
	 "The default size for the font. This is used for the 'base' size, "
	 "and can be scaled up or down in the tags.",
	 ({ 16, 32, 64 }));
  
  defvar("default_font", "urw_itc_avant_garde-demi-r", "Default font",
	 TYPE_STRING_LIST,
	 "The default font. The 'font dir' will be prepended to the path",
	 list_fonts());
#endif
}

string query_location() { return query("location"); }

object load_font(string name, string justification, int xs, int ys)
{
  object fnt = Image.font();

  if ((!name)||(name == ""))
  {
    return get_font("default",32,0,0,lower_case(justification||"left"),
		    (float)xs, (float)ys);
  } else if(sscanf(name, "%*s/%*s") != 2) {
    name=QUERY(default_size)+"/"+name;
  }

  name = "fonts/" + name;

  if(!fnt->load( name ))
  {
    report_debug("Failed to load the compatibility font "+name+
		 ", using the default font.\n");
    return get_font("default",32,0,0,lower_case(justification||"left"),
		    (float)xs, (float)ys);
  }
  catch
  {
    if(justification=="right") fnt->right();
    if(justification=="center") fnt->center();
    if(xs)fnt->set_x_spacing((100.0+(float)xs)/100.0);
    if(ys)fnt->set_y_spacing((100.0+(float)ys)/100.0);
  };
  return fnt;
}

static private mapping cached_args = ([ ]);

#define MAX(a,b) ((a)<(b)?(b):(a))

#if !efun(make_matrix)
static private mapping (int:array(array(int))) matrixes = ([]);
array (array(int)) make_matrix(int size)
{
  if(matrixes[size]) return matrixes[size];
  array res;
  int i;
  int j;
  res = Array.map(allocate(size), lambda(int s, int size){
    return allocate(size); }, size);

  for(i=0; i<size; i++)
    for(j=0; j<size; j++)
      res[i][j] = (int)MAX((float)size/2.0-sqrt((size/2-i)*(size/2-i) + (size/2-j)*(size/2-j)),0);
  return matrixes[size] = res;
}
#endif

string fix_relative(string file, object id)
{
  if(file != "" && file[0] == '/') return file;
  file = combine_path(dirname(id->not_query) + "/",  file);
  return file;
}

object last_image;      // Cache the last image for a while.
string last_image_name;
object load_image(string f,object id)
{
  if(last_image_name == f && last_image) return last_image->copy();
  string data;
  object file;
  object img
#if !constant(Image.PNM)
  =Image.image()
#endif
    ;
  
  if(!(data=roxen->try_get_file(fix_relative(f, id),id)))
    if(!(file=open(f,"r")) || (!(data=file->read())))
      return 0;
//werror("Read "+strlen(data)+" bytes.\n");
#if constant(Image.GIF.decode)
  catch { if(!img) img = Image.GIF.decode( data ); };
#endif
#if constant(Image.JPEG.decode)
  catch { if(!img) img = Image.JPEG.decode( data ); };
#endif
#if constant(Image.PNG.decode)
  catch { if(!img) img = Image.PNG.decode( data ); };
#endif
#if constant(Image.PNM.decode)
  catch { if(!img) img = Image.PNM.decode( data ); };
#endif
#if !constant(Image.PNM.decode)
  if (catch { if(!img->frompnm(data)) return 0;}) return 0;
#endif
  if(!img) return 0;
  last_image = img; last_image_name = f;
  return img->copy();
}

object  blur(object img, int amnt)
{
  img->setcolor(0,0,0);
  img = img->autocrop(amnt, 0,0,0,0, 0,0,0);

  for(int i=0; i<amnt; i++) 
    img = img->apply_matrix( make_matrix((int)sqrt(img->ysize()+20)));
  return img;
}

object  outline(object  on, object  with,
		       array (int) color, int radie, int x, int y)
{
  int steps=10;
  for(int j=0; j<=steps; j++)
    on->paste_alpha_color(with, @color,
			  (int)(0.5+x-(sin((float)j/steps*3.145*2)*radie)),
			  (int)(0.5+y-(cos((float)j/steps*3.145*2)*radie)));
  return on;
}

array white = ({ 255,255,255 });
array lgrey = ({ 200,200,200 });
array grey = ({ 128,128,128 });
array black = ({ 0,0,0 });

array wwwb = ({ lgrey,lgrey,grey,black });
object  bevel(object  in, int width, int|void invert)
{
  int h=in->ysize();
  int w=in->xsize();

  object corner = Image.image(width+1,width+1);
  object corner2 = Image.image(width+1,width+1);
  object pix = Image.image(1,1);

  for(int i=-1; i<=width; i++) {
    corner->line(i,width-i,i,-1, @white);
    corner2->setpixel(width-i, width-i, @white);
    in->paste_alpha(pix, 185, w - width + i+1, h - width + i+1);
  }

  if(!invert)
  {
    in->paste_alpha(Image.image(width,h-width*2,@white), 160, 0, width);
    in->paste_alpha(Image.image(width,h-width*2,@black), 128, in->xsize()-width, width);
    in->paste_alpha(Image.image(w-width,width,@white), 160, 0, 0);
    in->paste_alpha(Image.image(w-width,width,@black), 128, width, in->ysize()-width);
  } else  {
    corner=corner->invert();
    corner2=corner2->invert();
    in->paste_alpha(Image.image(width,h-width*2,@black), 160, 0, width);
    in->paste_alpha(Image.image(width,h-width*2,@white), 128, in->xsize()-width, width);
    in->paste_alpha(Image.image(w-width,width,@black), 160, 0, 0);
    in->paste_alpha(Image.image(w-width,width,@white), 128, width, in->ysize()-width);
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


object make_text_image(mapping args, object font, string text,object id)
{
  object text_alpha=font->write(@(text/"\n"));
  int xoffset=0, yoffset=0;

  if(!text_alpha->xsize() || !text_alpha->ysize())
    text_alpha = Image.image(10,10, 0,0,0);
  
//  perror("Making image of '%s', args=%O\n", text, args);

  if(int op=((((int)args->opaque)*255)/100)) // Transparent text...
    text_alpha=text_alpha->color(op,op,op);

  int txsize=text_alpha->xsize();
  int tysize=text_alpha->ysize(); // Size of the text, in pixels. 

  int xsize=txsize; // image size, in pixels
  int ysize=tysize;

//  perror("Xsize=%d; ysize=%d\n",xsize,ysize);

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


  if(args->texture) {
    foreground = load_image(args->texture,id);
    if(args->tile)
    {
      object b2 = Image.image(xsize,ysize);
      for(int x=0; x<xsize; x+=foreground->xsize())
	for(int y=0; y<ysize; y+=foreground->ysize())
	  b2->paste(foreground, x, y);
      foreground = b2;
    } else if(args->mirrortile) {
      object b2 = Image.image(xsize,ysize);
      object b3 = Image.image(foreground->xsize()*2,foreground->ysize()*2);
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
  }
  int background_is_color;
  if(args->background &&
     ((background = load_image(args->background, id)) ||
      (sizeof(args->background)>1 &&
       (background=Image.image(xsize,ysize, @(parse_color(args->background[1..]))))
       && (background_is_color=1))))
  {
    object alpha;
    if(args->alpha && (alpha = load_image(args->alpha,id)) && background_is_color)
    {
      xsize=MAX(xsize,alpha->xsize());
      ysize=MAX(ysize,alpha->ysize());
      if((float)args->scale)
	alpha=alpha->scale(1/(float)args->scale);
      background=Image.image(xsize,ysize, @(parse_color(args->background[1..])));
    }
      
    if((float)args->scale >= 0.1 && !alpha)
      background = background->scale(1.0/(float)args->scale);
    
    if(args->tile)
    {
      object b2 = Image.image(xsize,ysize);
      for(int x=0; x<xsize; x+=background->xsize())
	for(int y=0; y<ysize; y+=background->ysize())
	  b2->paste(background, x, y);
      background = b2;
    } else if(args->mirrortile) {
      object b2 = Image.image(xsize,ysize);
      object b3 = Image.image(background->xsize()*2,background->ysize()*2);
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
    background = Image.image(xsize, ysize, @bgcolor);

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

  if(args->size || args->xsize || args->ysize)
  {
    int xs=background->xsize(), ys=background->ysize();
    if(args->size) { xs=(int)args->size; ys=(int)(args->size/",")[-1]; }
    if(args->xsize) xs=(int)args->xsize; 
    if(args->ysize) ys=(int)args->ysize;
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
    sscanf(args->textbox, "%d,%s", alpha, bg);
    sscanf(bg,"%s,%d", bg,border);
    background->paste_alpha(Image.image(txsize+border*2,tysize+border*2,
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

#define MIN(x,y) ((x)<(y)?(x):(y))

  if(args->bshadow)
  {
    int sdist = (int)(args->bshadow)+1;
    int xs,ys;
    xs = text_alpha->xsize()+sdist*2+4;
    ys = text_alpha->ysize()+sdist*2+4;
    object ta = Image.image(xs+sdist*2,ys+sdist*2);
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
  

  if(!foreground)  foreground=Image.image(txsize, tysize, @fgcolor);
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
//     foreground = foreground->autocrop();
//     text_alpha = text_alpha->autocrop();
    
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

  if((float)args->scale>0.0)
    if((float)args->scale <= 2.0)
      background = background->scale((float)args->scale);


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

string base_key;
object mc;


array to_clean = ({});
void clean_cache_dir()
{
  if(!sizeof(to_clean))
    to_clean = get_dir(query("cache_dir"))||({});
  if(!sizeof(to_clean)) return;
  array st = file_stat(query("cache_dir")+to_clean[0]);
  int md;
  if (st) {
    md = st[ST_ATIME];
  }

  /* NOTE: We assume that time() is larger than query("cache_age")*3600 */

  if((time() - md) > (query("cache_age")*3600))
    rm(query("cache_dir")+to_clean[0]);
  
  to_clean = to_clean[1..];
  if(sizeof(to_clean))
    call_out(clean_cache_dir, 0.1);
  else
    call_out(clean_cache_dir, 3600);
}

void start(int|void val, object|void conf)
{
  loaded = 1;

  if(conf)
  {
    mkdirhier( query( "cache_dir" )+"/.foo" );
#ifndef __NT__
#if efun(chmod)
    // FIXME: Should this error be propagated?
    catch { chmod( query( "cache_dir" ), 0777 ); };
#endif
#endif
    remove_call_out(clean_cache_dir);
    call_out(clean_cache_dir, 10);
    mc = conf;
    base_key = "gtext:"+(conf?conf->name:roxen->current_configuration->name);
  }
}

#ifdef QUANT_DEBUG
void print_colors(array from)
{
#if efun(color_name)
  for(int i=0; i<sizeof(from); i++)
    perror("%d: %s\n", i, color_name(from[i]));
#endif
}
#endif

int number=0;

#ifdef THREADS
object number_lock = Threads.Mutex();
#define NUMBER_LOCK() do { object __key = number_lock->lock()
#define NUMBER_UNLOCK()       if (__key) destruct(__key); } while(0)
#else /* !THREADS */
#define NUMBER_LOCK()
#define NUMBER_UNLOCK()
#endif /* THREADS */

mapping find_cached_args(int num);


#if !constant(iso88591)
constant iso88591
=([ "&nbsp;":   " ",  "&iexcl;":  "¡",  "&cent;":   "¢",  "&pound;":  "£",
    "&curren;": "¤",  "&yen;":    "¥",  "&brvbar;": "¦",  "&sect;":   "§",
    "&uml;":    "¨",  "&copy;":   "©",  "&ordf;":   "ª",  "&laquo;":  "«",
    "&not;":    "¬",  "&shy;":    "­",  "&reg;":    "®",  "&macr;":   "¯",
    "&deg;":    "°",  "&plusmn;": "±",  "&sup2;":   "²",  "&sup3;":   "³",
    "&acute;":  "´",  "&micro;":  "µ",  "&para;":   "¶",  "&middot;": "·",
    "&cedil;":  "¸",  "&sup1;":   "¹",  "&ordm;":   "º",  "&raquo;":  "»",
    "&frac14;": "¼",  "&frac12;": "½",  "&frac34;": "¾",  "&iquest;": "¿",
    "&Agrave;": "À",  "&Aacute;": "Á",  "&Acirc;":  "Â",  "&Atilde;": "Ã",
    "&Auml;":   "Ä",  "&Aring;":  "Å",  "&AElig;":  "Æ",  "&Ccedil;": "Ç",
    "&Egrave;": "È",  "&Eacute;": "É",  "&Ecirc;":  "Ê",  "&Euml;":   "Ë",
    "&Igrave;": "Ì",  "&Iacute;": "Í",  "&Icirc;":  "Î",  "&Iuml;":   "Ï",
    "&ETH;":    "Ð",  "&Ntilde;": "Ñ",  "&Ograve;": "Ò",  "&Oacute;": "Ó",
    "&Ocirc;":  "Ô",  "&Otilde;": "Õ",  "&Ouml;":   "Ö",  "&times;":  "×",
    "&Oslash;": "Ø",  "&Ugrave;": "Ù",  "&Uacute;": "Ú",  "&Ucirc;":  "Û",
    "&Uuml;":   "Ü",  "&Yacute;": "Ý",  "&THORN;":  "Þ",  "&szlig;":  "ß",
    "&agrave;": "à",  "&aacute;": "á",  "&acirc;":  "â",  "&atilde;": "ã",
    "&auml;":   "ä",  "&aring;":  "å",  "&aelig;":  "æ",  "&ccedil;": "ç",
    "&egrave;": "è",  "&eacute;": "é",  "&ecirc;":  "ê",  "&euml;":   "ë",
    "&igrave;": "ì",  "&iacute;": "í",  "&icirc;":  "î",  "&iuml;":   "ï",
    "&eth;":    "ð",  "&ntilde;": "ñ",  "&ograve;": "ò",  "&oacute;": "ó",
    "&ocirc;":  "ô",  "&otilde;": "õ",  "&ouml;":   "ö",  "&divide;": "÷",
    "&oslash;": "ø",  "&ugrave;": "ù",  "&uacute;": "ú",  "&ucirc;":  "û",
    "&uuml;":   "ü",  "&yacute;": "ý",  "&thorn;":  "þ",  "&yuml;":   "ÿ",
]);
#endif



constant nbsp = iso88591["&nbsp;"];

constant replace_from = indices( iso88591 )+ ({"&ss;","&lt;","&gt;","&amp",});
constant replace_to   = values( iso88591 ) + ({ nbsp, "<", ">", "&", }); 

#define simplify_text( from ) replace(from,replace_from,replace_to)

#define CACHE_SIZE 2048

#define FNAME(a,b) (query("cache_dir")+sprintf("%x",hash(reverse(a[6..])))+sprintf("%x",hash(b))+sprintf("%x",hash(reverse(b-" ")))+sprintf("%x",hash(b[12..])))

array get_cache_file(string a, string b)
{
  object fd = open(FNAME(a,b), "r");
  if(!fd) return 0;
  catch {
    array r = decode_value(fd->read());
    if(r[0]==a && r[1]==b) return r[2];
  };
}

void store_cache_file(string a, string b, array data)
{
  object fd = open(FNAME(a,b), "wct");
#ifndef __NT__
#if efun(chmod)
  // FIXME: Should this error be propagated?
  catch { chmod( FNAME(a,b), 0666 ); };
#endif
#endif
  if(!fd) return;
  fd->write(encode_value(({a,b,data})));
  destruct(fd);
}


array(int)|string write_text(int _args, string text, int size, object id)
{
  string key = base_key+_args;
  array err;
  string orig_text = text;
  mixed data;
  mapping args = find_cached_args(_args) || ([]);

  if(data = cache_lookup(key, text))
  {
    if(args->nocache) // Remove from cache. Very useful for access counters
      cache_remove(key, text);
    if(size) return data[1];
    return data[0];
  } else if(data = get_cache_file( key, text )) {
    cache_set(key, text, data);
    if(size) return data[1];
    return data[0];
  }
  //werror("Not cached: %O -> %O\n", key, text);
  //werror("In cache: %O\n", sort(indices(cache->cache)));

  // So. We have to actually draw the thing...

  err = catch
  {
    object img;

    if(!sizeof(args))
    {
      args=(["fg":"black","bg":"white","notrans":"1","nocache":"1"]);
      text="Please reload this page";
    }
    if(!args->verbatim)
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
      text = replace(res[..strlen(res)-2], ({ "!","?",": " }), ({ nbsp+"!",nbsp+"?",nbsp+": " }));
      text = replace(replace(replace(text,({". ",". "+nbsp}), ({"\000","\001"})),".","."+nbsp+nbsp),({"\000","\001"}),({". ","."+nbsp}));
    }

//  cache_set(key, text, "rendering");

#if efun(resolve_font)
    if(args->afont)
    {
      data = resolve_font(args->afont);
    } 
    else 
#endif
      if(args->nfont)
    {
      int bold, italic;
      if(args->bold) bold=1;
      if(args->light) bold=-1;
      if(args->italic) italic=1;
      if(args->black) bold=2;
      data = get_font(args->nfont,(int)args->font_size||32,bold,italic,
		      lower_case(args->talign||"left"),
		      (float)(int)args->xpad, (float)(int)args->ypad);
    }
    else if(args->font)
    {
      data = resolve_font(args->font);
      if(!data)
	data = load_font(args->font, lower_case(args->talign||"left"),
			 (int)args->xpad,(int)args->ypad);
    } else {
      int bold, italic;
      if(args->bold) bold=1;
      if(args->light) bold=-1;
      if(args->italic) italic=1;
      if(args->black) bold=2;
      data = get_font(roxen->QUERY(default_font),32,bold,italic,
		      lower_case(args->talign||"left"),
		      (float)(int)args->xpad, (float)(int)args->ypad);
    }

    if (!data) {
      roxen_perror("gtext: No font!\n");
//       werror("no font found! < "+_args+" <"+text+">\n");
//       cache_set(key, orig_text, 0);
      return(0);
    }

    // Fonts and such are now initialized.
    img = make_text_image(args,data,text,id);

    // Now we have the image in 'img', or nothing.
    if(!img) {
//       werror("error while drawing image? (no image) < "+_args+" <"+text+">\n");
//       cache_set(key, orig_text, 0);
      return 0;
    }
  
    int q = (int)args->quant||(args->background||args->texture?250:QUERY(cols));

    if(q>255) q=255;
    if(q<3) q=3;

// Quantify
    if(!args->fs)
    {
#ifdef QUANT_DEBUG
      print_colors(img->select_colors(q-1)+({parse_color(args->bg)}));
#endif
      img = img->map_closest(img->select_colors(q-1)+({parse_color(args->bg)}));
    }

    if(!args->scroll)
      if(args->fadein)
      {
	int amount=2, steps=10, delay=10, initialdelay=0, ox;
	string res = img->gif_begin();
	sscanf(args->fadein, "%d,%d,%d,%d", amount, steps, delay, initialdelay);
	if(initialdelay)
	{
	  object foo=Image.image(img->xsize(),img->ysize(),@parse_color(args->bg));
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
	if(args->fs)
	  data=({ img->togif_fs(@(args->notrans?({}):parse_color(args->bg))),
		  ({img->xsize(),img->ysize()})});
	else
	  data=({ img->togif(@(args->notrans?({}):parse_color(args->bg))),
		  ({img->xsize(),img->ysize()})});
	img=0;
      } else {
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

// place in caches, as a gif image.
    if(!args->nocache)
      store_cache_file( key, orig_text, data );
    cache_set(key, orig_text, data);
    //  werror("Cache set:  %O -> %O\n", key, orig_text);
    if(size) return data[1];
    return data[0];
  };
//   werror("Got error < "+_args+" <"+text+">\n");
  cache_set(key, text, 0);
  throw(err);
}

mapping find_file(string f, object rid); // Pike 0.5...
void restore_cached_args(); // Pike 0.5...


array stat_file(string f, object rid)
{
  if(f[-1]=='/') f = f[..strlen(f)-2];
  if(sizeof(f/"/")==1) return ({ 509,-3,time(),time(),time(),0,0 });
  int len=4711;
  catch(len= strlen(find_file(f,rid)->data));
  return ({ 33204,len,time(),time(),time(),0,0 });
}

array find_dir(string f, object rid)
{
  if(!strlen(f))
  {
    if(!args_restored) restore_cached_args();
    return Array.map(indices(cached_args), lambda(mixed m){return (string)m;});
  }
  return ({"Example"});
}

  
mapping find_file(string f, object rid)
{
  int id;
#if constant(Gz)
  object g;
#endif

  if((rid->method != "GET") 
     || (sscanf(f,"%d/%s", id, f) != 2))
    return 0;

  if( query("gif") && f[strlen(f)-4..]==".gif") // Remove .gif
    f = f[..strlen(f)-5];

  if(!sizeof(f))   // No string to write.
    return 0;

  if (f[0] == '$') // Illegal in BASE64
    f = f[1..];
#if constant(Gz)
  else if (sizeof(indices(g=Gz)))
    catch(f = g->inflate()->inflate(MIME.decode_base64(f)));
#endif
  else
    catch(f = MIME.decode_base64(f));

  // Generate the image.
  return http_string_answer(write_text(id,f,0,rid), "image/gif");
}
mapping url_cache = ([]);
string quote(string in)
{
  string option;
  if(option = url_cache[in]) return option;
  object g;
  if (sizeof(indices(g=Gz))) {
    option=MIME.encode_base64(g->deflate()->deflate(in));
  } else {
    option=MIME.encode_base64(in);
  }
  if(search(in,"/")!=-1) return url_cache[in]=option;
  string res="$";	// Illegal in BASE64
  for(int i=0; i<strlen(in); i++)
    switch(in[i])
    {
     case 'a'..'z':
     case 'A'..'Z':
     case '0'..'9':
     case '.': case ',': case '!':
      res += in[i..i];
      break;
     default:
      res += sprintf("%%%02x", in[i]);
    }
  if(strlen(res) < strlen(option)) return url_cache[in]=res;
  return url_cache[in]=option;
}

#define ARGHASH query("cache_dir")+"ARGS_"+hash(mc->name)

int last_argstat;

void restore_cached_args()
{
  args_restored = 1;
  array a = file_stat(ARGHASH);
  if(a && (a[ST_MTIME] > last_argstat))
  {
    last_argstat = a[ST_MTIME];
    object o = open(ARGHASH, "r");
    if(o)
    {
      string data = o->read();
      catch {
	object q;
	if(sizeof(indices(q=Gz)))
	  data=q->inflate()->inflate(data);
      };
      catch {
	cached_args |= decode_value(data);
      };
    }
    NUMBER_LOCK();
    if (cached_args && sizeof(cached_args)) {
      number = sort(indices(cached_args))[-1]+1;
    } else {
      cached_args = ([]);
      number = 0;
    }
    NUMBER_UNLOCK();
  }
}

void save_cached_args()
{
  restore_cached_args();
  object o = open(ARGHASH, "wct");
  if(o)
  {
#ifndef __NT__
#if efun(chmod)
    // FIXME: Should this error be propagated?
    catch { chmod( ARGHASH, 0666 ); };
#endif
#endif
    string data=encode_value(cached_args);
    catch {
      object q;
      if(sizeof(indices(q=Gz)))
	data=q->deflate()->deflate(data);
    };
    o->write(data);
  }
}

mapping find_cached_args(int num)
{
  if(!args_restored) restore_cached_args();
  if(cached_args[num]) return cached_args[num];
  restore_cached_args(); /* Not slow anymore, checks with stat... */
  if(cached_args[num]) return cached_args[num];
  return 0;
}



int find_or_insert(mapping find)
{
  mapping f2 = copy_value(find);
  int res;
  string q;

  foreach(glob("magic_*", indices(f2)), q) 
    m_delete(f2,q);

  if(!args_restored)
    restore_cached_args( );

  array a=indices(f2),b=values(f2);
  sort(a,b);
  q = a*""+Array.map(b, lambda(mixed x) { return (string)x; })*"";

  if(res = cached_args[ q ])
    return res;

  restore_cached_args(); /* Not slow now, checks with stat.. */

  if(res = cached_args[ q ])
    return res;

  NUMBER_LOCK();
  cached_args[ number ] = f2;
  cached_args[ q ] = number;
  int n = number++;
  NUMBER_UNLOCK();

  remove_call_out(save_cached_args);
  call_out(save_cached_args, 10);
  return n;
}


string magic_javascript_header(object id)
{
  if(!id->supports->netscape_javascript || !id->supports->images) return "";
  return
    ("\n<script>\n"
     "function i(ri,hi,txt)\n"
     "{\n"
     "  document.images[ri].src = hi.src;\n"
     "  setTimeout(\"top.window.status = '\"+txt+\"'\", 100);\n"
     "}\n"
     "</script>\n");

}


string magic_image(string url, int xs, int ys, string sn,
		   string image_1, string image_2, string alt,
		   string mess,object id,string input,string extra_args,string lp)
{
  if(!id->supports->images) return (lp?lp:"")+alt+(lp?"</a>":"");
  if(!id->supports->netscape_javascript)
    return (!input)?
       ("<a "+extra_args+"href=\""+url+"\"><img src=\""+image_1+"\" name="+sn+" border=0 "+
       "alt=\""+alt+"\"></a>"):
    ("<input type=image "+extra_args+" src=\""+image_1+"\" name="+input+">");

  return
    ("<script>\n"
     " "+sn+"l = new Image("+xs+", "+ys+");"+sn+"l.src = \""+image_1+"\";\n"
     " "+sn+"h = new Image("+xs+", "+ys+");"+sn+"h.src = \""+image_2+"\";\n"
     "</script>\n"+
     ("<a "+extra_args+"href=\""+url+"\" "+
      (input?"onClick='document.forms[0].submit();' ":"")
      +"onMouseover=\"i('"+sn+"',"+sn+"h,'"+(mess||url)+"'); return true;\"\n"
      "onMouseout=\"top.window.status='';document.images['"+sn+"'].src = "+sn+"l.src;\"><img "
      "width="+xs+" height="+ys+" src=\""+image_1+"\" name="+sn+
      " border=0 alt=\""+alt+"\" ></a>"));
}


string extra_args(mapping in)
{
  string s="";
  foreach(indices(in), string i)
  {
    switch(i)
    {
     case "target":
     case "hspace":
     case "vspace":
     case "onclick":
     case "class":
     case "id":
      s+=i+"='"+in[i]+"' ";
      m_delete(in, i);
      break;
    }
  }
  return s;
}

string tag_gtext_id(string t, mapping arg,
		    object id, object foo, mapping defines)
{
  int short=!!arg->short;
  if(arg->help) return "Arguments are identical to the argumets to &lt;gtext&gt;. This tag returns a url-prefix that can be used to generate gtexts.";
  m_delete(arg, "short"); m_delete(arg, "maxlen");
  m_delete(arg,"magic");  m_delete(arg,"submit");
  extra_args(arg);        m_delete(arg,"split");
  if(defines->fg && !arg->fg) arg->fg=defines->fg;
  if(defines->bg && !arg->bg) arg->bg=defines->bg;
  if(defines->nfont && !arg->nfont) arg->nfont=defines->nfont;
  if(defines->afont && !arg->afont) arg->afont=defines->afont;
  if(defines->font &&  !arg->font) arg->font=defines->font;

  if(arg->background) 
    arg->background = fix_relative(arg->background,id);
  if(arg->texture) 
    arg->texture = fix_relative(arg->texture,id);
  if(arg->magic_texture)
    arg->magic_texture=fix_relative(arg->magic_texture,id);
  if(arg->magic_background) 
    arg->magic_background=fix_relative(arg->magic_background,id);
  if(arg->magicbg) 
    arg->magicbg = fix_relative(arg->magicbg,id);
  if(arg->alpha) 
    arg->alpha = fix_relative(arg->alpha,id);

  int num = find_or_insert( arg );

  if(!short)
    return query_location()+num+"/";
  else
    return (string)num;
}

string tag_graphicstext(string t, mapping arg, string contents,
			object id, object foo, mapping defines)
{
  if((contents-" ")=="") 
    return "";
//Allow <accessed> and others inside <gtext>.
  if(arg->nowhitespace)
  {
    sscanf(contents,"%*[ \n\r\t]%s",contents);
    sscanf(reverse(contents),"%*[ \n\r\t]%s",contents);
    contents=reverse(contents);
  }
  if(t=="gtext" && arg->help)
    return doc();
  else if(arg->help)
    return "This tag calls &lt;gtext&gt; with different default values.";
  if(arg->background) 
    arg->background = fix_relative(arg->background,id);
  if(arg->texture) 
    arg->texture = fix_relative(arg->texture,id);
  if(arg->magic_texture)
    arg->magic_texture=fix_relative(arg->magic_texture,id);
  if(arg->magic_background) 
    arg->magic_background=fix_relative(arg->magic_background,id);
  if(arg->magicbg) 
    arg->magicbg = fix_relative(arg->magicbg,id);
  if(arg->alpha) 
    arg->alpha = fix_relative(arg->alpha,id);
  

  string gif="";
  if(query("gif")) gif=".gif";
  
#if efun(_static_modules)
  contents = parse_rxml(contents, id, foo, defines);
#else
  contents = parse_rxml(contents, id, foo);
#endif

  string lp, url, ea;
  string pre, post, defalign, gt, rest, magic;
  int i;
  string split;

  contents = contents[..((int)arg->maxlen||QUERY(deflen))];
  m_delete(arg, "maxlen");

  if(arg->magic)
  {
    magic=replace(arg->magic,"'","`");
    m_delete(arg,"magic");
  }

  int input;
  if(arg->submit)
  {
    input=1;
    m_delete(arg,"submit");
  }
  

  ea = extra_args(arg);

  // Modify the 'arg' mapping...
  if(arg->href)
  {
    url = arg->href;
    lp = "<a href=\""+arg->href+"\" "+ea+">";
    if(!arg->fg) arg->fg=defines->link||"#0000ff";
    m_delete(arg, "href");
  }

  if(defines->fg && !arg->fg) arg->fg=defines->fg;
  if(defines->bg && !arg->bg) arg->bg=defines->bg;
  if(defines->nfont && !arg->nfont) arg->nfont=defines->nfont;
  if(defines->afont && !arg->afont) arg->afont=defines->afont;
  if(defines->font &&  !arg->font) arg->font=defines->font;
  if(defines->bold && !arg->bold) arg->bold=defines->bold;
  if(defines->italic && !arg->italic) arg->italic=defines->italic;
  if(defines->black && !arg->black) arg->black=defines->black;
  if(defines->narrow && !arg->narrow) arg->narrow=defines->narrow;

  if(arg->split)
  {
    if (sizeof(split=arg->split) != 1)
      split = " ";
    m_delete(arg,"split");
  }

  // Support for <gh 2> like things.
  for(i=2; i<10; i++) 
    if(arg[(string)i])
    {
      arg->scale = 1.0 / ((float)i*0.6);
      m_delete(arg, (string)i);
      break;
    }

  // Support for <gh1> like things.
  if(sscanf(t, "%s%d", t, i)==2)
    if(i > 1) arg->scale = 1.0 / ((float)i*0.6);

  string na = arg->name, al=arg->align;
  m_delete(arg, "name"); m_delete(arg, "align");

  // Now the 'args' mapping is modified enough..
  int num = find_or_insert( arg );

  gt=contents;
  rest="";

  switch(t)
  {
   case "gh1": case "gh2": case "gh3": case "gh4":
   case "gh5": case "gh6": case "gh7":
   case "gh": pre="<p>"; post="<br>"; defalign="top"; break;
   case "gtext":
    pre="";  post=""; defalign="bottom";
    break;
   case "anfang":
    gt=contents[0..0]; rest=contents[1..];
    pre="<br clear=left>"; post=""; defalign="left";
    break;
  }

  if(split)
  {
    string word;
    array res = ({ pre });
    string pre = query_location() + num + "/";

    if(lp) res+=({ lp });
    
    gt=replace(gt, "\n", " ");
    
    foreach(gt/" "-({""}), word)
    {
      if (split != " ") {
	array arr = word/split;
	int i;
	for (i = sizeof(arr)-1; i--;)
	  arr[i] += split;
	if (arr[-1] == "")
	  arr = arr[..sizeof(arr)-2];
	foreach (arr, word) {
	  array size = write_text(num,word,1,id);
	  res += ({ "<img border=0 alt=\"" +
		      replace(arg->alt || word, "\"", "'") +
		      "\" src=\"" + pre + quote(word) + gif + "\" width=" +
		      size[0] + " height=" + size[1] + " " + ea + ">"
		      });
	}
	res += ({"\n"});
      } else {
	array size = write_text(num,word,1,id);
	res += ({ "<img border=0 alt=\"" +
		    replace(arg->alt || word, "\"", "'") +
		    "\" src=\"" + pre + quote(word) + gif + "\" width=" +
		    size[0] + " height=" + size[1] + " " + ea + ">\n"
		    });
      }
    }
    if(lp) res += ({ "</a>"+post });
    return res*"";
  }
  
  array size = write_text(num,gt,1,id);
  if(!size)
    return ("<font size=+1><b>Missing font or other similar error -- "
	    "failed to render text</b></font>");

  if(magic)
  {
    string res = "";
    if(!arg->fg) arg->fg=defines->link||"#0000ff";
    arg = mkmapping(indices(arg), values(arg));
    if(arg->fuzz)
      if(arg->fuzz != "fuzz")
	arg->glow = arg->fuzz;
      else
	arg->glow = arg->fg;
    arg->fg = defines->alink||"#ff0000";
    if(arg->magicbg) arg->background = arg->magicbg;
    if(arg->bevel) arg->pressed=1;

    foreach(glob("magic_*", indices(arg)), string q)
    {
      arg[q[6..]]=arg[q];
      m_delete(arg, q);
    }
    
    int num2 = find_or_insert(arg);
    array size = write_text(num2,gt,1,id);

    if(!defines->magic_java) res = magic_javascript_header(id);
    defines->magic_java="yes";

    return replace(res +
		   magic_image(url||"", size[0], size[1], "i"+(defines->mi++),
			       query_location()+num+"/"+quote(gt)+gif,
			       query_location()+num2+"/"+quote(gt)+gif,
			       (arg->alt?arg->alt:replace(gt, "\"","'")),
			       (magic=="magic"?0:magic),
			       id,input?na||"submit":0,ea,lp),
		   "</script>\n<script>","");
  }
  if(input)
    return (pre+"<input type=image name=\""+na+"\" border=0 alt=\""+
	    (arg->alt?arg->alt:replace(gt,"\"","'"))+
	    "\" src="+query_location()+num+"/"+quote(gt)+gif
	    +" align="+(al || defalign)+ea+
	    " width="+size[0]+" height="+size[1]+">"+rest+post);

  return (pre+(lp?lp:"")
	  + "<img border=0 alt=\""
	  + (arg->alt?arg->alt:replace(gt,"\"","'"))
	  + "\" src=\""
	  + query_location()+num+"/"+quote(gt)+gif+"\" "+ea
	  + " align="+(al || defalign)
	  + " width="+size[0]+" height="+size[1]+">"+rest+(lp?"</a>":"")+post);
}

inline string ns_color(array (int) col)
{
  if(!arrayp(col)||sizeof(col)!=3)
    return "#000000";
  return sprintf("#%02x%02x%02x", col[0],col[1],col[2]);
}


string make_args(mapping in)
{
  array a=indices(in), b=values(in);
  for(int i=0; i<sizeof(a); i++)
    if(lower_case(b[i])!=a[i])
      if(search(b,"\"")==-1)
	a[i]+="=\""+b[i]+"\"";
      else
	a[i]+="='"+b[i]+"'";
  return a*" ";
}

string|array (string) tag_body(string t, mapping args, object id, object file,
			       mapping defines)
{
  int cols,changed;
  if(args->help) return "This tag is parsed by &lt;gtext&gt; to get the document colors.";
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


string|array(string) tag_fix_color(string tagname, mapping args, object id, 
				   object file, mapping defines)
{
  int changed;

  if(args->help) return "This tag is parsed by &lt;gtext&gt; to get the document colors.";
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

string|void pop_color(string tagname,mapping args,object id,object file,
		 mapping defines)
{
  if(args->help) return "This end-tag is parsed by &lt;gtext&gt; to get the document colors.";
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

mapping query_tag_callers()
{
  mapping tags = ([ "gtext-id":tag_gtext_id]);
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
  return ([ "anfang":tag_graphicstext,
	    "gh":tag_graphicstext,
	    "gh1":tag_graphicstext, "gh2":tag_graphicstext,
	    "gh3":tag_graphicstext, "gh4":tag_graphicstext,
	    "gh5":tag_graphicstext, "gh6":tag_graphicstext,
	    "gtext":tag_graphicstext, ]);
}
