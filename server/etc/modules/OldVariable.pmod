static mapping changed_values = set_weak_flag( ([]), 1 );
static int unique_vid;

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
  
  mixed set_from_form( RequestID id )
    //. Set this variable from the form variable in id->Variables,
    //. if any are available. The default implementation simply sets
    //. the variable to the string in the form variables.
  {
    array(mixed) val;
    if( sizeof( val = get_form_vars()) && val[""] )
      set( val[""] );
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

class Int
{
  inherit Variable;
  constant type = "Int";
  static int _max, _min, mm_set;

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
  
  void set_range(int mm, int mi )
  {
    if( _max == 0 && _min == 0 )
      mm_set = 0;
    else
      mm_set = 1;
    _max = mm;
    _min = mi;
  }


  string render_form( RequestID id )
  {
    
  }
}
