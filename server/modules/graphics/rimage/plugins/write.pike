constant doc = "Write some 'text' at 'xpos', 'ypos', 'height' pixels high using 'font'. This function is intended for use on the _mask_ channel, not the image channel. The text is always white on black.";

void render( mapping args, mapping this, string channel, object id, object m)
{
  int xp = (int)args->xpos;
  int yp = (int)args->ypos;
  int height = (int)args->height;
  object font = resolve_font( args->font || "default" );

  object txt = font->write( args->text || "no text" );
  if(height) txt = txt->scale(0,height);

  int xs = txt->xsize(), ys = txt->ysize();
  
  if(args->replace || !this[channel]) 
    this[channel] = Image.image( xs+xp, ys+yp );
  if(this[channel]->xsize() < xs+xp ||
     this[channel]->ysize() < xs+xp)
    this[channel]=this[channel]->copy(0,0,max(xs+xp,this[channel]->xsize()),
				      max(xs+xp,this[channel]->ysize()));

  this[channel]->paste_alpha_color( txt, 255,255,255, xp, yp );
}
