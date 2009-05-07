// This file is part of rimage. Copyright © 1998 - 2009, Roxen IS.

constant doc=" corners='col1,col2,col3,col4' xpos= ypos= width= height=";
void render( mapping args, mapping this, string channel, object id, object m)
{
  int xs = (int)(args->width  || this->width);
  int ys = (int)(args->height || this->height);
  int xp = (int)args->xpos;
  int yp = (int)args->ypos;
  object i = m->get_channel( this, channel );

  if(!i)
    i = Image.image( xs+xp, ys+yp );
  m->set_channel( this, channel,
                  i->tuned_box( xp,yp,xp+xs-1,yp+ys-1,
                                Array.map((args->corners||"black,white,black,white")/",",
                                          Colors.parse_color)));
}
