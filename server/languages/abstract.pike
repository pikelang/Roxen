/*
 * name = "Abstract language class";
 * doc = "Handles the conversion of numbers and dates. You have to restart the server for updates to take effect.";
 */

// Array(string) with the months of the year, beginning with January
constant months = ({ "", "", "", "", "", "", "", "", "", "", "", "" });

// Array(string) with the days of the week, beginning with Sunday
constant days = ({ "", "", "", "", "", "", "" });

// Mapping(string:string) from language code to language name
constant languages = ([]);

// Array(string) with all the language's identifiers
constant _aliases = ({});

// Array(string) with language code and the language.
constant _id = ({ "??", "Unknown language" });

array id()
{
  return _id;
}

string month(int num)
{
  return months[ num - 1 ];
}

string day(int num)
{
  return days[ num - 1 ];
}

array aliases()
{
  return _aliases;
}

string language(string code)
{
  return languages[code];
}

string number(int i)
{
  return (string)i;
}

string ordered(int i)
{
  return (string)i;
}

string date(int i, mapping|void m)
{
  mapping lt=localtime(i);
  return sprintf("%4d-%02d-%02d", lt->year+1900, lt->mon+1, lt->mday);
}
