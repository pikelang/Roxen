multiset illegal_chars =
(<
  // Characters that generate problems when used with Unix _or_ NT
  // filesystems Also a few special characters to ease quoting
  // problems in the config IF (such as '!')
  "?",  "!",  "/",  "\\",  "~",  "\"",  "'",  "`",
  "#",  "$",  "%",  "&", "=", ";", ":", "_", "\t",
  "<", ">", "|", "*"
>);

int check_config_name(string name)
{
  if( strlen( name ) < 2 )
    return 1;

  if( name[0] == ' ' || name[-1] == ' ' )
    return 1;

  name = lower_case(name);

  if( sizeof( rows( illegal_chars, name/"" ) -({ 0 }) ) )
    return 1;
  
  foreach(roxen->configurations, Configuration c)
    if(lower_case(c->name) == name)
      return 1;
  return (< " ", "cvs", "global variables" >)[ name ];
}

mixed parse( RequestID id )
{
  string n = id->variables->name;
  string p, e;
  int c;
  while( sscanf( n, "%s<%x>%s", p, c, e ) )
    n = p+sprintf("%c",c)+e;
  id->variables->name=
    (replace(n||"","\000"," ")/" "-({""}))*" ";
  if( check_config_name( id->variables->name ) )
    return Roxen.http_string_answer("error");
  return "";
}
