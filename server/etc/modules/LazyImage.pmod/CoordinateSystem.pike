inherit LazyImage.LazyImage;
constant operation_name = "coordinate-system";

//! Used args:
//!
//!   xsize: Image horizontal size in pixels (REQUIRED)
//!   ysize: Image vertical size in pixels (REQUIRED)
//!   color: Image color. Defaults to black.
//!   mode: The layer mode. Normal is default.
//!   transparent: If given, the layer will be fully transparent.
//!                The default is a fully opaque layer.


protected
{
  mapping parse_data(string d)
  {
    mapping data = ([]);
    mapping current_data = ([]);
    Parser.HTML p = Parser.HTML();
    p->xml_tag_syntax( 2 );
    p->add_container( "x", lambda(Parser.HTML p, mapping a, string c) {
			     current_data = ([]);
			     data->x = current_data;
			     current_data->args = a;
			     return c;
			   } );
    p->add_container( "y", lambda(Parser.HTML p, mapping a, string c) {
			     current_data = ([]);
			     data->y = current_data;
			     current_data->args = a;
			     return c;
			   } );

    p->add_container( "labels", lambda( Parser.HTML p,mapping a, string c )
				{
				  if( (!c||!strlen(c)) && !a->format )
				    RXML.parse_error( "labels requires "
						      "either content or a "
						      "format argument\n");
				  current_data->labels += ({({ a, c })});
				} );
    p->add_container( "ticks",  lambda( Parser.HTML p,mapping a, string c )
				{
				  current_data->ticks += ({a});
				  return c;
				} );

    p->add_container( "frame",  lambda( Parser.HTML p,mapping a, string c )
				{
				  if( data->frame )
				    RXML.parse_error(
				      "Frame defined twice\n");
				  data->frame = a;
				  return c;
				} );

    p->feed( d )->finish();
    return data;
  }
    
  LazyImage.Layers process( LazyImage.Layers layers )
  {
    mapping data = args->parsed_data;

    Image.Layer lab_l = Image.Layer();
    int x_inner = translate_coordinate( args->xsize,0,layers ),
      y_inner = translate_coordinate( args->ysize,0,layers );

    lab_l->set_misc_value( "name", args->name||"coordinate-system.labels" );

    lab_l->set_mode( translate_mode( args->mode ) );
    int xo = translate_coordinate( args->xoffset, lab_l,layers),
      yo = translate_coordinate( args->yoffset, lab_l,layers);
    lab_l->set_offset( xo, yo );


    // Now it's time to actually draw..

    string do_sprintf( string format, mixed data )
    {
      string f = "f";
      sscanf(format-"%%", "%*s%%%*s%[bduoxXcfgGeEFtsqOHn]", f);
      switch( f )
      {
	case "n":
	case "t":
	case "O":
	  // mixed
	  return sprintf( format, data );
	case "s":
	case "q":
	case "H":
	  // string
	  return sprintf( format, (string) data );
	case "b":
	case "d":
	case "u":
	case "o":
	case "x":
	case "X":
	case "c":
	  // int
	  return sprintf( format, (int) data );
	case "f":
	case "g":
	case "G":
	case "e":
	case "E":
	case "F":
	default:
	  // float
	  return sprintf( format, (float) data );
      }
    };
      
    array(array(Image.Image)) xlabels = ({});
    array(array(Image.Image)) ylabels = ({});

#define LABELS(X)							   \
      if( data->X && data->X->labels )					   \
      {									   \
	mapping d   = data->X;						   \
	foreach( d->labels||({}), array ld )				   \
	{								   \
	  mapping l = ld[0];						   \
	  array ll = ({});						   \
	  string c = String.trim_all_whites(ld[1]);			   \
									   \
	  float step = translate_coordinate_f( l->step,lab_l,layers );	   \
	  float le = translate_coordinate_f( l->end,lab_l,layers );	   \
	  float ls = translate_coordinate_f( l->start,lab_l,layers );	   \
									   \
	  if( !l->format )						   \
	    ll = map( c/"\n", String.trim_all_whites );			   \
	  else								   \
	  {								   \
	    if( step > 0.0 )						   \
	      for( float p=ls; p <= le; p += step )			   \
		ll += ({ do_sprintf( l->format, p ) });			   \
	    else if( step < 0.0 )					   \
	      for( float p=ls; p >= le; p += step )			   \
		ll += ({ do_sprintf( l->format, p ) });			   \
	  }								   \
									   \
	  string font =							   \
	    (l->font || d->args->font || args->font || "default")+" "+	   \
	    (translate_coordinate(l->fontsize||				   \
				  d->args->fontsize||			   \
				  args->fontsize,0,layers)||32);	   \
	  Font f = resolve_font( font );				   \
									   \
	  if( !f )							   \
	    RXML.parse_error("Cannot find the font ("+font+")\n");	   \
	  array labels=map(map(ll,parse_variables,lab_l,layers ),f->write);\
									   \
	  if( l->rotate )						   \
	    labels=labels->rotate(translate_coordinate_f(l->rotate,lab_l,layers), \
                                  255,255,255)->autocrop();		   \
          else								   \
   	     labels = labels->autocrop();				   \
          X##labels += ({labels});					   \
	}								   \
      }

    LABELS(x);
    LABELS(y);

#undef LABELS
      
    int xedge, yedge;
    foreach( Array.flatten(xlabels), Image.Image i )
      if( i->ysize() > yedge )
	yedge = i->ysize();
      
    foreach( Array.flatten(ylabels), Image.Image i )
      if( i->xsize() > xedge )
	xedge = i->xsize();

#define TSIZE 30
#define XPAD 10
#define YPAD 10

    int twiddle_x, twiddle_y;
    xedge += XPAD;
    yedge += YPAD;

    if( data->x &&
	translate_coordinate_f(data->x->args->start,lab_l,layers)!=0.0 )
      twiddle_x = 1;
      
    if( data->y &&
	translate_coordinate_f(data->y->args->start,lab_l,layers)!=0.0 )
      twiddle_y = 1;

    int width =  x_inner + xedge + XPAD;
    int height = y_inner + yedge + YPAD;
    Image.Image img = Image.Image(   width+(twiddle_x?TSIZE:0),
				     height+(twiddle_y?TSIZE:0),
				     0,0,0 );
    Image.Image alpha = Image.Image( width+(twiddle_x?TSIZE:0),
				     height+(twiddle_y?TSIZE:0),
				     0,0,0 );
    lab_l->set_image( img, alpha );

    /* place labels on image */
    if( data->x && data->x->labels )
    {
      mapping d   = data->x;
      int     i; 
      float   x0 = translate_coordinate_f( d->args->start,lab_l,layers );
      float   x1 = translate_coordinate_f( d->args->end,lab_l,layers );
      foreach( d->labels||({}), array ld )
      {
	mapping  l = ld[0];
	array   ll = xlabels[i++];
	float step = translate_coordinate_f( l->step,lab_l,layers );
	float   le = translate_coordinate_f( l->end,lab_l,layers );
	float   ls = translate_coordinate_f( l->start,lab_l,layers );
	Image.Color color = translate_color( l->color||
					     d->args->color||
					     args->color );
	int j;

	void place_label( float p, int i )
	{
	  if( sizeof( ll ) <= i )
	    return;
	  int x, y;
	  Image.Image lab = ll[i];
	  y = (height-yedge)+YPAD+(twiddle_y?TSIZE:0);
	  x = xedge + (twiddle_x ? TSIZE : 0 )+
	    (int)(virtual_to_screen( p, x0, x1, width-xedge-XPAD ))-
	    lab->xsize()/2;
	  img->paste( Image.Image( lab->xsize(), lab->ysize(), color ),
		      x, y );
	  alpha->paste_alpha_color( lab, Image.Color.white, x, y );
	};
	  
	if( step > 0.0 )
	  for( float p=ls; p <= le; (p += step), j++ )
	    place_label( p, j );
	else if( step < 0.0 )					     
	  for( float p=ls; p >= le; (p += step), j++ )
	    place_label( p,j );
      }
    }

      
    if( data->y && data->y->labels )					       
    {									       
      mapping d   = data->y;
      int     i; 
      float   x0 = translate_coordinate_f( d->args->start,lab_l,layers );
      float   x1 = translate_coordinate_f( d->args->end,lab_l,layers );
      foreach( d->labels||({}), array ld )
      {
	mapping  l = ld[0];
	float step = translate_coordinate_f( l->step,lab_l,layers );
	float   le = translate_coordinate_f( l->end,lab_l,layers );
	float   ls = translate_coordinate_f( l->start,lab_l,layers );
	array   ll = ylabels[i++];
	Image.Color color = translate_color( l->color||
					     d->args->color||
					     args->color );
	int j;

	void place_label( float p, int i )
	{
	  if( sizeof( ll ) <= i )
	    return;

	  int x, y;
	  Image.Image lab = ll[i];
	  int lx=lab->xsize(), ly = lab->ysize();

	  y = (int)((height-yedge-YPAD)-
		    (virtual_to_screen( p, x0, x1, height-yedge-YPAD ))
		    - ly/2)+YPAD;
	  x = (xedge-lx)-XPAD;
	  if( (x + lx > img->xsize()) 
	      || (y + ly > img->ysize())
	      || (x < 0 ) || (y < 0 ) )		// outside, skip
	    return;
	  img = img->box( x,y, x+lx-1,y+ly-1, color );
	  alpha->paste_alpha_color( lab, Image.Color.white, x, y );
	};
	  
	if( step > 0.0 )
	  for( float p=ls; p <= le; (p += step), j++ )
	    place_label( p, j );
	else if( step < 0.0 )
	  for( float p=ls; p >= le; (p += step), j++ )
	    place_label( p,j );
      }
    }

    Image.Layer frame;
    if( data->frame )
    {
      mapping a = data->frame;
      /* Draw the frame. */
      frame = Image.Layer(  );
      frame->set_image( (img=img->copy()->
			 clear(translate_color( a->color||args->color ))),
			(alpha=alpha->copy()->clear(0,0,0) ));
      frame->set_mode( translate_mode( a->mode || args->mode ) );
      frame->set_offset( translate_coordinate( args->xoffset, lab_l,layers),
			 translate_coordinate( args->yoffset, lab_l,layers)+YPAD );
      frame->set_misc_value( "name", args->name||"coordinate-system.frame" );

	
      array coords;
      int yy;
      coords =
	({
	  xedge, 0,
	  xedge, (yy=height-yedge-YPAD),
	});

      if( twiddle_y )
      {
	coords +=
	  ({
	    xedge+TSIZE/6, yy+(TSIZE/4),
	    xedge-TSIZE/6, yy+(TSIZE/4)*2,
	    xedge, yy+(TSIZE/4)*3,
	    xedge, yy+TSIZE,
	  });
	yy += TSIZE;
      }
	
      if( twiddle_x )
	coords +=
	  ({
	    xedge+(TSIZE/4),   yy,
	    xedge+(TSIZE/4)*2, yy+TSIZE/6,
	    xedge+(TSIZE/4)*3, yy-TSIZE/6,
	    xedge+TSIZE,       yy,
	  });
      coords += ({ width+(twiddle_x?TSIZE:0), yy });

      alpha->setcolor( 255,255,255 );
	
      alpha = alpha->polygone(@LazyImage.make_polygon_from_line
			      (translate_coordinate_f
			       ((a->width||"1.0"),frame,layers ),
			       coords,
			       translate_cap_style( args->cap ),
			       translate_join_style( args->join ) ));
      frame->set_image( img, alpha );
    }

    if( data->x && data->x->ticks )
    {
      array po = ({});
      float x0 = translate_coordinate_f( data->x->args->start,lab_l,layers );
      float x1 = translate_coordinate_f( data->x->args->end,lab_l,layers );
      void draw_tick( float p, float h, float w, Image.Image i )
      {
	int y = (int)((height-yedge-YPAD) - (h/2))+
	  (twiddle_y?TSIZE:0);
	int x = (int)((xedge + (twiddle_x ? TSIZE : 0 )+
		       (float)virtual_to_screen( p, x0, x1,
						 width-xedge-XPAD ))
		      -w/2);

	alpha->paste( i, x, y );
      };
      foreach( data->x->ticks, mapping l )
      {
	float step = translate_coordinate_f( l->step,lab_l,layers );
	float   le = translate_coordinate_f( l->end,lab_l,layers );
	float   ls = translate_coordinate_f( l->start,lab_l,layers );

	float   h = translate_coordinate_f( l->length,lab_l,layers );
	float   w = translate_coordinate_f( l->width,lab_l,layers );
	Image.Image i = Image.Image( (int)w, (int)h, 255,255,255 );
	if( step > 0.0 )						       
	  for( float p=ls; p < le; (p += step) )
	    draw_tick( p,h,w,i );
	else if( step < 0.0 )					     
	  for( float p=ls; p > le; (p += step) )
	    draw_tick( p,h,w,i );
      }
    }

    if( data->y && data->y->ticks )
    {
      array po = ({});
      float x0 = translate_coordinate_f( data->y->args->start,lab_l,layers );
      float x1 = translate_coordinate_f( data->y->args->end,lab_l,layers );
      void draw_tick( float p, float h, float w, Image.Image i )
      {
	int y = (int)((height-yedge-YPAD)-
		      (virtual_to_screen( p, x0, x1, height-yedge-YPAD ))
		      - w/2);
	int x = (int)(xedge-h/2);
	alpha->paste( i, x, y );
      };
      foreach( data->y->ticks, mapping l )
      {
	float step = translate_coordinate_f( l->step,lab_l,layers );
	float   le = translate_coordinate_f( l->end,lab_l,layers );
	float   ls = translate_coordinate_f( l->start,lab_l,layers );

	float   h = translate_coordinate_f( l->length,lab_l,layers );
	float   w = translate_coordinate_f( l->width,lab_l,layers );
	Image.Image i = Image.Image( (int)h, (int)w, 255,255,255 );
	if( step > 0.0 )						       
	  for( float p=ls; p < le; (p += step) )
	    draw_tick( p,h,w,i );
	else if( step < 0.0 )					     
	  for( float p=ls; p > le; (p += step) )
	    draw_tick( p,h,w,i );
      }
    }

    if( layers )
      foreach( layers, Image.Layer l )
	l->set_offset( xedge+(twiddle_x ? TSIZE : 0 )+l->xoffset(),
		       l->yoffset()+YPAD );
    return (layers||({})) + ({lab_l,frame,})-({0});
  }

  LazyImage.Arguments check_args( LazyImage.Arguments a )
  {
    a->parsed_data = parse_data(a->data);
    m_delete(a, "data");
    return a;
  }
};


