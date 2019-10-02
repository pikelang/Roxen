string parse( RequestID id )
{
  string n = id->variables->name;
  string p, e;
  int c;
  while( sscanf( n, "%s<%x>%s", p, c, e ) )
    n = p+sprintf("%c",c)+e;
  return (array(string))((array(int))n)*",";
}
