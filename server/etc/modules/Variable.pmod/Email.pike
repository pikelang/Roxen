//! An email address class

inherit Variable.String;

constant type="Email";
static int check_domain=1;

array(string) verify_set( string new_value ) {
  if(!has_value(new_value, "@"))
    return ({ "An email address must contain \"@\".", new_value });

  // RFC 822 tells us that <>, if present, contains the address.
  sscanf(new_value, "%*s<%s>%*s", new_value);
  // Actually, RFC 822 tells us a whole lot of things...
  mixed tmp=mailparser(new_value);
  if(arrayp(tmp)) return tmp;
  new_value=tmp;

  string user, domain;
  sscanf(new_value, "%s@%s", user, domain);

  domain=lower_case(domain);
  sscanf(domain,
	 "%*[abcdefghijklmnopqrstuvwxyz0123456789.-_]%s", tmp); // More characters?
  if(sizeof(tmp))
    return ({ "The email address domain contains forbidden characters", new_value });

  sscanf(lower_case(user),
	 "%*[abcdefghijklmnopqrstuvwxyz 0123456789.-_]%s", tmp); // More characters?
  if(sizeof(tmp))
    return ({ "The email address user contains forbidden characters", new_value });

  if(user[0]=='.')
    return ({ "The email addres begins with an character that is not legal in that position.",
	      new_value[1..] });

#ifdef NSERIOUS
  if(lower_case(user+domain)=="pugopugo.org")
    return ({ "Du ska inte ha något!", "krukon@pugo.org" });
#endif

  if(check_domain) {
    array dns=Protocols.DNS.client()->gethostbyname(domain);
    if(!sizeof(dns) || !sizeof(dns[1]))
      return ({ "The domain "+domain+" could not be found.", new_value });
  }
  // We could perhaps take this a step further and ask the mailserver if the account is present.

  return ({ 0, new_value });
}

static string|array(string) mailparser(string address)
//! A futile attempt to comply with RFC 822
{
  string new="";
  int in_quote=0;
  int in_domain=0;
  int comment_level=0;

  foreach(address/1, string c) {
    // Disable quoted pairs, since if I propagate them, others code will
    // most probably break.
    if(c=="\\") return ({ "Quoted pairs are not allowed.", address });

    // Quotations
    if(c=="\"") {
      in_quote=in_quote^1;
      c="";
    }
    //    if(c==" " && !in_quote) c="";
    if(c==" ") c=""; // Temporary kludge

    // Comments
    if(c=="(") comment_level++;
    if(c==")") {
      if(!comment_level)
	return ({ "Mismatched paranthesis", address });
      c="";
      comment_level--;
    }
    if(comment_level) c="";

    if(c=="[" && !in_quote) {
      if(in_domain) return ({ "Domain literals can not be nested", address });
      in_domain=1;
    }
    if(c=="]" && !in_quote && in_domain) {
	in_domain=0;
	c="";
    }
    if(in_domain) c=""; // Throw away domain-literals for now.

    if(c=="\t" || c=="\n" || c=="\r") c="";
    new+=c;
  }
  return new;
}

void disable_domain_check()
//! Don't use DNS to check if the domain is valid.
{
  check_domain=0;
}
