#include <module.h>
inherit "module";

constant thread_safe=1;

constant cvs_version = "$Id$";
constant module_type = MODULE_TAG;

LocaleString module_name = "Tags: Captcha";
LocaleString module_doc  = "<p>Provides captcha tags. You may interface with this module either through RXML tags or by using the Pike API.</p>";

private roxen.ImageCache image_cache;

#define _ok RXML_CONTEXT->misc[" _ok"]

private string salt;

private mapping(string:int) consumed_captchas = ([]);
private mapping(string:int) old_consumed_captchas = ([]);

private void rotate_old_captchas()
{
  old_consumed_captchas = consumed_captchas;
  consumed_captchas = ([]);
}

private roxen.BackgroundProcess rotate_process;

void start(Configuration conf, int when)
{
  image_cache = roxen.ImageCache("captcha", generate_image);
  salt = roxen.query("server_salt");
  rotate_process = roxen.BackgroundProcess(timeout, rotate_old_captchas);
}

private void flush_cache()
{
  image_cache->flush();
}

mapping(string:function) query_action_buttons()
{
  return ([ "Clear Cache" : flush_cache ]);
}

string status()
{
  array s = image_cache->status();
  return sprintf("<b>Images in cache:</b> %d images<br />\n"
		 "<b>Cache size:</b> %s",
		 s[0], Roxen.sizetostring(s[1]));
}

private constant font = "budbird";
private constant height = 50;
private constant width = 120;
private constant timeout = 3600;

private Image.Image|array(Image.Layer)|mapping generate_image(mapping args,
							      RequestID id)
{
  Font f = resolve_font(args->font || font);

  array(Image.Layer) layers = ({ });

  int xsize = 0;
  int i;

  if(args["background-color"] || args["background-image"]) {
    if(args["background-color"]) {
      Image.Color color = Image.Color(args["background-color"]);
      layers += ({ Image.Layer(width, height, color )});
    }
    if(args["background-image"]) {
      array|Image.Layer tmp = roxen.load_layers(args["background-image"], id);
      if(tmp) {
        tmp = Image.lay(tmp);
        Image.Image img = tmp->image();
        Image.Image mask = tmp->alpha();
        int imgwidth = img->xsize();
        int imgheight = img->ysize();
        int oversizewidth = imgwidth > width ? imgwidth - width : 0;
        int oversizeheight = imgheight > height ? imgheight - height : 0;
        int randx = -random(oversizewidth);
        int randy = -random(oversizeheight);

        Image.Image background = Image.Image(width, height);
        Image.Image background_a = Image.Image(width, height);
        background->paste(img, randx, randy);
        background_a->paste(mask, randx, randy);
        layers += ({ Image.Layer(background, background_a) });
      }
    }
  }
  else {
    string background_data =
      Stdio.read_file("roxen-images/captcha-background.png");

    Image.Image background_image = Image.PNG.decode(background_data);
    background_image = background_image->scale(width*2, height*2);
    Image.Image background = Image.Image(width, height);
    background->paste(background_image, -random(width), -random(height));
    layers += ({ Image.Layer(background) });
  }

  foreach ((array)args->challenge, int c) {
    Image.Color color;
    if(args["color"])
      color = Image.Color(args["color"]);
    Image.Image image = f->write(sprintf("%c", c));
    image = image->rotate(random(80)-40)->scale(0.8);
    Image.Image image_a = image->clone();
    if(color)
      image = image->color(color);
    Image.Layer l = Image.Layer();
    l->set_image(image, image_a);
    l->set_offset(i*20, random(height-l->ysize()));
    layers += ({ l });
    xsize += image->xsize();
    i++;
  }

  return Image.lay(layers,0,0,width,height);
}

private string my_hash(string s)
{
  return Gmp.mpz(Crypto.HMAC(Crypto.MD5)(s)(salt), 256)->digits(36);
}

// --- Public API below ---

mapping(string:mixed) get_captcha(RequestID id, void|mapping options)
//! Returns a mapping with parameters needed to present a captcha
//! challenge to a user. The mapping will contain the indices:
//! "url" - the captcha image URL.
//! "secret" - the hashed "secret" string associated with the image.
//! "image-height" / "image-width" - dimensions of the captcha image.
{
  string challenge;

  do {
    challenge = (string)map(allocate(5),
			    lambda(int i)
			    {
			      return random(25)+65;
			    });
  } while(consumed_captchas[challenge] || old_consumed_captchas[challenge]);

  mapping opt_args = ([ "background-color":1,
                        "background-image":1,
                        "color":1,
                        "font":1
                        ]);
  options = opt_args & (options || ([ ]) );
  if(options["background-image"])
    options["background-image"] = Roxen.fix_relative( options["background-image"], id );

  mapping args = options + ([ "challenge" : challenge, "format" : "png" ]);
  string url =
    query_absolute_internal_location(id) +
    image_cache->store(args, id, timeout);


  string compact_time = Gmp.mpz(time())->digits(36);

  string secret = compact_time + "-" + my_hash(compact_time +
					       lower_case(challenge));

  return ([ "url"          : url,
	    "secret"       : secret,
	    "image-width"  : width,
	    "image-height" : height, ]);
}

int(0..1) verify_captcha(string response, string secret)
//! Verifies a captcha response @[response] against a secret @[secret].
{
  string cl = lower_case(response);

  array(string) elems = secret / "-";

  if (sizeof(elems) == 2) {
    string compact_time = elems[0];
    string hash = elems[1];

    int ts = Gmp.mpz(compact_time, 36)->cast_to_int();

    if (time(1) - ts < timeout &&
	my_hash (compact_time + lower_case(response)) == hash &&
	!consumed_captchas[response] &&
	!old_consumed_captchas[response]) {
      consumed_captchas[response] = 1;
      return 1;
    }
  }

  return 0;
}

mapping find_internal( string f, RequestID id )
{
  // Remove file exensions
  sscanf (f, "%[^./]", f);
  return image_cache->http_file_answer( f, id );
}

class TagCaptchaVerify {
  inherit RXML.Tag;
  constant name = "captcha-verify";
  mapping(string:RXML.Type) req_arg_types =
    ([ "response" : RXML.t_text(RXML.PEnt),
       "secret" : RXML.t_text(RXML.PEnt)
    ]);

  class Frame {
    inherit RXML.Frame;
    int do_iterate;
    int ok;

    array do_enter(RequestID id) {
      ok = verify_captcha(args->response, args->secret);
      do_iterate = ok ? 1 : -1;
    }

    array do_return(RequestID id) {
      if(ok) {
	_ok = 1;
	result = content;
      } else {
	_ok = 0;
      }
      return 0;
    }
  }
}

class TagEmitCaptcha {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "captcha";

  array(mapping(string:mixed)) get_dataset(mapping args, RequestID id)
  {
    mapping(string:mixed) res = get_captcha(id, args);
    return ({ res });
  }
}

//! @ignore
TAGDOCUMENTATION;
//! @endignore
#ifdef manual
constant tagdoc = ([
  "emit#captcha":
  ({ #"<desc type='plugin'>
         <p>
          <short>
            Prepares a captcha and emits needed parameters.
          </short>
          <ex-box>
            <emit source='captcha'>
              <img src='&_.url;' height='&_.image-height;' width='&_.image-width;'/>
              <form>
                <input type='text' name='response' />
                <input type='hidden' name='secret' value='&_.secret;' />
              </form>
            </emit>
          </ex-box>
         </p>
       </desc>
       <attr name='background-color' value='color'><p>
         Captcha background color.
         If none of the \"background-color\" or \"background-image\" attributes
         are specified, a default background image will be used.
        </p>
       </attr>
       <attr name='background-image' value='path'><p>
         Captcha background image. It's recommended that the image is larger than the captcha.
         The image offset will be randomized then.
         If none of the \"background-color\" or \"background-image\" attributes
         are specified, a default background image will be used.
        </p>
       </attr>
       <attr name='color' value='color' default='white'><p>
         Captcha text color.
        </p>
       </attr>
       <attr name='font' value='string'><p>
          Selects which font to use. You can get a list of all available fonts
          by using the list fonts task in the administration interface. You can
          optionally specify a font size too: <pre>font='yikes! 35'</pre></p>
        </attr>",
     ([ "&_.url;":#"<desc type='entity'>
                       <p>URL to the captcha image.</p>
                     </desc>",
	"&_.secret;":#"<desc type='entity'>
                          <p>
                            Encrypted (hashed) secret that can be sent to
                            clients and should be used together with the
                            captcha response for verification.
                          </p>
                        </desc>",
        "&_.image-height;":#"<desc type='entity'>
                               <p>The captcha image's height.</p>
                             </desc>",
        "&_.image-width;":#"<desc type='entity'>
                               <p>The captcha image's width.</p>
                             </desc>",

     ]) }),

  "captcha-verify":
  #"<desc type='cont'>
      <p>
        <short>Verifies a captcha response.</short>
        If the verification is successful, the tag's contents will be executed. You may also use the <tag>else</tag> tag together with this tag.
      </p>

      <ex-box>
        <captcha-verify response='&form.response;' secret='&form.secret;'>
          Captcha verification was successful.
        </captcha-verify>
        <else>
          Try again.
        </else>
      </ex-box>
    </desc>

    <attr name='response' value='string'>
      <p>The client's captcha response.</p>
    </attr>

    <attr name='secret' value='string'>
      <p>The string provided by the captcha emit plugin.</p>
    </attr>",
]);
#endif