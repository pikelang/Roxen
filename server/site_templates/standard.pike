inherit "common";
constant site_template = 1;

constant name = "Standard site";
constant doc  = "Standard ChiliMoon site, with most of the commonly used "
  "modules. If you are a new ChiliMoon user, or would like to start a "
  "fresh new site using the server to its full potential, use this "
  "template.";

constant modules = ({
  "contenttypes",
  "diremit",
  "directories",
  "gbutton",
  "graphic_text",
  "obox",
  "url_rectifier",
  "rxmlparse",
  "rxmltags",
  "tablist",
  "filesystem",
});
