inherit Variable.String;

// Locale macros
//<locale-token project="roxen_config"> LOCALE </locale-token>
#define LOCALE(X,Y)    \
  ([string](mixed)Locale.translate("roxen_config",roxenp()->locale->get(),X,Y))

constant type="Upload";

protected string filename;

int set_filename( string to )
//. Set the filename associated with this upload variable. Not normally
//. nesessary, since it's set automatically when the form is processed.
{
  if( filename = to )
    return 1;
}

string get_filename()
//. Get the filename associated with this upload variable. 
{
  return filename;
}

void set_from_form( RequestID id )
{
  mixed val;
  if( (val = get_form_vars( id )) && val[""] 
      && val[".filename"] && set_filename( val[".filename"] )
      && strlen(val[""])
      && (val = transform_from_form( val[""] ) ) 
      && val != query() )
  {
    array b;
    mixed q = catch( b = verify_set_from_form( val ) );
    if( q || sizeof( b ) != 2 )
    {
      if( q )
        add_warning( q );
      else
        add_warning( "Internal error: Illegal sized array "
		     "from verify_set_from_form\n" );
      return;
    }
    if( b ) 
    {
      set_warning( b[0] );
      set( b[1] );
    }
  }
}

string render_form( RequestID id, void|mapping additional_args )
{
  return ("<input type=file name='"+path()+"' />");
}

string render_view( RequestID id )
{
  return get_filename()
    ? sprintf( LOCALE(344,"Uploaded file: %s"), get_filename() )
    : "";
}
