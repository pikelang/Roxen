//! A language-list class

inherit Variable.MultipleChoice;

constant type = "LanguageChoice";

static string _title( string lang ) {
  return 
    roxenp()->language(roxenp()->locale->get(), "language")(lang)
    || lang;
}



