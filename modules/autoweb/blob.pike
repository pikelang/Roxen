#include <module.h>

inherit "module";
inherit "roxenlib";

int image_counter=0;
mapping image_format_f=([]);
mapping image_format_b=([]);

string add_image(mapping args)
{
  string args_e=encode_value(args);
  string key=sprintf("%0:8X%0:8X%0:8X", random(2000000000), time(),
		     image_counter);
  if(image_format_b[args_e]==0)
  {
    //New image
    image_format_f+=([key:args]);
    image_format_b+=([args_e:key]);
    image_counter++;
  } else {
    //Old image
    key=image_format_b[args_e];
  }
  return key;
}

mapping get_image_format(string key)
{
  return image_format_f[key];
}

string tag_blob(string tag_name, mapping args, object request_id,
		object file, mapping defines)
{
  string r = "";

  int size = 10;
  if(args["size"])
    sscanf(args["size"], "%d", size);

  string key=add_image(args);
  args["src"] = query("mountpoint") + key + ".gif";
  args += ([ "width":(string)size, "height":(string)size ]); 
  args -= ([ "size":1, "corner":1, "bg":1, "fg":1 ]);
  return make_tag("img", args);
  
}

object(Image) blob_image(int size, array bg, array fg, string corner)
{
  int alias = 2;
  int x = 0, y = 0;
  switch(corner) {
  case "0": x = 0;              y = 0;              break;
  case "1": x = size*alias - 1; y = 0;              break;
  case "2": x = size*alias - 1; y = size*alias - 1; break;
  case "3": x = 0;              y = size*alias - 1; break;
  default:  x = 0;              y = 0;              break;
  }

  object img = Image.image(size*alias, size*alias, @bg)->
	       circle(x, y, size*alias, size*alias, @fg);

  // Fill the cirkle with a solid color.
  img=img->paste_alpha_color(img->select_from(x, y, 1), @fg);

  return img->scale((float)1/(float)alias);;
}

mapping find_file(string f, object request_id)
{
  mapping m;
  string key = ((f||"")/".")[0];
  mapping args = get_image_format(key);
  if(args)
    if(m = cache_lookup("blob", key))
      return m;
    else {
      object image = blob_image((int)args["size"], parse_color(args["bg"]),
				parse_color(args["fg"]), args["corner"]);
      string trans = args->transparent;
      m=http_string_answer(trans?
			   Image.GIF.encode_trans(image, @parse_color(trans)):
			   Image.GIF.encode(image), "image/gif");
      cache_set("blob", key, m);
      return m;
    }
  object font=get_font("default",32,0,0, lower_case("left"),
		       (float)(int)0, (float)(int)0);
  object image=font->write("Please reload this page!");
  return http_string_answer(Image.GIF.encode(image), "image/gif");
}

void create()
{
  defvar("mountpoint", "/blob/", "Mountpoint", TYPE_LOCATION|VAR_MORE,
	 "Mountpointen for the blob module.");
}

array register_module()
{
  return ({ 
    MODULE_LOCATION | MODULE_PARSER,
      "Blob module", 
      "A module to generate radial corners.", 0, 1});
}

string query_location() { return query("mountpoint"); }

mapping query_tag_callers()
{
  return ([ "blob":tag_blob]);
}
