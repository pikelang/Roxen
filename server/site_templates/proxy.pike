inherit "common";
constant site_template = 1;

constant name = "Proxy site";
constant doc  = "A site that includes all the proxy modules.";

constant modules = 
({
  "proxy",
  "ftpgateway",
//  "gopher",
//   "wais",
  "connect",
});
