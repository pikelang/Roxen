#charset iso-8859-2
// -*- pike -*-

string module_doc( string module_name, string variable, int long )
{
  return module_doc_strings[module_name+"/"+variable+"/"+long];
}

mapping (string:string) module_doc_strings =
([
  "roxen/foo/0":"Foo Variable",
 "roxen/foo/1":"This is the foo variable documentation string... It goes on and on\nand on and on\n",
 
]);
