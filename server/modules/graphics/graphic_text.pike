constant cvs_version="$Id: graphic_text.pike,v 1.76 1997/09/22 01:21:26 js Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "roxenlib";

#if efun(_static_modules)
# define map_array Array.map
import Image;
# define Image image
# define Font  font
#endif

#if !efun(Privs)
constant Privs=((program)"privs");
#endif /* !efun(Privs) */

array register_module()
{
  return ({ MODULE_LOCATION | MODULE_PARSER,
	      "Graphics text",
	      "Defines a few new containers, which all render text to gifs "
	      "using the image module in pike.\n<p>"
	      "<b>&lt;gh1&gt;</b> to <b>&lt;gh6&gt;:</b> Headers<br>\n"
	      "<b>&lt;gh&gt;:</b> Header<br>\n"
	      "<b>&lt;gtext&gt;:</b> Graphical text<br>\n"
	      "<b>&lt;anfang&gt;:</b> Make the first character a "
	      "graphical one. Not all that useful, really.<br>\n"
	      "<br>\n"
	      "<b>Common arguments:</b>\n <pre>"
	      " verbatim        Do not try to be typographically correct\n"
	      " bg=color        Use this background, default taken from the\n"
	      "                 &lt;body&gt; tag, if any\n"
	      " fg=color        Use this foreground, default taken from the\n"
	      "                 &lt;body&gt; tag, if any\n"
	      " nfont=fnt       Use this font. The fonts can be found in the\n"
	      "                 directory specified in the configuration\n"
	      "                 interface.\n"
	      "                 If no font is specified, the one from the\n"
	      "                 define 'nfont' is used, or if there is no\n"
	      "                 define, the default font will be used.\n"
	      " bold            Try to find a bold version of the font.\n"
	      " italic          Try to find an italic version of the font.\n"
	      " black           Try to find a black (heavy) version of the font.\n"
	      " light           Try to find a light version of the font.\n"
	      " scale=float     Scale to this font, mostly useful in the &lt;gtext&gt;\n"
	      "                 tag, will not work at all in the &lt;gh[number]&gt;\n"
	      "                 tags.\n"
	      " 2 3 4 5 6       Short for scale=1.0/([number]*0.6)\n"
	      " notrans         Do _not_ make the background color transparent\n"
	      " split           Make each word into a separate gif image\n"
	      " href=url        Link the image to the specified URL\n"
	      "                 The 'link' color of the document will be\n"
	      "                 used as the default foreground of the text\n"
	      " alt=message     Sets the 'alt' attribute.\n"
	      "                 Use alt=\"\" if no alternate message is wanted.\n"
	      " quant=cols      Use this number of colors\n"
	      " magic[=message] Modifier to href, more flashy links\n"
	      "                 Does <b>not</b> work with 'split'\n"
	      " fuzz[=color]    Apply the 'glow' effect to the result\n"
 	      " fs              Use floyd-steinberg dithering\n"
	      " border=int,col. Draw an border (width is the first argument\n"
	      "                 in the specified color\n"
	      " spacing=int     Add this amount of spacing around the text\n"
	      " xspacing=int    like spacing, but only horizontal\n"
	      " yspacing=int    like spacing, but only vertical\n"
	      " size=int,int    Use this (absolute) size\n"
	      " xsize=int       Use this (absolute) size\n"
	      " ysize=int       Use this (absolute) size\n"
	      " bevel=int       Draw a bevel box (width is the argument)\n"
	      " pressed         Invert the \"direction\" of the bevel box\n"
	      " talign=dir      Justify the text to the left, right, or center\n"
	      " textbox=al,col. Use 'al' as opaque value to draw a box below\n"
	      "                 the text with the specified color.\n"
	      " xpad=X%         Increase padding between characters with X%\n"
	      " xpad=Y%         Increase padding between lines with Y%\n"
	      " shadow=int,dist Draw a drop-shadow (variable distance/intensity)\n"
	      " bshadow=dist    Draw a blured drop-shadow (variable distance)\n"
	      " scolor=color    Use this color as the shadow color.\n"
	      " ghost=dist,blur,col\n"
	      "                 Do a 'ghost text'. Do NOT use together with\n"
	      "                 'shadow'. Magic coloring won't work with it.\n"
	      " glow=color      Draw a 'glow' outline around the text.\n"
	      " opaque=0-100%   Draw with more or less opaque text (100%\n"
	      "                 is default)\n"
	      " rotate=ang(deg.)Rotate the finished image\n"
	      " background=file Use the specifed file as a background\n"
	      " texture=file    Use the specified file as text texture\n"
	      " turbulence=args args is: frequency,color;freq,col;freq,col\n"
	      "                 Apply a turbulence filter, and use this as the\n"
	      "                 background.\n"
	      " maxlen=arg      The maximum length of the rendered text will be\n"
	      "                 the specified argument. The default is 300, this\n"
	      "                 is used to safeguard against mistakes like\n"
	      "                 &lt;gh1&gt;&lt;/gh&gt;, which would otherwise\n"
	      "                 parse the whole document.\n"
	      " help            Display this text\n"
	      " scroll=width,steps,delay  Make a horrible scrolltext\n"
	      " fadein=blur,steps,delay,initialdelay  Make a (somewhat less) horrible fadein\n"
	      "\n"
	      "<b>Arguments passed on the the &lt;a&gt; tag (if href is specified):</b>\n "
	      " target=...\n"
	      " onClick=...\n"
	      "</pre>\n",
	      0,
	      1,
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
  defvar("speedy", 0, "Avoid automatic detection of document colors",
	 TYPE_FLAG|VAR_MORE,
	 "If this flag is set, the tags 'body', 'tr', 'td', 'font' and 'th' "
	 " will <b>not</b> be parsed to automatically detect the colors of "
	 " a document. You will then have to specify all colors in all calls "
	 " to &lt;gtext&gt;");
  
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

object(Font) load_font(string name, string justification, int xs, int ys)
{
  object fnt = Font();

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

static private mapping (int:mapping(string:mixed)) cached_args = ([ ]);

#define MAX(a,b) ((a)<(b)?(b):(a))

#if !efun(make_matrix)
static private mapping (int:array(array(int))) matrixes = ([]);
array (array(int)) make_matrix(int size)
{
  if(matrixes[size]) return matrixes[size];
  array res;
  int i;
  int j;
  res = map_array(allocate(size), lambda(int s, int size){
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
  object img = Image();

  if(!(data=roxen->try_get_file(fix_relative(f, id),id)))
    if(!(file=open(f,"r")) || (!(data=file->read())))
      return 0;
//werror("Read "+strlen(data)+" bytes.\n");
  if(!img->frompnm(data)) return 0;
  last_image = img; last_image_name = f;
  return img->copy();
}

object (Image) blur(object img, int amnt)
{
  img->setcolor(0,0,0);
  img = img->autocrop(amnt, 0,0,0,0, 0,0,0);

  for(int i=0; i<amnt; i++) 
    img = img->apply_matrix( make_matrix((int)sqrt(img->ysize()+20)));
  return img;
}

object (Image) outline(object (Image) on, object (Image) with,
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
object (Image) bevel(object (Image) in, int width, int|void invert)
{
  int h=in->ysize();
  int w=in->xsize();

  object corner = Image(width+1,width+1);
  object corner2 = Image(width+1,width+1);
  object pix = Image(1,1);

  for(int i=-1; i<=width; i++) {
    corner->line(i,width-i,i,-1, @white);
    corner2->setpixel(width-i, width-i, @white);
    in->paste_alpha(pix, 185, w - width + i+1, h - width + i+1);
  }

  if(!invert)
  {
    in->paste_alpha(Image(width,h-width*2,@white), 160, 0, width);
    in->paste_alpha(Image(width,h-width*2,@black), 128, in->xsize()-width, width);
    in->paste_alpha(Image(w-width,width,@white), 160, 0, 0);
    in->paste_alpha(Image(w-width,width,@black), 128, width, in->ysize()-width);
  } else  {
    corner=corner->invert();
    corner2=corner2->invert();
    in->paste_alpha(Image(width,h-width*2,@black), 160, 0, width);
    in->paste_alpha(Image(width,h-width*2,@white), 128, in->xsize()-width, width);
    in->paste_alpha(Image(w-width,width,@black), 160, 0, 0);
    in->paste_alpha(Image(w-width,width,@white), 128, width, in->ysize()-width);
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


object (Image) make_text_image(mapping args, object font, string text,object id)
{
  object text_alpha=font->write(@(text/"\n"));
  int xoffset=0, yoffset=0;

  if(!text_alpha->xsize() || !text_alpha->ysize())
    text_alpha = Image(10,10, 0,0,0);
  
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


  if(args->texture)    foreground = load_image(args->texture,id);

  if((args->background) && (background = load_image(args->background, id))) {
    background = background;
    if((float)args->scale >= 0.1)
      background = background->scale(1.0/(float)args->scale);


    xsize = background->xsize();
    ysize = background->ysize();
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
    background = Image(xsize, ysize, @bgcolor);

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
    background = background->copy(0,0,xs,ys);
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
    background->paste_alpha(Image(txsize+border*2,tysize+border*2,
				  @parse_color(bg)),
			    255-(alpha*255/100),xoffset-border,yoffset-border);
  }

  if(args->ghost)
  { // Francesco..
    int sdist = (int)args->ghost;
    int bl=(int)(args->ghost/",")[1];
    array(int)clr=parse_color((args->ghost/",")[-1]);
    int j;
    object ta = text_alpha->copy();
    for (j=0;j<bl;j++)
      ta=ta->apply_matrix(({
	({6,7,7,7,6}),({7,8,8,8,7}),({7,8,8,8,7}),({7,8,8,8,7}),({6,7,7,7,6})
       }));
    background->paste_alpha_color(ta,@clr,xoffset+sdist,yoffset+sdist);
    fgcolor=bgcolor;
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
    object ta = Image(xs+sdist*2,ys+sdist*2);
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
  

  if(!foreground)  foreground=Image(txsize, tysize, @fgcolor);
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

  background->paste_mask(foreground, text_alpha, xoffset, yoffset);

  if(args->scale)
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

void start(int|void val, object|void conf)
{
  if(conf)
  {
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

mapping find_cached_args(int num);

constant nbsp = sprintf("%c",160);

array(int)|string write_text(int _args, string text, int size,
			     object id)
{
  string key = base_key+_args;
  array err;
  err = catch
  {
    object img;
    mapping args = find_cached_args(_args);
    if(!args)
    {
      args=(["fg":"black","bg":"white"]);
      text="Please reload this page";
    }

    if(!args->verbatim)
    {
      text = replace(text, nbsp, "&nbsp;");
      text = replace(text,({ "&nbsp;","&ss;","&lt;","&gt;","&amp;"}),
		     ({" ",nbsp,"<", ">", "&" }));
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
    // Check the cache first..
    while(mixed data = cache_lookup(key, text))
    {
      if(data == "rendering")
      {
	sleep(0.1);
	continue;
      }
      if(args->nocache) // Remove from cache. Very usable for access counters
	cache_remove(key, text);
      if(size) return data[1];
      return data[0];
    }
    //  Nothing found in the cache. Generate a new image.
    cache_set(key, text, "rendering");

#if efun(get_font)
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
#endif
      string fkey = args->font+"/"+args->talign+"/"+args->xpad+"/"+args->ypad;
      data = cache_lookup("fonts", fkey);
      if(!data)
      { 
	data = load_font(args->font, lower_case(args->talign||"left"),
			 (int)args->xpad,(int)args->ypad);
	cache_set("fonts", fkey, data);
      }
#if efun(get_font)
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
#endif

    if (!data) {
      roxen_perror("gtext: No font!\n");
      return(0);
    }

    // Fonts and such are now initialized.
    img = make_text_image(args,data,text,id);

    // Now we have the image in 'img', or nothing.
    if(!img) return 0;
  
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

// place in cache, as a gif image.

    if(!args->scroll)
      if(args->fadein)
      {
	int amount=2, steps=10, delay=10, initialdelay=0, ox;
	string res = img->gif_begin();
	sscanf(args->fadein, "%d,%d,%d,%d", amount, steps, delay, initialdelay);
	if(initialdelay)
	{
	  object foo=image(img->xsize(),img->ysize(),0,0,0);
	  res += foo->gif_add(0,0,initialdelay);
	}
	for(int i = 0; i<steps; i++)
	{
	  object foo=img->clone();
	  foo = foo->apply_matrix(make_matrix(( (int)((steps-i)*amount))));
	  werror((string)i);
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

    
    cache_set(key, text, data);
    if(size) return data[1];
    return data[0];
  };
  cache_set(key, text, 0);
  throw(err);
}

  
mapping find_file(string f, object rid)
{
  int id;
  sscanf(f,"%d/%s", id, f);
  catch(f = Gz.inflate()->inflate(MIME.decode_base64(f)));
  return http_string_answer(write_text(id,f,0,rid), "image/gif");
}
mapping url_cache = ([]);
string quote(string in)
{
  if(url_cache[in]) return url_cache[in];
  string option=MIME.encode_base64(Gz.deflate()->deflate(in));
  if((search(in,"/")!=-1) || (search(in,"/.")!=-1)) return url_cache[in]=option;
  string res="";
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

int args_restored = 0;
void restore_cached_args()
{
  args_restored = 1;
  object privs = Privs("Reading gtext argument list");
  object o = open(".gtext_args_"+hash(mc->name), "r");
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
  if (cached_args && sizeof(cached_args)) {
    number = sort(indices(cached_args))[-1]+1;
  } else {
    cached_args = ([]);
    number = 0;
  }
}

void save_cached_args()
{
  int on;
  on = number;
  restore_cached_args();
  object privs = Privs("Saving gtext argument list");
  if(on > number) number=on;
  object o = open(".gtext_args_"+hash(mc->name), "wct");
  string data=encode_value(cached_args);
  catch {
    object q;
    if(sizeof(indices(q=Gz)))
      data=q->deflate()->deflate(data);
  };
  o->write(data);
}

mapping find_cached_args(int num)
{
  if(!args_restored) restore_cached_args();
  if(cached_args[num]) return cached_args[num];

  // This is a very unlikely event...
  restore_cached_args();
  if(cached_args[num]) return cached_args[num];
  return 0;
}



int find_or_insert(mapping find)
{
  if(!args_restored) restore_cached_args();
  array a = indices(cached_args);
  array b = values(cached_args);
  int i;
  for(i=0; i<sizeof(a); i++)
    if(equal(find, b[i])) {
      return a[i];
    }
  cached_args[number]=find;
  remove_call_out(save_cached_args);
  call_out(save_cached_args, 10);
  return number++;
}


string magic_javascript_header(object id)
{
  if(!id->supports->javascript || !id->supports->images) return "";
  return
    ("\n<script>\n"
     "function img_act(ri,hi,txt)\n"
     "{\n"
     "  document.images[ri].src = hi.src;\n"
     "  setTimeout(\"top.window.status = '\"+txt+\"'\", 100);\n"
     "}\n"
     "</script>\n");

}


string magic_image(string url, int xs, int ys, string sn,
		   string image_1, string image_2, string alt,
		   string mess,object id,string input,string extra_args)
{
  if(!id->supports->images) return alt;
  if(!id->supports->javascript)
    return (!input)?
      ("<a "+extra_args+"href=\""+url+"\"><img _parsed=1 src=\""+image_1+"\" name="+sn+" border=0 "+
       "alt=\""+alt+"\"></a>\n"):
    ("<input type=image "+extra_args+" src=\""+image_1+"\" name="+input+">");

  return
    ("<script>\n"
     " "+sn+"l = new Image("+xs+", "+ys+");"+sn+"l.src = \""+image_1+"\";\n"
     " "+sn+"h = new Image("+xs+", "+ys+");"+sn+"h.src = \""+image_2+"\";\n"
     "</script>\n"+
     ("<a "+extra_args+"href=\""+url+"\" "+
      (input?"onClick='document.forms[0].submit();' ":"")
      +"onMouseover=\"img_act('"+sn+"',"+sn+"h,'"+(mess||url)+"'); return true;\"\n"
      "onMouseout='document.images[\""+sn+"\"].src = "+sn+"l.src;'><img "
      "_parsed=1 width="+xs+" height="+ys+" src=\""+image_1+"\" name="+sn+
      " border=0 alt=\""+alt+"\" ></a>\n"));
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
  m_delete(arg, "short"); m_delete(arg, "maxlen");
  m_delete(arg,"magic");  m_delete(arg,"submit");
  extra_args(arg);        m_delete(arg,"split");
  if(defines->fg && !arg->fg) arg->fg=defines->fg;
  if(defines->bg && !arg->bg) arg->bg=defines->bg;
#if efun(get_font)
  if(!arg->nfont) arg->nfont=defines->nfont;
#endif
  if(!arg->font) arg->font=defines->font
#if !efun(get_font)
		   ||QUERY(default_font)
#endif
		   ;

  int num = find_or_insert( arg );

  if(!short)
    return query_location()+num+"/";
  else
    return (string)num;
}

string tag_graphicstext(string t, mapping arg, string contents,
			object id, object foo, mapping defines)
{
// Allow <accessed> and others inside <gtext>.


  if(arg->help)
    return register_module()[2];

#if efun(_static_modules)
  contents = parse_rxml(contents, id, foo, defines);
#else
  contents = parse_rxml(contents, id, foo);
#endif

  string pre, post, defalign, gt, rest, magic;
  int i, split;

 // No images here, let's generate an alternative..
  if(!id->supports->images || id->prestate->noimages)
  {
    if(!arg->split) contents=replace(contents,"\n", "\n<br>\n");
    if(arg->submit) return "<input type=submit name=\""+(arg->name+".x")+"\" value=\""+contents+"\">";
    switch(t)
    {
     case "gtext":
     case "anfang":
      if(arg->href)
	return "<a href=\""+arg->href+"\">"+contents+"</a>";
      return contents;
     default:
      if(sscanf(t, "%s%d", t, i)==2)
	rest="<h"+i+">"+contents+"</h"+i+">";
      else
	rest="<h1>"+contents+"</h1>";
      if(arg->href)
	return "<a href=\""+arg->href+"\">"+rest+"</a>";
      return rest;
      
    }
  }

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
  
  string lp, url, ea;

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
#if efun(get_font)
  if(!arg->nfont) arg->nfont=defines->nfont;
#endif
  if(!arg->font) arg->font=defines->font
#if !efun(get_font)
		   ||QUERY(default_font)
#endif
		   ;
  if(!arg->bold) arg->bold=defines->bold;
  if(!arg->italic) arg->italic=defines->italic;
  if(!arg->black) arg->black=defines->black;
  if(!arg->narrow) arg->narrow=defines->narrow;

  if(arg->split)
  {
    split=1;
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
    array res = ({pre});
    string pre = query_location()+num+"/";

    if(lp) res+=({ lp });
    
    gt=replace(gt, "\n", " ");
    
    foreach(gt/" "-({""}), word)
    {
      array size = write_text(num,word,1,id);
      res += ({ "<img _parsed=1 border=0 alt=\""+replace(word,"\"","'")
		  +"\" src=\""+pre+quote(word)+"\" width="+
		  size[0]+" height="+size[1]+" "+ea+">\n"
		  });
    }
    if(lp) res+=({ "</a>"+post });
    return res*"";
  }
  
  array size = write_text(num,gt,1,id);
  if(!size) {
    return ("<font size=+1><b>Missing font or other similar error -- "
	    "failed to render text</b></font>");
  }
  if(magic)
  {
    string res = "";
    if(!arg->fg) arg->fg=defines->link||"#0000ff";
    arg = mkmapping(indices(arg), values(arg));
    if(arg->fuzz)
    {
      if(arg->fuzz != "fuzz")
	arg->glow = arg->fuzz;
      else
	arg->glow = arg->fg;
    }
    arg->fg = defines->alink||"#ff0000";
    if(arg->bevel) arg->pressed=1;

    int num2 = find_or_insert(arg);
    array size = write_text(num2,gt,1,id);

    if(!defines->magic_java) res = magic_javascript_header(id);
    defines->magic_java="yes";

    return res +
      magic_image(url||"", size[0], size[1], "i"+(defines->mi++),
		  query_location()+num+"/"+quote(gt),
		  query_location()+num2+"/"+quote(gt),
		  (arg->alt?arg->alt:replace(gt, "\"","'")),
		  (magic=="magic"?0:magic),
		  id,input?na||"submit":0,ea);
  }
  if(input)
    return (pre+"<input type=image name=\""+na+"\" border=0 alt=\""+
	    (arg->alt?arg->alt:replace(gt,"\"","'"))+
	    "\" src="+query_location()+num+"/"+quote(gt)
	    +" align="+(al || defalign)+ea+
	    " width="+size[0]+" height="+size[1]+">"+rest+post);
  return (pre+(lp?lp:"")+
	  "<img _parsed=1 border=0 alt=\""+
	  (arg->alt?arg->alt:replace(gt,"\"","'")+"\"")
	  +"\" src=\""+
	  query_location()+num+"/"+quote(gt)+"\" "+ea
	  +" align="+(al || defalign)+
	  " width="+size[0]+" height="+size[1]+">"+rest+(lp?"</a>":"")+post);
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

string tag_body(string t, mapping args, object id, object file,
		mapping defines)
{
  int cols,changed;
  if(args->bgcolor||args->text||args->link||args->alink
     ||args->background||args->vlink)
    cols=1;

#define FIX(Y,Z,X) do{if(!args->Y){if(cols){defines->X=Z;args->Y=Z;changed=1;}}else{defines->X=args->Y;if(args->Y[0]!='#'){args->Y=ns_color(parse_color(args->Y));changed=1;}}}while(0)

  if(!search(id->client*"","Mosaic"))
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
  if(changed) return ("<body "+make_args(args)+">");
}


string tag_fix_color(string tagname, mapping args, object id, object file,
		     mapping defines)
{
  int changed;

  if(!id->misc->colors)
    id->misc->colors = ({ ({ defines->fg, defines->bg, tagname }) });
  else
    id->misc->colors += ({ ({ defines->fg, defines->bg, tagname }) });
#undef FIX
#define FIX(X,Y) if(args->X){defines->Y=args->X;if(args->X[0]!='#'){args->X=ns_color(parse_color(args->X));changed = 1;}}

  FIX(bgcolor,bg);
  FIX(text,fg);
  FIX(color,fg);
  if(changed) return ("<"+tagname+" "+make_args(args)+">");
  return 0;
}

string pop_color(string tagname,mapping args,object id,object file,
		 mapping defines)
{
  array c = id->misc->colors;
  sscanf(tagname, "/%s", tagname);
  while(c && sizeof(c))
  {
    if(c[-1][2]==tagname)
    {
      defines->fg = c[-1][0];
      defines->bg = c[-1][1];
      break;
    }
    c = c[..sizeof(c)-2];
  }
  id->misc->colors = c;
}

mapping query_tag_callers()
{
  return ([ "gtext-id":tag_gtext_id, ]) | (query("speedy")?([]):
  (["font":tag_fix_color,
    "body":tag_body,
    "table":tag_fix_color,
    "tr":tag_fix_color,
    "td":tag_fix_color,
    "layer":tag_fix_color,
    "ilayer":tag_fix_color,
    "/td":pop_color,
    "/tr":pop_color,
    "/font":pop_color,
    "/body":pop_color,
    "/table":pop_color,
    "/layer":pop_color,
    "/ilayer":pop_color,
   ]));
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
