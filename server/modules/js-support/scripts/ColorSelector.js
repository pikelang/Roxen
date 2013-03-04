//  Color selector scripts. Used by <var type="color"> in WebServer wizards.
//  $Id$


//  Known HTML color names
var html_color_names = new Array(
      "ALICEBLUE", "ANTIQUEWHITE", "AQUA", "AQUAMARINE", "AZURE", "BEIGE",
      "BISQUE", "BLACK", "BLANCHEDALMOND", "BLUE", "BLUEVIOLET", "BROWN",
      "BURLYWOOD", "CADETBLUE", "CHARTREUSE", "CHOCOLATE", "CORAL",
      "CORNFLOWERBLUE", "CORNSILK", "CRIMSON", "CYAN", "DARKBLUE",
      "DARKCYAN", "DARKGOLDENROD", "DARKGRAY", "DARKGREEN", "DARKKHAKI",
      "DARKMAGENTA", "DARKOLIVEGREEN", "DARKORANGE", "DARKORCHID",
      "DARKRED", "DARKSALMON", "DARKSEAGREEN", "DARKSLATEBLUE",
      "DARKSLATEGRAY", "DARKTURQUOISE", "DARKVIOLET", "DEEPPINK",
      "DEEPSKYBLUE", "DIMGRAY", "DODGERBLUE", "FELDSPAR", "FIREBRICK",
      "FLORALWHITE", "FORESTGREEN", "FUCHSIA", "GAINSBORO", "GHOSTWHITE",
      "GOLD", "GOLDENROD", "GRAY", "GREEN", "GREENYELLOW", "HONEYDEW",
      "HOTPINK", "INDIANRED ", "INDIGO ", "IVORY", "KHAKI", "LAVENDER",
      "LAVENDERBLUSH", "LAWNGREEN", "LEMONCHIFFON", "LIGHTBLUE",
      "LIGHTCORAL", "LIGHTCYAN", "LIGHTGOLDENRODYELLOW", "LIGHTGREY",
      "LIGHTGREEN", "LIGHTPINK", "LIGHTSALMON", "LIGHTSEAGREEN",
      "LIGHTSKYBLUE", "LIGHTSLATEBLUE", "LIGHTSLATEGRAY", "LIGHTSTEELBLUE",
      "LIGHTYELLOW", "LIME", "LIMEGREEN", "LINEN", "MAGENTA", "MAROON",
      "MEDIUMAQUAMARINE", "MEDIUMBLUE", "MEDIUMORCHID", "MEDIUMPURPLE",
      "MEDIUMSEAGREEN", "MEDIUMSLATEBLUE", "MEDIUMSPRINGGREEN",
      "MEDIUMTURQUOISE", "MEDIUMVIOLETRED", "MIDNIGHTBLUE", "MINTCREAM",
      "MISTYROSE", "MOCCASIN", "NAVAJOWHITE", "NAVY", "OLDLACE", "OLIVE",
      "OLIVEDRAB", "ORANGE", "ORANGERED", "ORCHID", "PALEGOLDENROD",
      "PALEGREEN", "PALETURQUOISE", "PALEVIOLETRED", "PAPAYAWHIP",
      "PEACHPUFF", "PERU", "PINK", "PLUM", "POWDERBLUE", "PURPLE", "RED",
      "ROSYBROWN", "ROYALBLUE", "SADDLEBROWN", "SALMON", "SANDYBROWN",
      "SEAGREEN", "SEASHELL", "SIENNA", "SILVER", "SKYBLUE", "SLATEBLUE",
      "SLATEGRAY", "SNOW", "SPRINGGREEN", "STEELBLUE", "TAN", "TEAL",
      "THISTLE", "TOMATO", "TURQUOISE", "VIOLET", "VIOLETRED", "WHEAT",
      "WHITE", "WHITESMOKE", "YELLOW", "YELLOWGREEN");

var html_color_values = new Array(
      "#F0F8FF", "#FAEBD7", "#00FFFF", "#7FFFD4", "#F0FFFF", "#F5F5DC",
      "#FFE4C4", "#000000", "#FFEBCD", "#0000FF", "#8A2BE2", "#A52A2A",
      "#DEB887", "#5F9EA0", "#7FFF00", "#D2691E", "#FF7F50", "#6495ED",
      "#FFF8DC", "#DC143C", "#00FFFF", "#00008B", "#008B8B", "#B8860B",
      "#A9A9A9", "#006400", "#BDB76B", "#8B008B", "#556B2F", "#FF8C00",
      "#9932CC", "#8B0000", "#E9967A", "#8FBC8F", "#483D8B", "#2F4F4F",
      "#00CED1", "#9400D3", "#FF1493", "#00BFFF", "#696969", "#1E90FF",
      "#D19275", "#B22222", "#FFFAF0", "#228B22", "#FF00FF", "#DCDCDC",
      "#F8F8FF", "#FFD700", "#DAA520", "#808080", "#008000", "#ADFF2F",
      "#F0FFF0", "#FF69B4", "#CD5C5C", "#4B0082", "#FFFFF0", "#F0E68C",
      "#E6E6FA", "#FFF0F5", "#7CFC00", "#FFFACD", "#ADD8E6", "#F08080",
      "#E0FFFF", "#FAFAD2", "#D3D3D3", "#90EE90", "#FFB6C1", "#FFA07A",
      "#20B2AA", "#87CEFA", "#8470FF", "#778899", "#B0C4DE", "#FFFFE0",
      "#00FF00", "#32CD32", "#FAF0E6", "#FF00FF", "#800000", "#66CDAA",
      "#0000CD", "#BA55D3", "#9370D8", "#3CB371", "#7B68EE", "#00FA9A",
      "#48D1CC", "#C71585", "#191970", "#F5FFFA", "#FFE4E1", "#FFE4B5",
      "#FFDEAD", "#000080", "#FDF5E6", "#808000", "#6B8E23", "#FFA500",
      "#FF4500", "#DA70D6", "#EEE8AA", "#98FB98", "#AFEEEE", "#D87093",
      "#FFEFD5", "#FFDAB9", "#CD853F", "#FFC0CB", "#DDA0DD", "#B0E0E6",
      "#800080", "#FF0000", "#BC8F8F", "#4169E1", "#8B4513", "#FA8072",
      "#F4A460", "#2E8B57", "#FFF5EE", "#A0522D", "#C0C0C0", "#87CEEB",
      "#6A5ACD", "#708090", "#FFFAFA", "#00FF7F", "#4682B4", "#D2B48C",
      "#008080", "#D8BFD8", "#FF6347", "#40E0D0", "#EE82EE", "#D02090",
      "#F5DEB3", "#FFFFFF", "#F5F5F5", "#FFFF00", "#9ACD32");


//  Validation of HTML color names
function html_color_to_rgb(name)
{
  name = name.toUpperCase();
  var start = 0;
  var end = html_color_names.length - 1;
  while (end - start > 3) {
    var pos = Math.floor((start + end) / 2);
    var test = html_color_names[pos];
    if (test == name)
      return html_color_values[pos];
    else if (test < name)
      start = pos + 1;
    else
      end = pos - 1;
  }
  for (var pos = start; pos <= end; pos++) {
    if (html_color_names[pos] == name)
      return html_color_values[pos];
  }
  return "#000000";
}



//  Conversion from integer to hex
var hex_digits = new Array("0", "1", "2", "3", "4", "5", "6", "7",
			   "8", "9", "A", "B", "C", "D", "E", "F");
var hex_string = "0123456789ABCDEF";
function int_to_hex(n)
{
  return hex_digits[Math.floor(n / 16)] + hex_digits[n % 16];
}


function hex_to_int(h)
{
  h = h.toUpperCase();
  var d1 = hex_string.indexOf(h.charAt(0));
  var d2 = hex_string.indexOf(h.charAt(1));
  if (d1 < 0 || d2 < 0)
    return 0;
  return d1 * 16 + d2;
}


//  Conversion from HSV to RGB color space. Expects values in the
//  range 0-255 for H, S and V. Returns a string of the form RRGGBB.
function hsv_to_rgb_string(h, s, v)
{
  var r, g, b;
  var i, f, p, q, t;

  if (s == 0) {
    r = g = b = v;
  } else {
    h = h * 360.0 / 255.0;
    s = s / 255.0;
    v = v / 255.0;

    h = h / 60.0;
    i = Math.floor(h);
    f = h - i;
    p = v * (1 - s);
    q = v * (1 - s * f);
    t = v * (1 - s * (1 - f));

    if      (i == 0) { r = v; g = t; b = p; }
    else if (i == 1) { r = q; g = v; b = p; }
    else if (i == 2) { r = p; g = v; b = t; }
    else if (i == 3) { r = p; g = q; b = v; }
    else if (i == 4) { r = t; g = p; b = v; }
    else { r = v; g = p; b = q; }

    r = r * 255.0;
    g = g * 255.0;
    b = b * 255.0;
  }

  return int_to_hex(Math.round(r)) +
         int_to_hex(Math.round(g)) + 
         int_to_hex(Math.round(b));
}


function rgb_string_to_hsv(rgb_str)
{
  //  Expected input is on form "#rrggbb"
  var r = hex_to_int(rgb_str.substring(1, 3));
  var g = hex_to_int(rgb_str.substring(3, 5));
  var b = hex_to_int(rgb_str.substring(5, 7));
  var min, max, delta;
  var h, s, v;

  min = Math.min(r, g, b);
  max = Math.max(r, g, b);
  delta = max - min;
  v = max;

  if (max > 0 && delta > 0) {
    s = Math.round(255.0 * delta / max);
  } else {
    if(v > 0)
      return new Array(0, 0, v);
    return new Array(0, 255, 0);
  }

  if (r == max) {
    h = 1.0 * (g - b) / delta;
  } else if (g == max) {
    h = 2 + 1.0 * (b - r) / delta;
  } else {
    h = 4 + 1.0 * (r - g) / delta;
  }
  h = h * 60.0;
  if (h < 0)
    h += 360.0;
  
  return new Array(Math.round(h * 255.0 / 360.0), s, v);
}


function colsel_click(event, prefix, h, s, v, in_bar, in_cross)
{
  var x = (getEventX(event) - getTargetX(event)) * 2;
  var y = (getEventY(event) - getTargetY(event)) * 2;

  //  Kludge to get correct coordinates. Only needed in MSIE browsers for
  //  unknown reasons.
  if (isIE4) {
    x -= 4;
    y -= 4;
  }
  
  if (x < 0) x = 0;
  if (x > 255) x = 255;
  if (y < 0) y = 0;
  if (y > 255) y = 255;

  if (in_cross) {
    if (in_cross == "x") {
      v = 255 - y;
    } else if (in_cross == "y") {
      h = x;
    }
  } else if (in_bar) {
    s = 255 - y;
  } else {
    h = x;
    v = 255 - y;
  }
  colsel_update(prefix, h, s, v, 1);
  return new Array(h, s, v);
}


function colsel_update(prefix, h, s, v, update_field, force_color)
{
  var color_str = force_color ? force_color : ("#" + hsv_to_rgb_string(h, s, v));
    
  var bar_img = getObject(prefix + "colorbar");
  if (bar_img) {
    var bar_url = "/internal-roxen-colorbar-small:" + h + "," + v + ",-1";
    bar_img.src = bar_url;
  }

  var mark_x_img = getObject(prefix + "mark_x");
  if (mark_x_img)
    mark_x_img.style.left = 5 + Math.floor(h / 2) + "px";
  var mark_y_img = getObject(prefix + "mark_y");
  if (mark_y_img)
    mark_y_img.style.top = 5 + Math.floor((255 - v) / 2) + "px";
  var mark_y_small_img = getObject(prefix + "mark_y_small");
  if (mark_y_small_img)
    mark_y_small_img.style.top = 5 + Math.floor((255 - s) / 2) + "px";
  
  var preview_td = getObject(prefix + "preview");
  if (preview_td) {
    preview_td.style.background = color_str;
  }
  
  if (update_field) {
    var color_field = getObject(prefix + "color_input");
    if (color_field) {
      color_field.value = color_str;
    }
  }
}


function normalize_rgb_string(rgb_str)
{
  //  Pad to at least 6 digits and convert to uppercase
  rgb_str = rgb_str + "000000";
  rgb_str = rgb_str.substring(0, 7);
  return rgb_str.toUpperCase();
}


function colsel_type(prefix, value, update_field)
{
  //  If value starts with # we consider it to be #RRGGBB format
  var is_hex = (value.charAt(0) == "#");
  var rgb_value =
    is_hex ? normalize_rgb_string(value) : html_color_to_rgb(value);
  
  //  Attempt to parse the color as RRGGBB and set the popup images
  //  accordingly.
  var new_hsv = rgb_string_to_hsv(rgb_value);
  colsel_update(prefix, new_hsv[0], new_hsv[1], new_hsv[2],
                update_field, rgb_value);
  return new_hsv;
}
