//! A date class

inherit Variable.String;

// Locale macros
//<locale-token project="roxen_config"> LOCALE </locale-token>

#define LOCALE(X,Y)    \
  ([string](mixed)Locale.translate("roxen_config",roxenp()->locale->get(),X,Y))

constant type = "Date";

Calendar.Day get_date()
//! Returns the date as a Calendar.Day object.
{
  return Calendar.dwim_day( query() );
}

array(string) verify_set( string new_value )
{
  if( catch( Calendar.dwim_day( new_value ) ) )
    return ({ LOCALE(312,"Could not interpret the date"), new_value });
  return ({ 0, new_value });
}
