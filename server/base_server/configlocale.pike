object locale()
{
  return roxen.locale->get();
}

object LOCALE()
{
  return roxen.locale->get()->config_actions;
}

mixed `->(string s)
{
  if(this_object()[s+"_"+locale()->name])
    return this_object()[s+"_"+locale()->name];
  switch(s)
  {
   case "ok_label": return " "+locale()->ok+" ";
   case "cancel_label": return " "+locale()->cancel+" ";
   case "next_label": return " "+locale()->next+" -> ";
   case "previous_label": return " <- "+locale()->previous+" ";
  }
  return this_object()[s];
}
