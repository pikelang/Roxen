inherit "wizard";

string name = "Neighborhood//Roxen Neighborhood...";
string doc = "";

string page_0()
{
  return sprintf("<pre>%O</pre>", neighborhood);
}

mixed handle(object id)
{
  return wizard_for(id,0);
}
