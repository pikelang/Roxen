
constant box      = "large";
constant box_initial = 1;

constant box_position = -1;

constant box_name = "Welcome message";
constant box_doc  = "ChiliMoon welcome message and news";

string parse( RequestID id )
{
  // Ok. I am lazy. This could be optimized. :-)
  return #"
<table><tr>
  <td><img src='/internal-roxen-unit' width='50'/></td>
  <td><eval><insert file=\"welcome.txt\" /></eval></td>
  <td><img src='/internal-roxen-unit' width='50'/></td>
</tr></table>
";
}
