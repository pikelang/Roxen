//! A date class

inherit Variable.String;

constant type = "Date";

array(string) verify_set( string new_value ) {
#if constant(Calendar.II)
  if( catch( Calendar.dwim_day( new_value ) ) )
    return ({ "Could not interpret the date", new_value });
  return ({ 0, new_value });
#else
  int y,m,d;
  if( sscanf(new_value,"%4d-%2d-%2d",y,m,d)!=3 &&
      sscanf(new_value,"%4d%2d%2d",y,m,d)!=3 )
    return ({ "Could not interpret the date", new_value });
  else {
    if( sprintf("%4d-%02d-%02d", y, m, d) != Calendar.ISO.Year(y)->
	month(m)->day(d)->iso_name() )
      return ({ new_value+" does not appear to be a valid date.", new_value });
  }
  return ({ 0, new_value });
#endif
}
