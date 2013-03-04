/*
 * name = "Chinese language plugin ";
 * doc = "Handles the conversion of numbers and dates to Chinese. You have to restart the server for updates to take effect. Present implementation handles only support for localized language name.";
 */

inherit "abstract.pike";

constant cvs_version = "$Id$";
constant _id = ({ "zh", "chinese", "\x4e2d\x6587" });
constant _aliases = ({ "zh", "chi", "zho", "chinese", "\x4e2d\x6587" });

protected void create()
{
  roxen.dump( __FILE__ );
}
