//! A date class

inherit Variable.String;

// Locale macros
//<locale-token project="roxen_config"> LOCALE </locale-token>
#define LOCALE(X,Y)    \
   ([string](mixed)Locale.translate("roxen_config",get_core()->locale->get(),X,Y))

constant type = "Date";
string date_type = "%Y-%M-%D";
  // int any_date = 0;

array(string) verify_set( string new_value ) {

  // dwim_day is not strict enough.
  //  if( any_date ) {
  //    object ok = 0;
  //    catch( ok = Calendar.ISO.dwim_day( new_value ) );
  //    if( !ok )
  //      return ({ "Could not interpret the date", new_value });
  //    return ({ 0, new_value });
  //  }
  //  else {
  if( !Calendar.parse(date_type, new_value ) )
    return ({ "Could not interpret the date", new_value });
  return ({ 0, new_value });

}

void set_date_type( string new_date_type ) {
  //  if( new_date_type == "any" )
  //    any_date = 1;
  //  else
    date_type = new_date_type;
}
