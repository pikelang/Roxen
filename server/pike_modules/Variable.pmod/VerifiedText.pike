//! A text class with multiple customized verifications.

inherit Variable.VerifiedString;

constant type = "VerifiedText";

string render_form( RequestID id, void|mapping args ) {

  if(!args)
    args=([]);
  else
    args+=([]);

  args->name=path();
  string render="<textarea";

  foreach(indices(args), string attr) {
    render+=" "+attr+"=";
    if(!has_value(args[attr], "\"")) render+="\""+args[attr]+"\"";
    else if(!has_value(args[attr], "'")) render+="'"+args[attr]+"'";
    else render+="'"+replace(args[attr], "'", "&#39;")+"'";
  }

  return render+">"+ Roxen.html_encode_string ((string)query()) +"</textarea>";
}
