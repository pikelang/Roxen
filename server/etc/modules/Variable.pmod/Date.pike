//! A date class

inherit Variable.String;

constant type = "Date";

array(string) verify_set( string new_value ) {

  //#if constant(Calendar.II)
  //  if( catch( Calendar.dwim_day( new_value ) ) )
  //    return ({ "Could not interpret the date", new_value });
  //  return ({ 0, new_value });
  //#else
  int y,m,d;
  string x, err="";
  if( sscanf(new_value,"%4d-%2d-%2d%s",y,m,d,x)<3 &&
      sscanf(new_value,"%4d%2d%2d%s",y,m,d,x)<3 )
    return ({ "Could not interpret the date", new_value });

  if(x && sizeof(x))
    err += "Found trailing data after the date. ";

  if(m<1) {
    m=1;
    err += "Month must be at least 1. ";
  }
  if(m>12) {
    m=12;
    err += "Month must be 12 or less. ";
  }
  if(d<1) {
    d=1;
    err += "Day must be at least 1.";
  }
  if(sizeof(err))
    return ({ err, sprintf("%04d-%02d-%02d", y,m,d) });

  int days;
  if(catch(days=Calendar.ISO.Year(y)->month(m)->number_of_days()))
    return ({ new_value+" does not appear to be a valid date.", new_value });
  if(d > days) {
    d = days;
    return ({ "Day must be "+d+" or less.", sprintf("%04d-%02d-%02d", y,m,d) });
  }
  return ({ 0, sprintf("%04d-%02d-%02d", y,m,d) });
  //#endif
}
