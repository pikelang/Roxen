inherit "roxenlib";
string doc="Load an image. NOTE: If the current layer is the 'image' layer this function can modify _both_ the mask and image layers if the loaded image has a alpha channel. Specify the image with the 'file' argument. The image must recide in roxen's virtual filesystem. An optional 'type' argument can be specified. Supported types are: "+
String.implode_nicely( ({
#if constant(Image.GIF.decode)
		      "gif",
#endif
#if constant(Image.JPEG.decode)
		      "jpeg",
#endif
#if constant(Image.PNG.decode)
		      "png",
#endif
#if constant(Image.PNM.decode)
		      "pnm",
#endif
#if constant(Image.XFace.decode)
		      "xface",
#endif
		      }) ) + 
". If no type is specified it is autodetected.";


int load_gif(string data, mapping this, string channel )
{
#if constant(Image.GIF._decode)
  catch {
    array a = Image.GIF._decode( data );
    object img_res = Image.image(a[0],a[1]);
    object alpha;
    if(channel == "image")
      alpha = Image.image(a[0],a[1]);
    foreach(a[4..], array b)
    {
      if(b[0]==Image.GIF.RENDER)
	if(b[4])
	{
	  img_res->paste_mask( b[3], b[4], b[1], b[2] );
	  if(channel == "image")
	    alpha->paste_alpha_color( b[4], 255,255,255, b[1],b[2] );
	}
	else
	{
	  img_res->paste( b[3],b[1],b[2] );
	  if(channel == "image")
	    alpha = Image.image( a[1],a[1], 255,255,255 );
	}
    }
    
    if(channel == "image")
    {
      this[channel] = img_res;
      this->mask = alpha;
    } else
      this[channel] = img_res;
    return 1;
  };
#endif
  return 0;
}

int load_jpg(string data, mapping this, string channel)
{
#if constant(Image.JPEG.decode)
  catch {
    object i = Image.JPEG.decode( data );
    if(i) {
      this[channel] = i;
      return 1;
    }
  };
#endif
}

int load_pnm(string data, mapping this, string channel)
{
#if constant(Image.PNM.decode)
  catch {
    object i = Image.PNM.decode( data );
    if(i) {
      this[channel] = i;
      return 1;
    }
  };
#endif
}

int load_png(string data, mapping this, string channel)
{
#if constant(Image.PNG._decode)
  catch {
    mixed i = Image.PNG._decode( data );
    if(i) {
      if(channel == "image")
      {
	this->image = i->image;
	if(i->alpha)
	  this->mask = i->alpha;
      } else
	this[channel] = i->alpha;
      return 1;
    }
  };
#endif
}

int load_xface(string data, mapping this, string channel)
{
#if constant(Image.XFace.decode)
  catch {
    object i = Image.XFace.decode( data );
    if(i) {
      this[channel] = i;
      return 1;
    }
  };
#endif
}

int load_jpeg(string data, mapping this, string channel)
{
#if constant(Image.JPEG.decode)
  catch {
    object i = Image.JPEG.decode( data );
    if(i) {
      this[channel] = i;
      return 1;
    }
  };
#endif
}

void low_render( mapping args, mapping this, 
		 string channel, object id, object m )
{
  if(!args->file) return;
  args->file = fix_relative( args->file, id );
  string data = id->conf->try_get_file( args->file,id );
  array (object) i;

  if(data)
  {
    if(args->type)
    {
      switch(lower_case(args->type))
      {
       case "gif": load_gif( data, this, channel ); break;
       case "jpeg":
       case "jpg": load_jpeg( data, this, channel ); break;
       case "png": load_png( data, this, channel ); break;
       case "pnm": load_pnm( data, this, channel ); break;
       case "xface": load_xface( data, this, channel ); break;
      }
    } else {
      if(load_gif(data, this, channel)) return;
      if(load_jpeg( data, this, channel )) return;
      if(load_png( data, this, channel )) return;
      if(load_pnm( data, this, channel )) return;
      if(load_xface( data, this, channel )) return;
    }
  }
}

void render( mapping args, mapping this, 
	     string channel, object id, object m )
{
  mapping t = ([]);
  int xp = (int)args->xpos;
  int yp = (int)args->ypos;
  low_render(args, t, channel, id, m);

  if(!t->image && !t->mask) return;

  if(t->mask)
  {
    int xs = t->mask->xsize()+xp, ys=t->mask->ysize()+yp;
    if(this->mask)
    {
      xs = max(this->mask->xsize(), xs);
      ys = max(this->mask->ysize(), ys);
      if(this->mask->xsize() < xs || this->mask->ysize() < ys)
	this->mask = this->mask->copy(0,0,xs-1,ys-1);
      this->mask->paste_alpha_color( t->mask, 255, 255, 255, xp, yp );
    } else
      this->mask=t->mask->copy(-xp,-yp,t->mask->xsize()-1,t->mask->ysize()-1);
  }

  if(t->image)
  {
    int xs = t->image->xsize(), ys=t->image->ysize();
    if(!t->mask)
      t->mask = Image.image( xs,ys, 255,255,255 );
    if(this->image)
    {
      int xx = max(this->image->xsize(), xs+xp);
      int yy = max(this->image->ysize(), ys+xp);
      if(this->image->xsize() < xx || this->image->ysize() < yy)
	this->image = this->image->copy(0,0,xx-1,yy-1);
      this->image->paste_mask( t->image, t->mask, xp, yp );
    } else
      this->image=t->image->copy(-xp,-yp,xs-1,ys-1);
  }
}
