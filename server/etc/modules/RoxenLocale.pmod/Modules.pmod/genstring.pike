string head = Stdio.read_bytes("header");
string charset = "iso-8859-1";

string parse_variable_string( string mod, string var, string str )
{
  return sprintf("%O:%O,\n %O:%O,\n ", 
                 mod+"/"+var+"/0",  (str/"\n")[0],
                 mod+"/"+var+"/1",  (str/"\n")[1..]*"\n" );
}

string parse_indata( string what )
{
  string module;
  string variable;
  string next_doc = "";
  string res="";
  foreach( (what-"\r")/"\n", string line )
  {
    string ov = variable;
    if(!strlen(line))
      continue;
    if(sscanf(line, "--- charset %s", charset ))
      continue;
    if(sscanf(line, "--- module %s", module ))
      continue;
    if(sscanf(line, "--- variable %s", variable ))
    {
      if(module && ov) 
        res += parse_variable_string( module, ov, next_doc );
      next_doc = "";
    }
    if( module && variable && line[ 0 ] != '#' && line[ 0 ] != '-' )
      next_doc += line+"\n";
  }
  res += parse_variable_string( module, variable, next_doc );
  return res;
}


void main(int argc, array argv)
{
  Stdio.File( replace( argv[-1], ".in", ".pmod") , "wct" )->
  write( replace(head, ({"STRINGS", "CHARSET", }),
                 ({ parse_indata( Stdio.read_bytes(argv[-1])), charset }) ));
}
