//! A language-list class

inherit Variable.MultipleChoice;

constant type = "LanguageChoice";

static string _title( string lang ) {
  return Standards.ISO639_2.get_language(lang)||lang;
}



