
#if !efun(make_matrix)
private mapping (int:array(array(int))) matrixes = ([]);
array (array(int)) make_matrix(int size)
{
  if(matrixes[size]) return matrixes[size];
  array res = allocate(size, allocate)(size);
  for(int i=0; i<size; i++)
    for(int j=0; j<size; j++)
      res[i][j] = (int)max((float)size/2.0-sqrt((size/2-i)*(size/2-i) + (size/2-j)*(size/2-j)),0);
  return matrixes[size] = res;
}
#endif

string fix_relative(string file, string bd)
{
  if(file != "" && file[0] == '/') return file;
  return combine_path(bd+"/",file);
}

Image.Image blur(Image.Image img, int amnt)
{
  img->setcolor(0,0,0);
  img = img->autocrop(amnt, 0,0,0,0, 0,0,0);

  for(int i=0; i<amnt; i++)
    img = img->apply_matrix( make_matrix((int)sqrt(img->ysize()+20)));
  return img;
}

Image.Image outline(Image.Image on, Image.Image with,
		       array (int) color, int radie, int x, int y)
{
  int steps=10;
  for(int j=0; j<=steps; j++)
    on->paste_alpha_color(with, @color,
			  (int)(0.5+x-(sin((float)j/steps*3.145*2)*radie)),
			  (int)(0.5+y-(cos((float)j/steps*3.145*2)*radie)));
  return on;
}

Image.Image do_tile(Image.Image source, int xsize, int ysize)
{
  Image.Image res = Image.Image(xsize, ysize);
  for(int x=0; x<xsize; x+=source->xsize())
    for(int y=0; y<ysize; y+=source->ysize())
      res->paste(source, x, y);
  return res;
}

Image.Image do_mirrortile(Image.Image source, int xsize, int ysize)
{
  Image.Image quad = Image.Image(source->xsize()*2,source->ysize()*2);
  quad->paste(source,0,0);
  quad->paste(source->mirrorx(),source->xsize(),0);
  quad->paste(source->mirrory(),0,source->ysize());
  quad->paste(source->mirrorx()->mirrory(),source->xsize(),
	      source->ysize());
  return do_tile(quad, xsize, ysize);
}

array white = ({ 255,255,255 });
array lgrey = ({ 200,200,200 });
array grey = ({ 128,128,128 });
array black = ({ 0,0,0 });

Image.Image bevel(Image.Image in, int width, int|void invert)
{
  int h=in->ysize();
  int w=in->xsize();

  Image.Image corner = Image.Image(width+1,width+1);
  Image.Image corner2 = Image.Image(width+1,width+1);
  Image.Image pix = Image.Image(1,1);

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

#if !constant(open)
Stdio.File open(string file, string mode)
{
  Stdio.File f = Stdio.File();
  if(f->open(file, mode))
    return f;
  return 0;
}
#endif


#if constant(roxen)
Image.Image last_image;      // Cache the last image for a while.
string last_image_name;
Image.Image load_image(string f,string bd, object|void id)
{
  if(last_image_name == f && last_image) return last_image->copy();
  string data;
  Stdio.File file;
  Image.Image img=Image.Image();

  if(!(file=open(fix_relative(f,bd),"r")) || (!(data=file->read())))
    return 0;

  //Image._decode( data ) here

  if(!img) return 0;
  last_image = img; last_image_name = f;
  return img->copy();
}
#endif /* constant(roxen) */


//  Returns error mapping if subresources (e.g. background or texture)
//  cannot be loaded.
array(Image.Image)|mapping make_text_image(
  mapping args, Image.Font font, string text, RequestID id)
{
  if( args->encoding )
    text = roxen.decode_charset(args->encoding,text);
  mapping text_info;
  if(font->write_with_info)
    text_info = font->write_with_info(text/"\n", (int)args->oversampling);
  else
    text_info = ([ "img" : font->write(@(text/"\n")) ]);
  Image.Image text_alpha= text_info->img;
  int extend_alpha = 0;
  int overshoot = (int)text_info->overshoot;
  int xoffset=0, yoffset= -overshoot;

  if(!text_alpha->xsize() || !text_alpha->ysize())
    text_alpha = Image.Image(10,10, 0,0,0);

  if(int op=((((int)args->opaque)*255)/100)) // Transparent text...
    text_alpha=text_alpha->color(op,op,op);

  int txsize=text_alpha->xsize();
  int tysize=text_alpha->ysize(); // Size of the text, in pixels.

  int xsize=txsize; // image size, in pixels
  int ysize=tysize - overshoot;

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
    xsize+=(int)args->bshadow+6;
    ysize+=(int)args->bshadow+5;
  }

  if(args->fadein)
  {
    xsize+=6;
    ysize+=6;
    xoffset+=3;
    yoffset+=3;
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

  array (int) bgcolor = parse_color(args->bgcolor);
  array (int) fgcolor = parse_color(args->fgcolor);

  Image.Image background,foreground;

#if constant(Sitebuilder)
  if (Sitebuilder.sb_start_use_imagecache) {
    Sitebuilder.sb_start_use_imagecache(args, id);
  }
#endif

  if(args->texture)
  {
    extend_alpha = 1;
    mapping err = ([ ]);
    Image.Image t = roxen.load_image(args->texture, id, err);
    if( t )
    {
      foreground = t;
      if(args->tile)
      {
	foreground = do_tile(foreground, xsize, ysize);
      } else if(args->mirrortile) {
	foreground = do_mirrortile(foreground, xsize, ysize);
      }
    } else {
      if (err->error == Protocols.HTTP.HTTP_UNAUTH)
	return err;
      werror("Failed to load image for "+args->texture+"\n");
    }
  }
  int background_is_color;
  Image.Image alpha;
  mapping err = ([ ]);
  mapping(string:string|Image.Image) bg_info =
    args->background && roxen.low_load_image(args->background, id, err);
  if (!bg_info && err->error == Protocols.HTTP.HTTP_UNAUTH)
    return err;
  if (bg_info) {
    background = bg_info->img;
  } else if (args->background && sizeof(args->background) > 1) {
    if (background =
	Image.Image(xsize,ysize, @(parse_color(args->background[1..]))))
      background_is_color = 1;
  }
  if (background) {
    extend_alpha = 1;
    if (args->alpha && background_is_color) {
      if (alpha = roxen.load_image(args->alpha, id, err)) {
	xsize=max(xsize,alpha->xsize());
	ysize=max(ysize,alpha->ysize());
	if((float)args->scale)
	  alpha=alpha->scale(1/(float)args->scale);
	background=Image.Image(xsize,ysize, @(parse_color(args->background[1..])));
      } else {
	if (err->error == Protocols.HTTP.HTTP_UNAUTH)
	  return err;
      }
    } else if (bg_info) {
      alpha = bg_info->alpha;
      if((float)args->scale >= 0.1 && alpha)
	alpha = alpha->scale(1.0/(float)args->scale);
    }

    if((float)args->scale >= 0.1 && !alpha)
      background = background->scale(1.0/(float)args->scale);

    if(args->tile)
    {
      background = do_tile(background, xsize, ysize);
      if (alpha) alpha = do_tile(alpha, xsize, ysize);
    } else if(args->mirrortile) {
      background = do_mirrortile(background, xsize, ysize);
      if (alpha) alpha = do_mirrortile(alpha, xsize, ysize);
    }
    xsize = max(xsize,background->xsize());
    ysize = max(ysize,background->ysize());

    if(alpha)
      background->paste_alpha_color(alpha->invert(),@bgcolor);

  } else
    background = Image.Image(xsize, ysize, @bgcolor);

#if constant(Sitebuilder)
  if (Sitebuilder.sb_end_use_imagecache) {
    Sitebuilder.sb_end_use_imagecache(args, id);
  }
#endif
  
  int xsize2 = (int)args->xsize || xsize;
  int ysize2 = (int)args->ysize || ysize;
  switch(lower_case(args->talign||"left")) {
  case "center":
    xoffset = (xsize2/2 - txsize/2);
    yoffset = (ysize2/2 - tysize/2);
    break;
  case "right":
    xoffset = (xsize2 - txsize);
    break;
       case "left":
  }
  
  if(args->move)
  {
    int dx,dy;
    if(sscanf(args->move, "%d,%d", dx, dy)!=2)
      m_delete(args,"move");
    else {
      xoffset += dx;
      yoffset += dy;
    }
  }

  if(!zero_type(args["baselineoffset"]) && text_info->ascender)
    yoffset += (-text_info->ascender + (int)args["baselineoffset"]);
  
  if(args->border)
  {
    extend_alpha = 1;
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
    if(!args->rescale) {
      background = background->copy(0,0,xs-1,ys-1);
      if(alpha)
       alpha = alpha->copy(0,0,xs-1,ys-1);
    } else {
      background = background->scale(xs, ys);
      if(alpha)
	alpha = alpha->scale(xs, ys);
    }
  }

  if(args->bgturbulence)
  {
    extend_alpha = 1;
    array (float|array(int)) arg=({});
    foreach((args->bgturbulence/";"),  string s)
    {
      array q= s/",";
      if(sizeof(q)<2) arg+=({ ((float)s)||0.2, ({ 255,255,255 }) });
      arg+=({ ((float)q[0])||0.2, parse_color(q[1]) });
    }
    background=background->turbulence(arg);
  }

  if(args->bevel) {
    extend_alpha = 1;
    background = bevel(background,(int)args->bevel,!!args->pressed);
  }

  if(args->textbox) // Draw a text-box on the background.
  {
    extend_alpha = 1;
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
    extend_alpha = 1;
    array(string) a = (args->ghost/",");
    if (sizeof(a) < 2) {
      // Bad argument.
    } else {
      int sdist = (int)(a[0]);
      int bl=(int)(a[1]);
      array(int)clr=parse_color(a[-1]);
      int j;
      Image.Image ta = text_alpha->copy();
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
    extend_alpha = 1;
    int sd = ((int)args->shadow+10)*2;
    int sdist = ((int)(args->shadow/",")[-1])+2;
    Image.Image ta = text_alpha->copy();
    ta = ta->color(255-sd,255-sd,255-sd);
    array sc = parse_color(args->scolor||"black");
    background->paste_alpha_color(ta,sc[0],sc[1],sc[2],
				  xoffset+sdist,yoffset+sdist);
  }

  if(args->bshadow)
  {
    extend_alpha = 1;
    int sdist = (int)(args->bshadow)+1;
    int xs,ys;
    xs = text_alpha->xsize()+sdist*2+4;
    ys = text_alpha->ysize()+sdist*2+4;
    Image.Image ta = Image.Image(xs+sdist*2,ys+sdist*2);
    array sc = parse_color(args->scolor||"black");

    ta->paste_alpha_color(text_alpha,255,255,255,sdist,sdist);
    ta = ta->blur( min(sdist,1) );

    background->paste_alpha_color(ta,sc[0],sc[1],sc[2],
				  xoffset+sdist,yoffset+sdist);
  }

  if(args->glow)
  {
    extend_alpha = 1;
    int amnt = (int)(args->glow/",")[-1]+2;
    array (int) blurc = parse_color((args->glow/",")[0]);
    background->paste_alpha_color(blur(text_alpha, amnt),@blurc,
				  xoffset-amnt, yoffset-amnt);
  }

  if(args->chisel) {
    extend_alpha = 1;
    foreground=text_alpha->apply_matrix(({ ({8,1,0}),
					   ({1,0,-1}),
					   ({0,-1,-8}) }),
					128,128,128, 15 )
      ->color(@fgcolor);
  }

  if(!foreground)  foreground=Image.Image(txsize, tysize, @fgcolor);
  if(args->textscale)
  {
    extend_alpha = 1;
    string c1="black",c2="black",c3="black",c4="black";
    sscanf(args->textscale, "%s,%s,%s,%s", c1, c2, c3, c4);
    foreground->tuned_box(0,0, txsize,tysize,
			  ({parse_color(c1),parse_color(c2),parse_color(c3),
			      parse_color(c4)}));
  }
  if(args->outline) {
    extend_alpha = 1;
    outline(background, text_alpha, parse_color((args->outline/",")[0]),
	    ((int)(args->outline/",")[-1])+1, xoffset, yoffset);
  }

  if(args->textbelow)
  {
    extend_alpha = 1;
    array color = parse_color(args->textbelow);

    background->setcolor( @color );
    yoffset = background->ysize();
    background = background->copy(0,0,
				  max(background->xsize()-1,
				      foreground->xsize()-1),
				  background->ysize()-1
				  +foreground->ysize());
    xoffset = (background->xsize()-foreground->xsize())/2;
  }

  background->paste_mask(foreground, text_alpha, xoffset, yoffset);
  foreground = 0;
  text_alpha->setcolor (0, 0, 0);
  text_alpha = text_alpha->copy (-xoffset, -yoffset,
				 background->xsize() - xoffset - 1,
				 background->ysize() - yoffset - 1);

  if (extend_alpha && !args["no-auto-alpha"]) {
    Image.Image ext = background->distancesq( @bgcolor );
    ext->gamma( 8 );
    text_alpha |= ext;
  } else if(args["no-auto-alpha"] && alpha)
    text_alpha |= alpha;

  if(args->rotate)
  {
    string c;
    if(sscanf(args->rotate, "%*d,%s", c)==2)
       background->setcolor(@parse_color(c));
    else
       background->setcolor(@bgcolor);
    background = background->rotate((float)args->rotate);
    text_alpha = text_alpha->rotate((float)args->rotate);
  }

  if(args->crop) {
    mixed dims = background->find_autocrop();
    background = background->copy (@dims);
    text_alpha = text_alpha->copy (@dims);
  }
  return ({background, text_alpha});
}
