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

mapping get_image_format(string filename)
{
  if(sscanf(filename,"%s.%*s", string key)>1)
    return image_format_f[key];
  else
    return 0;
}

inline string ns_color(array (int) col)
{
  if(!arrayp(col)||sizeof(col)!=3)
    return "#000000";
  return sprintf("#%02x%02x%02x", col[0],col[1],col[2]);
}

string tag_blob(string tag_name, mapping args, object request_id,
		object file, mapping defines)
{
  string r="";
  string usage="Usage: &lt;blob corner=\"number\"" +
    "size=\"number\"bg=\"#rrggbb\" fg=\"#rrggbb\"&gt;";
  int corner=0;
  if(args["corner"])
    if(sscanf(args["corner"], "%d", corner)<1)
      return r+= usage;
	
  args["corner_i"]=corner;
  int size=10;
  if(args["size"])
    if(sscanf(args["size"], "%d", size)<1)
      return r+=usage;

  string key=add_image(args);
  args["src"] = query("mountpoint") + key + ".gif";
  args+=(["width":args["size"], "height":args["size"]]); 
  args-=(["size":1, "corner":1, "corner_i":1, "bg":1, "fg":1]);
  return make_tag("img", args);
  
}

object(Image) blob_image(int size, array bg, array fg, int corner)
{
  int alias = 2;
  int x=0, y=0;
  object img=Image.image(size*alias, size*alias, @bg);
  switch(corner) {
  case 0: x=0;            y=0;            break;
  case 1: x=size*alias-1; y=0;            break;
  case 2: x=size*alias-1; y=size*alias-1; break;
  case 3: x=0;            y=size*alias-1; break;
  }
  img=img->circle(x, y, size*alias, size*alias, @fg);
  object mask=img->select_from(x, y, 1);
  img=img->paste_alpha_color(mask, @fg);
  return img->scale((float)1/(float)alias);;
}

mapping find_file(string f, object request_id)
{
  mapping args = get_image_format(f);
  if(args) {
    object image = blob_image((int)args["size"],
				       parse_color(args["bg"]),
				       parse_color(args["fg"]),
				       args["corner_i"]);
    string i;
    if(args->transparent) {
      i = Image.GIF.encode_trans(image, @parse_color(args->transparent));
    }
    else i = Image.GIF.encode(image);
    return http_string_answer(i, "image/gif");
  }
  object font=get_font("default",32,0,0, lower_case("left"),
		       (float)(int)0, (float)(int)0);
  
  object image=font->write("Please reload this page!");
  return http_string_answer(image->togif(), "image/gif");
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
