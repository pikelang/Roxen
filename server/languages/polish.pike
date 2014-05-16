/* Bugs by: Mak */
#charset iso-8859-2
/*
 * name = "Polish language plugin ";
 * doc = "Handles the conversion of numbers and dates to polish. You have to restart the server for updates to take effect.";
 *
 * Piotr Klaban <makler@man.torun.pl>
 *
 * Character encoding: ISO-8859-2
 */

inherit "abstract.pike";
inherit Locale.Language.pol : pol;

constant cvs_version = "$Id$";
constant _id = ({ pol::iso_639_1, pol::iso_639_2, pol::english_name, pol::name });
constant _aliases = pol::aliases;

array aliases()
{
  return _aliases;
}

string date(int timestamp, mapping|void m)
{
  if(!m) m=([]);

  if (m->full) return pol::date(timestamp, "full");
  if (m->date) return pol::date(timestamp, "date");
  if (m->time) return pol::date(timestamp, "time");

  return pol::date(timestamp);
}

protected void create()
{
  roxen.dump( __FILE__ );
}
