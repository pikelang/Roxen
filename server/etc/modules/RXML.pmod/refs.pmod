// Kludge for the circular module references.

void create()
{
  ._fix_module_ref ("PXml", RXML.PXml);
  ._fix_module_ref ("PEnt", RXML.PEnt);
  ._fix_module_ref ("PExpr", RXML.PExpr);
  ._fix_module_ref ("utils", RXML.utils);
  ._fix_module_ref ("Roxen", Roxen);
  ._fix_module_ref ("roxen", roxen);
  ._fix_module_ref (
    "empty_tag_set",
    class {
      inherit RXML.TagSet;
      void add_tag (RXML.Tag t)
	{RXML.fatal_error ("Trying to change the empty tag set.\n");}
      void add_tags (array(RXML.Tag) ts)
	{RXML.fatal_error ("Trying to change the empty tag set.\n");}
      void remove_tag (string|object(RXML.Tag) t)
	{RXML.fatal_error ("Trying to change the empty tag set.\n");}
      void add_string_entities (mapping(string:string) e)
	{RXML.fatal_error ("Trying to change the empty tag set.\n");}
      void clear_string_entities()
	{RXML.fatal_error ("Trying to change the empty tag set.\n");}
      mixed `->= (string var, mixed val)
	{RXML.fatal_error ("Trying to change the empty tag set.\n");}
      void changed()
	{RXML.fatal_error ("Trying to change the empty tag set.\n");}
      string _sprintf (int flag)
	{return flag == 'O' && "RXML.empty_tag_set";}
    } (0, "empty_tag_set"));
}
