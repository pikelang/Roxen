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
  //  Pad to at least 6 digits and strip # prefix
  rgb_str = rgb_str + "000000";
  if (rgb_str.charAt(0) == "#")
    rgb_str = rgb_str.substring(1, 7);
  else
    rgb_str = rgb_str.substring(0, 6);
  
  var r = hex_to_int(rgb_str.substring(0, 2));
  var g = hex_to_int(rgb_str.substring(2, 4));
  var b = hex_to_int(rgb_str.substring(4, 6));
  var min, max, delta;
  var h, s, v;

  min = Math.min(r, g, b);
  max = Math.max(r, g, b);
  delta = max - min;
  v = max;

  if (max > 0 && delta > 0) {
    s = Math.round(255.0 * delta / max);
  } else {
    return new Array(0, 0, v);
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


function colsel_click(event, prefix, h, s, v, in_bar)
{
  var x = (event.clientX - getTargetX(event)) * 2;
  var y = (event.clientY - getTargetY(event)) * 2;

  if (x < 0) x = 0;
  if (x > 255) x = 255;
  if (y < 0) y = 0;
  if (y > 255) y = 255;

  if (in_bar) {
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
    var bar_url = "/internal-roxen-colorbar:" + h + "," + v + "," + s;
    bar_img.src = bar_url;
  }
  
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


function colsel_type(prefix, value, update_field)
{
  //  Attempt to parse the color as RRGGBB and set the popup images
  //  accordingly.
  var new_hsv = rgb_string_to_hsv(value);
  colsel_update(prefix, new_hsv[0], new_hsv[1], new_hsv[2],
                update_field, value);
  return new_hsv;
}