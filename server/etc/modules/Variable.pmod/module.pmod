// $Id: module.pmod,v 1.11 2000/09/01 01:15:21 mast Exp $

#include <module.h>
#include <roxen.h>

// Locale macros
static inline string getloclang() {
  return roxenp()->locale->get();
}

//<locale-token project="roxen_config"> LOCALE </locale-token>

#if constant(Locale.DeferredLocale)
#define LOCALE(X,Y)	\
  ([string](mixed)Locale.DeferredLocale("roxen_config",getloclang,X,Y))
#else  /* !Locale.DeferredLocale */
#define LOCALE(X,Y)	\
  ([string](mixed)RoxenLocale.DeferredLocale("roxen_config",getloclang,X,Y))
#endif /* Locale.DeferredLocale */

// Increased for each variable, used to index the mappings below.
static int unique_vid;

// The theory is that most variables (or at least a sizable percentage
// of all variables) does not have these members. Thus this saves
// quite a respectable amount of memory, the cost is speed. But not
// all that great a percentage of speed.
static mapping(int:mixed)  changed_values = ([]);
static mapping(int:function(object:void)) changed_callbacks = ([]);
static mapping(int:int)    all_flags      = ([]);
static mapping(int:string) all_warnings   = ([]);
static mapping(int:function(RequestID,object:int))
                           invisibility_callbacks = set_weak_flag( ([]), 1 );

class Variable
//! The basic variable type in Roxen. All other variable types should
//! inherit this class.
{
  constant is_variable = 1;

  constant type = "Basic";
  //! Mostly used for debug (sprintf( "%O", variable_obj ) uses it)

  static int _id = unique_vid++;
  // used for indexing the mappings.

  static mixed _initial; // default value
  static string _path;   // used for forms
  static string|object  __name, __doc;

  void destroy()
  {
    // clean up...
    m_delete( all_flags, _id );
    m_delete( all_warnings, _id );
    m_delete( invisibility_callbacks, _id );
    m_delete( changed_values, _id );
  }

  string get_warnings()
    //! Returns the current warnings, if any.
  {
    return all_warnings[ _id ];
  }

  int get_flags() 
    //! Returns the 'flags' field for this variable.
    //! Flags is a bitwise or of one or more of 
    //! 
    //! VAR_EXPERT         Only for experts 
    //! VAR_MORE           Only visible when more-mode is on (default on)
    //! VAR_DEVELOPER      Only visible when devel-mode is on (default on)
    //! VAR_INITIAL        Should be configured initially.
  {
    return all_flags[_id];
  }

  void set_flags( int flags )
    //! Set the flags for this variable.
    //! Flags is a bitwise or of one or more of 
    //! 
    //! VAR_EXPERT         Only for experts 
    //! VAR_MORE           Only visible when more-mode is on (default on)
    //! VAR_DEVELOPER      Only visible when devel-mode is on (default on)
    //! VAR_INITIAL        Should be configured initially.
  {
    if(!flags )
      m_delete( all_flags, _id );
    else
      all_flags[_id] = flags;
  }

  int check_visibility( RequestID id,
                        int more_mode,
                        int expert_mode,
                        int devel_mode,
                        int initial )
    //! Return 1 if this variable should be visible in the
    //! configuration interface. The default implementation check the
    //! 'flags' field, and the invisibility callback, if any. See
    //! get_flags, set_flags and set_invisibibility_check_callback
  {
    int flags = get_flags();
    function cb;
    if( initial && !(flags & VAR_INITIAL) )      return 0;
    if( (flags & VAR_EXPERT) && !expert_mode )   return 0;
    if( (flags & VAR_MORE) && !more_mode )       return 0;
    if( (flags & VAR_DEVELOPER) && !devel_mode ) return 0;
    if( (cb = get_invisibility_check_callback() ) && 
        cb( id, this_object() ) )
      return 0;
    return 1;
  }

  void set_invisibility_check_callback( function(RequestID,Variable:int) cb )
    //! If the function passed as argument returns 1, the variable
    //! will not be visible in the configuration interface.
    //!
    //! Pass 0 to remove the invisibility callback.
  {
    if( functionp( cb ) )
      invisibility_callbacks[ _id ] = cb;
    else
      m_delete( invisibility_callbacks, _id );
  }

  function(Variable:void) get_changed_callback( )
    //! Return the callback set with set_changed_callback
  {
    return changed_callbacks[ _id ];
  }

  void set_changed_callback( function(Variable:void) cb )
    //! The function passed as an argument will be called 
    //! when the variable value is changed.
    //! 
    //! Pass 0 to remove the callback.
  {
    if( functionp( cb ) )
      changed_callbacks[ _id ] = cb;
    else
      m_delete( changed_callbacks, _id );
  }

  function(RequestID,Variable:int) get_invisibility_check_callback() 
    //! Return the current invisibility check callback
  {
    return invisibility_callbacks[_id];
  }

  string doc(  )
    //! Return the documentation for this variable (locale dependant).
    //! 
    //! The default implementation queries the locale object in roxen
    //! to get the documentation.
  {
    return __doc || "";
  }
  
  string name(  )
    //! Return the name of this variable (locale dependant).
    //! 
    //! The default implementation queries the locale object in roxen
    //! to get the documentation.
  {
    return __name || "unnamed "+_id;
  } 

  string type_hint(  )
    //! Return the type hint for this variable.
    //! Type hints are generic documentation for this variable type, 
    //! and is the same for all instances of the type.
  {
  }

  mixed default_value()
    //! The default (initial) value for this variable.
  {
    return _initial;
  }

  void set_warning( string to )
    //! Set the warning shown in the configuration interface
  { 
    if( to && strlen(to) )
      all_warnings[ _id ] = to; 
    else
      m_delete( all_warnings, _id );
  }

  int set( mixed to )
    //! Set the variable to a new value. 
    //! If this function returns true, the set was successful. 
    //! Otherwise 0 is returned. 0 is also returned if the variable was
    //! not changed by the set. 1 is returned if the variable was
    //! changed, and -1 is returned if the variable was changed back to
    //! it's default value.
    //!
    //! If verify_set() threw a string, ([])[0] is returned, that is,
    //! 0 with zero_type set.
    //!
    //! If verify_set() threw an exception, the exception is thrown.
  {
    string err, e2;
    if( e2 = catch( [err,to] = verify_set( to )) )
    {
      if( stringp( e2 ) )
      {
        set_warning( e2 );
        return ([])[0];
      }
      throw( e2 );
    }
    set_warning( err );
    return low_set( to );
  }

  int low_set( mixed to )
    //! Forced set. No checking is done whatsoever.
    //! 1 is returned if the variable was changed, -1 is returned if
    //! the variable was changed back to it's default value and 0
    //! otherwise.
  {
    if( equal( to, query() ) )
      return 0;

    if( !equal(to, default_value() ) )
    {
      changed_values[ _id ] = to;
      if( get_changed_callback() )
        catch( get_changed_callback()( this_object() ) );
      return 1;
    }
    else
    {
      m_delete( changed_values, _id );
      if( get_changed_callback() )
        catch( get_changed_callback()( this_object() ) );
      return -1;
    }
  }

  mixed query()
    //! Returns the current value for this variable.
  {
    mixed v;
    if( !zero_type( v = changed_values[ _id ] ) )
      return v;
    return default_value();
  }
  
  int is_defaulted()
    //! Return true if this variable is set to it's default value.
  {
    return zero_type( changed_values[ _id ] ) || 
           equal(changed_values[ _id ], default_value());
  }

  array(string|mixed) verify_set( mixed new_value )
    //! Return ({ error, new_value }) for the variable, or throw a string.
    //! 
    //! If error != 0, it should contain a warning or error message.
    //! If new_value is modified, it will be used instead of the 
    //! supplied value.
    //!
    //! If a string is thrown, it will be used as a error message from
    //! set, and the variable will not be changed.
  {
    return ({ 0, new_value });
  }

  mapping(string:string) get_form_vars( RequestID id )
    //! Return all form variables preficed with path().
  {
    string p = path();
    array names = glob( p+"*", indices(id->variables) );
    mapping res = ([ ]);
    foreach( sort(names), string n )
      res[ n[strlen(p).. ] ] = id->variables[ n ];
    return res;
  }

  mixed transform_from_form( string what )
    //! Given a form value, return what should be set.
    //! Used by the default set_from_form implementation.
  {
    return what;
  }
  
  void set_from_form( RequestID id )
    //! Set this variable from the form variable in id->Variables,
    //! if any are available. The default implementation simply sets
    //! the variable to the string in the form variables.
    //!
    //! Other side effects: Might create warnings to be shown to the 
    //! user (see get_warnings)
  {
    mapping val;
    if( sizeof( val = get_form_vars(id)) && val[""] && 
        transform_from_form( val[""] ) != query() )
      set( transform_from_form( val[""] ));
  }
  
  string path()
    //! A unique identifier for this variable. 
    //! Should be used to prefix form variable names.
    //! 
    //! Unless this variable was created by defvar(), the path is set
    //! by the configuration interface the first time the variable is
    //! to be shown in a form. This function can thus return 0. If it
    //! does, and you still have to show the form, call set_path( )
    //! with a unique string.
  {
    return _path;
  }

  void set_path( string to )
    //! Set the path. Not normally called from user-level code.
    //! 
    //! This function must be called at least once before render_form
    //! can be called (at least if more than one variable is to be 
    //! shown on the same page). This is normally done by the 
    //! configuration interface.
  {
    _path = to;
  }

  string render_form( RequestID id, void|mapping additional_args );
    //! Return a (HTML) form to change this variable. The name of all <input>
    //! or similar variables should be prefixed with the value returned
    //! from the path() function.

  string render_view( RequestID id )
    //! Return a 'view only' version of this variable.
  {
    return Roxen.html_encode_string( (string)query() );
  }
  
  static string _sprintf( int i )
  {
    if( i == 'O' )
      return sprintf( "Variables.%s(%s) [%O]", type, 
                      (string)name(), 
                      query() );
  }

  static void create(mixed default_value, void|int flags,
                     void|string|object std_name, void|string|object std_doc)
    //! Constructor. 
    //! Flags is a bitwise or of one or more of 
    //! 
    //! VAR_EXPERT         Only for experts 
    //! VAR_MORE           Only visible when more-mode is on (default on)
    //! VAR_DEVELOPER      Only visible when devel-mode is on (default on)
    //! VAR_INITIAL        Should be configured initially.
    //! 
    //! The std_name and std_doc is the name and documentation string
    //! for the default locale (always english)
  {
    set_flags( flags );
    _initial = default_value;
    __name = std_name;
    __doc = std_doc;
  }
}




// =====================================================================
// Float
// =====================================================================

class Float
//! Float variable, with optional range checks, and adjustable precision.
{
  inherit Variable;
  constant type = "Float";
  static float _max, _min;
  static int _prec = 2;

  static string _format( float m )
  {
    if( !_prec )
      return sprintf( "%d", (int)m );
    return sprintf( "%1."+_prec+"f", m );
  }

  void set_range(float minimum, float maximum )
    //! Set the range of the variable, if minimum and maximum are both
    //! 0.0 (the default), the range check is removed.
  {
    _max = maximum;
    _min = minimum;
  }

  void set_precision( int prec )
    //! Set the number of _decimals_ shown to the user.
    //! If prec is 3, and the float is 1, 1.000 will be shown.
    //! Default is 2.
  {
    _prec = prec;
  }

  array(string|float) verify_set( float new_value )
  {
    string warn;
    if( new_value > _max && _max > _min)
    {
      warn = sprintf("Value is bigger than %s, adjusted", _format(_max) );
      new_value = _max;
    }
    else if( new_value < _min && _min < _max)
    {
      warn = sprintf("Value is less than %s, adjusted", _format(_min) );
      new_value = _min;
    }
    return ({ warn, new_value });
  }
  
  float transform_from_form( string what )
  {
    return (float)what;
  }

  string render_view( RequestID id )
  {
    return Roxen.html_encode_string( _format(query()) );
  }
  
  string render_form( RequestID id, void|mapping additional_args )
  {
    int size = 15;
    if( _max == _min ) 
      size = max( strlen(_format(_max)), strlen(_format(_min)) )+2;
    return input(path(), _format(query()), size, additional_args);
  }
}




// =====================================================================
// Int
// =====================================================================

class Int
//! Integer variable, with optional range checks
{
  inherit Variable;
  constant type = "Int";
  static int _max, _min;

  void set_range(int minimum, int maximum )
    //! Set the range of the variable, if minimum and maximum are both
    //! 0 (the default), the range check is removed.
  {
    _max = maximum;
    _min = minimum;
  }

  array(string|int) verify_set( int new_value )
  {
    string warn;
    if( new_value > _max && _max > _min )
    {
      warn = sprintf("Value is bigger than %d, adjusted", _max );
      new_value = _max;
    }
    else if( new_value < _min && _min < _max)
    {
      warn = sprintf("Value is less than %d, adjusted", _min );
      new_value = _min;
    }
    return ({ warn, new_value });
  }

  int transform_from_form( string what )
  {
    return (int)what;
  }

  string render_form( RequestID id, void|mapping additional_args )
  {
    int size = 10;
    if( _min == _max ) 
      size = max( strlen((string)_max), strlen((string)_min) )+2;
    return input(path(), (string)query(), size, additional_args);
  }
}


// =====================================================================
// String
// =====================================================================

class String
//! String variable
{
  inherit Variable;
  constant type = "String";
  constant width = 40;
  //! The width of the input field. Used by overriding classes.
  string render_form( RequestID id, void|mapping additional_args )
  {
    return input(path(), (string)query(), width, additional_args);
  }
}

// =====================================================================
// Text
// =====================================================================
class Text
//! Text (multi-line string) variable
{
  inherit String;
  constant type = "Text";
  constant cols = 60;
  //! The width of the textarea
  constant rows = 10;
  //! The height of the textarea
  string render_form( RequestID id, void|mapping additional_args )
  {
    return "<textarea cols='"+cols+"' rows='"+rows+"' name='"+path()+"'>"
           + Roxen.html_encode_string( query() || "" ) +
           "</textarea>";
  }
}



// =====================================================================
// Password
// =====================================================================
class Password
//! Password variable (uses crypt)
{
  inherit String;
  constant width = 20;
  constant type = "Password";

  void set_from_form( RequestID id )
  {
    mapping val;
    if( sizeof( val = get_form_vars(id)) && 
        val[""] && strlen(val[""]) )
      set( crypt( val[""] ) );
  }

  string render_view( RequestID id )
  {
    return "******";
  }

  string render_form( RequestID id, void|mapping additional_args )
  {
    additional_args = additional_args || ([]);
    additional_args->type="password";
    input(path(), "", 30, additional_args);
  }
}

class File
//! A filename
{
  inherit String;
  constant type = "File";
  constant width = 50;

  string read( )
  //! Read the file as a string.
  {
    return Stdio.read_bytes( query() );
  }

  Stat stat()
  //! Stat the file
  {
    return file_stat( query() );
  }

#ifdef __NT__
  array verify_set( string value )
  {
    return ::verify_set( replace( value, "\\", "/" ) );
  }
#endif

}

class Location
//! A location in the virtual filesystem
{
  inherit String;
  constant type = "Location";
  constant width = 50;
}

class URL
//! A URL.
{
  inherit String;
  constant type = "URL";
  constant width = 50;

  array verify_set( string new_value )
  {
    return verify_port( new_value, 1 );
  } 
}

class Directory
//! A Directory.
{
  inherit String;
  constant type = "Directory";
  constant width = 50;

  array verify_set( string value )
  {
#ifdef __NT__
    value = replace( value, "\\", "/" );
#endif
    if( strlen(value) && value[-1] != '/' )
      value += "/";
    if( !strlen( value ) )
      return ::verify_set( value );
    if( !(r_file_stat( value ) && (r_file_stat( value )[ ST_SIZE ] == -2 )))
       return ({value+" is not a directory", value });
    return ::verify_set( value );
  }

  Stat stat()
  //! Stat the directory
  {
    return file_stat( query() );
  }

  array get( )
  //! Return a listing of all files in the directory
  {
    return get_dir( query() );
  }
}



// =====================================================================
// MultipleChoice (one of many) baseclass
// =====================================================================

class MultipleChoice
//! Base class for multiple-choice (one of many) variables.
{
  inherit Variable;
  static array _list = ({});
  static mapping _table = ([]);

  void set_choice_list( array to )
    //! Set the list of choices.
  {
    _list = to;
  }

  array get_choice_list( )
    //! Get the list of choices. Used by this class as well.
    //! You can overload this function if you want a dynamic list.
  {
    return _list;
  }

  void set_translation_table( mapping to )
    //! Set the lookup table.
  {
    _table = to;
  }

  mapping get_translation_table( )
    //! Get the lookup table. Used by this class as well.
    //! You can overload this function if you want a dynamic table.
  {
    return _table;
  }

  static string _name( mixed what )
    //! Get the name used as value for an element gotten from the
    //! get_choice_list() function.
  {
    return (string)what;
  }

  static string _title( mixed what )
    //! Get the title used as description (shown to the user) for an
    //! element gotten from the get_choice_list() function.
  {
    if( mapping tt = get_translation_table() )
      return tt[ what ] || (string)what;
    return (string)what;
  }

  string render_form( RequestID id, void|mapping additional_args )
  {
    string res = "<select name='"+path()+"'>\n";
    string current = _name (query());
    int selected = 0;
    foreach( get_choice_list(), mixed elem )
    {
      mapping m = ([]);
      m->value = _name( elem );
      if( equal( m->value, current ) ) {
        m->selected="selected";
	selected = 1;
      }
      res += "  "+Roxen.make_container( "option", m, _title( elem ) )+"\n";
    }
    if (!selected)
      // Make an entry for the current value if it's not in the list,
      // so no other value appears to be selected, and to ensure that
      // the value doesn't change as a side-effect by another change.
      res = "  " + Roxen.make_container (
	"option", (["value": current, "selected": "selected"]),
	"(keep stale value " + current + ")");
    return res + "</select>";
  }
  static void create( mixed default_value, array|mapping choices,
                      int _flags, string std_name, string std_doc )
    //! Constructor. 
    //!
    //! Choices is the list of possible choices, can be set with 
    //! set_choice_list at any time.
    //! 
    //! Flags is a bitwise or of one or more of 
    //! 
    //! VAR_EXPERT         Only for experts 
    //! VAR_MORE           Only visible when more-mode is on (default on)
    //! VAR_DEVELOPER      Only visible when devel-mode is on (default on)
    //! VAR_INITIAL        Should be configured initially.
    //! 
    //! The std_name and std_doc is the name and documentation string
    //! for the default locale (always english)
  {
    ::create( default_value, _flags, std_name, std_doc );
    if( mappingp( choices ) ) {
      set_translation_table( choices );
      set_choice_list( indices(choices) );
    } else
      set_choice_list( choices );
  }
}


// =====================================================================
// MultipleChoice subclasses
// =====================================================================

class StringChoice
//! Select one of many strings.
{
  inherit MultipleChoice;
  constant type = "StringChoice";
}


class IntChoice
//! Select one of many integers.
{
  inherit MultipleChoice;
  constant type = "IntChoice";
  int transform_from_form( string what )
  {
    return (int)what;
  }
}

class FloatChoice
//! Select one of many floating point (real) numbers.
{
  inherit MultipleChoice;
  constant type = "FloatChoice";
  static int _prec = 3;

  void set_precision( int prec )
    //! Set the number of _decimals_ shown to the user.
    //! If prec is 3, and the float is 1, 1.000 will be shown.
    //! Default is 2.
  {
    _prec = prec;
  }

  static string _title( mixed what )
  {
    if( !_prec )
      return sprintf( "%d", (int)what );
    return sprintf( "%1."+_prec+"f", what );
  }

  int transform_from_form( string what )
  {
    array q = get_choice_list();
    mapping a = mkmapping( map( q, _name ), q );
    return a[what] || (float)what; // Do we want this fallback?
  }
}

class FontChoice
//! Select a font from the list of available fonts
{
  inherit StringChoice;
  constant type = "FontChoice";
  void set_choice_list()
  {
  }
  array get_choice_list()
  {
    return roxenp()->fonts->available_fonts();
  }
  static void create(mixed default_value,int flags,
                     string std_name,string std_doc)
    //! Constructor. 
    //! Flags is a bitwise or of one or more of 
    //! 
    //! VAR_EXPERT         Only for experts 
    //! VAR_MORE           Only visible when more-mode is on (default on)
    //! VAR_DEVELOPER      Only visible when devel-mode is on (default on)
    //! VAR_INITIAL        Should be configured initially.
    //! 
    //! The std_name and std_doc is the name and documentation string
    //! for the default locale (always english)
  {
    ::create( default_value, 0, flags,std_name, std_doc );
  }
}


// =====================================================================
// List baseclass
// =====================================================================
class List
//! Many of one type types
{
  inherit String;
  constant type="List";
  constant width = 40;

  string transform_to_form( mixed what )
    //! Override this function to do the value->form mapping for
    //! individual elements in the array.
  {
    return (string)what;
  }

  mixed transform_from_form( string what )
  {
    return what;
  }

  static int _current_count = time()*100+(gethrtime()/10000);
  void set_from_form(RequestID id)
  {
    int rn, do_goto;
    array l = query();
    mapping vl = get_form_vars(id);
    // first do the assign...

    if( (int)vl[".count"] != _current_count )
      return;
    _current_count++;

    foreach( indices( vl ), string vv )
      if( sscanf( vv, ".set.%d", rn ) )
      {
        m_delete( id->variables, path()+vv );
        l[rn] = transform_from_form( vl[vv] );
        m_delete( vl, vv );
      }
    // then the move...
    foreach( indices(vl), string vv )
      if( sscanf( vv, ".up.%d.x%*s", rn ) == 2 )
      {
        do_goto = 1;
        m_delete( id->variables, path()+vv );
        m_delete( vl, vv );
        l = l[..rn-2] + l[rn..rn] + l[rn-1..rn-1] + l[rn+1..];
      }
      else  if( sscanf( vv, ".down.%d.x%*s", rn )==2 )
      {
        do_goto = 1;
        m_delete( id->variables, path()+vv );
        l = l[..rn-1] + l[rn+1..rn+1] + l[rn..rn] + l[rn+2..];
      }
    // then the possible add.
    if( vl[".new.x"] )
    {
      do_goto = 1;
      m_delete( id->variables, path()+".new.x" );
      l += ({ transform_from_form( "" ) });
    }

    // .. and delete ..
    foreach( indices(vl), string vv )
      if( sscanf( vv, ".delete.%d.x%*s", rn )==2 )
      {
        do_goto = 1;
        m_delete( id->variables, path()+vv );
        l = l[..rn-1] + l[rn+1..];
      }
    if( do_goto )
    {
      if( !id->misc->do_not_goto )
      {
        id->misc->moreheads = ([
          "Location":id->raw_url+"?random="+random(4949494)+"#"+path(),
        ]);
        if( id->misc->defines )
          id->misc->defines[ " _error" ] = 302;
      }
    }
    set( l ); // We are done. :-)
  }

  string render_form( RequestID id, void|mapping additional_args )
  {
    string prefix = path()+".";
    int i;

    _current_count++;

    string res = "<a name='"+path()+"'>\n</a><table>\n"
    "<input type='hidden' name='"+prefix+"count' value='"+_current_count+"' />\n";

    foreach( map(query(), transform_to_form), string val )
    {
      res += "<tr>\n<td><font size='-1'>"+ input( prefix+"set."+i, val, width) + "</font></td>\n";
#define BUTTON(X,Y) ("<submit-gbutton2 name='"+X+"'>"+Y+"</submit-gbutton2>")
#define REORDER(X,Y) ("<submit-gbutton2 name='"+X+"' icon-src='"+Y+"'></submit-gbutton2>")
      if( i )
        res += "\n<td>"+
            REORDER(prefix+"up."+i, "/internal-roxen-up")+
            "</td>";
      else
        res += "\n<td></td>";
      if( i != sizeof( query())- 1 )
        res += "\n<td>"+
            REORDER(prefix+"down."+i, "/internal-roxen-down")
            +"</td>";
      else
        res += "\n<td></td>";
      res += "\n<td>"+
            BUTTON(prefix+"delete."+i, LOCALE(227, "Delete") )
          +"</td>";
          "</tr>";
      i++;
    }
    res += 
        "\n<tr><td colspan='2'>"+
        BUTTON(prefix+"new", LOCALE(297, "New row") )+
        "</td></tr></table>\n\n";

    return res;
  }
}


// =====================================================================
// List subclasses
// =====================================================================
class DirectoryList
//! A list of directories
{
  inherit List;
  constant type="DirectoryList";

  array verify_set( array(string) value )
  {
    string warn = "";
    foreach( value, string vi )
    {
      if(!strlen(vi)) // empty
        continue;
      if( !(r_file_stat( vi ) && (r_file_stat( vi )[ ST_SIZE ] == -2 )))
        warn += vi+" is not a directory\n";
      if( strlen(vi) && vi[-1] != '/' )
        value = replace( value, vi, vi+"/" );
    }
#ifdef __NT__
      value = map( value, replace, "\\", "/" );
#endif
    if( strlen( warn ) )
      return ({ warn, value });
    
    return ::verify_set( value );
  }
}

class StringList
//! A list of strings
{
  inherit List;
  constant type="StringList";
}

class IntList
//! A list of integers
{
  inherit List;
  constant type="IntList";
  constant width=20;

  string transform_to_form(int what) { return (string)what; }
  int transform_from_form(string what) { return (int)what; }
}

class FloatList
//! A list of floating point numbers
{
  inherit List;
  constant type="DirectoryList";
  constant width=20;

  static int _prec = 3;

  void set_precision( int prec )
    //! Set the number of _decimals_ shown to the user.
    //! If prec is 3, and the float is 1, 1.000 will be shown.
    //! Default is 2.
  {
    _prec = prec;
  }

  string transform_to_form(int what) 
  {
    return sprintf("%1."+_prec+"f",  what); 
  }
  float transform_from_form(string what) { return (float)what; }
}

class URLList
//! A list of URLs
{
  inherit List;
  constant type="URLList";

  array verify_set( array(string) new_value )
  {
    string warn  = "";
    array res = ({});
    foreach( new_value, string vv )
    {
      string tmp1, tmp2;
      [tmp1,tmp2] = verify_port( vv, 1 );
      if( tmp1 )
        warn += tmp1;
      res += ({ tmp2 });
    }
    if( !strlen( warn ) )
      warn = 0;
    return ({ warn, res });
  }
}

class PortList
//! A list of Port URLs
{
  inherit List;
  constant type="PortList";

  array verify_set( array(string) new_value )
  {
    string warn  = "";
    array res = ({});
    foreach( new_value, string vv )
    {
      string tmp1, tmp2;
      [tmp1,tmp2] = verify_port( vv, 0 );
      if( tmp1 )
        warn += tmp1;
      res += ({ tmp2 });
    }
    if( !strlen( warn ) )
      warn = "";
    return ({ warn, res });
  } 
}


class FileList
//! A list of filenames.
{
  inherit List;
  constant type="FileList";

#ifdef __NT__
  array verify_set( array(string) value )
  {
    return ::verify_set( map( value, replace, "\\", "/" ) );
  }
#endif
}


// =====================================================================
// Flag
// =====================================================================

class Flag
//! A on/off toggle.
{
  inherit Variable;
  constant type = "Flag";

  int transform_from_form( string what )
  {
    return (int)what;
  }

  string render_form( RequestID id, void|mapping additional_args )
  {
    string res = "<select name=\""+path()+"\"> ";
    if(query())
      res += "<option value=\"1\" selected=\"selected\">" +
	LOCALE("yes", "Yes")+ "</option>\n"
	"<option value=\"0\">" +LOCALE("no", "No")+ "</option>\n";
    else
      res += "<option value=\"1\">" +LOCALE("yes", "Yes")+ "</option>\n"
	"<option value=\"0\" selected>" +LOCALE("no", "No")+ "</option>\n";
    return res+"</select>";
  }
}




// =================================================================
// Utility functions used in multiple variable classes above
// =================================================================

static array(string) verify_port( string port, int nofhttp )
{
  if(!strlen(port))
    return ({ 0, port });
  string warning="";
  if( (int)port )
  {
    warning += "Assuming http://*:"+port+"/ for "+port+"\n";
    port = "http://*:"+port+"/";
  }
  string protocol, host, path;

  if(!strlen( port ) )
    return ({ "Empty URL field", port });

  if(sscanf( port, "%[^:]://%[^/]%s", protocol, host, path ) != 3)
    return ({""+port+" does not conform to URL syntax\n", port });
  
  if( path == "" )
  {
    warning += "Added / to the end of "+port+"\n";
    host += "/";
  }
  int pno;
  if( sscanf( host, "%s:%d", host, pno ) == 2)
  {
    if( roxenp()->protocols[ lower_case( protocol ) ] 
        && (pno == roxenp()->protocols[ lower_case( protocol ) ]->default_port ))
        warning += "Removed the "
                "default port number ("+pno+") from "+port+"\n";
    else
      host = host+":"+pno;
  }
  if( nofhttp && protocol == "fhttp" )
  {
    warning += "Changed " + protocol + " to http\n";
    protocol = "http";
  }
  if( protocol != lower_case( protocol ) )
  {
    warning += "Changed "+protocol+" to "+ lower_case( protocol )+"\n";  
  }

  port = lower_case( protocol )+"://"+host+path;

  if( !roxenp()->protocols[ lower_case( protocol ) ] )
    warning += "Warning: The protocol "+lower_case(protocol)+" is unknown\n";
  return ({ (strlen(warning)?warning:0), port });
}

static string input(string name, string value, int size,
		    void|mapping(string:string) args, void|int noxml)
{
  if(!args)
    args=([]);
  else
    args+=([]);

  args->name=name;
  args->value=value;
  args->size=(string)size; 

  string render="<input";

  foreach(indices(args), string attr) {
    render+=" "+attr+"=";
    if(!has_value(args[attr], "\"")) render+="\""+args[attr]+"\"";
    else if(!has_value(args[attr], "'")) render+="'"+args[attr]+"'";
    else render+="\""+replace(args[attr], "'", "&#39;")+"\"";
  }

  if(noxml) return render+">";
  return render+" />";
}
