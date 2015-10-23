// This file is part of rimage. Copyright © 1998 - 2009, Roxen IS.

constant doc =
"If there already is an image in the channel, add a 'width' x 'height' "
"pixels big solid box with the color 'color' at 'xpos', 'ypos', otherwise"
" create the channel as a 'width' x 'height' solid  'color' colored box";

void render( mapping args, mapping this, string channel, object id, object m )
{
  int xp = (int)args->xpos;
  int yp = (int)args->ypos;
  int xs = (int)(args->width  || (this->xsize()-xp));
  int ys = (int)(args->height || (this->ysize()-yp));
  array (int) color = Colors.parse_color( args->color || "black" );
  object i = m->get_channel( this, channel );
  object a = m->get_channel( this, "alpha" );

  if(!args->replace && i)
  {
    if(!args["nomask"] && channel == "image")
    {
      if(!a)
        a = Image.image( xs+xp,ys+yp, 0,0,0 );
      a->box( xp,yp,xp+xs-1,yp+ys-1, 255,255,255, (int)(255-((int)(args->alpha)*2.55)) );
      m->set_channel( this, "alpha", a );
    }
    i->box( xp,yp,xp+xs-1,yp+ys-1, @color, (int)(255-((int)(args->alpha)*2.55)) );
    m->set_channel( this, channel, i );
  }
  else
  {
    if(!args["nomask"] && channel == "image")
    {
      int av = (int)(255-((int)(args->alpha)*2.55));
      a = Image.image( xs,ys, av,av,av);
    } else if(a)
      a = 0;
    this->set_image( i, a );
  }
}
