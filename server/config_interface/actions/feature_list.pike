inherit "wizard";
#include <roxen.h>
//<locale-token project="admin_tasks"> LOCALE </locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("admin_tasks",X,Y)

constant action = "debug_info";

string name= LOCALE(6, "Pike module list");
string doc = LOCALE(7,"Show information about which features and modules are "
		    "available in the Pike this Roxen is using.");

constant all_features = ({
  // only include modules that are sensible to use with Roxen
  "Bz2",
  "COM",
  "GSSAPI",
  "Gdbm",
  "Gmp",
  "Gz",
  "Image.FreeType",
  "Image.GIF",
  "Image.JPEG",
  "Image.PNG",
  "Image.TIFF",
  "Java",
  "Kerberos",
  "Mird",
  "Msql",
  "Mysql",
  "Nettle",
  "Odbc",
  "Oracle",
  "PDF",
  "Postgres",
  "Regexp.PCRE",
  "Regexp.PCRE.Widestring",
  "SANE",
  "SQLite",
  "WhiteFish",
  "double_precision_float",
  "out-of-band_data",
  "sybase",
  "threads",
});

string nice_name( string what )
{
  return map(replace(what, ([ "_":" ","-":" " ]) )/" ",capitalize)*" ";
}

mixed parse(object id)
{
  string res;
  array features = Tools.Install.features();
  array disabled = all_features - features;

  res =
    "<cf-title>" + LOCALE(6, "Pike module list") + "</cf-title>"
    "<p />"
    ""+ LOCALE(238, "Features") +"\n"
    "<ul>\n"+
    String.implode_nicely( sort(map(features,nice_name)-({0})),
			   LOCALE(79,"and"))
    + "</ul><br />\n";

  if (sizeof(disabled))
    res += ""+LOCALE(140,"Unavailable features")+"\n"
      "<ul>\n"
      + String.implode_nicely( sort(map(disabled,nice_name)-({0})),
			       LOCALE(79,"and"))
      + "</ul><br />\n";

  return res+ "<p><cf-ok/></p>";
}
