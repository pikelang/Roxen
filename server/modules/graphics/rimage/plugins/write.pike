// This file is part of rimage. Copyright © 1998 - 2009, Roxen IS.

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

  object i = m->get_channel( this, channel );
  if(args->replace || !i)
    i = Image.image( xs+xp, ys+yp );
  m->verify_size( i, xs+xp, ys+yp )
    ->paste_alpha_color( txt, 255,255,255, xp, yp );
  m->set_channel( this, channel, i );
}
