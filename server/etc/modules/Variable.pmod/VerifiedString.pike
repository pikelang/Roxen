//! A string class with multiple customized verifications.

//#pragma strict_types

inherit Variable.String;

// Locale macros
//<locale-token project="roxen_config"> LOCALE </locale-token>
#define LOCALE(X,Y)    \
  ([string](mixed)Locale.translate("roxen_config",roxenp()->locale->get(),X,Y))

constant type = "VerifiedString";
array(function(string:array(string))) verifications = ({});
int default_on_error = 0;

#define OR  1
#define AND 2
int logic_mode = AND;

void clear_verifications() {
  verifications = ({});
}

array(string) verify_set( string new_value ) {
  string warn;
  foreach(verifications, function(string:array(string)) verify) {
    [warn, new_value] = verify(new_value);
    if(warn && logic_mode==AND) {
      if(default_on_error) new_value = default_value();
      return ({ warn, new_value });
    }
    if(!warn && logic_mode==OR) {
      return ({ warn, new_value });
    }
  }
  return ({ warn, new_value });
}

void add_regexp(string new_regexp)
//! Add a regexp that the new value must match.
{
  Regexp regexp=Regexp(new_regexp);
  verifications+=({
    lambda(string in) {
      if(!regexp->match(in))
	return ({ sprintf(LOCALE(496,"Value %s does not match the regexp %s."),
			  in, new_regexp), in });
      return ({ 0, in });
    }
  });
}

void add_glob(string new_glob)
//! Add a glob that the new value must match.
{
  verifications+=({
    lambda(string in) {
      if(!glob(new_glob, in))
	return ({ sprintf(LOCALE(497,"Value %s does not match the glob %s."),
			  in, new_glob), in });
      return ({ 0, in });
    }
  });
}

void add_minlength(int minlength)
//! Set a minimum length that the new value must be.
{
  verifications+=({
    lambda(string in) {
      if(sizeof(in)<minlength)
	return ({ sprintf(LOCALE(498,"Value %s must be at least %d characters "
				 "long. (%d character short)"),
		       in, minlength, minlength-sizeof(in)), in });
      return ({ 0, in });
    }
  });
}

void add_maxlength(int maxlength)
//! Set a maximum length that the new value must be.
{
  verifications+=({
    lambda(string in) {
      if(sizeof(in)>maxlength)
	return ({ sprintf(LOCALE(499,"Value %s must not be more than %d "
				 "characters long. (%d character too long)"),
		       in, maxlength, sizeof(in)-maxlength), in[..maxlength-1]});
      return ({ 0, in });
    }
  });
}

void add_upper()
//! If called, the value must be in uppercase.
{
  verifications+=({
    lambda(string in) {
      if(upper_case(in)!=in)
	return ({ sprintf(LOCALE(500,"Value %s is not uppercased."), in),
		  upper_case(in) });
      return ({ 0, in });
    }
  });
}

void add_lower()
//! If called, the value must be in lowercase.
{
  verifications+=({
    lambda(string in) {
      if(lower_case(in)!=in)
	return ({ sprintf(LOCALE(501,"Value %s is not lowercased."), in),
		  lower_case(in) });
      return ({ 0, in });
    }
  });
}

void set_default_on_error()
//! If called, the value will be resetted to the default value if the new value does
//! not pass the verification.
{
  default_on_error=1;
}

void set_or_logic()
//! By default all conditions must be met for the variable to be valid. This "AND"
//! behavior can be changed into an "OR" behavior with this method. If called it is
//! enough if only one condition is met for the variable to be valid.
{
  logic_mode=OR;
}
