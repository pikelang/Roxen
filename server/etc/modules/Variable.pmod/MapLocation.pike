//! A class that enables specification of a physical location.

inherit Variable.Variable;

constant type = "MapLocation";

roxen.ImageCache cache;
//! This is the image cache used for the maps.

protected int width = 500;
protected int height = 300;
protected function(void:string) internal_location;
protected mapping map_settings;
protected mapping marker_settings;

void set_land_color(int(0..255) r, int(0..255) g, int(0..255) b)
  //! Sets the color of the land areas.
{
  map_settings = map_settings || ([]);
  map_settings->color_fu = lambda(string name) { return ({ r, g, b }); };
}

void set_sea_color(int(0..255) r, int(0..255) g, int(0..255) b)
  //! Sets the color of the sea areas.
{
  map_settings = map_settings ||([]);
  map_settings->color_sea = ({ r, g, b });
}

void set_marker_size(int size)
  //! Sets the size of the marker.
{
  if(size<1) throw( ({ "Marker size less than 1.\n", backtrace() }) );
  marker_settings = marker_settings || ([]);
  marker_settings->size = size;
}

void set_marker_color(int(0..255) r, int(0..255) g, int(0..255) b)
  //! Sets the color of the marker.
{
  marker_settings = marker_settings || ([]);
  marker_settings->color = ({ r, g, b });
}

void set_dimensions(int _width, int _height)
  //! Defines the dimensions of the clickable map.
  //! Zero means automatically calculated.
{
  if(_width) {
    width = _width;
    height = _height || (int)(width*3.0/5.0);
  }
  else {
    height = _height || 300;
    width = (int)(height*5.0/3.0);
  }
}

mixed transform_from_form( string x, string y )
  //! Given a form value, return what should be set.
  //! Used by the default set_from_form implementation.
{
  return ({ (int)x, (int)y });
}

array(string|mixed) verify_set( mixed new_value )
  //! Verfifies that the coordinates is not off the map.
{
  if(!new_value)
    return ({ 0, 0 });
  int error;
  if( new_value[0]<0 ) {
    new_value[0]=0;
    error=1;
  }
  if( new_value[1]<0 ) {
    new_value[1]=0;
    error=1;
  }
  if( new_value[0]>=width ) {
    new_value[0]=width-1;
    error=1;
  }
  if( new_value[1]>=height ) {
    new_value[1]=height-1;
    error=1;
  }
  if(error)
    return ({ "Coordinates off the map. Corrected.", new_value });
  return ({ 0, new_value });
}

void set_from_form( RequestID id )
  //! Set this variable from the form variable in id->variables,
  //! if any are available. The default implementation simply sets
  //! the variable to the string in the form variables.
  //!
  //! Other side effects: Might create warnings to be shown to the 
  //! user (see get_warnings)
  //! 
  //! Calls verify_set_from_form and verify_set
{
  mixed val;
  if( sizeof( val = get_form_vars(id)) && val[".x"] && val[".y"] &&
      !equal( (val = transform_from_form( val[".x"], val[".y"] )), query() ) ) {
    array b;
    mixed q = catch( b = verify_set_from_form( val ) );
    if( q || sizeof( b ) != 2 ) {
      if( q )
	add_warning( q );
      else
	add_warning( "Internal error: Illegal sized array "
		     "from verify_set_from_form\n" );
      return;
    }
    if( b ) {
      set_warning( b[0] );
      set( b[1] );
    }
  }
  else if( sizeof( val = get_form_vars(id) ) && val["R.x"] )
    set( 0 );
}

protected string create_src( RequestID id ) {
  mapping state = ([ "width":width,
		     "height":height ]);
  array coord = query();
  if(coord)
    state->markers = ({ ([ "x":coord[0],
			   "y":coord[1],
			   "size":4,
			   "color": ({ 255, 0, 0 }) ]) });
  if(marker_settings)
    state->markers[0] += marker_settings;
  if(map_settings)
    state += map_settings;

  return internal_location() + cache->store(state, id);
}

string render_view( RequestID id, void|mapping additional_args ) {
  return Roxen.make_tag( "img", additional_args + ([ "src":create_src(id) ]) );
}

string render_form( RequestID id, void|mapping additional_args ) {
  string ret = Variable.input(path(), 0, 0, additional_args +
			([ "src":create_src(id),
			   "type":"image" ]) );
  if(query())
    ret += "<submit-gbutton2 name=\""+path()+"R\">"+"Remove marker"+"</submit-gbutton2>";

  return ret;
}

void create(array default_value, function(void:string) _internal_location,
	    void|int flags, void|LocaleString std_name,
	    void|LocaleString std_doc) {
  internal_location = _internal_location;
  cache = roxen.ImageCache( "atlas", generate_image );
  ::create(default_value, flags, std_name, std_doc);
}

Image.Image generate_image(mapping state, RequestID id)
{
  if(!state)
    return 0;

  Map.Earth m = Map.Earth();

  Image.Image img = m->image(state->width, state->height, state);

  return img;
}
