static mapping changed_values = set_weak_flag( ([]), 1 );
static int unique_vid;
static inherit "html";

class Variable
//. The basic variable type in Roxen. All other variable types should
//. inherit this class. 
{
  constant type = "Basic";
  //. Mostly used for debug

  string sname;
  //. The 'short' name of this variable. This string is not
  //. translated.

  static string _initial;
  static int _id = unique_vid++;

  string doc( RequestID id )
    //. Return the documentation for this variable (locale dependant).
    //. 
    //. The default implementation queries the locale object in roxen
    //. to get the documentation.
  {
    return LC->module_doc_string( this_object(), sname, 1, id );
  }
  
  string name( RequestID id )
    //. Return the name of this variable (locale dependant).
    //. 
    //. The default implementation queries the locale object in roxen
    //. to get the documentation.
  {
    return LC->module_doc_string( this_object(), sname, 0, id );
  } 

  mixed default_value()
    //. The default (initial) value for this variable.
  {
    return _initial;
  }

  string set( mixed to )
    //. Set the variable to a new value. If this function returns a
    //. string, it is a warning (or error) to the user who changed the
    //. value.
  {
    string err, e2;
    if( e2 = catch( [err,to] = verify_set( to )) )
      return (string)e2;

    low_set( to );
    return err;
  }

  void low_set( mixed to )
    //. Forced set. No checking is done whatsoever.
  {
    if( to != default_value() )
      changed_values[ this_object() ] = to;
    else
      m_delete( changed_values, this_object() );
  }

  mixed query( )
    //. Returns the current value for this variable.
  {
    if( changed_values[ this_object() ] )
      return changed_values[ this_object() ];
    return default_value();
  }

  int is_defaulted()
    //. Return true if this variable is set to the default value.
  {
    return !changed_values[ this_object() ];
  }

  array(string|mixed) mixed verify_set( mixed new_value )
    //. Return ({ error, new_value }) for the variable, or throw a string.
    //. 
    //. If error != 0, it should contain a warning or error message.
    //. If new_value is modified, it will be used instead of the 
    //. supplied value.
    //.
    //. If a string is thrown, it will be used as a error message from
    //. set, and the variable will not be changed.
  {
    return ({ 0, new_value });
  }

  mapping(string:string) get_form_vars( RequestID id )
    //. Return all form variables preficed with path().
  {
    array names = glob( path()+"*", indices(id->variables) );
    mapping res = ([ ]);
    foreach( names, string n )
      res[ n[strlen(path()..) ] ] = id->variables[ n ];
    return res;
  }

  mixed transform_from_form( string what )
    //. Given a form value, return what should be set.
    //. Used by the default set_from_form implementation.
  {
    return what;
  }
  
  mixed set_from_form( RequestID id )
    //. Set this variable from the form variable in id->Variables,
    //. if any are available. The default implementation simply sets
    //. the variable to the string in the form variables.
  {
    mapping val;
    if( sizeof( val = get_form_vars()) && val[""] && 
        transform_from_form( val[""] ) != query() )
      set( transform_from_form( val[""] ));
  }
  
  string path()
    //. A unique identifier for this variable. 
    //. Should be used to prefix form variables.
  {
    return "V"+_id;
  }

  string render_form( RequestID id )
    //. Return a form to change this variable. The name of all <input>
    //. or similar variables should be prefixed with the value returned
    //. from the path() function.
  {
  }

  string render_view( RequestID id )
    //. Return a 'view only' version of this variable.
  {
    return (string)query();
  }
  
  static string _sprintf( int i )
  {
    if( i == 'O' )
      return sprintf( "Variables.%s(%s) [%O]", type, name, query() );
  }

  void create( string short_name, mixed default_value )
    //. Constructor. 
  {
    sname = _sn;
    _initial = _dv;
  }
}




// =====================================================================
// Float
// =====================================================================

class Float
//. Float variable, with optional range checks, and adjustable precision.
{
  inherit Variable;
  constant type = "Int";
  static float _max, _min;
  static int _prec = 2, mm_set;

  static string _format( float m )
  {
    if( !_prec )
      return sprintf( "%d", (int)m );
    return sprintf( "%1."+_prec+"f", m );
  }

  void set_range(float minimum, float maximum )
    //. Set the range of the variable, if minimum and maximum are both
    //. 0.0 (the default), the range check is removed.
  {
    if( minimum == maximum )
      mm_set = 0;
    else
      mm_set = 1;
    _max = maximum;
    _min = minimum;
  }

  void set_precision( int prec )
    //. Set the number of _decimals_ shown to the user.
    //. If prec is 3, and the float is 1, 1.000 will be shown.
    //. Default is 2.
  {
    _prec = ndigits;
  }

  array(string|float) verify_set( float new_value )
  {
    string warn;
    if( mm_set )
    {
      if( new_value > _max )
      {
        warn = sprintf("Value is bigger than %s, adjusted", _format(_max) );
        new_value = _max;
      }
      else if( new_value < _min )
      {
        warn = sprintf("Value is less than %s, adjusted", _format(_min) );
        new_value = _min;
      }
    }
    return ({ warn, new_value });
  }
  
  int transform_from_form( string what )
  {
    return (float)what;
  }

  string render_view( RequestID id )
  {
    return _format(query());
  }
  
  string render_form( RequestID id )
  {
    int size = 15;
    if( mm_set ) 
      size = max( strlen(_format(_max)), strlen(_format(_min)) )+2;
    return input(path(), _format(query()), size);
  }
}




// =====================================================================
// Int
// =====================================================================

class Int
//. Integer variable, with optional range checks
{
  inherit Variable;
  constant type = "Int";
  static int _max, _min, mm_set;

  void set_range(int minimum, int maximum )
    //. Set the range of the variable, if minimum and maximum are both
    //. 0 (the default), the range check is removed.
  {
    if( minimum == maximum )
      mm_set = 0;
    else
      mm_set = 1;
    _max = maximum;
    _min = minimum;
  }

  array(string|int) verify_set( int new_value )
  {
    string warn;
    if( mm_set )
    {
      if( new_value > _max )
      {
        warn = sprintf("Value is bigger than %d, adjusted", _max );
        new_value = _max;
      }
      else if( new_value < _min )
      {
        warn = sprintf("Value is less than %d, adjusted", _min );
        new_value = _min;
      }
    }
    return ({ warn, new_value });
  }

  int transform_from_form( string what )
  {
    return (int)what;
  }

  string render_form( RequestID id )
  {
    int size = 10;
    if( mm_set ) 
      size = max( strlen((string)_max), strlen((string)_min) )+2;
    return input(path(), (string)query(), size);    
  }
}


// =====================================================================
// String
// =====================================================================

class String
//. String variable
{
  inherit Variable;
  constant type = "String";
  string render_form( RequestID id )
  {
    return input(path(), (string)query(), 60);
  }
}

// =====================================================================
// Text
// =====================================================================
class Text
//. Text (multi-line string) variable
{
  inherit String;
  constant type = "Text";
  string render_form( RequestID id )
  {
    return "<textarea name='"+path()+"'>"
           + Roxen.html_encode_string( query() || "" ) +
           "</textarea>";
  }
}



// =====================================================================
// Password
// =====================================================================
class Password
//. Password variable (uses crypt)
{
  inherit String;
  constant type = "Password";

  mixed set_from_form( RequestID id )
  {
    mapping val;
    if( sizeof( val = get_form_vars()) && 
        val[""] && strlen(val[""]) )
      set( crypt( val[""] ) );
  }

  string render_view( RequestID id )
  {
    return "******";
  }

  string render_form( RequestID id )
  {
    return "<input name=\""+path()+"\" type=password size=30>";
  }
}


// =====================================================================
// MultipleChoice (one of many) baseclass
// =====================================================================

class MultipleChoice
//. Base class for multiple-choice (one of many) variables.
{
  inherit Variable;
  static array _list = ({});
  void set_choice_list( array to )
    //. Set the list of choices.
  {
    _list = to;
  }

  array get_choice_list( )
    //. Get the list of choices. Used by this class as well.
    //. You can overload this function if you want a dynamic list.
  {
    return _list;
  }

  static string _name( mixed what )
    //. Get the name used as value for an element gotten from the
    //. get_list() function.
  {
    return (string)what;
  }

  static string _title( mixed what )
    //. Get the title used as description (shown to the user) for an
    //. element gotten from the get_list() function.
  {
    return (string)what;
  }

  void render_form( RequestID id )
  {
    string res = "<select name='"+path()+"'>\n";
    foreach( get_list(), mixed elem )
    {
      mapping m = ([]);
      m->value = _name( elem );
      if( m->value == query() )
        m->selected="selected";
      res += "  "+make_container( "option", m, _title( elem ) )+"\n";
    }
    return res + "</select>";
  }
}


// =====================================================================
// MultipleChoice subclasses
// =====================================================================

class StringChoice
//. Select one of many strings.
{
  inherit MultipleChoice;
}


class IntChoice
//. Select one of many integers.
{
  inherit MultipleChoice;
  int transform_from_form( string what )
  {
    return (int)what;
  }
}


class FloatChoice
//. Select one of many floating point (real) numbers.
{
  inherit MultipleChoice;
  static int _prec = 3;

  void set_precision( int prec )
    //. Set the number of _decimals_ shown to the user.
    //. If prec is 3, and the float is 1, 1.000 will be shown.
    //. Default is 2.
  {
    _prec = ndigits;
  }

  static string _title( mixed what )
  {
    if( !_prec )
      return sprintf( "%d", (int)m );
    return sprintf( "%1."+_prec+"f", m );
  }

  int transform_from_form( string what )
  {
    array q = get_choice_list();
    array a = mkmapping( map( q, _name ), q );
    return a[what] || (float)what; // Do we want this fallback?
  }
}

