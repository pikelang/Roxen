inherit "wizard";

constant task = "debug_info";
constant name = "Pike module list";
constant doc  = ("Show information about which features and modules are "
		 "available in the Pike this ChiliMoon is using.");

constant all_features = ({
  // only include modules that are sensible to use with ChiliMoon
  "threads", "out-of-band_data", "Gdbm", "Gmp", "Gz",
  "Image.FreeType", "Image.GIF", "Image.JPEG", "Image.TIFF", "Image.TTF",
  "Image.PNG", "Java", "Mird", "Msql", "Mysql", "Odbc", "Oracle", "PDF",
  "Postgres", "SANE", "sybase",
});

string nice_name( string what )
{
  return map(replace(what, ([ "_":" ","-":" " ]) )/" ",String.capitalize)*" ";
}
  
mixed parse(object id)
{
  string res;
  array features = Tools.Install.features();
  array disabled = all_features - features;

  res =
    "<font size='+1'><b>Pike module list</b></font>"
    "<p />"
    "Features\n"
    "<ul>\n"+
    String.implode_nicely( sort(map(features,nice_name)-({0})),
			   "and")
    + "</ul><br />\n";

  if (sizeof(disabled))
    res += "Unavailable features\n"
      "<ul>\n"
      + String.implode_nicely( sort(map(disabled,nice_name)-({0})),
			       "and")
      + "</ul><br />\n";

  return res+ "<p><cf-ok/></p>";
}
