
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


string fix_relative(string file, string bd)
{
  if(file != "" && file[0] == '/') return file;
  return combine_path(bd+"/",file);
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

#if !constant(open)
object open(string file, string mode)
{
  object f = Stdio.File();
  if(f->open(file, mode))
    return f;
  return 0;
}
#endif

object last_image;      // Cache the last image for a while.
string last_image_name;
object load_image(string f,string bd, object|void id)
{
  if(last_image_name == f && last_image) return last_image->copy();
  string data;
  object file;
  object img
#if !constant(Image.PNM)
  =Image.image()
#endif
    ;
#if constant(roxen)  
  if(!(data=roxen->try_get_file(fix_relative(f, bd),id)))
#endif
    if(!(file=open(fix_relative(f,bd),"r")) || (!(data=file->read())))
      return 0;
//  werror("Read "+strlen(data)+" bytes.\n");
#if constant(Image.PNM.decode)
  catch { if(!img) img = Image.PNM.decode( data ); };
#endif
#if constant(Image.GIF.decode)
  catch { if(!img) img = Image.GIF.decode( data ); };
#endif
#if constant(Image.JPEG.decode)
  catch { if(!img) img = Image.JPEG.decode( data ); };
#endif
#if !constant(Image.PNM.decode)
  if (catch { if(!img->frompnm(data)) return 0;}) return 0;
#endif
  if(!img) return 0;
  last_image = img; last_image_name = f;
  return img->copy();
}

object make_text_image(mapping args, object font, string text,string basedir,
		       object|void id)
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

  
  array (int) bgcolor = Colors.parse_color(args->bg);
  array (int) fgcolor = Colors.parse_color(args->fg);

  object background,foreground;


  if(args->texture) {
    foreground = load_image(args->texture,basedir,id);
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

  if((args->background) && 
     (background=load_image(args->background,basedir,id))) {
    background = background;
    if((float)args->scale >= 0.1)
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
  } else
    background = Image.image(xsize, ysize, @bgcolor);

  if(args->border)
  {
    int b = (int)args->border;
    background->setcolor(@Colors.parse_color((args->border/",")[-1]));

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
    if(args->scale == "scale")
      background = background->scale(xs,ys);
    else
      background = background->copy(0,0,xs-1,ys-1);
  }

  xsize = background->xsize();
  ysize = background->ysize();
  switch(lower_case(args->talign||"left")) 
  {
   case "center":
     xoffset = (xsize/2 - txsize/2);
     yoffset = (ysize/2 - tysize/2);
     break;
   case "right":
     xoffset = (xsize - txsize);
     break;
   case "left":
  }

  
  if(args->turbulence)
  {
    array (float|array(int)) arg=({});
    foreach((args->turbulence/";"),  string s)
    {
      array q= s/",";
      if(sizeof(q)<2) args+=({ ((float)s)||0.2, ({ 255,255,255 }) });
      arg+=({ ((float)q[0])||0.2, Colors.parse_color(q[1]) });
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
				  @Colors.parse_color(bg)),
			    255-(alpha*255/100),xoffset-border,yoffset-border);
  }

  if(args->ghost)
  { // Francesco..
    int sdist = (int)args->ghost;
    int bl=(int)(args->ghost/",")[1];
    array(int)clr=Colors.parse_color((args->ghost/",")[-1]);
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
    array sc = Colors.parse_color(args->scolor||"black");
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
    array sc = Colors.parse_color(args->scolor||"black");

    ta->paste_alpha_color(text_alpha,255,255,255,sdist,sdist);
    ta = blur(ta, MIN((sdist/2),1))->color(256,256,256);

    background->paste_alpha_color(ta,sc[0],sc[1],sc[2],
				  xoffset+sdist,yoffset+sdist);
  }

  if(args->glow)
  {
    int amnt = (int)(args->glow/",")[-1]+2;
    array (int) blurc = Colors.parse_color((args->glow/",")[0]);
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
			  ({Colors.parse_color(c1),Colors.parse_color(c2),Colors.parse_color(c3),
			      Colors.parse_color(c4)}));
  }
  if(args->outline)
    outline(background, text_alpha, Colors.parse_color((args->outline/",")[0]),
	    ((int)(args->outline/",")[-1])+1, xoffset, yoffset);

  background->paste_mask(foreground, text_alpha, xoffset, yoffset);

  if((float)args->scale != 0.0)
    if((float)args->scale <= 2.0)
      background = background->scale((float)args->scale);


  foreground = text_alpha = 0;


  if(args->rotate)
  {
    string c;
    if(sscanf(args->rotate, "%*d,%s", c)==2)
       background->setcolor(@Colors.parse_color(c));
    else
       background->setcolor(@bgcolor);
    background = background->rotate((float)args->rotate);
  }

  if(args->crop) background = background->autocrop();
  
  return background;
}

