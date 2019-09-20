
inherit .StringChoice;
constant type = "TableChoice";
.Variable db;

array(string) get_choice_list( )
{
  return sort(DBManager.db_tables( db->query() ));
}

void create( string default_value,
	     void|int flags,
	     void|LocaleString std_name,
	     void|LocaleString std_doc,
	     .Variable _dbchoice )
{
  ::create( default_value, ({}), flags, std_name, std_doc );
  db = _dbchoice;
}

