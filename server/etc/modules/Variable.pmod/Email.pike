//! An email address class

inherit Variable.String;

constant type="Email";

array(string) verify_set( string new_value ) {
  new_value=lower_case(new_value);
  if(!has_value(new_value, "@"))
    return ({ "An email address must contain \"@\".", new_value });

  string user, domain, tmp;
  sscanf(new_value, "%s@%s", user, domain);
  sscanf(user+domain,
	 "%*[abcdefghijklmnopqrstuvwxyz0123456789.-_]%s", tmp); // More characters?
  if(sizeof(tmp))
    return ({ "The email address contains forbidden characters", new_value });

  array dns=Protocols.DNS.client()->gethostbyname(domain);
  if(!sizeof(dns) || !sizeof(dns[1]))
    return ({ "The domain "+domain+" could not be found.", new_value });
  return ({ 0, new_value });
}
