#include <module.h>
#define LOW_LOCALE (roxenp()->locale->get())
#define LC LOW_LOCALE

static inherit "html";

#define RequestID object


static int unique_vid;

// The theory is that most variables (or at least a sizable percentage
// of all variables) does not have these members. This this saves
// quite a respectable amount of memory, the cost is speed. But not
// all that great a percentage of speed.
static mapping changed_values = ([]);
static mapping all_flags = ([]);
static mapping all_warnings = ([]);

static mapping invisibility_callbacks = set_weak_flag( ([]), 1 );

class Variable
//. The basic variable type in Roxen. All other variable types should
//. inherit this class. 
{
  constant type = "Basic";
  //. Mostly used for debug

  constant is_variable = 1;

  static string _id = (unique_vid++)->digits(256); 
  // used for indexing the mappings.

  static mixed _initial; // default value
  static string _path;   // used for forms

  void destroy()
  {
    // clean up...
    m_delete( all_flags, _id );
    m_delete( all_warnings, _id );
    m_delete( invisibility_callbacks, _id );
    m_delete( changed_values, _id );
    RoxenLocale.standard.unregister_module_doc( _id );
  }

  string get_warnings()
    //. Returns the current warnings, if any.
  {
    return all_warnings[ _id ];
  }

  int check_visibility( RequestID id,
                        int more_mode,
                        int expert_mode,
                        int devel_mode,
                        int initial )
    //. Return 1 if this variable should be visible in the configuration
    //. interface.
  {
    int flags = all_flags[_id];
    function cb;
    if( initial && !(flags & VAR_INITIAL) )      return 0;
    if( (flags & VAR_EXPERT) && !expert_mode )   return 0;
    if( (flags & VAR_MORE) && !more_mode )       return 0;
    if( (flags & VAR_DEVELOPER) && !devel_mode ) return 0;
    if( (cb = invisibility_callbacks[_id]) && 
        cb( id, this_object() ) )
      return 0;
    return 1;
  }

  void set_invisibility_check_callback( function(RequestID,Variable:int) cb )
    //. If the function passed as argument returns 1, the variable
    //. will not be visible in the configuration interface.
    //.
    //. Pass 0 to remove the invisibility callback.
  {
    if( functionp( cb ) )
      invisibility_callbacks[ _id ] = cb;
    else
      m_delete( invisibility_callbacks, _id );
  }

  string doc(  )
    //. Return the documentation for this variable (locale dependant).
    //. 
    //. The default implementation queries the locale object in roxen
    //. to get the documentation.
  {
    return LC->module_doc_string( _id, 1 ) ||
           RoxenLocale.standard.module_doc_string( _id, 1 ) ||
           "No way!";
  }
  
  string name(  )
    //. Return the name of this variable (locale dependant).
    //. 
    //. The default implementation queries the locale object in roxen
    //. to get the documentation.
  {
    return LC->module_doc_string( _id, 0 ) ||
           RoxenLocale.standard.module_doc_string( _id, 0 ) ||
           "No way!";
  } 

  string type_hint(  )
    //. Return the type hint for this variable.
    //. Type hints are generic documentation for this variable type, 
    //. and is the same for all instances of the variable.
  {
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
    void set_warning( string to )
    { 
      if( to && strlen(to) )
        all_warnings[_id] = to; 
      else
        m_delete( all_warnings, _id );
    };
    if( e2 = catch( [err,to] = verify_set( to )) )
    {
      set_warning( e2 );
      return e2;
    }
    low_set( to );
    set_warning( err );
    return err;
  }

  void low_set( mixed to )
    //. Forced set. No checking is done whatsoever.
  {
    if( !equal(to, default_value() ) )
      changed_values[ _id ] = to;
    else
      m_delete( changed_values, _id );
  }
  
  mixed query( )
    //. Returns the current value for this variable.
  {
    mixed v;
    if( !zero_type( v = changed_values[ _id ] ) )
      return v;
    return default_value();
  }

  int is_defaulted()
    //. Return true if this variable is set to the default value.
  {
    return zero_type( changed_values[ _id ] ) || 
           equal(changed_values[ _id ], default_value());
  }

  array(string|mixed) verify_set( mixed new_value )
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
    string p = path();
    array names = glob( p+"*", indices(id->variables) );
    mapping res = ([ ]);
    foreach( sort(names), string n )
      res[ n[strlen(p).. ] ] = id->variables[ n ];
    return res;
  }

  mixed transform_from_form( string what )
    //. Given a form value, return what should be set.
    //. Used by the default set_from_form implementation.
  {
    return what;
  }
  
  void set_from_form( RequestID id )
    //. Set this variable from the form variable in id->Variables,
    //. if any are available. The default implementation simply sets
    //. the variable to the string in the form variables.
    //.
    //. Other side effects: Might create warnings to be shown to the 
    //. user (see get_warnings)
  {
    mapping val;
    if( sizeof( val = get_form_vars(id)) && val[""] && 
        transform_from_form( val[""] ) != query() )
      set( transform_from_form( val[""] ));
  }
  
  string path()
    //. A unique identifier for this variable. 
    //. Should be used to prefix form variables.
  {
    return _path;
  }

  void set_path( string to )
    //. Set the path. Not normally called from user-level code.
    //. 
    //. This function must be called at least once before render_form
    //. can be called. This is normally done by the configuration
    //. interface.
  {
    _path = to;
  }

  string render_form( RequestID id );
    //. Return a form to change this variable. The name of all <input>
    //. or similar variables should be prefixed with the value returned
    //. from the path() function.

  string render_view( RequestID id )
    //. Return a 'view only' version of this variable.
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


  int deflocaledoc( string locale, string name, string doc,
                    mapping|void choices )
    //. Define the documentation (name and built-in runtime documentation) 
    //. for the specified locale.
    //. 
    //. Returns 1 if the locale exists, 0 otherwise.
    //. 
    //. The choices mapping is a mapping from value to the displayed
    //. option title. You can pass 0 to avoid translation.

  {
    catch {
      RoxenLocale[locale]->
        register_module_doc(_id, name,doc,choices);
      return 1;
    };
    return 0;
  }


  static void create(mixed default_value,int flags,
                     string std_name,string std_doc)
    //. Constructor. 
    //. Flags is a bitwise or of one or more of 
    //. 
    //. VAR_EXPERT         Only for experts 
    //. VAR_MORE           Only visible when more-mode is on (default on)
    //. VAR_DEVELOPER      Only visible when devel-mode is on (default on)
    //. VAR_INITIAL        Should be configured initially.
    //. 
    //. The std_name and std_doc is the name and documentation string
    //. for the default locale (always english)
    //. 
    //. Use deflocaledoc to define translations.
  {
    _initial = default_value;
    if( flags ) 
      all_flags[ _id ] = flags;
    if( std_name )
      RoxenLocale.standard.register_module_doc(_id,std_name,std_doc);
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
    _prec = prec;
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
  
  float transform_from_form( string what )
  {
    return (float)what;
  }

  string render_view( RequestID id )
  {
    return Roxen.html_encode_string( _format(query()) );
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
  constant width = 40;
  //. The width of the input field. Used by overriding classes.
  string render_form( RequestID id )
  {
    return input(path(), (string)query(), width);
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
  constant cols = 60;
  //. The width of the textarea
  constant rows = 10;
  //. The height of the textarea
  string render_form( RequestID id )
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
//. Password variable (uses crypt)
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

  string render_form( RequestID id )
  {
    return "<input name=\""+path()+"\" type=password size=30>";
  }
}

class File
//. A filename
{
  inherit String;
  constant type = "File";
  constant width = 50;
}

class Location
//. A location in the virtual filesystem
{
  inherit String;
  constant type = "Location";
  constant width = 50;
}

class URL
//. A URL.
{
  inherit String;
  constant type = "URL";
  constant width = 50;
}

class Directory
//. A Directory.
{
  inherit String;
  constant type = "Directory";
  constant width = 50;
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
    //. get_choice_list() function.
  {
    return  (string)what;
  }

  static string _title( mixed what )
    //. Get the title used as description (shown to the user) for an
    //. element gotten from the get_choice_list() function.
  {
    mapping tr = LC->module_doc_string( _id, 2 );
    if( tr )
      return tr[ what ] || (string)what;
    return (string)what;
  }

  string render_form( RequestID id )
  {
    string res = "<select name='"+path()+"'>\n";
    foreach( get_choice_list(), mixed elem )
    {
      mapping m = ([]);
      m->value = _name( elem );
      if( m->value == query() )
        m->selected="selected";
      res += "  "+Roxen.make_container( "option", m, _title( elem ) )+"\n";
    }
    return res + "</select>";
  }
  static void create( mixed default_value, array choices,
                      int _flags, string std_name, string std_doc )
    //. Constructor. 
    //.
    //. Choices is the list of possible choices, can be set with 
    //. set_choice_list at any time.
    //. 
    //. Flags is a bitwise or of one or more of 
    //. 
    //. VAR_EXPERT         Only for experts 
    //. VAR_MORE           Only visible when more-mode is on (default on)
    //. VAR_DEVELOPER      Only visible when devel-mode is on (default on)
    //. VAR_INITIAL        Should be configured initially.
    //. 
    //. The std_name and std_doc is the name and documentation string
    //. for the default locale (always english)
    //. 
    //. Use deflocaledoc to define translations.
  {
    ::create( default_value, _flags, std_name, std_doc );
    set_choice_list( choices );
  }
}


// =====================================================================
// MultipleChoice subclasses
// =====================================================================

class StringChoice
//. Select one of many strings.
{
  inherit MultipleChoice;
  constant type = "StringChoice";
}


class IntChoice
//. Select one of many integers.
{
  inherit MultipleChoice;
  constant type = "IntChoice";
  int transform_from_form( string what )
  {
    return (int)what;
  }
}

class FloatChoice
//. Select one of many floating point (real) numbers.
{
  inherit MultipleChoice;
  constant type = "FloatChoice";
  static int _prec = 3;

  void set_precision( int prec )
    //. Set the number of _decimals_ shown to the user.
    //. If prec is 3, and the float is 1, 1.000 will be shown.
    //. Default is 2.
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
//. Select a font from the list of available fonts
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
    //. Constructor. 
    //. Flags is a bitwise or of one or more of 
    //. 
    //. VAR_EXPERT         Only for experts 
    //. VAR_MORE           Only visible when more-mode is on (default on)
    //. VAR_DEVELOPER      Only visible when devel-mode is on (default on)
    //. VAR_INITIAL        Should be configured initially.
    //. 
    //. The std_name and std_doc is the name and documentation string
    //. for the default locale (always english)
    //. 
    //. Use deflocaledoc to define translations.
  {
    ::create( default_value,0, flags,std_name, std_doc );
  }
}


// =====================================================================
// List baseclass
// =====================================================================
class List
//. Many of one type types
{
  inherit String;
  constant type="List";
  constant width = 40;

  string transform_to_form( mixed what )
    //. Override this function to do the value->form mapping for
    //. indivindial elements in the array.
  {
    return (string)what;
  }

  mixed transform_from_form( string what )
  {
    return what;
  }

  static int _current_count = time()*10+(gethrtime()/100000);
  void set_from_form(RequestID id)
  {
    int rn;
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
        m_delete( id->variables, path()+vv );
        m_delete( vl, vv );
        l = l[..rn-2] + l[rn..rn] + l[rn-1..rn-1] + l[rn+1..];
      }
      else  if( sscanf( vv, ".down.%d.x%*s", rn )==2 )
      {
        m_delete( id->variables, path()+vv );
        l = l[..rn-1] + l[rn+1..rn+1] + l[rn..rn] + l[rn+2..];
      }
    // then the possible add.
    if( vl[".new.x"] )
    {
      m_delete( id->variables, path()+".new.x" );
      l += ({ transform_from_form( "" ) });
    }

    // .. and delete ..
    foreach( indices(vl), string vv )
      if( sscanf( vv, ".delete.%d.x%*s", rn )==2 )
      {
        m_delete( id->variables, path()+vv );
        l = l[..rn-1] + l[rn+1..];
      }
    set( l ); // We are done. :-)
  }

  string render_form( RequestID id )
  {
    string prefix = path()+".";
    int i;

    _current_count++;

    string res = "<table>\n"
   "<input type=hidden name='"+prefix+"count' value='"+_current_count+"' />";

    foreach( map(query(), transform_to_form), string val )
    {
      res += "<tr><td><font size=-1>"+ input( prefix+"set."+i, val, width) + "</font></td>";

#define BUTTON(X,Y) ("<submit-gbutton2 name='"+X+"'>"+Y+"</submit-gbutton2>")
      if( i )
        res += "\n<td>"+
            BUTTON(prefix+"up."+i, "^")+
            "</td>";
      else
        res += "<td></td>";
      if( i != sizeof( query())- 1 )
        res += "\n<td>"+
            BUTTON(prefix+"down."+i, "v")
            +"</td>";
      else
        res += "<td></td>";
      res += "\n<td>"+
            BUTTON(prefix+"delete."+i, "&locale.delete;")
          +"</td>";
          "</tr>";
      i++;
    }
    res += 
        "<tr><td colspan='2'>"+
        BUTTON(prefix+"new", "&locale.new_row;")+
        "</td></tr></table>\n";

    return res;
  }
}


// =====================================================================
// List subclasses
// =====================================================================
class DirectoryList
//. A list of directories
{
  inherit List;
  constant type="DirectoryList";
}

class StringList
//. A list of strings
{
  inherit List;
  constant type="StringList";
}

class IntList
//. A list of integers
{
  inherit List;
  constant type="IntList";
  constant width=20;

  string transform_to_form(int what) { return (string)what; }
  int transform_from_form(string what) { return (int)what; }
}

class FloatList
//. A list of floating point numbers
{
  inherit List;
  constant type="DirectorYList";
  constant width=20;

  static int _prec = 3;

  void set_precision( int prec )
    //. Set the number of _decimals_ shown to the user.
    //. If prec is 3, and the float is 1, 1.000 will be shown.
    //. Default is 2.
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
//. A list of URLs
{
  inherit List;
  constant type="UrlList";
}


class FileList
//. A list of URLs
{
  inherit List;
  constant type="FileList";
}


// =====================================================================
// Flag
// =====================================================================

class Flag
//. A on/off toggle.
{
  inherit Variable;
  constant type = "Flag";

  int transform_from_form( string what )
  {
    return (int)what;
  }

  string render_form( RequestID id )
  {
    string res = "<select name="+path()+"> ";
    if(query())
      res +=  ("<option value=1 selected>"+LOW_LOCALE->yes+"</option>\n"
                "<option value=0>"+LOW_LOCALE->no)+"</option>\n";
     else
       res +=  ("<option value=1>"+LOW_LOCALE->yes+"</option>\n"
                "<option value=0 selected>"+LOW_LOCALE->no)+"</option>\n";
    return res+"</select>";
  }
}
