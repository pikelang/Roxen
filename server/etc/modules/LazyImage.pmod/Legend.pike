inherit LazyImage.LazyImage;
constant operation_name = "legend";

protected
{
  LazyImage.Layers process( LazyImage.Layers layers )
  {
    array labels = args->parsed_labels;
    int col = 2;
      
    if( args->columns )
      col = (int)args->columns;

    if( col < 1 )
      RXML.parse_error("legend: columns must be at least 1\n");

    Image.Color.Color bgcolor = translate_color( args->bgcolor||"white" );
    Image.Color.Color fgcolor = translate_color( args->fgcolor||"black" );

    array text_images = ({});
      
    int height;
    string font = (args->font||"default")+" "+
      (height=(translate_coordinate(args->fontsize,0,layers)||16));
    Image.Font f = resolve_font( font );

    foreach( labels, mapping l )
    {
      Image.Image i = f->write(@(String.trim_all_whites(l->contents)/"\n"));
      if( args["left-to-right"] )  i = i->mirror_y();
      text_images += ({ i });
    }
    if( args["square-border"] )
      height+=2;
    Image.Image square = Image.Image( height, height );

    // Generate the labels.

    int mxs, mys;
    for( int i = 0; i<sizeof( text_images ); i++ )
    {
      Image.Image r = Image.Image( height+text_images[i]->xsize() + 4,
				   text_images[i]->ysize()+4, bgcolor );
      Image.Image a = Image.Image( height+text_images[i]->xsize() + 4,
				   text_images[i]->ysize()+4 );
	
      a=a->paste_alpha_color( text_images[i], 255,255,255,  height+4, 2 );
      r=r->setcolor( @fgcolor->rgb() );
      r=r->box( height+4,2,
		height+4+text_images[i]->xsize()-1,
		2+text_images[i]->ysize()-1 );

      if( args["square-border"] )
      {
	square=square->clear( parse_color( args["square-border"] ) );
	square=square->box( 1,1,height-2,height-2,
			    parse_color(labels[i]->color) );
      }
      else
	square=square->clear(  parse_color( labels[i]->color ) );
      r=r->paste( square, 0,(a->ysize()-square->ysize())/2 );
      a=a->paste( square->clear(255,255,255),
		  0,(a->ysize()-square->ysize())/2 );
      if( a->xsize() > mxs ) mxs = a->xsize();
      if( a->ysize() > mys ) mys = a->ysize();
      text_images[i] = ({ a, r });
    }

      

    int xp, yp;
    int xs, ys;
    {
      int i;
      while( i < sizeof( labels ) )
      {
	for( int j =0; j<col; j++,i++ )
	{
	  if( i>=sizeof( labels ) )  break;
	  text_images[i] = ({xp, yp, text_images[i] });
	  xp += mxs+5;
	  if( xp > xs ) xs = xp;
	}
	xp = 0;
	yp += mys;
	if( yp > ys ) ys = yp;
      }
    }
    xs+=5;
    Image.Image i = Image.Image( xs, ys );
    Image.Image a = Image.Image( xs, ys );
      
    foreach( text_images, array l )
    {
      [int x,int y,array ii] = l;
      x+=5;
      a=a->paste( ii[0], x, y );
      i=i->paste( ii[1], x, y );
    }
    Image.Layer lab,background,border;
    lab = Image.Layer( )->set_image( i, a );

    if( args->border )
    {
      i = Image.Image( i->xsize()+2, i->ysize()+2,
		       translate_color( args->border ));
      a = i->copy();
      a = a->setcolor( 255,255,255);
      a = a->box( 1,1,a->xsize()-2,a->ysize()-2 );
      a = a->invert();
      border = Image.Layer( )->set_image( i,a );
    }

    if( args->background )
    {
      switch( args->background )
      {
	case "100%":
	case "solid":
	  background = Image.Layer( )
	    ->set_image(i->copy()->clear( bgcolor ),
			a->copy()->clear( 255,255,255 ) );
	  break;
	default:
	  int aa;
	  if( aa=(int)args->background )
	  {
	    aa = (aa*255)/100;
	    if( aa > 255 )
	      aa = 255;
	    background = Image.Layer( )
	      ->set_image(i->copy()->clear( bgcolor ),
			  a->copy()->clear( aa,aa,aa ) );
	    break;
	  }
	case "none":
	case "0%":
      }
    }
    xp = translate_coordinate( args->xoffset, background||border||lab,layers );
    yp = translate_coordinate( args->xoffset, background||border||lab,layers );
    foreach( ({ background, lab, border }), Image.Layer l )
    {
      if(!l) continue;
      l->set_offset( l->xoffset()+xp,  l->yoffset()+yp );
      l->set_misc_value( "name", args->name||"labels" );
    }
    return (({ background, lab, border })-({0}))+(layers||({}));
  }

  LazyImage.Arguments check_args( LazyImage.Arguments args )
  {
    if( !args->labels )
      RXML.parse_error("Expected labels in legend\n");
    array labels = ({});
    void parse_label( Parser.HTML h, mapping m, string c )
    {
      labels += ({ ([ "contents":c ])+m });
    };
    Parser.HTML h = Parser.HTML()->add_container("label", parse_label);
    h->xml_tag_syntax( 2 );
    h->feed( args->labels )->finish();
    args->parsed_labels = labels;
    m_delete(args, "labels");
  }
};
