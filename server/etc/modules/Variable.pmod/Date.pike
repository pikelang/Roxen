//! A date class

inherit Variable.String;

// Locale macros
//<locale-token project="roxen_config"> LOCALE </locale-token>
#define LOCALE(X,Y)    \
   ([string](mixed)Locale.translate("roxen_config",roxenp()->locale->get(),X,Y))

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
    return ({ LOCALE(312, "Could not interpret the date"), new_value });

  if(x && sizeof(x))
    err += LOCALE(352, "Found trailing data after the date. ");

  if(m<1) {
    m=1;
    err += LOCALE(353, "Month must be at least 1. ");
  }
  if(m>12) {
    m=12;
    err += LOCALE(354, "Month must be 12 or less. ");
  }
  if(d<1) {
    d=1;
    err += LOCALE(355, "Day must be at least 1.");
  }
  if(sizeof(err))
    return ({ err, sprintf("%04d-%02d-%02d", y,m,d) });

  int days;
  if(catch(days=Calendar.ISO.Year(y)->month(m)->number_of_days()))
    return ({ sprintf(LOCALE(356, "%s does not appear to be a valid date."), new_value),
	      new_value });
  if(d > days) {
    d = days;
    return ({ sprintf((string)LOCALE(357, "Day must be %d or less."), d),
	      sprintf("%04d-%02d-%02d", y,m,d) });
  }
  return ({ 0, sprintf("%04d-%02d-%02d", y,m,d) });
  //#endif
}
