//! Select a database from all available databases.

inherit .StringChoice;
constant type = "DatabaseChoice";

function(void:void|object) config = lambda() { return 0; };

this_program set_configuration_pointer( function(void:object) configuration )
//! Provide a function that returns a configuration object,
//! that will be used for authentication against the database
//! manager. Typically called as
//! @expr{set_configuration_pointer(my_configuration)@}.
{
  config = configuration;
  return this_object();
}

array get_choice_list( )
{
  if (!functionp(config)) {
    //  Some modules apparently send in a configration reference instead of
    //  a function pointer when calling set_configuration_pointer().
    report_warning("Incorrect usage of Variable.DatabaseChoice:\n\n%s",
		   describe_backtrace(backtrace()));
    return ({ " none" });
  }
  return ({ " none" }) + sort(DBManager.list( config() ));
}

protected void create(string default_value, void|int flags,
		      void|LocaleString std_name, void|LocaleString std_doc)
{
  ::create( default_value, ({}), flags, std_name, std_doc );
}
