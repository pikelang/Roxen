inherit "roxenlib";
    
int check_config_name(string name)
{
  if((name == "") || (name[-1] == '~') || (search(name, "/") != -1))
    return 1;
  
  name = lower_case(name);

  foreach(roxen->configurations, object c)
    if(lower_case(c->name) == name)
      return 1;
  return (< " ", "\t", "cvs", "global variables" >)[ name ];
}

mixed parse( object id )
{
  id->variables->name=
    (replace(id->variables->name,"\000"," ")/" "-({""}))*" ";
  if( check_config_name( id->variables->name ) )
    return http_string_answer("<error>foo</error>");
  return "";
}
