//! A password class with multiple customized verifications.

inherit Variable.VerifiedString;

int width = 20;
constant type = "VerifiedPassword";

string render_view( RequestID id ) {
  return "******";
}

string render_form( RequestID id, void|mapping additional_args ) {
  additional_args = additional_args || ([]);
  additional_args->type="password";
  return Variable.input(path(), "", 30, additional_args);
}
