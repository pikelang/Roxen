// $Id$

#include <module.h>
#include <roxen.h>

// Locale macros
//<locale-token project="roxen_config"> LOCALE </locale-token>

#define LOCALE(X,Y)    \
  ([string](mixed)Locale.translate("roxen_config",roxenp()->locale->get(),X,Y))

// Increased for each variable, used to index the mappings below. The unique
// prefix is needed to avoid clobbering variables after server restart.
protected int unique_vid;
protected string unique_prefix = (string) getpid();

// The theory is that most variables (or at least a sizable percentage
// of all variables) do not have these members. Thus this saves
// quite a respectable amount of memory, the cost is speed. But
// hopefully not all that great a percentage of speed.
protected mapping(string:mixed)  changed_values = ([]);
protected mapping(string:function(object:void)) changed_callbacks = ([]);
protected mapping(string:int)    all_flags      = ([]);
protected mapping(string:string) all_warnings   = ([]);
protected mapping(string:function(RequestID,object:int))
                           invisibility_callbacks = set_weak_flag( ([]), 1 );

mapping(string:Variable) all_variables = set_weak_flag( ([]), 1 );

mapping get_all_variables()
{
  return all_variables;
}

Variable get_variables( string v )
{
  return all_variables[v];
}

string get_diff_def_html( Variable v,
			  string button_tag,
			  string def_url,
			  string diff_url,
			  int page )
{
  if( page )
    return v->diff( 2 );

  if( v->is_defaulted() || (v->get_flags() & VAR_NO_DEFAULT) )
    return "";

  string oneliner = v->diff( 0 ), diff_button="";
  mapping m;

  if( !oneliner )
  {
    if( v->diff( 1 ) )
    {
      m = ([ "href":diff_url,"target":"_new", ]);
      diff_button =
	Roxen.make_container( "a",m,
			      Roxen.make_container(
				button_tag,
				([]),
				LOCALE(474,"Show changes")
			      ) );
    }
  }
  m = ([ "href" : def_url,
	 "onclick" : "return confirm('" + LOCALE(1041, "Are you sure you want "
						    "to restore the default "
						    "value?") + "');" ]);
  return diff_button + " " +
    Roxen.make_container( "a",m,
	Roxen.make_container( button_tag, ([]),
			      LOCALE(475, "Restore default value" )+
			      (oneliner||"") ) );

}

class Diff
{
  private array(string) diff;
  
  private
  array(string) print_row(array(string) diff_old, array(string) diff_new,
                          int line, int|void start, int|void end)
  {
    if(!sizeof(diff_old) && sizeof(diff_new))
      // New row.
      return Array.map(diff_new, lambda(string s) {return "+ " + s;} );
    
    if(sizeof(diff_old) && !sizeof(diff_new))
      // Deleted row.
      return Array.map(diff_old, lambda(string s) {return "- " + s;} );
    
    if(diff_old != diff_new)
      // Modified row.
      return Array.map(diff_old, lambda(string s) {return "- " + s;} )
        + Array.map(diff_new, lambda(string s) {return "+ " + s;} );

    if(start + end < sizeof(diff_old) && (start || end))
    {
      if(start && !end)
        diff_old = diff_old[.. start - 1];
      else
      {
        diff_old = diff_old[.. start - 1] +
                   ({ line + sizeof(diff_old) - end }) +
                   diff_old[sizeof(diff_old) - end ..];
      }
    }
    
    return Array.map(diff_old, lambda(string|int s)
                               { if(intp(s)) return "Line "+s+":";
                               return "  " + s; } );
  }
  
  string html(void|int hide_header)
  {
    string r = "";
    int added, deleted;
    if(sizeof(diff) && diff[-1] == "  ")
      diff = diff[..sizeof(diff)-2];
    foreach(diff, string row)
    {
      row = Roxen.html_encode_string(row);
      row = replace(row, "\t", "  ");
      row = replace(row, " ", "&nbsp;");
      switch(row[0])
      {
        case '&': r += "<tt>"+row+"</tt><br>\n";
          break;
        case '+': r += "<tt><font color='darkgreen'>"+row+"</font></tt><br>\n";
          added++;
          break;
        case '-': r += "<tt><font color='darkred'>"+row+"</font></tt><br>\n";
          deleted++;
          break;
        case 'L': r += "<i>"+row+"</i><br>\n";
          break;
      }
    }
    if (!hide_header)
      r =
        "<b>" + LOCALE(476, "Change in content") + "</b><br />\n"+
        "<i>"+(added==1? LOCALE(477, "1 line added."):
               sprintf(LOCALE(478, "%d lines added."), added)) + " " +
               (deleted==1? LOCALE(479, "1 line deleted."):
                sprintf(LOCALE(480, "%d lines deleted."), deleted)) +
        "</i><p>\n"+
        r;
    return r;
  }

  array get()
  {
    return diff;
  }
  
  void create(array(string) new, array(string) old, int context)
  {
    array(array(string)) diff_old, diff_new;
    
    [diff_old, diff_new] = Array.diff(old, new);
    int line = 1;
    int diffp = 0;
    diff = ({ });
    for(int i = 0; i < sizeof(diff_old); i++)
    {
      if(diff_old[i] != diff_new[i])
      {
        diff += print_row(diff_old[i], diff_new[i], line);
        
        diffp = 1;
      }
      else if(sizeof(diff_old) > 1)
      {
        diff += print_row(diff_old[i], diff_new[i], line,
                          diffp?context:0,
                          sizeof(diff_old) - 1 > i?context:0 );
        diffp = 0;
      }
      line += sizeof(diff_old[i] - ({ }));
    }
  }
}



class Variable
//! The basic variable type in Roxen. All other variable types should
//! inherit this class.
{
  constant is_variable = 1;

  constant type = "Basic";
  //! Mostly used for debug (sprintf( "%O", variable_obj ) uses it)

  string _id = unique_prefix + "_" + (string) unique_vid++;
  // used for indexing the mappings.

  protected mixed _initial; // default value
  protected string _path = sprintf("v%s",_id);   // used for forms
  protected LocaleString  __name, __doc;

  string diff( int render )
  //! Generate a html diff of the difference between the current
  //! value and the default value.
  //!
  //! This method is used by the configuration interface.
  //!
  //! The argument @[render] is used to select the operation mode.
  //!
  //! render=0 means that you should generate an inline diff. This
  //! should be at most 1 line of text with no more than 30 or so
  //! characters. This is mostly useful for simple variable types such
  //! as integers or choice-lists.
  //!
  //! If you return 0 when render=0, this function will be called with
  //! render=1 instead. If you return a non-zero value, you indicate
  //! that there is a diff available. In this case the function can be
  //! called again with render=2, in this case you have a full page of
  //! HTML code to render on.
  //!
  //! If you return 0 for render=1 as well, no difference will be
  //! shown. This is the default.
  {
    return 0;
  }

  void destroy()
  {
    if (global::this) {
      // clean up...
      m_delete( all_flags, _id );
      m_delete( all_warnings, _id );
      m_delete( invisibility_callbacks, _id );
      m_delete( changed_values, _id );
    }
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
    //! @int
    //!   @value VAR_EXPERT
    //!     Only for experts.
    //!   @value VAR_MORE
    //!     Only visible when more-mode is on (default on).
    //!   @value VAR_DEVELOPER
    //!     Only visible when devel-mode is on (default on).
    //!   @value VAR_INITIAL
    //!     Should be configured initially.
    //!   @value VAR_INVISIBLE
    //!     The variable is permanently hidden from view.
    //! @endint
  {
    return all_flags[_id];
  }

  void set_flags( int flags )
    //! Set the flags for this variable.
    //! Flags is a bitwise or of one or more of 
    //!
    //! @int
    //!   @value VAR_EXPERT
    //!     Only for experts.
    //!   @value VAR_MORE
    //!     Only visible when more-mode is on (default on).
    //!   @value VAR_DEVELOPER
    //!     Only visible when devel-mode is on (default on).
    //!   @value VAR_INITIAL
    //!     Should be configured initially.
    //!   @value VAR_INVISIBLE
    //!     The variable is permanently hidden from view.
    //! @endint
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
                        int initial,
                        int|void variable_in_cfif )
    //! Check if the variable should be visible to the
    //! configuration interface user.
    //!
    //! @param variable_in_cfif
    //! If variable_in_cfif is true, the variable is in a module
    //! that is added to the configuration interface itself.
    //!
    //! @returns
    //! Return 1 if this variable should be visible in the
    //! configuration interface. The default implementation check the
    //! 'flags' field, and the invisibility callback, if any. See
    //! get_flags, set_flags and set_invisibibility_check_callback
    //!
  {
    int flags = get_flags();
    function cb;
    if( flags & VAR_INVISIBLE )                      return 0;
    if( initial && !(flags & VAR_INITIAL) )          return 0;
    if( (flags & VAR_EXPERT) && !expert_mode )       return 0;
    if( (flags & VAR_MORE) && !more_mode )           return 0;
    if( (flags & VAR_DEVELOPER) && !devel_mode )     return 0;
    if( (flags & VAR_NOT_CFIF) && variable_in_cfif ) return 0;
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

  void add_changed_callback( function(Variable:void) cb )
  //! Add a new callback to be called when the variable is changed.
  //! If set_changed_callback is called, callbacks added with this function
  //! are overridden.
  {
    mixed oc = get_changed_callback( );
    if( arrayp( oc ) )
      oc += ({ cb });
    else
      oc = ({ oc, cb }) - ({ 0 });
    changed_callbacks[ _id ] = oc;
  }

  function(RequestID,Variable:int) get_invisibility_check_callback() 
    //! Return the current invisibility check callback
  {
    return invisibility_callbacks[_id];
  }

  LocaleString doc(  )
    //! Return the documentation for this variable (locale dependant).
    //! 
    //! The default implementation queries the locale object in roxen
    //! to get the documentation.
  {
    return __doc || "";
  }

  void set_doc (LocaleString doc)
  //! Set the (locale dependent) documentation for this variable.
  {
    __doc = doc;
  }

  LocaleString name(  )
    //! Return the name of this variable (locale dependant).
    //! 
    //! The default implementation queries the locale object in roxen
    //! to get the documentation.
  {
    return __name || LOCALE(326,"unnamed")+" "+_id;
  } 

  void set_name (LocaleString name)
  //! Set the (locale dependent) name for this variable.
  {
    __name = name;
  }

  LocaleString type_hint(  )
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

  void set_default_value (mixed to)
  //! Change the default value. If the variable was previously set to
  //! the old default value, this will also change its actual value.
  {
    _initial = to;
  }

  void set_warning( string to )
    //! Set the warning shown in the configuration interface
  { 
    if( to && strlen(to) )
      all_warnings[ _id ] = to; 
    else
      m_delete( all_warnings, _id );
  }

  void add_warning( string to )
  //! Like set_warning, but adds to the current warning, if any.
  {
    if(to) set_warning( (get_warnings()||"") + to );
  }

  int set( mixed to )
    //! Set the variable to a new value. 
    //! If this function returns true, the set was successful. 
    //! Otherwise 0 is returned. 0 is also returned if the variable was
    //! not changed by the set. 1 is returned if the variable was
    //! changed, and -1 is returned if the variable was changed back to
    //! its default value.
    //!
    //! If verify_set() threw a string, ([])[0] is returned, that is,
    //! 0 with zero_type set.
    //!
    //! If verify_set() threw an exception, the exception is thrown.
  {
    string err;
    mixed e2;
    if( e2 = catch( [err,to] = verify_set( to )) )
    {
      if( stringp( e2 ) )
      {
        add_warning( e2 );
        return ([])[0];
      }
      throw( e2 );
    }
    add_warning( err );
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
	get_changed_callback()( this_object() );
      return 1;
    }
    else
    {
      m_delete( changed_values, _id );
      if( get_changed_callback() )
	get_changed_callback()( this_object() );
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

  mixed encode()
  //! Returns the current value for this variable encoded for storage.
  //!
  //! The default implementation just returns the value from @[query()].
  //!
  //! @seealso
  //!   @[query()], @[decode()]
  {
    return query();
  }

  int decode(mixed encoded)
  //! Set the variable from the encoded representation
  //! returned by @[encode()].
  //!
  //! The default implementation just calls @[set()] with the argument.
  //!
  //! @seealso
  //!   @[set()], @[decode()]
  {
    return set(encoded);
  }

  int is_defaulted()
    //! Return true if this variable is set to it's default value.
  {
    return zero_type( changed_values[ _id ] ) || 
           equal(changed_values[ _id ], default_value());
  }

  array(string|mixed) verify_set_from_form( mixed new_value )
  //! Like verify_set, but only called when the variables are set
  //! from a form.
  {
    return ({ 0, new_value });
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
    array names = glob( p+"*", indices(id->real_variables) );
    mapping res = ([ ]);
    foreach( sort(names), string n )
      res[ n[strlen(p).. ] ] = id->real_variables[ n ][0];
    return res;
  }

  mixed transform_from_form( string what, mapping|void v )
    //! Given a form value, return what should be set.
    //! Used by the default set_from_form implementation.
  {
    return what;
  }
  
  int(0..1) set_from_form( RequestID id, void|int(0..1) force )
    //! Set this variable from the form variable in id->variables,
    //! if any are available. The default implementation simply sets
    //! the variable to the string in the form variables. @[force]
    //! forces the variable to be set even if the variable already
    //! has the new value, forcing possible warnings to be added.
    //! Returns 1 if the variable was changed, otherwise 0.
    //!
    //! Other side effects: Might create warnings to be shown to the 
    //! user (see get_warnings)
    //! 
    //! Calls verify_set_from_form and verify_set
  {
    mixed val;
    if( sizeof( val = get_form_vars(id)) && val[""])
    {
      set_warning(0);
      val = transform_from_form( val[""], val );
      if( !force && val == query() )
	return 0;
      array b;
      mixed q = catch( b = verify_set_from_form( val ) );
      if( q || sizeof( b ) != 2 )
      {
        if( q )
          add_warning( q );
        else
          add_warning( "Internal error: Illegal sized array "
		       "from verify_set_from_form\n" );
        return 0;
      }
      if( b ) 
      {
        add_warning( b[0] );
	set( b[1] );
	return 1;
      }
    }
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
    m_delete( all_variables, _path );
    _path = to;
    all_variables[ to ] = this_object();
  }

  string render_form( RequestID id, void|mapping additional_args );
    //! Return a (HTML) form to change this variable. The name of all <input>
    //! or similar variables should be prefixed with the value returned
    //! from the path() function.

  string render_view( RequestID id )
    //! Return a 'view only' version of this variable.
  {
    mixed v = query();
    if( arrayp(v) ) v = map(v,lambda(mixed v){return(string)v;})*", " ;
    return Roxen.html_encode_string( (string)v );
  }
  
  protected string _sprintf( int i )
  {
    if( i == 'O' )
      return sprintf( "Variable.%s(%s)",type,(string)name());
  }

  protected void create(mixed default_value, void|int flags,
			void|LocaleString std_name, void|LocaleString std_doc)
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
    all_variables[ path() ] = this_object();
  }
}

class NoLimit
{
  string _sprintf (int flag)
  {
    switch (flag) {
      case 's': return "n/a";
      case 'O': return this == no_limit ? "no_limit" : "<bogus no_limit clone>";
      default: return 0;
    }
  }
}

NoLimit no_limit = NoLimit();
//! @[no_limit] is used as value in a limit setting to signify that it
//! isn't applicable, to allow open ended intervals in e.g. @[Float]
//! and @[Int].
//!
//! @note
//! Always use the @[no_limit] object, never instance another one from
//! the @[NoLimit] class.



// =====================================================================
// Float
// =====================================================================

class Float
//! Float variable, with optional range checks, and adjustable precision.
{
  inherit Variable;
  constant type = "Float";
  protected float|NoLimit _max = no_limit, _min = no_limit;
  protected int _prec = 2;
  protected int _may_be_empty = 0;
  protected int(0..1) _is_empty = 0;

  protected string _format( float|NoLimit m )
  {
    if (m == no_limit)
      return "n/a";
    if( !_prec )
      return sprintf( "%d", (int)m );
    return sprintf( "%1."+_prec+"f", m );
  }

  string diff( int render )
  {
    if(!render)
      return "("+_format(default_value())+")";
  }
  
  void set_range(float|NoLimit minimum, float|NoLimit maximum )
    //! Set the range of the variable.
    //!
    //! As a compatibility measure, the range check is removed if
    //! maximum < minimum.
  {
    if (maximum != no_limit && minimum != no_limit && maximum < minimum)
      _max = _min = no_limit;
    else {
      _max = maximum;
      _min = minimum;
    }
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
    if (new_value == (float)0 && _is_empty)
      return ({ 0, new_value });
    string warn;
    if(_max != no_limit && new_value > _max)
    {
      warn = sprintf(LOCALE(328,"Value is bigger than %s, adjusted"),
		     _format(_max) );
      new_value = _max;
    }
    else if(_min != no_limit && new_value < _min)
    {
      warn = sprintf(LOCALE(329,"Value is less than %s, adjusted"),
		     _format(_min) );
      new_value = _min;
    }
    return ({ warn, new_value });
  }
  
  float transform_from_form( mixed what )
  {
    if (!sizeof(what) && _may_be_empty) {
      _is_empty = 1;
      return (float)0;
    }
    string junk;
    if(!sizeof(what)) {
      add_warning(LOCALE(80, "No data entered.\n"));
      return _min;
    }
    sscanf(what, "%f%s", what, junk);
    if(!junk) {
      add_warning(LOCALE(81, "Data is not a float.\n"));
      return _min;
    }
    if(sizeof(junk))
      add_warning(sprintf(LOCALE(82, "Found the string %O trailing after the float.\n"), junk));
    return (float)what;
  }

  string render_view( RequestID id )
  {
    return Roxen.html_encode_string( _format(query()) );
  }
  
  string render_form( RequestID id, void|mapping additional_args )
  {
    int size = 15;
    if( _max != no_limit && _min != no_limit )
      size = max( strlen(_format(_max)), strlen(_format(_min)) )+2;
    string value;
    catch {
      if (_may_be_empty && (float)query() == (float)0)
	value = "";
      else
	value = query()==""? "" : _format( (float)query() );
    };
    
    additional_args = additional_args || ([]);
    if (!additional_args->type)
      additional_args->type="text";

    return input(path(), value, size, additional_args);
  }

  void may_be_empty(int(0..1) state)
  //! Decides if an empty variable also is valid.
  {
    _may_be_empty = state;
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
  protected int|NoLimit _max = no_limit, _min = no_limit;

  protected int(0..1) _may_be_empty = 0;
  protected int(0..1) _is_empty = 0;

  void set_range(int|NoLimit minimum, int|NoLimit maximum )
    //! Set the range of the variable.
    //!
    //! As a compatibility measure, the range check is removed if
    //! maximum < minimum.
  {
    if (maximum != no_limit && minimum != no_limit && maximum < minimum)
      _max = _min = no_limit;
    else {
      _max = maximum;
      _min = minimum;
    }
  }

  string diff( int render )
  {
    if(!render)
      return "("+default_value()+")";
  }

  array(string|int) verify_set( mixed new_value )
  {
    if (new_value == 0 && _is_empty)
      return ({ 0, new_value });
    string warn;
    if(!intp( new_value ) )
      return ({ sprintf(LOCALE(152,"%O is not an integer"),new_value),
		query() });
    if( _max != no_limit && new_value > _max)
    {
      warn = sprintf(LOCALE(328,"Value is bigger than %s, adjusted"),
		     (string)_max );
      new_value = _max;
    }
    else if( _min != no_limit && new_value < _min)
    {
      warn = sprintf(LOCALE(329,"Value is less than %s, adjusted"),
		     (string)_min );
      new_value = _min;
    }
    return ({ warn, new_value });
  }

  int transform_from_form( mixed what )
  {
    if (!sizeof(what) && _may_be_empty) {
      _is_empty = 1;
      return 0;
    }
    string junk;
    if(!sizeof(what)) {
      add_warning(LOCALE(80, "No data entered.\n"));
      return _min;
    }
    sscanf( what, "%d%s", what, junk );
    if(!junk) {
      add_warning(LOCALE(83, "Data is not an integer\n"));
      return _min;
    }
    if(sizeof(junk))
      add_warning(sprintf(LOCALE(84, "Found the string %O trailing after the integer.\n"), junk));
    return what;
  }

  string render_form( RequestID id, void|mapping additional_args )
  {
    int size = 10;
    if( _min != no_limit && _max != no_limit )
      size = max( strlen((string)_max), strlen((string)_min) )+2;
    string value = (query() == 0 && _is_empty)? "" : (string)query();

    additional_args = additional_args || ([]);
    if (!additional_args->type)
      additional_args->type="text";

    return input(path(), value, size, additional_args);
  }

  void may_be_empty(int(0..1) state)
  //! Decides if an empty variable also is valid.
  {
    _may_be_empty = state;
  }
}

class TmpInt
//! @[Int] that doesn't get saved.
{
  inherit Int;
  void save() {}
}

class Priority
//! @[Int] that gets adjusted to the configured range.
{
  inherit Int;
  constant type = "Priority";
  protected int|NoLimit _max = 9, _min = 0;

  void set_range(int|NoLimit minimum, int|NoLimit maximum )
    //! Set the range of the variable.
    //!
    //! @note
    //!   Also scales the value of the variable accordingly.
  {
    if (_max != maximum) {
      if (!maximum || !_max) {
	set_default_value(0);
	low_set(0);
      } else {
	// Scale the old value.
	int new_val = (query() * maximum)/_max;
	if (new_val < minimum) new_val = minimum;
	int new_default = (default_value() * maximum)/_max;
	set_default_value(new_default);
	low_set(new_val);
      }
    }
    _max = maximum;
    _min = minimum;
  }

  string|int encode()
  {
    if (!_max) return 0;
    int ones = _max/9;
    int val = query();
    if (val % ones) {
      // New-style.
      int digits = sizeof(sprintf("%d", ones));
      // NB: We pad with zeroes to the field size to encode the
      //     field size that was used at encode time.
      return sprintf("%*0d", digits, val);
    }
    // Compat.
    return val / ones;
  }

  int decode(string|int encoded)
  {
    if (!_max) {
      return set(0);
    }
    int ones = _max/9;
    if (intp(encoded)) {
      return set(encoded * ones);
    }
    if (encoded == "") {
      // Paranoia check in case someone has modified the config file.
      return set(5 * ones);	// Default value.
    }
    // Expand the encoded value to the current field size.
    int digits = sizeof(sprintf("%d", ones));
    while (sizeof(encoded) < digits) {
      encoded += encoded;
    }
    if (sizeof(encoded) > digits) {
      encoded = encoded[..digits-1];
    }
    return set(array_sscanf(encoded, "%d")[0]);
  }

  LocaleString|string doc()
  {
    return ::doc() +
      sprintf((string)LOCALE(0, "<p>%d is the highest priority and "
			     "0 the lowest.</p>"),
	      _max);
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
  int width = 40;
  //! The width of the input field. Used by overriding classes.

  string diff( int render )
  {
    if(!render)
      return "("+Roxen.html_encode_string( default_value() )+")";
  }

  array(string) verify_set_from_form( mixed new )
  {
    return ({ 0, [string]new-"\r" });
  }

  string render_form( RequestID id, void|mapping additional_args )
  {
    additional_args = additional_args || ([]);
    if (!additional_args->type)
      additional_args->type="text";
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

  int cols = 56;
  //! The width of the textarea

  int rows = 10;
  //! The height of the textarea
  
  string diff( int render )
  {
    switch( render )
    {
      case 0: return 0;
      case 1: return "";
      case 2: 
	array lines_orig = default_value()/"\n";
	array lines_new  = query()/"\n";

	Diff diff = Diff( lines_new, lines_orig, 2 );

	if( sizeof(diff->get()) )
	  return diff->html();
	else
	  return "<i>"+LOCALE(481,"No difference\n" )+"</i>";
    }
  }

  array(string) verify_set_from_form( mixed new )
  {
    return ({ 0, [string]new-"\r" });
  }

  string render_form( RequestID id, void|mapping additional_args )
  {
    return "<textarea cols='"+cols+"' rows='"+rows+"' name='"+path()+"' wrap='off'>"
           + Roxen.html_encode_string( query() || "" ) +
           "</textarea>";
  }

  protected void create(mixed default_value, void|int flags,
			void|LocaleString std_name, void|LocaleString std_doc)
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
    if( strlen( default_value ) && default_value[0] == '\n' )
      // This is enforced by both netscape and IE... So let's just conform.
      default_value = default_value[1..];
    ::create( default_value, flags, std_name, std_doc );
  }
  
}



// =====================================================================
// Password
// =====================================================================
class Password
//! Password variable (uses crypt_password)
{
  inherit String;
  int width = 20;
  constant type = "Password";

  int(0..1) set_from_form( RequestID id )
  {
    mapping val;
    if( sizeof( val = get_form_vars(id)) && 
        val[""] && strlen(val[""]) ) {
      set( crypt_password( val[""] ) );
      return 1;
    }
    return 0;
  }

  string render_view( RequestID id )
  {
    return "******";
  }

  string render_form( RequestID id, void|mapping additional_args )
  {
    additional_args = additional_args || ([]);
    additional_args->type="password";
    return input(path(), "", 30, additional_args);
  }
}

class File
//! A filename
{
  inherit String;
  constant type = "File";
  int width = 50;

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
  int width = 50;

  array verify_set( string value )
  {
    if( !strlen( value ) || !((<'~','/'>)[value[-1]]) )
      return ({
	LOCALE(330,"You most likely want an ending '/' on this variable"),
	value
      });
    return ::verify_set( value );
  }
}

class URL
//! A URL.
{
  inherit String;
  constant type = "URL";
  int width = 50;

  array verify_set_from_form( string new_value )
  {
    return verify_port( new_value );
  } 
}

class Directory
//! A Directory.
{
  inherit String;
  constant type = "Directory";
  int width = 50;

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
       return ({sprintf(LOCALE(331,"%s is not a directory"),value)+"\n",value});
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
  protected array _list = ({});
  protected mapping _table = ([]);

  string diff( int render )
  {
    if(!render)
      return "("+_title( default_value() )+")";
  }

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

  protected string _name( mixed what )
    //! Get the name used as value for an element gotten from the
    //! get_choice_list() function.
  {
    return (string)what;
  }

  protected string _title( mixed what )
    //! Get the title used as description (shown to the user) for an
    //! element gotten from the get_choice_list() function.
  {
    if( mapping tt = get_translation_table() )
      return tt[ what ] || (string)what;
    return (string)what;
  }

  string render_form( RequestID id, void|mapping additional_args )
  {
    string autosubmit = "";
    if(additional_args && additional_args->autosubmit)
      autosubmit = " autosubmit='autosubmit' onChange='javascript:submit();'";
    string res = "<select name='"+path()+"'"+autosubmit+">\n";
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
      res += "  " + Roxen.make_container (
	"option", (["value":current, "selected": "selected"]),
	sprintf(LOCALE(332,"(keep stale value %s)"),current));
    return res + "</select>";
  }

  protected void create( mixed default_value, array|mapping choices,
			 void|int _flags, void|LocaleString std_name,
			 void|LocaleString std_doc )
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
      set_choice_list( sort(indices(choices)) );
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
  protected int _prec = 3;

  void set_precision( int prec )
    //! Set the number of _decimals_ shown to the user.
    //! If prec is 3, and the float is 1, 1.000 will be shown.
    //! Default is 2.
  {
    _prec = prec;
  }

  protected string _title( mixed what )
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

  protected void create(mixed default_value, void|int flags,
			void|LocaleString std_name, void|LocaleString std_doc)
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

class TableChoice
{
  inherit StringChoice;
  constant type = "TableChoice";
  Variable db;

  array(string) get_choice_list( )
  {
    return sort(DBManager.db_tables( db->query() ));
  }
    
  void create( string default_value,
	       void|int flags,
	       void|LocaleString std_name,
	       void|LocaleString std_doc,
	       Variable _dbchoice )
  {
    ::create( default_value, ({}), flags, std_name, std_doc );
    db = _dbchoice;
  }
}
  

class DatabaseChoice
//! Select a database from all available databases.
{
  inherit StringChoice;
  constant type = "DatabaseChoice";

  function(void:void|object) config = lambda() { return 0; };

  DatabaseChoice set_configuration_pointer( function(void:object) configuration )
  //! Provide a function that returns a configuration object,
  //! that will be used for authentication against the database
  //! manager. Typically called as
  //! @expr{set_configuration_pointer(my_configuration)@}.
  {
    config = configuration;
    return this_object();
  }

  array get_choice_list( )
  {
    if (!functionp(config)) {
      //  Some modules apparently send in a configration reference instead of
      //  a function pointer when calling set_configuration_pointer().
      report_warning("Incorrect usage of Variable.DatabaseChoice:\n\n%s",
		     describe_backtrace(backtrace()));
      return ({ " none" });
    }
    return ({ " none" }) + sort(DBManager.list( config() ));
  }

  protected void create(string default_value, void|int flags,
			void|LocaleString std_name, void|LocaleString std_doc)
  {
    ::create( default_value, ({}), flags, std_name, std_doc );
  }
}

class AuthMethodChoice
{
  inherit StringChoice;
  constant type = "AuthMethodChoice";

  protected Configuration config;
  
  array get_choice_list( )
  {
    return ({ " all" }) + sort( config->auth_modules()->name );
  }

  protected void create( string default_value, int flags,
			 string std_name, string std_doc,
			 Configuration c )
  {
    config = c;
    ::create( default_value, ({}), flags, std_name, std_doc );
  }
}

class UserDBChoice
{
  inherit StringChoice;
  constant type = "UserDBChoice";

  protected Configuration config;
  
  array get_choice_list( )
  {
    return ({ " all" }) + sort( config->user_databases()->name );
  }

  protected void create( string default_value, int flags,
			 string std_name, string std_doc,
			 Configuration c )
  {
    config = c;
    ::create( default_value, ({}), flags, std_name, std_doc );
  }
}

//! Select a module in the current configuration.
class ModuleChoice
{
  inherit StringChoice;
  constant type = "ModuleChoice";
  protected Configuration conf;
  protected string module_id;
  protected string default_id;
  protected int automatic_dependency;

  int low_set(RoxenModule to)
  {
    RoxenModule old = changed_values[_id];
    if (!old) {
      if (module_id) {
	old = transform_from_form(module_id);
      } else {
	old = default_value();
	if (old) {
	  module_id = _name(old);
	}
      }
      if (old) {
	changed_values[_id] = old;
      }
    }
    if (to == old) return 0;
    changed_values[_id] = to;
    if (module_id == _name(to)) return 0;	// Reloaded module or similar.
    module_id = _name(to);
    if( get_changed_callback() )
      get_changed_callback()( this_object() );
    return 1;
  }

  // NOTE: Will be called with a string at module init!
  int set(string|RoxenModule to)
  {
    if (stringp(to)) {
      module_id = to;
      RoxenModule mod = transform_from_form (to);
      if (!mod && automatic_dependency && conf->enabled_modules[to]) {
	conf->add_modules (({to}), 1);
	mod = transform_from_form (to);
      }
      if (!mod && conf->enabled_modules[to])
	// The module exists but isn't started yet. Don't call set()
	// in this case since that will cause a bogus warning.
	return 0;
      to = mod;
    }
    return ::set(to);
  }

  RoxenModule query()
  {
    RoxenModule res = changed_values[_id];
    if (!res) {
      if (module_id) {
	// The module might have been reloaded.
	// Try locating it again.
	res = transform_from_form(module_id);
	if (res) low_set(res);
      } else {
	res = default_value();
	if (res) low_set(res);
      }
    }
    return res;
  }

  //! Fetch the unsorted list of choices.
  protected array low_get_choice_list()
  {
    return indices(conf->otomod);
  }

  array get_choice_list()
  {
    array res = low_get_choice_list();
    // Sort order:
    //   priority: descending,
    //   title: ascending,
    //   module_id: ascending.
    sort(res->module_local_id(), res);
    sort(map(res, _title), res);
    res = reverse(res);
    sort(res->query("_priority"), res);
    res = reverse(res);
    return res;
  }

  protected string _name(RoxenModule val)
  {
    return val?val->module_local_id():"";
  }

  protected string _title(RoxenModule val)
  {
    return val?val->module_name:"";
  }

  RoxenModule transform_from_form(string module_id, mapping|void v)
  {
    return conf->find_module(module_id);
  }

  RoxenModule default_value()
  {
    if (default_id) {
      return transform_from_form(default_id);
    }
    array(RoxenModule) modules = get_choice_list();
    if (sizeof(modules)) {
      return modules[0];
    }
    return UNDEFINED;
  }

  array(string|mixed) verify_set( mixed new_value )
  {
    if (!new_value) {
      return ({ "Not configured", 0 });
    }
    return ({ 0, new_value });
  }

  //! @param default_id
  //!   The @[RoxenModule.module_local_id] of the default value.
  //! @param conf
  //!   The current configuration.
  //! @param no_automatic_dependency
  //!   Do not automatically depend on the chosen module. Normally, if
  //!   it already exists in the configuration then it will be loaded
  //!   before @expr{start@} in this module is called. Setting this
  //!   flag disables that.
  protected void create(string default_id, int flags,
			string std_name, string std_doc,
			Configuration conf,
			void|int no_automatic_dependency)
  {
    this_program::default_id = default_id;
    this_program::conf = conf;
    automatic_dependency = !no_automatic_dependency;
    ::create(0, ({}), flags, std_name, std_doc);
  }
}

//! Select a module that provides the specified interface.
class ProviderChoice
{
  inherit ModuleChoice;
  constant type = "ProviderChoice";
  protected string provides;

  protected array low_get_choice_list()
  {
    return conf->get_providers(provides);
  }

  //! @param default_id
  //!   The @[RoxenModule.module_local_id] of the default value.
  //! @param provides
  //!   The provider string to match modules against.
  //! @param conf
  //!   The current configuration.
  protected void create(string default_id, int flags,
			string std_name, string std_doc,
			string provides, Configuration conf)
  {
    this_program::provides = provides;
    ::create(default_id, flags, std_name, std_doc, conf);
  }
}

// =====================================================================
// List baseclass
// =====================================================================
class List
//! Many of one type types
{
  inherit Variable;
  constant type="List";
  int width = 40;

  array(string|array(string)) verify_set(mixed to)
  {
    if (stringp(to)) {
      // Backward compatibility junk...
      return ({ "Compatibility: "
		"Converted from TYPE_STRING to TYPE_STRING_LIST.\n",
		map(to/",", global.String.trim_all_whites),
      });
    }
    return ::verify_set(to);
  }

  string transform_to_form( mixed what )
    //! Override this function to do the value->form mapping for
    //! individual elements in the array.
  {
    return (string)what;
  }

  mixed transform_from_form( string what,mapping v )
  {
    return what;
  }

  protected int _current_count = time()*100+(gethrtime()/10000);
  int(0..1) set_from_form(RequestID id)
  {
    int rn, do_goto;
    array l = copy_value(query());
    mapping vl = get_form_vars(id);
    // first do the assign...
    if( (int)vl[".count"] != _current_count )
      return 0;
    _current_count++;
    set_warning(0);

    foreach( indices( vl ), string vv )
      if( sscanf( vv, ".set.%d", rn ) && (vv == ".set."+rn) )
      {
	if ((rn >= 0) && (rn < sizeof(l))) {
	  m_delete( id->real_variables, path()+vv );
	  l[rn] = transform_from_form( vl[vv], vl );
	  m_delete( vl, vv );
	} else {
	  report_debug("set_from_form(%O): vv:%O sizeof(l):%d\n",
		       id, vv, sizeof(l));
	}
      }
    // then the move...
    foreach( indices(vl), string vv )
      if( sscanf( vv, ".up.%d.x%*s", rn ) == 2 )
      {
        do_goto = 1;
        m_delete( id->real_variables, path()+vv );
        m_delete( vl, vv );
        l = l[..rn-2] + l[rn..rn] + l[rn-1..rn-1] + l[rn+1..];
      }
      else  if( sscanf( vv, ".down.%d.x%*s", rn )==2 )
      {
        do_goto = 1;
        m_delete( id->real_variables, path()+vv );
        l = l[..rn-1] + l[rn+1..rn+1] + l[rn..rn] + l[rn+2..];
      }
    // then the possible add.
    if( vl[".new.x"] )
    {
      do_goto = 1;
      m_delete( id->real_variables, path()+".new.x" );
      l += ({ transform_from_form( "",vl ) });
    }

    // .. and delete ..
    foreach( indices(vl), string vv )
      if( sscanf( vv, ".delete.%d.x%*s", rn )==2 )
      {
        do_goto = 1;
        m_delete( id->real_variables, path()+vv );
        l = l[..rn-1] + l[rn+1..];
      }

    array b;
    mixed q = catch( b = verify_set_from_form( l ) );
    if( q || sizeof( b ) != 2 )
    {
      if( q )
	add_warning( q );
      else
	add_warning( "Internal error: Illegal sized array "
		     "from verify_set_from_form\n" );
      return 0;
    }

    int ret;
    if( b ) 
    {
      add_warning( b[0] );
      set( b[1] );
      ret = 1;
    }

    if( do_goto && !id->misc->do_not_goto )
    {
      RequestID nid = id;
      while( nid->misc->orig )
	nid = id->misc->orig;

      string section = RXML.get_var("section", "var");
      string query = nid->query;
      if( !query )
	query = "";
      else
	query += "&";

      //  The URL will get a fragment identifier below and since some
      //  broken browsers (MSIE) incorrectly includes the fragment in
      //  the last variable value we'll place section before random.
      query +=
	(section ? ("section=" + section + "&") : "") +
	"random=" + random(4949494);
      query += "&_roxen_wizard_id=" + id->cookies["RoxenWizardId"];

      string url =
	Roxen.http_encode_invalids (nid->not_query +
				    (nid->misc->path_info || "") +
				    "?" + query + "#" + path());

      nid->set_response_header ("Location", url);
      if( nid->misc->defines )
	nid->misc->defines[ " _error" ] = 302;
      else if( id->misc->defines )
	id->misc->defines[ " _error" ] = 302;
    }

    return ret;
  }


  string render_row(string prefix, mixed val, int width)
  {
    return input( prefix, val, width );
  }

  string render_form( RequestID id, void|mapping additional_args )
  {
    string prefix = path()+".";
    int i;

    string res = "<a name='"+path()+"'>\n</a><table>\n"
    "<input type='hidden' name='"+prefix+"count' value='"+_current_count+"' />\n";

    foreach( map(query(), transform_to_form), mixed val )
    {
      res += "<tr>\n<td><font size='-1'>"+ render_row(prefix+"set."+i, val, width)
	+ "</font></td>\n";
#define BUTTON(X,Y) ("<submit-gbutton2 name='"+X+"'>"+Y+"</submit-gbutton2>")
#define REORDER(X,Y) ("<submit-gbutton2 name='"+X+"' icon-src='"+Y+"'></submit-gbutton2>")
#define DIMBUTTON(X) ("<disabled-gbutton icon-src='"+X+"'></disabled-gbutton>")
      if( i )
        res += "\n<td>"+
            REORDER(prefix+"up."+i, "/internal-roxen-up")+
            "</td>";
      else
        res += "\n<td>"+DIMBUTTON("/internal-roxen-up")+"</td>";
      if( i != sizeof( query())- 1 )
        res += "\n<td>"+
            REORDER(prefix+"down."+i, "/internal-roxen-down")
            +"</td>";
      else
        res += "\n<td>"+DIMBUTTON("/internal-roxen-down")+"</td>";
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
        warn += sprintf(LOCALE(331,"%s is not a directory"),vi)+"\n";
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
  int width=20;

  string transform_to_form(int what) { return (string)what; }
  int transform_from_form(string what,mapping v) { return (int)what; }
}

class FloatList
//! A list of floating point numbers
{
  inherit List;
  constant type="FloatList";
  int width=20;

  protected int _prec = 3;

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
  float transform_from_form(string what,mapping v) { return (float)what; }
}

class URLList
//! A list of URLs
{
  inherit List;
  constant type="URLList";

  array verify_set_from_form( array(string) new_value )
  {
    string warn  = "";
    array res = ({});
    foreach( new_value, string vv )
    {
      string tmp1, tmp2;
      [tmp1,tmp2] = verify_port( vv );
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

  string render_row( string prefix, mixed val, int width )
  {
    string res = "<input type=hidden name='"+prefix+"' value='"+prefix+"' />";

    Standards.URI split = Standards.URI( val );

    res += "<select name='"+prefix+"prot'>";
    int default_port;
    foreach( sort(indices( roxenp()->protocols )), string p )
    {
      if( p == split->scheme ) {
	res += "<option selected='t'>"+p+"</option>";
	default_port = roxenp()->protocols[p]->default_port;
      }
      else
	res += "<option>"+p+"</option>";
    }
    res += "</select>";

    res += "://<input type=text name='"+prefix+"host' value='"+
           Roxen.html_encode_string(split->host)+"' />";
    res += ":<input type=text size=5 name='"+prefix+"port' value='"+
      (split->port == default_port ? "" : split->port) +"' />";

    res += "/<input type=text name='"+prefix+"path' value='"+
      Roxen.html_encode_string(split->path[1..])+"' /><br />";
    mapping opts = ([]);
    string a,b;
    foreach( (split->fragment||"")/";", string x )
    {
      sscanf( x, "%s=%s", a, b );
      opts[a]=b;
    }
    res += "IP#: <input size=15 type=text name='"+prefix+"ip' value='"+
      Roxen.html_encode_string(opts->ip||"")+"' /> ";
    res += LOCALE(510,"Bind this port: ");
    res += "<select name='"+prefix+"nobind'>";
    if( (int)opts->nobind )
    {
      res +=
	("<option value='0'>"+LOCALE("yes","Yes")+"</option>"
	 "<option selected='t' value='1'>"+LOCALE("no","No")+"</option>");
    }
    else
    {
      res +=
	("<option selected='t' value='0'>"+LOCALE("yes","Yes")+"</option>"
	 "<option value='1'>"+LOCALE("no","No")+"</option>");
    }
    res += "</select>";
    return res;
  }

  string transform_from_form( string v, mapping va )
  {
    if( v == "" ) return "http://*/";
    v = v[strlen(path())..];
    if( strlen( va[v+"path"] ) && va[v+"path"][-1] != '/' )
      va[v+"path"]+="/";

    //  Handle IPv6 addresses
    string host = va[v + "host"];
    if (has_value(host, ":") && !has_prefix(host, "["))
      host = "[" + host + "]";
    
    return (string)Standards.URI(va[v+"prot"]+"://"+ host +
				 (va[v+"port"] && sizeof (va[v+"port"]) ?
				  ":"+ va[v+"port"] : "") +"/"+va[v+"path"]+"#"
		 // all options below this point
				 "ip="+va[v+"ip"]+";"
				 "nobind="+va[v+"nobind"]+";"
				);
  }

  array verify_set_from_form( array(string) new_value )
  {
    string warn  = "";
    array res = ({});
    foreach( new_value, string vv )
    {
      string tmp1, tmp2;
      [tmp1,tmp2] = verify_port( vv );
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
  array(string|array(string)) verify_set(mixed value )
  {
    // Backward compatibility junk...
    if (stringp(value))
      return ::verify_set( replace(value, "\\", "/") );
    
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
protected array(string) verify_port( string port )
{
  if(!strlen(port))
    return ({ 0, port });

  string warning="";
  if( (int)port )
  {
    warning += sprintf(LOCALE(333,"Assuming http://*:%[0]d/ for %[0]d")+"\n",
		       (int)port);
    port = "http://*:"+port+"/";
  }
  string protocol, host, path;

  if(!strlen( port ) )
    return ({ LOCALE(334,"Empty URL field")+"\n", port });

  if(sscanf( port, "%[^:]://%[^/]%s", protocol, host, path ) != 3)
    return ({ sprintf(LOCALE(335,"%s does not conform to URL syntax")+"\n",port),
	      port });
  
//   if( path == "" || path[-1] != '/' )
//   {
//     warning += sprintf(LOCALE(336,"Added / to the end of %s")+"\n",port);
//     path += "/";
//   }
  if( protocol != lower_case( protocol ) )
  {
    warning += sprintf(LOCALE(338,"Changed %s to %s"),
		       protocol, lower_case( protocol ))+"\n";  
    protocol = lower_case( protocol );
  }
#if constant(SSL.File)
  // All is A-OK
#else
  if( (protocol == "https" || protocol == "ftps") )
    warning +=
      LOCALE(339,"SSL support not available in this Pike version.")+"\n"+
      sprintf(LOCALE(340,"Please use %s instead."),
	      protocol[..strlen(protocol)-2])+"\n";
#endif
  int pno;
  int default_pno =
    (roxenp()->protocols[lower_case(protocol)] || ([ ]) )->default_port;
  if (has_value(host, "[")) {
    //  IPv6 address
    Standards.URI uri = Standards.URI(port);
    pno = uri->port;
    port = (string) uri;
  } else {
    if (sscanf(host, "%s:%d", host, pno) == 2)
      if (pno != default_pno)
	host = host + ":" + pno;
    port = protocol+"://"+host+path;
  }
  if (default_pno && (pno == default_pno))
    warning += sprintf(LOCALE(341, "Removed the default port number "
				   "(%d) from %s"), pno, port) + "\n";
  
  if( !roxenp()->protocols[ protocol ] )
    warning += sprintf(LOCALE(342,"Warning: The protocol %s is not known "
			      "by roxen"),protocol)+"\n";
  return ({ (strlen(warning)?warning:0), port });
}

string input(string name, string value, int size,
	     void|mapping(string:string) args, void|int noxml)
{
  if(!args)
    args=([]);
  else
    args+=([]);

  args->name=name;
  if(value)
    args->value = Roxen.html_encode_string(value);
  if(!args->size && size)
    args->size=(string)size; 

  string render="<input";

  foreach(indices(args), string attr) {
    render+=" "+attr+"=";
    if(!has_value(args[attr], "\"")) render+="\""+args[attr]+"\"";
    else if(!has_value(args[attr], "'")) render+="'"+args[attr]+"'";
    else render+="'"+replace(args[attr], "'", "&#39;")+"'";
  }

// render = "<tt>" + Roxen.html_encode_string(name) + "</tt><br />\n" + render;

  if(noxml) return render+">";
  return render+" />";
}
