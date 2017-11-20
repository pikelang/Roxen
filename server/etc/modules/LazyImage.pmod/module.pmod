//! Generic extensible lazy-evaluation image processing.

#include <module.h>

typedef array(Image.Layer) Layers;
//! The 'Layers' type.

typedef mapping(string:string|int|float|array|mapping) Arguments;
//! The 'Arguments' mapping type.


// Some utility functions.

mapping(string:int) layers_extents( Layers layers )
//! Returns the extents for the layers in the array. The return value
//! is ([ "x0":left, "x1":right, "y0":up, "y1":down, "w":width,
//! "h":height ])
{
  int x, y;
  int x0=10000000, y0=100000000;
  if( !layers )
    return ([]);
  foreach( layers, Image.Layer l )
  {
    if( l->xoffset() < x0 )  x0 = l->xoffset();
    if( l->yoffset() < y0 )  y0 = l->yoffset();
    if( l->xsize()+l->xoffset() > x )  x = l->xsize()+l->xoffset();
    if( l->ysize()+l->yoffset() > y )  y = l->ysize()+l->yoffset();
  }
  return ([
    "x0":x0, "y0":y0,
    "x1":x,  "y1":y,
    "w":x-x0,"h":y-y0,
  ]);
}


Layers find_layers( string pattern, array layers )
//! Utility function that can be used to get a list of layers by name
//! (glob pattern).
//!
//! pattern is a comma-separeted list of patterns.
//! \, can be used if a , should actually be present in one of the
//! patterns. '\,' is represented as '\\,'.
{
  array res = ({});
  if( !sizeof( layers ) )
    return res;
  foreach( replace(pattern, "\\,", "\x80000000")/",", string q )
  {
    q = replace( q, "\x80000000", "," );
    foreach( layers, Image.Layer l )
      if( glob( q, (l->get_misc_value( "name" )||"Background") ) )
	res += ({ l });
  }
  return res;
}

array(int) find_layers_indexes( string pattern, array layers )
//! Utility function that can be used to get a list of layer ids by
//! name (glob pattern).
//!
//! pattern is a comma-separeted list of patterns.
//! \, can be used if a , should actually be present in one of the
//! patterns. '\,' is represented as '\\,'.
{
  array res = ({});
  if( !sizeof( layers ) )
    return res;
  foreach( replace(pattern, "\\,", "\x80000000")/",", string q )
  {
    q = replace( q, "\x80000000", "," );
    int ii;
    foreach( layers, Image.Layer l )
    {
      if( glob( q, (l->get_misc_value( "name" )||"Background") ) )
	res += ({ ii });
      ii++;
    }
  }
  return res;
}

array(int) find_layers_id_indexes( string pattern, array layers )
//! Utility function that can be used to get a list of layer IDs by ID
//! (index number).
//! 
//! Rangechecking is done, and the array is indexed with 1 as the
//! first element. The function is very forgiving, out-of-range elements
//! will be converted to the closest possible element.
//!
//! Calling find_layers_id( "1,2,1,4", ({ l1, l2, l3 }) ) will return
//! ({ 0, 1, 0, 2 })
{
  array res = ({});
  if( !sizeof( layers ) )
    return res;
  int limit_index( int i )
  {
    if( i>sizeof(layers) )
      i = sizeof(layers);
    if( i < 0 && ( i < -sizeof(layers) ) )
      i = -sizeof(layers);
    if( i == 0 )
      i = 1;
    return i>0?i-1:i;
  };
  return map((array(int))(pattern/","),limit_index);
}

Layers find_layers_id( string pattern, array layers )
//! Utility function that can be used to get a list of layers by ID
//! (index number).
//! 
//! Rangechecking is done, and the array is indexed with 1 as the
//! first element. The function is very forgiving, out-of-range elements
//! will be converted to the closest possible element.
//!
//! Calling find_layers_id( "1,2,1,4", ({ l1, l2, l3 }) ) will return
//! ({ l1, l2, l1, l3 })
{
  array res = ({});
  if( !sizeof( layers ) )
    return res;
  int limit_index( int i )
  {
    if( i>sizeof(layers) )
      i = sizeof(layers);
    if( i < 0 && ( i < -sizeof(layers) ) )
      i = -sizeof(layers);
    if( i == 0 )
      i = 1;
    return i>0?i-1:i;
  };
  res = rows(layers,map((array(int))(pattern/","), limit_index));
  foreach( pattern/",", string q )
    foreach( layers, Image.Layer l )
      if( glob( q, (l->get_misc_value( "name" )||"Background") ) )
	res += ({ l });
  return res;
}


enum CappingStyle {   CAP_BUTT,   CAP_ROUND, CAP_PROJECTING };
enum JoinStyle    { JOIN_MITER,  JOIN_ROUND,     JOIN_BEVEL };

#define CAPSTEPS  10
#define JOINSTEPS 5
constant PI = Math.pi;

protected array(float) init_cap_sin_table()
{
  array(float) s_t = allocate(CAPSTEPS);

  for (int i = 0; i < CAPSTEPS; i++) {
    s_t[i] = sin(PI*i/(CAPSTEPS-1));
  }
  return(s_t);
}

protected array(float) cap_sin_table = init_cap_sin_table();

protected array(float) init_cap_cos_table()
{
  array(float) c_t = allocate(CAPSTEPS);

  for (int i = 0; i < CAPSTEPS; i++) {
    c_t[i] = cos(PI*i/(CAPSTEPS-1));
  }
  return(c_t);
}

protected array(float) cap_cos_table = init_cap_cos_table();


private array(float) xyreverse(array(float) a)
{
  array(float) r = reverse(a);
  int n = sizeof(r)/2;
  while(n--) {
    float t = r[n<<1];
    r[n<<1] = r[(n<<1)+1];
    r[(n<<1)+1] = t;
  }
  return r;
}


protected object compile_handler = class {
    mapping(string:mixed) get_default_module() {
      return ([ "this_program":0,
		// Kludge: These casts are to avoid that the type
		// checker in pike 7.8 freaks out..
		"`+": (function) `+,
		"`-": (function) `-,
		"`*": (function) `*,
		"`/": (function) `/,
		"`%": (function) `%,
		"`&": (function) `&,
		"`|": (function) `|,
		"`^": (function) `^,
		"`<": (function) `<,
		"`>": (function) `>,
		"`==": (function) `==,
		"`<=": (function) `<=,
		"`>=": (function) `>=,
	     ]);
    }

    mixed resolv(string id, void|string fn, void|string ch) {
      throw( ({ sprintf("The symbol %O is not known.\n", id),
		backtrace() }) );
    }
  }();

mixed parse_sexpr(string what)
{
  if( (string)(int)what == what )
    return (int)what;
  return compile_string("mixed foo="+what+";",0,compile_handler)()->foo;
}


array(array(float)) make_polygon_from_line(float h,
					   array(float) coords,
					   int|void cap_style,
					   int|void join_style)
{
  int points = sizeof(coords)>>1;
  int closed = points>2 &&
    coords[0] == coords[(points-1)<<1] &&
    coords[1] == coords[((points-1)<<1)+1];
  if(closed)
    --points;
  int point;
  float sx = h/2, sy = 0.0;
  array(float) left = ({ }), right = ({ });

  for(point=0; point<points; point++) {

    float ox = coords[point<<1], oy = coords[(point<<1)+1];
    int t = (point==points-1 ? (closed? 0 : point) : point+1);
    float tx = coords[t<<1], ty = coords[(t<<1)+1];
    float dx = tx - ox, dy = ty - oy, dd = sqrt(dx*dx + dy*dy);
    if(dd > 0.0) {
      sx = (-dy*h) / (dd*2);
      sy = (dx*h) / (dd*2);
    }

    if(point == 0 && !closed) {
      /* Initial cap */
      switch(cap_style) {
      case CAP_BUTT:
	left += ({ ox+sx, oy+sy });
	right += ({ ox-sx, oy-sy });
	break;
      case CAP_PROJECTING:
	left += ({ ox+sx-sy, oy+sy+sx });
	right += ({ ox-sx-sy, oy-sy+sx });
	break;
      case CAP_ROUND:
	array(float) initial_cap = allocate(CAPSTEPS*2);
	
	int j=0;
	for(int i=0; i<CAPSTEPS; i++) {
	  initial_cap[j++] = ox + sx*cap_cos_table[i] - sy*cap_sin_table[i];
	  initial_cap[j++] = oy + sy*cap_cos_table[i] + sx*cap_sin_table[i];
	}
	right += initial_cap;
	break;
      }
    }

    if(closed || point<points-1) {
      /* Interconnecting segment and join */
      if(point == points-2 && !closed)
	/* Let the final cap generate the segment */
	continue;

      int t2 = (t==points-1 ? 0 : t+1);
      float t2x = coords[t2<<1], t2y = coords[(t2<<1)+1];
      float d2x = t2x - tx, d2y = t2y - ty, d2d = sqrt(d2x*d2x + d2y*d2y);
      float s2x, s2y;
      if(d2d > 0.0) {
	s2x = (-d2y*h) / (d2d*2);
	s2y = (d2x*h) / (d2d*2);
      } else {
	s2x = sx;
	s2y = sy;
      }

      float mdiv = (sx*s2y-sy*s2x);
      if(mdiv == 0.0) {
	left += ({ tx+sx, ty+sy, tx+s2x, ty+s2y });
	right += ({ tx-sx, ty-sy, tx-s2x, ty-s2y });
      } else {
	float m = (s2y*(sy-s2y)+s2x*(sx-s2x))/mdiv;

	/* Left join */

	switch(mdiv<0.0 && join_style) {
	case JOIN_MITER:
	  left += ({ tx+sx+sy*m, ty+sy-sx*m });
	  break;
	case JOIN_BEVEL:
	  left += ({ tx+sx, ty+sy, tx+s2x, ty+s2y });
	  break;
	case JOIN_ROUND:
	  float theta0 = acos((sx*s2x+sy*s2y)/(sx*sx+sy*sy));
	  for(int i=0; i<JOINSTEPS; i++) {
	    float theta = theta0*i/(JOINSTEPS-1);
	    float sint = sin(theta), cost = cos(theta);
	    left += ({ tx+sx*cost+sy*sint, ty+sy*cost-sx*sint });
	  }
	  break;
	}

	/* Right join */

	switch(mdiv>0.0 && join_style) {
	case JOIN_MITER:
	  right += ({ tx-sx-sy*m, ty-sy+sx*m });
	  break;
	case JOIN_BEVEL:
	  right += ({ tx-sx, ty-sy, tx-s2x, ty-s2y });
	  break;
	case JOIN_ROUND:
	  float theta0 = -acos((sx*s2x+sy*s2y)/(sx*sx+sy*sy));
	  for(int i=0; i<JOINSTEPS; i++) {
	    float theta = theta0*i/(JOINSTEPS-1);
	    float sint = sin(theta), cost = cos(theta);
	    right += ({ tx-sx*cost-sy*sint, ty-sy*cost+sx*sint });
	  }
	  break;
	}
      }
    } else {
      /* Final cap */
      switch(cap_style) {
      case CAP_BUTT:
	left += ({ ox+sx, oy+sy });
	right += ({ ox-sx, oy-sy });
	break;
      case CAP_PROJECTING:
	left += ({ ox+sx+sy, oy+sy-sx });
	right += ({ ox-sx+sy, oy-sy-sx });
	break;
      case CAP_ROUND:
	array(float) end_cap = allocate(CAPSTEPS*2);
	
	int j=0;
	for(int i=0; i<CAPSTEPS; i++) {
	  end_cap[j++] = ox - sx*cap_cos_table[i] + sy*cap_sin_table[i];
	  end_cap[j++] = oy - sy*cap_cos_table[i] - sx*cap_sin_table[i];
	}
	right += end_cap;
	break;
      }
    }
  }

  if(closed)
    return ({ left, right });
  else
    return ({ left + xyreverse(right) });
}


protected mapping(program:string) programs;
protected object dirnode = master()->handle_import(".", __FILE__);

protected string get_program_name (program p)
{
  if (!programs) {
    array inds = indices (dirnode);
    array vals = rows (dirnode, inds);
    programs = mkmapping (vals, inds);
  }
  return programs[p];
}

int image_object_count;

protected Thread.Local request_id = Thread.Local();

class LazyImage( LazyImage parent )
//! One or more layers, with lazy evaluation.
//! This is the base-class that is inherited by all layer operations.
//! It handles things like data-sharing and optimization of the
//! operations, and also the generation of cache-keys.
{
  constant operation_name = "";
  //! The name of the operation. Used for debug purposes and as part
  //! of the cache-key.

  constant ignore_parent  = 0;
  //! If true, this operation ignores the data in the parent image, if any.

  constant destructive    = (<>);
  //! A multiset with the kind of data this operation is destructive on.
  //! One or more of "meta", "image" and "alpha".
  //! "meta" includes things like the layer mode and opacity.
  
  int refs;

  int object_id = ++image_object_count;
  //! A unique object identifier used for debug
  
  this_program ref( )
  //! Add a reference to this image. Not normally called directly
  {
    refs++;
    return this_object();
  }

  this_program unref()
  //! Remove a reference from this image. Not normally called directly
  {
    --refs;
#ifdef DEBUG
    if( refs < 0 )  error("Illegal number of references, <= 0\n");
#endif
    return this_object();
  }
  
  protected Layers result;
  protected Image.Layer render_result;

  protected Arguments args;
  //! The args given to @[new] or @[set_args].
  //! Please note that this mapping can be shared between several
  //! different images, do not modify it destructively in your code.
  
  protected string _sprintf( int f, mapping a )
  {
    switch( f )
    {
      case 'O':
#ifdef GXML_DEBUG
	string s1 = sprintf("%O", args) - "\n";
	string s2 = parent?sprintf("(\n%O)", parent):"";
	return replace(sprintf( "%s[%d:%d]: %s %s",
				operation_name, object_id, refs, s1, s2 ),
		       "\n", "\n  ");
#else
	string s = parent?sprintf("(%O)", parent):"";
	return sprintf( "%s%s", operation_name, s );
#endif /* GXML_DEBUG */
      default:
	error("Cannot sprintf image to '%c'\n", f );
    }
  }

  string translate_mode( string from )
  //! Translate a mode name, as given by the user, to a layer mode as
  //! understood by the image module. Takes care of some photoshop and
  //! gimp layer mode names.
  //!
  //! Please note that it does not understand localized Photoshop
  //! and Gimp layer-mode names.
  //!
  //! Prefix the mode name with pike: to force a mode, As an example,
  //! use "pike:lighten" to force the (HSV mode) "lighten" layer mode.
  //!
  //! "lighten" would use the "max" (RGB mode lighten), since that's the
  //! pike name for the mode that is known as "lighten" in Photoshop
  //! and Gimp.
  //!
  //! Use gimp:mode to force the gimp intepretation of mode where it
  //! and photoshop have different intepretations.
  {
    int gimp;
    if(!from)
      return "normal";

    if( sscanf( from, "pike:%s", from ) )
      return from;

    if( sscanf( from, "gimp:%s", from ) )
      gimp = 1;

    switch( from  = lower_case(from-"\t")-" " )
    {
      case "addition":    return "add"; // gimp
      case "darken":       // ps
      case "darkenonly":  return "min"; // gimp
      case "lighten":      // ps
      case "lightenonly": return "max"; // gimp
      case "diff": return "difference";

      case "hue":
	if( gimp ) return "hls_hue";
	return "hue";

      case "saturation":
	if( gimp ) return "hls_saturation";
	return "saturation";

      case "lightness":
      case "luminence":
      case "luminosity":
      case "value":
	if( gimp ) return "hls_lightness";
	return "value";
      case "colorburn":  return "multiply"; // ps, not 100% correct
      case "colordodge": return "idivide"; // ps
      case "softlight":  return "hardlight"; // not correct. 
	
      case 0:
	return "normal";

      default:
	return from;
    }
  }

  protected Image.Layer copy_layer( Image.Layer l )
  {
    return l->clone();
  }


  protected Image.Color translate_color( string col )
  //! Parse the color specified in 'col', and return the best-guess color
  //! If no intepretation can be done, return Image.Color.black  
  {
    return Image.Color.guess( col || "000" ) || Image.Color.black;
  }

  protected float virtual_to_screen( float v, float v0, float v1, int rs )
  //! Convert a the virtual coordinate @[v], with ranges between @[v0]
  //! and @[v1] to a screen coordinate where 0 corresponds to @[v0], and
  //! @[rs] corresponds to @[v1]
  {
    float vs = v1-v0;
    v-=v0;
    if( !vs ) vs = 1.0;
    return ((v/vs) * rs);
  }

  protected int find_guide( int index, int vertical, Layers in )
  {
    array guides = ({}), rguides;
    int limit_index( int i )
    {
      if( i>sizeof(guides) )
	i = sizeof(guides);
      if( i < 0 && ( i < -sizeof(guides) ) )
	i = -sizeof(guides);
      if( i == 0 )
	i = 1;
      return i>0?i-1:i;
    };
    foreach( in, Image.Layer s )
      guides |= s->get_misc_value( "guides" )||({});
    rguides = ({});
    foreach( guides, object g  )
      if( g->pos > 0 )
	if( g->vertical == vertical )
	  rguides |= ({ g->pos });
    guides = sort( rguides );
    return guides[ limit_index( index ) ];
  }

  protected string handle_variable( string variable, Image.Image|Image.Layer cl,
				    Layers l)
  {
    array(string) v = (variable/".");
    string exts_ind( mapping exts, int i)
    {
      switch( i )
      {
	case 'l': return (string)exts->x0;
	case 'r': return (string)exts->x1;
	case 't': return (string)exts->y0;
	case 'b': return (string)exts->y1;
	case 'w': return (string)exts->w;
	case 'h': return (string)exts->h;
      }
    };
    switch( v[0] )
    {
      case "guides":
	return (string)find_guide((int)v[-1], (v[1]=="v"),
				  get_current_layers());
	break;

      case "image":
	return exts_ind( layers_extents( get_current_layers() ), v[1][0] );

      case "layer":
	mapping exts = ([]);
	if( !cl )
	  RXML.parse_error( "No current layer (while parsing "+variable+" in "+
			  operation_name+")\n");
	if( cl->xoffset )
	  exts = ([
	    "x0":cl->xoffset(), "y0":cl->yoffset(),
	    "w":cl->xsize(),    "h":cl->ysize(),
	  ]);
	else
	  exts = ([ "w":cl->xsize(), "h":cl->ysize(), ]);
	return exts_ind( exts, v[1][0] );
      case "layers":
	if (!sizeof(l))
	  RXML.parse_error( "No layers (while parsing "+variable+" in "+
			    operation_name+")\n");
	exts = ([]);
	Layers layers = find_layers(v[1], l);
	if (!sizeof(layers))
	  RXML.parse_error( "No such layer (while parsing "+variable+" in "+
			    operation_name+")\n");
	Image.Layer tl = layers[0];
	if( tl->xoffset )
	  exts = ([
	    "x0":tl->xoffset(), "y0":tl->yoffset(),
	    "w":tl->xsize(),    "h":tl->ysize(),
	  ]);
	else
	  exts = ([ "w":tl->xsize(), "h":tl->ysize(), ]);
	return exts_ind( exts, v[2][0] );
    }
  }
  

  protected string parse_variables( string from, Image.Layer|Image.Image cl,
				    Layers l)
  {
    if( !from )
      return 0;
    string a, b, v;
    while( sscanf( from, "%s$[%s]%s", a, v, b ) == 3 )
      from = a+handle_variable( v,cl,l )+b;
    return from;
  }
  
  protected int translate_coordinate( string from, Image.Layer|Image.Image cl,
				      Layers l)
  {
    if( !from ) return 0;
    return (int)parse_sexpr( parse_variables( from, cl, l ) );
  }

  protected int translate_cap_style( string style )
  {
    switch( lower_case(String.trim_all_whites(style||"")) )
    {
      default:
	return CAP_BUTT;
      case "round":
	return CAP_ROUND;
      case "projecting":
	return CAP_PROJECTING;
    }
  }

  protected int translate_join_style( string style )
  {
    switch( lower_case(String.trim_all_whites(style||"")) )
    {
      default:
	return JOIN_MITER;
      case "round":
	return JOIN_ROUND;
      case "bevel":
	return JOIN_BEVEL;
    }
  }

  protected float translate_coordinate_f( string from,
					  Image.Layer|Image.Image cl,
					  Layers l)
  {
    if( !from ) return 0;
    return (float)parse_sexpr( parse_variables( from, cl, l ) );
  }
  
  protected Image.Layer copy_layer_data( Image.Layer l )
  {
    Image.Image i = l->image();
    Image.Image a = l->alpha();
    if( a && destructive->alpha ) a = a->copy();
    if( destructive->image )      i = i->copy();

    l = copy_layer( l );
    l->set_image( i,a );
    return l;
  }

  protected Arguments check_args( Arguments a )
  //! Verify that the argument mapping is valid. This function can
  //! call the error functions in the RXML module. The default
  //! implementation does nothing but return it's argument.
  {
    return a;
  }
  
  protected Layers|mapping process( Layers layers )
  //! Do the actual work needed to process the image.
  //! The default implementation does nothing but return the image
  //! layers.
  {
    return layers;
  }
  
  Layers|mapping run(int|void i, RequestID|void id)
  //! Apply all operations needed to actually generate the image. 
  //! After the first time this function is called, the result is
  //! cached.
  {
    if(id)
      request_id->set(id);
    
    if( result )
      return result;

    if( parent )
    {
      if( !ignore_parent ) {
	/*Layers*/array(Image.Layer)|mapping res = parent->run(i+1);
	if (mappingp(res))
	  return res;
	result = res;
      }
      
      if( parent->refs > 1 ) 
      {
	// only copy if the parent data is used in more places than this.
	// It's sort of unessesary otherwise.
	if( destructive->image || destructive->alpha )
	  result = map( result, copy_layer_data );
	else if( destructive->meta )
	{
	  result = map( result, copy_layer );
	}
      }
      parent->unref();
    }
    parent = 0;
    if( result )
      add_layers( result );
    
#ifdef GXML_DEBUG
    int t2 = gethrtime();
    werror("%20s:", operation_name);
    float t = gauge{
#endif /* GXML_DEBUG */
	/*Layers*/array(Image.Layer)|mapping process_res = process( result );
	if (mappingp(process_res))
	  return process_res;
	result = process_res;
#ifdef GXML_DEBUG
      };
    werror(" %.3f %.3f\n",t,(gethrtime()-t2)/1000000.0 );
#endif /* GXML_DEBUG */
    return result;
  }

  Image.Layer|mapping render()
  //! Apply all operations needed to actually generate the image, and
  //! render the array of layers to a single layer. After the first
  //! time this function is called, the result is cached.
  {
    if( render_result )
      return render_result;
    /*Layers*/array(Image.Layer)|mapping run_res = run(0);
    if (mappingp(run_res))
      return run_res;
    return render_result = Image.lay(run_res);
  }

  string _hash;
  string hash()
  {
    if( _hash )
      return _hash;
    return _hash = (parent?parent->hash():"") +
      low_hash( this_object(), args );
  }
  
  int xsize()
  //! Returns the xsize of the image. 
  //! This might involve a call to @[render]
  {
    return render()->xsize();
  }

  int ysize()
  //! Returns the ysize of the image.
  //! This might involve a call to @[render]
  {
    return render()->ysize();
  }

  void set_args( Arguments a, void|int no_arg_check )
  //! Set the args mapping.
  //! Not normally called directly.
  {
    if(no_arg_check)
      args = a;
    else
      args = check_args( a ) || a;
  }

  mapping encode()
  {
    mapping res = ([ "n": get_program_name(object_program(this_object())),
		     "a": args,
		     "r": refs ]);
    if(parent)
      res["p"] = parent->encode();
    
    return res;
  }
}

class LoadImage
//! Load a image, as specified by the 'src' argument.
{
  inherit LazyImage;
  constant operation_name = "load-image";

  protected
  {
    Layers|mapping process( Layers layers)
    {
      RequestID id = request_id->get();
      if(!id)
	error("Oops, no request id object.");
      
      //  Reject empty source paths for sufficiently high compat_level
      if ((args->src || "") == "") {
	float compat_level = (float) id->conf->query("compat_level");
	if (compat_level >= 5.2) {
	  RXML.parse_error("Empty src attribute not allowed.\n");
	}
      }
      
      array|mapping res;
#if constant(Sitebuilder) && constant(Sitebuilder.sb_start_use_imagecache)
      //  Let SiteBuilder get a chance to decode its argument data
      if (Sitebuilder.sb_start_use_imagecache) {
	Sitebuilder.sb_start_use_imagecache(args, id);
	res = roxen.load_layers(args->src, id);
	Sitebuilder.sb_end_use_imagecache(args, id);
      } else
#endif
      {
	res = roxen.load_layers(args->src, id);
      }
      if( !res || mappingp(res) ) {
	if (mappingp(res) && res->error == Protocols.HTTP.HTTP_UNAUTH)
	  return res;
	RXML.parse_error("Failed to load specified image [%O]\n", args->src );
      }
      if( args->tiled )
	foreach( res, Image.Layer l )
	  l->set_tiled( 1 );
      return (layers||({}))+res;
    }

    Arguments check_args( Arguments args)
    {
      RequestID id = RXML.get_context()->id;
      if( !args->src )
	RXML.parse_error("Missing src attribute to load\n");
      if (args->src == "") {
	float compat_level = (float) id->conf->query("compat_level");
	if (compat_level >= 5.2)
	  RXML.parse_error("Empty src attribute not allowed.\n");
      }
      args->src = Roxen.fix_relative( args->src, id );
      Stat s = id->conf->try_stat_file( args->src, id );
      
      // try_stat_file() may fail although it is a valid image,
      // e.g. /internal-roxen-*.
      if (s)
      {
	string fn = id->conf->real_file( args->src, id );
	if( fn ) Roxen.add_cache_stat_callback( id, fn, s[ST_MTIME] );
	args->stat = s[ ST_MTIME ];
#if constant(Sitebuilder) && constant(Sitebuilder.sb_prepare_imagecache)
	//  The file we called try_stat_file() on above may be a SiteBuilder
	//  file. If so we need to extend the argument data with e.g.
	//  current language fork.
	if (Sitebuilder.sb_prepare_imagecache)
	  args = Sitebuilder.sb_prepare_imagecache(args, args->src, id);
#endif
      }
      return args;
    }
  };
}

class SelectLayers
//! Select a list of layers to be rendered. The arguments 'include',
//! 'include-id', 'exclude' and 'exlude-id' are used to select the
//! layers.
{
  inherit LazyImage;
  constant operation_name = "select-layers";

  protected {
    Layers process( Layers l )
    {
      Layers res = l;

      if( args->include )
	res = find_layers( args->include, l );
      else if( args["include-id"] )
	res = find_layers_id( args["include-id"], l );

      if( args->exclude )
	res -= find_layers( args->exclude, res );
      else if( args["exclude-id"] )
	res -= find_layers_id( args["exclude-id"], l );

      return res;
    }
  };
}


class Text
//! Either generate a new layer (if 'layers' or 'layers-id' are not
//! specified) filled with the color 'color' and with an alpha channel
//! consisting of the rendered 'text', or, if 'on' is specified,
//! places the text on top of the layer or layers specified in on. If
//! 'modulate-alpha' and ('layers' or 'layers-id') is specified, the
//! text will be used to modulate the alpha channel of the layers
//! specified by 'layers' or 'layers-id'. 'replace-alpha' works more
//! or less like 'modulate-alpha', but the layer alpha channel is
//! replaced entirely by the text.
{
  inherit LazyImage;
  constant operation_name = "text";
  constant destructive    = (<"image","alpha">);

  protected {
    Layers process( array(Image.Layer|array(Image.Layer)) l )
    {
      Image.Layer ti;
      Font f;
      array(int) on;

      
      if( args->layers )
	on = find_layers_indexes( args->layers, l );
      if( args["layers-id"] )
	on = find_layers_id_indexes( args["layers-id"], l );

      string font =
	(args->font||"default")+" "+
	(translate_coordinate(args->fontsize,0,l)||32);
      f = resolve_font( font );

      if( !f )
	RXML.parse_error("Cannot find the font ("+font+")\n");

      mapping text_info;
      if(f->write_with_info)
	text_info = f->write_with_info(parse_variables(args->text,0,l)/"\n");
      else
	text_info = ([ "img" : f->write(@(parse_variables(args->text,0,l)/"\n")) ]);
      Image.Image text = text_info->img;
      int overshoot = (int)text_info->overshoot;

      int x = translate_coordinate( args->x,text,l );
      int y = translate_coordinate( args->y,text,l );
      y -= overshoot;

      if( args["modulate-alpha"] )
	foreach( on, int i )
	{
	  Image.Image a = l[i]->alpha();
	  if( !a )
	    a = l[i]->image()->copy()->clear(Image.Color.black);
	  a = a->paste_alpha_color( text, 255,255,255, x, y );
	  l[ i ]->set_image( l[ i ]->image(), l[i]->alpha() );
	}
      else if( args["replace-alpha"] )
	foreach( on, int i )
	  l[i]->set_image( l[i]->image(),
			   text->copy( 0,0,
				       l[i]->image()->xsize()-1,
				       l[i]->image()->ysize()-1) );
      else
      {
	ti = Image.Layer( Image.Image( text->xsize(), text->ysize(),
				     translate_color( args->color ) )
			  , text, translate_mode( args->mode ) );
	ti->set_offset( x,y );
	ti->set_misc_value( "name", parse_variables(args->name || args->text,
						    ti,l));

	if( !on )  return (l||({})) + ({ ti });
	foreach( on, int i )
	{
	  ti = copy_layer( ti );
	  if( string n = l[i]->get_misc_value( "name" ) )
	    ti->set_misc_value( "name", parse_variables(n,ti,l) );
	  else
	    ti->set_misc_value( "name",
				parse_variables(args->name || args->text,
						ti,l) );
	  l[ i ] = ({ l[i], ti });
	}
	return Array.flatten( l );
      }
    }

    Arguments check_args( Arguments args )
    {
      if( args["modulate-alpha"] && !(args->on || args["on-id"] ) )
	RXML.parse_error("Need 'layers' or 'layers-id' "
		    "when using 'modulate-alpha'\n" );
      if( !args->text )
	RXML.parse_error("No text specified\n" );

      return args;
    }
  };
}

class ReplaceAlpha
//! Replace the alpha channel of the specified layer(s) (specified
//! with 'layers' or 'layers-id', defaults to all layers) with either
//! the alpha channel of a layer, or a group of layers (specified with
//! 'from' or 'from-id'), or the color specified in 'clear'.
{
  inherit LazyImage;
  constant operation_name = "replace-alpha";
  constant destructive    = (<"alpha">);
  
  protected {
    Layers process( Layers layers )
    {
      Layers victims = layers;
      if( args->layers )
	victims = find_layers( args->layers, layers );
      else if( args["layers-id"] )
	victims = find_layers( args["layers-id"], layers );

      if( args->from || args["from-id"])
      {
	Image.Image new_alpha;
	Layers tmp;
	if( args->from ) tmp = find_layers( args->from, layers );
	if( args["from-id"] ) tmp = find_layers( args["from-id"], layers );

	if( !sizeof( tmp ) )
	  args->color = "black";
	else
	{
	  int xs, ys;
	  // 1. Find size.
	  foreach( victims, Image.Layer l )
	  {
	    if( l->xsize() > xs )
	      xs = l->xsize();
	    if( l->ysize() > ys )
	      ys = l->ysize();
	  }
	  new_alpha = Image.Image( xs, ys );
	  foreach( tmp, Image.Layer l )
	    new_alpha->paste_alpha_color( l->alpha(), 255,255,255 );
	  foreach( victims, Image.Layer l )
	    l->set_image( l->image(),
			  new_alpha->copy( 0,0,
					   l->image()->xsize()-1,
					   l->image()->ysize()-1 ) );
	};
      }
      if( args->color )
      {
	Image.Color c = translate_color( args->color );
	foreach( victims, Image.Layer l ) {
	  if (l->image()) {
	    l->set_image( l->image(), l->image()->copy()->clear( c ) );
	  } else {
	    l->set_image(0, 0);
	  }
	}
      }

      return layers;
    }

    Arguments check_args( Arguments args )
    {
      if( !parent )
	RXML.parse_error( "replace-alpha cannot be the toplevel node\n" );
      return args;
    }
  };
}

class Shadow
//! Returns the layers and a shadow for those layers.
{
  inherit LazyImage;
  constant operation_name = "shadow";
  
  protected {

    Layers process( Layers layers )
    {
      Layers q = layers;
      if( args->layers )       q = find_layers( args->layers, layers );
      if( args["layers-id"] )  q = find_layers_id( args["layers-id"], layers );
      int grow = (int)args->soft; // How much can the image really grow?
      int xoffset = args->xoffset ? (int)args->xoffset : 2;
      int yoffset = args->yoffset ? (int)args->yoffset : 2;

      // Now, generate the shadow image.
      mapping e = layers_extents( q );
      Image.Image shadow = Image.Image( e->w+grow*2, e->h+grow*2 );

      if( !sizeof( q ) )
	return layers;
      
      foreach( q, Image.Layer l )
	shadow->paste_alpha_color( (l->alpha() ||
				    l->image()->copy()->clear(255,255,255)),
				   255,255,255,
				   l->xoffset()-e->x0+grow,
				   l->yoffset()-e->y0+grow );
      // Blur, if wanted.

      if( args->soft )
	shadow = shadow->grey_blur( (int)args->soft );

      Image.Layer sl = Image.Layer( shadow->copy()
				    ->clear( translate_color( args->color ) ),
				    shadow );
      sl->set_offset( e->x0 + xoffset - grow,
		      e->y0 + yoffset - grow );
      sl->set_misc_value( "name", (args->name ||
				   q[0]->get_misc_value("name")+".shadow"));
      return (layers-q) + ({sl}) + q;
    }
    
    Arguments check_args( Arguments a )
    {
      if( !parent )
	RXML.parse_error( "shadow cannot be the toplevel node\n" );
      return args;
    }
  };
}

class Join
//! Used by join_images, not really intended for direct use.
{
  inherit LazyImage;
  constant operation_name = "join";
  constant ignore_parent   = 1;
  Arguments args;
  
  string hash()
  {
    return low_hash( this_object(), (["":args->contents->hash()*""]) );
  }

  void set_args( mapping _args )
  {
    args = _args;
  }
    
  protected {
    string _sprintf( int f, mapping a )
    {
      switch( f )
      {
	case 'O':
#ifdef GXML_DEBUG
	  return replace(sprintf( "%s[%d:%d]: %O (%{\n%O %})",
				  operation_name, object_id, refs,
				  args - ([ "contents":1 ]),
				  args->contents),
			 "\n", "\n  ");
#else
	  return sprintf( "%s(%{%O, %})", operation_name, args->contents);
	  
#endif
	default:
	  error("Cannot sprintf image to '%c'\n", f );
      }
    }
  };
  Layers|mapping run( int|void i, RequestID|void id )
  {
    if(id)
      request_id->set(id);
    
    array(Layers|mapping) res_array = args->contents->run(i + 1);
    foreach(res_array, /*Layers*/array(Image.Layer)|mapping res)
      if (mappingp(res))
	return res;
    return `+( ({}), @res_array );
  }

  mapping encode()
  {
    return ([ "n": get_program_name(object_program(this_object())),
	      "a": args - ([ "contents": 1 ]),
	      "p": args->contents->encode(),
	      "r": refs ]);
  }
  
}

class SetLayerMode
//! Set the mode of the specified layers (args layers or layers-id) to
//! the mode specified in args->mode.
{
  inherit LazyImage;
  constant operation_name = "set-layer-mode";
  constant destructive    = (<"meta">);

  protected {
    Layers process( Layers l )
    {
      Layers q = l;
      if( args->layers )       q = find_layers( args->layers, l );
      if( args["layers-id"] )  q = find_layers_id( args["layers-id"], l );
      if( catch {
	q->set_mode( translate_mode( args->mode ) );
      } )
	RXML.parse_error( "The layer mode %O is not supported\n",args->mode );
      return l;
    }


    Arguments check_args( Arguments args )
    {
      if( !args->mode )
	RXML.parse_error( "Expected mode as an argument\n" );
      if( !parent )
	RXML.parse_error( "set-layer-mode cannot be the toplevel node\n" );
      return args;
    }
  };
}

class MoveLayer
//! Move the specified layers (args layers or layers-id) to the
//! location specified in args->x and args->y.
{
  inherit LazyImage;
  constant operation_name = "move-layer";
  constant destructive    = (<"meta">);

  protected {
    Layers process( Layers l )
    {
      Layers q = l;
      if( args->layers )      q=find_layers( args->layers, l );
      if( args["layers-id"] ) q=find_layers_id(args["layers-id"], l);

      int x = translate_coordinate( args->x,0,l );
      int y = translate_coordinate( args->y,0,l );
      
      if( !args["absolute"] )
	foreach( q, Image.Layer l )
	  l->set_offset(x+l->xoffset(), y+l->yoffset());
      else
	q->set_offset( x, y );
      return l;
    }
    
    Arguments check_args( Arguments args )
    {
      if( !parent )
	RXML.parse_error( "move-layer cannot be the toplevel node\n" );
      return args;
    }
  };
}

class NewLayer
//! A empty layer.
//! Used args:
//!
//!   xsize: Image horizontal size in pixels (REQUIRED)
//!   ysize: Image vertical size in pixels (REQUIRED)
//!   color: Image color. Defaults to black.
//!   mode: The layer mode. Normal is default.
//!   transparent: If given, the layer will be fully transparent.
//!                The default is a fully opaque layer.
{
  inherit LazyImage;
  constant operation_name = "new-layer";

  protected {
    Layers process( Layers l )
    {
      Image.Layer new_layer = Image.Layer();
      int xs = translate_coordinate( args->xsize,0,l ),
	  ys = translate_coordinate( args->ysize,0,l );

      Image.Image i = Image.Image( xs,ys,
				   translate_color(args->color||"000" ));
      Image.Image a = Image.Image( xs,ys,
				   args->transparent?
				   Image.Color.black:
				   Image.Color.white );
      new_layer->set_misc_value( "name", args->name||"-" );

      new_layer->set_image( i, a );
      new_layer->set_mode( translate_mode( args->mode ) );
      int xo = translate_coordinate( args->xoffset, new_layer, l),
	  yo = translate_coordinate( args->yoffset, new_layer, l);
      new_layer->set_offset( xo, yo );
      if( args->tiled )
	new_layer->set_tiled( 1 );
      return (l||({}))+({new_layer});
    }
  };
}


class Crop
//! Crop the layers to the specified size.
//! Uses the 'x', 'y', 'width' and 'height' arguments.
{
  inherit LazyImage;
  constant operation_name = "crop";
  constant destructive    = (<"meta","image","alpha">);
  protected {
    Layers process( Layers layers )
    {
      int x0 = translate_coordinate( args->x, 0, layers );
      int y0 = translate_coordinate( args->y, 0, layers );
      int width = translate_coordinate(args->width, 0, layers );
      int height = translate_coordinate( args->height, 0, layers );

      foreach( layers, Image.Layer l )
      {
	if( l->tiled() )
	  continue;
	if( l->xoffset() > x0+width ||
	    l->yoffset() > y0+height ) // totally outside the image.
	  layers -= ({ l });
	else
	{
	  /* Do this the easy way... + and - are hard. :-) */
	  Image.Image i = Image.Image( width, height );
	  Image.Image a = Image.Image( width, height );
	  if( l->image() )
	    i = i->paste( l->image(), l->xoffset()-x0, l->yoffset()-y0 );

	  if( l->alpha() )
	    a = a->paste( l->alpha(), l->xoffset()-x0, l->yoffset()-y0 );
	  else
	    a->paste( l->image()->copy()->clear( Image.Color.white ),
		      l->xoffset()-x0, l->yoffset()-y0 );
	  l->set_image( i, a );
	  l->set_offset( 0, 0 );
	}
      }
      return layers;
    }

    Arguments check_args( Arguments args )
    {
      if( !args->x || !args->y )
	RXML.parse_error("Need 'x' and 'y' arguments for crop\n" );
      if( !parent )
	RXML.parse_error( "crop cannot be the toplevel node\n" );
      return args;
    }
  };
}


class Scale
//! Scale the layers to the specified size. Uses the 'width' and
//! 'height' arguments (in pixels). If either width or height are not
//! specified, the aspect of the image will be maintained.
//!
//! If 'mode=relative' is specified, the width and height will be
//! given as percentages of the original width and height.
{
  inherit LazyImage;
  constant operation_name = "scale";
  constant destructive    = (<"meta","image","alpha">);
  protected {
    Layers process( Layers layers )
    {
      Layers victims = layers;
      if( args->layers )
	victims = find_layers( args->layers, layers );
      else if( args["layers-id"] )
	victims = find_layers( args["layers-id"], layers );

      int|float width, height, max_width, max_height;
      if( args->mode == "relative" )
      {
	width = translate_coordinate_f( args->width, 0, layers ) / 100.0;
	height = translate_coordinate_f( args->height, 0, layers ) / 100.0;
      }
      else
      {
	width = translate_coordinate( args->width, 0, layers );
	height = translate_coordinate( args->height, 0, layers );
      }
      if (args["max-width"])
	max_width = translate_coordinate( args["max-width"], 0, layers );
      if (args["max-height"])
	max_height = translate_coordinate( args["max-height"], 0, layers );
      
      foreach( victims, Image.Layer l )
      {
	if( max_width || max_height )
	{
	  if (max_width && max_height)
	  {
	    if ( max_width / (float)l->xsize() < max_height / (float)l->ysize() )
	      max_height = 0;
	    else
	      max_width = 0;
	  }
	  max_width = min( max_width, l->xsize() );
	  max_height = min( max_height, l->ysize() );
	}

	Image.Image i = l->image(), a = l->alpha();
	if( i )
	  i = i->scale( max_width||width, max_height||height );
	if( a )
	  a = a->scale( max_width||width, max_height||height );
	l->set_image( i, a );
      }
      return layers;
    }

    Arguments check_args( Arguments args )
    {
      if( !args->width && !args->height &&
	  !args["max-width"] && !args["max-height"] )
	RXML.parse_error("Either 'width' or 'height' arguments "
			 "must be specified\n" );
      if( !parent )
	RXML.parse_error( "scale cannot be the toplevel node\n" );
      return args;
    }
  };
}

class Rotate
//! Rotate cpecified number of degrees
{
  inherit LazyImage;
  constant operation_name = "rotate";
  constant destructive    = (<"image","alpha","meta">);
  protected {
    Layers process( Layers layers )
    {
      Layers victims = layers;
      if( args->layers )
	victims = find_layers( args->layers, layers );
      else if( args["layers-id"] )
	victims = find_layers( args["layers-id"], layers );

      float r = (float)args->degrees;
      foreach( victims, Image.Layer l )
      {
	Image.Image i = l->image(), a = l->alpha();
	if( i )
	  i = i->rotate( r );
	if( a )
	  a = a->rotate( r );
	l->set_image( i, a );
      }
      return layers;
    }

    Arguments check_args( Arguments args )
    {
      if( !args->degrees )
	RXML.parse_error( "Required argument 'degrees' missing.\n" );
      if( !parent )
	RXML.parse_error( "rotate cannot be the toplevel node\n" );
      return args;
    }
  };
}

class GreyBlur
//! About three times faster version of blur, but only blurs greyscale
//! images.
{
  inherit LazyImage;
  constant operation_name = "grey-blur";
  constant destructive    = (<"image","alpha">);
  protected {
    Layers process( Layers layers )
    {
      int t = max((int)args->times, 1);
      Layers victims = layers;

      if( args->layers )
	victims = find_layers( args->layers, layers );
      else if( args["layers-id"] )
	victims = find_layers( args["layers-id"], layers );


      foreach( victims, Image.Layer l )
      {
	Image.Image i;
	if( args->what == "alpha" )
	  i = l->alpha() || l->image()->copy()->clear(255,255,255);
	else
	  i = l->image();

	if( !i )
	  continue;

	i = i->grey_blur( t );

	if( args->what == "alpha" )
	  l->set_image( l->image(), i );
	else
	  l->set_image( i, l->alpha() );
      }

      return layers;
    }

    Arguments check_args( Arguments args )
    {
      if( !parent )
	RXML.parse_error( "blur cannot be the toplevel node\n" );
      return args;
    }
  };
}

class Blur
//! Blur either the layers or the layers alpha channel (specified with
//! the 'what' argument) the specified amount (radius=x and times=x,
//! defaults to 3 and 1, respectively)
//!
//! The radius == 3 case is optimized, and thus is significantly
//! faster than the other cases.
{
  inherit LazyImage;
  constant operation_name = "blur";
  constant destructive    = (<"image","alpha">);
  protected {
    array(array(int)) blur_matrix( int r )
    {
      return ({({1})*r })*r;
    }

    Layers process( Layers layers )
    {
      int d = max((int)args->radius, 3);
      int t = max((int)args->times, 1);
      array mt = blur_matrix( d );
      Layers victims = layers;

      if( args->layers )
	victims = find_layers( args->layers, layers );
      else if( args["layers-id"] )
	victims = find_layers( args["layers-id"], layers );


      foreach( victims, Image.Layer l )
      {
	Image.Image i;
	if( args->what == "alpha" )
	  i = l->alpha() || l->image()->copy()->clear(255,255,255);
	else
	  i = l->image();

	if( !i )
	  continue;

	if( d == 3 )
	  i = i->blur( t );
	else for( int tt; tt<t; tt++ )
	  i = i->apply_matrix( mt );

	if( args->what == "alpha" )
	  l->set_image( l->image(), i );
	else
	  l->set_image( i, l->alpha() );
      }

      return layers;
    }

    Arguments check_args( Arguments args )
    {
      if( !parent )
	RXML.parse_error( "blur cannot be the toplevel node\n" );
      return args;
    }
  };
}

#define BASIC_I_OR_A_OPERATION(X,Y,Z,A)					\
class X									\
{									\
  inherit LazyImage;							\
  constant operation_name =  Y;						\
  constant destructive    = (<"image","alpha">);			\
  protected {								\
    Layers process( Layers layers )					\
    {									\
      Layers victims = layers;						\
									\
      if( args->layers )						\
	victims = find_layers( args->layers, layers );			\
      else if( args["layers-id"] )					\
	victims = find_layers( args["layers-id"], layers );		\
									\
									\
      foreach( victims, Image.Layer l )					\
      {									\
	Image.Image i;							\
	foreach((args->what=="both"?({"image","alpha"}):({args->what})),\
	        string what)                                            \
        {                                                               \
	if( what == "alpha" )					        \
	  i = l->alpha() || l->image()->copy()->clear(255,255,255);	\
	else								\
	  i = l->image();						\
									\
	if( !i )							\
	  continue;							\
									\
	i = i->Z( A );							\
									\
	if( what == "alpha" )					        \
	  l->set_image( l->image(), i );				\
	else								\
	  l->set_image( i, l->alpha() );				\
	}                                                               \
      }									\
									\
      return layers;							\
    }									\
									\
    Arguments check_args( Arguments args )				\
    {									\
      if( !parent )							\
	RXML.parse_error( Y+" cannot be the toplevel node\n" );		\
      return args;                                                      \
    }									\
  };									\
}

//! @ignore
BASIC_I_OR_A_OPERATION( Gamma, "gamma", gamma,
			translate_coordinate_f(args->gamma,0,layers) );
BASIC_I_OR_A_OPERATION( Invert, "invert", invert, );
BASIC_I_OR_A_OPERATION( Grey,   "grey", grey, );
BASIC_I_OR_A_OPERATION( Color,  "color", color,
			@translate_color(args->color)->rgb());
BASIC_I_OR_A_OPERATION( Clear,  "clear", clear,
			translate_color(args->color));
BASIC_I_OR_A_OPERATION( MirrorX, "mirror-x", mirrorx, );
BASIC_I_OR_A_OPERATION( MirrorY, "mirror-y", mirrory, );
BASIC_I_OR_A_OPERATION( HSV2RGB, "hsv-to-rgb", hsv_to_rgb, );
BASIC_I_OR_A_OPERATION( RGB2HSV, "rgb-to-hsv", rgb_to_hsv, );
BASIC_I_OR_A_OPERATION( Distance,"color-distance",distancesq,
			translate_color(args->color));
BASIC_I_OR_A_OPERATION( SelectFrom,"select-from",select_from,
			@({translate_coordinate( args->x,0,layers ),
			   translate_coordinate( args->y,0,layers ),
			   (int)args["edge-value"] % 256 }));
//! @endignore

class Expand
//! Expand all the layers to the size of the whole image
{
  inherit LazyImage;
  constant operation_name = "expand";
  constant destructive    = (<"image","alpha">);

  protected {
    Layers process( Layers layers )
    {
      Layers victims = layers;
      if( !layers )
	RXML.parse_error( "Expand cannot be the toplevel node\n");
      
      if( args->layers )
	victims = find_layers( args->layers, layers );
      else if( args["layers-id"] )
	victims = find_layers( args["layers-id"], layers );

      mapping m = layers_extents( layers );
      
      foreach( victims, Image.Layer l )
      {
	if( l->tiled() )
	  continue;
	Image.Image i = Image.Image( m->w, m->h );
	Image.Image a = Image.Image( m->w, m->h );

	if( l->image() )
	  i = i->paste( l->image(), l->xoffset()-m->x0, l->yoffset()-m->y0 );

	if( l->alpha() )
	  a = a->paste( l->alpha(), l->xoffset()-m->x0, l->yoffset()-m->y0 );
	else
	  a->paste( l->image()->copy()->clear( Image.Color.white ),
		    l->xoffset()-m->x0, l->yoffset()-m->y0 );
	l->set_image( i, a );
	l->set_offset( 0, 0 );
      }
      return layers;
    }

    Arguments check_args( Arguments args )
    {
      if( !parent )
	RXML.parse_error( "expand cannot be the toplevel node\n" );
      return args;
    }
  };
}

class Line
{
  inherit LazyImage;
  // generates a new layer, or draws in the alpha of an old one.
  constant operation_name = "line";
  constant destructive    = (< "alpha", >);

  protected {
    Layers process( Layers layers )
    {
      array(float) coordinates = ({});
      Layers on;
      Image.Image pi;

      if( args->layers )      on = find_layers( args->layers, layers );
      if( args["layers-id"] ) on = find_layers_id( args["layers-id"], layers );
      
      int x = translate_coordinate( args->xsize, 0, layers ),
	  y = translate_coordinate( args->ysize, 0, layers );
      mapping ext;

      if( on )
      {
	ext = layers_extents( on );
	x = ext->x1;
	y = ext->y1;
      }

      if( x && y )
	pi = Image.Image( x, y );

      foreach(args->coordinates/",", string c)
	coordinates += ({
	  translate_coordinate_f( c, pi, layers )
	});

      if( args["coordinate-system"] )
      {
	float a, b, c, d;
	if( sscanf( parse_variables(args["coordinate-system"], pi, layers),
		    "%f,%f-%f,%f", a, b, c, d ) != 4 )
	  RXML.parse_error("Illegal syntax for coordinate-system. "
			   "Expected x0,y0-x1,y1\n");

	for( int i=0; i<sizeof( coordinates ); i+=2 )
	{
	  coordinates[i]  = virtual_to_screen( coordinates[i], a, c, x );
	  coordinates[i+1] = (y-virtual_to_screen( coordinates[i+1], b, d, y ));
	}
      }

      if( !pi )
      {
	foreach( coordinates / 2, array s )
	{
	  if( (int)s[0] > x )	x = (int)s[0];
	  if( (int)s[1] > y )   y = (int)s[1];
	}
	pi = Image.Image( x, y );
      }

      pi->setcolor( 255,255,255 );

      array(array(float)) coords =
	make_polygon_from_line( translate_coordinate_f( args->width||"1.0",pi,
							layers ),
				coordinates,
				translate_cap_style( args->cap ),
				translate_join_style( args->join ) );
				
      
      pi = pi->polygone( @coords );

      if( args->opacity )
	pi *= ((float)args->opacity)/100.0;
	
      
      if( !on )
      {
	Image.Layer l = Image.Layer( );
	l->set_misc_value( "name",
			   parse_variables(args->name || "poly", pi, layers) );
	l->set_offset( translate_coordinate( args->xoffset, pi, layers ),
		       translate_coordinate( args->yoffset, pi, layers ) );

	l->set_image( Image.Image( x,y, translate_color( args->color ) ),
		      pi );
	return (layers||({}))+({l});
      }

      if( args["base-opacity"] )
	pi += (int)(((float)args["base-opacity"]/100.0)*255);
      foreach( on, Image.Layer l )
      {
	Image.Image a = l->alpha();
	if( !a ) a=l->image();
	a = a->copy()->clear(0,0,0)->paste( pi, -l->xoffset(), -l->yoffset() );
	l->set_image( l->image(),a );
      }
      return layers;
    }

    Arguments check_args( Arguments args )
    {
      if( !args->coordinates ||
	  sizeof( args->coordinates/"," )&1 )
	RXML.parse_error( "Illegal coordinate list\n");
      return args;
    }
  };
}


class Polygone
{
  inherit LazyImage;
  // generates a new layer, or draws in the alpha of an old one.
  constant operation_name = "poly";
  constant destructive    = (< "alpha", >);

  protected {
    Layers process( Layers layers )
    {
      array(float) coordinates = ({});
      Layers on;
      Image.Image pi;

      if( args->layers )      on = find_layers( args->layers, layers );
      if( args["layers-id"] ) on = find_layers_id( args["layers-id"], layers );
      
      int x = translate_coordinate( args->xsize, 0, layers ),
	  y = translate_coordinate( args->ysize, 0, layers );
      mapping ext;

      if( on )
      {
	ext = layers_extents( on );
	x = ext->x1;
	y = ext->y1;
      }

      if( x && y )
	pi = Image.Image( x, y );

      foreach(args->coordinates/",", string c)
	coordinates += ({
	  translate_coordinate_f( c, pi, layers )
	});

      if( args["coordinate-system"] )
      {
	float a, b, c, d;
	if( sscanf( parse_variables(args["coordinate-system"], pi, layers),
		    "%f,%f-%f,%f", a, b, c, d ) != 4 )
	  RXML.parse_error("Illegal syntax for coordinate-system. "
			   "Expected x0,y0-x1,y1\n");

	for( int i=0; i<sizeof( coordinates ); i+=2 )
	{
	  coordinates[i]  = virtual_to_screen( coordinates[i], a, c, x );
	  coordinates[i+1] = (y-virtual_to_screen( coordinates[i+1], b, d, y ));
	}
      }
      if( !pi )
      {
	foreach( coordinates / 2, array s )
	{
	  if( (int)s[0] > x )	x = (int)s[0];
	  if( (int)s[1] > y )   y = (int)s[1];
	}
	pi = Image.Image( x, y );
      }

      pi->setcolor( 255,255,255 );
      pi = pi->polygone( coordinates );

      if( args->opacity )
	pi *= ((float)args->opacity)/100.0;
	
      
      if( !on )
      {
	Image.Layer l = Image.Layer( );
	l->set_misc_value( "name",
			   parse_variables(args->name || "poly", pi, layers) );
	l->set_offset( translate_coordinate( args->xoffset, pi, layers ),
		       translate_coordinate( args->yoffset, pi, layers ) );

	l->set_image( Image.Image( x,y, translate_color( args->color ) ),
		      pi );
	return (layers||({}))+({l});
      }

      if( args["base-opacity"] )
	pi += (int)(((float)args["base-opacity"]/100.0)*255);
      foreach( on, Image.Layer l )
      {
	Image.Image a = l->alpha();
	if( !a ) a=l->image();
	a = a->copy()->clear(0,0,0)->paste( pi, -l->xoffset(), -l->yoffset() );
	l->set_image( l->image(),a );
      }
      return layers;
    }

    Arguments check_args( Arguments args )
    {
      if( !args->coordinates ||
	  sizeof( args->coordinates/"," )&1 )
	RXML.parse_error( "Illegal coordinate list\n");
      return args;
    }
  };
}




protected string low_hash( program|object p, mapping a )
{
  Crypto.MD5 o = Crypto.MD5();
  if(!a)
    error("low_hash called before set_args\n");
  o->update( p->operation_name );
  o->update( sprintf( "%O", a ) );
  return o->digest();
}

protected Thread.Local current_layers = Thread.Local();
protected Thread.Local known_images = Thread.Local();

void add_layers( Layers l )
{
  current_layers->set( set_weak_flag(current_layers->get()|l,1) );
}

Layers get_current_layers()
{
  return current_layers->get()-({0});
}

void clear_cache()
{
  known_images->set( set_weak_flag( ([ ]), 1 ) );
  current_layers->set( ({}) );
}

LazyImage join_images( LazyImage ... i )
//! Create a new @[LazyImage] that contains all layers in the
//! specified images.
{
  Join j = Join( 0 );

  // Merge any join nodes in the arguments here to avoid deep recursion.
  array(LazyImage) contents =
    map(i, lambda(LazyImage i) {
	     if (i && (i->operation_name == "join") && i->args) {
	       return [array(LazyImage)]i->args->contents;
	     }
	     return ({ i });
	   }) * ({});
  
  j->set_args( ([ "contents":contents ]) );
  return j;
}

LazyImage new( program p, LazyImage parent, mapping args, void|int hard )
//! Create a new (shared) LazyImage.
//!
//! The @[args] mapping is intended to be the args received in
//! the tag.
//!
//! For most tags the content of the tag is intended to be the @[parent].
//! If there is more than one @[LazyImage] in the contents, use
//! @[join_images]( images ) as the parent.
//!
//! @[p] should be a child of the @[LazyImage] class.
//! @[parent] can be 0.
//!
//! The @[hard] flag indicates if references counting and check_arg
//! should be skipped. Usefull when decoding an already verified
//! object tree.
  
{
  string hash = (parent?parent->hash():"") + low_hash( p, args );
  mapping ki = known_images->get();
  if( ki[ hash ] )
    return hard? ki[ hash ]: ki[ hash ]->ref();

  LazyImage res = p( parent ? (hard? parent: parent->ref()) : 0 );
  res->set_args( args, hard );
  ki[ res->_hash = hash ] = res;
  return hard? res: res->ref(); // no ->ref() here.
}

LazyImage decode(mapping node_tree)
{
  if(!node_tree)
    return 0;
  
  if(arrayp(node_tree->p)) {
    LazyImage image = join_images(@map(node_tree->p, decode));
    image->refs = node_tree->r;
    return image;
  }
  
  program prog = dirnode[node_tree->n];

  if(!prog || !prog->operation_name)
    error("Unknown program: %O.\n", node_tree->n);

  LazyImage image = new(prog, decode(node_tree->p), node_tree->a, 1);
  image->refs = node_tree->r;
  return image;
}
