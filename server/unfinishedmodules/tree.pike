#if 0
/* State has to be encoded somewhere...
 */


string tag_tree(string tag, mapping opts, string data, mapping got)
{
  array tree=parse_tree(data);
  return replace(display_tree(tree), ({ "&v;", "&r;" }), ({ "{", "}" }));
}
#endif
