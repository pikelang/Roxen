inherit "common";
constant site_template = 1;

constant name = "Standard site";
constant doc  = "Standard roxen site, with most of the commonly used modules. "
		"If you are a new roxen user, or would like to start a fresh "
		"new site using the server to its full potential, use this "
		"template.";

constant modules = ({
//"awizard",
//"cgi",
  "contenttypes",
  "directories",
  "gbutton",
  "graphic_text",
  "obox",
  "url_rectifier",
//"pikescript",
  "rxmlparse",
  "rxmltags",
  "tablist",
  "filesystem",
});
