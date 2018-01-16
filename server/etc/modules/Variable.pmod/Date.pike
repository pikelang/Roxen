//! A date class

inherit Variable.String;

// Locale macros
//<locale-token project="roxen_config"> LOCALE </locale-token>
#define LOCALE(X,Y)    \
   ([string](mixed)Locale.translate("roxen_config",roxenp()->locale->get(),X,Y))

constant type = "Date";
protected int _may_be_empty=0;
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
  if(!sizeof(new_value) && _may_be_empty)
    return ({ 0, new_value });
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

void may_be_empty(int(0..1) state)
//! Decides if an empty variable also is valid.
{
  _may_be_empty = state;
}

string render_form( RequestID id, void|mapping additional_args )
{
  additional_args = additional_args || ([]);
  if (!additional_args->type)
    additional_args->type="date";
  return ::render_form(id, additional_args);
}
