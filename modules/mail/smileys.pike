inherit "module";
inherit "roxenlib";
#include <module.h>


array register_module()
{
  return ({
    MODULE_LOCATION|MODULE_PARSER,
    "AutoMail smiley parser",
    "Yo man :-)",0,1
    });
}

void create()
{
  defvar("location", "/smile/", "Location", TYPE_LOCATION,"" );
}

mapping find_file( string f )
{
  if(f = Faces[ f ])
    return ([ 
      "data":f,
      "type":"image/gif"
    ]);
}

mapping query_container_callers()
{
  return ([ "parse-smileys":container_face_highlight ]);
}

array replace_from, replace_to;

static string fix_img_with_filename( string from, mapping m )
{
  mapping m = ([ "src":query_location()+"Face"+from,
		 "alt":html_encode_string(search(m,from)),
  ]);
  return make_tag( "img", m );
}

static void fix_face_mapping( mapping m )
{
  replace_from = indices(m);
  replace_to = Array.map(values(m), fix_img_with_filename, m);
}

void start()
{
  fix_face_mapping(
([
  ":-&lt;":"Angry",
  ":-]":"Goofy",
  ":-D":"Grinning",
  ":-}":"Happy",
  ":-)":"Happy",
  "8-)":"Happy",
  ":)":"Happy",
  "=)":"Happy",
  "=>":"Happy",
  "=&gt;":"Happy",
  ":-/":"Ironic",
  ":-\\":"Ironic",
  "8-|":"KOed",
  "|-O":"KOed",
  "8-%":"KOed",
  "|-%":"KOed",
  ":-#":"Nyah",
  "|-#":"Nyah",
  "=-#":"Nyah",
  ":-(":"Sad",
// "=(":"Sad",
  "8-(":"Sad",
  ":-{":"Sad",
  "={":"Sad",
  "8-{":"Sad",
  ":-0":"Startled",
  ":-o":"Startled",
  "8-o":"Startled",
  "8-O":"Startled",
  ":-|":"Straight",
  ":-p":"Talking",
  ":-d":"Tasty",
  ";-)":"Winking",
  ";->":"Winking",
  ";-&gt;":"Winking",
  ";-}":"Winking",
// ";)":"Winking",  To common in HTML code!
  ":-V":"Wry",
  ":-v":"Wry",
  ":-µ":"Wry",
  "]8-)":"Devilish",
  "]:-)":"Devilish",
  "];-)":"Devilish",
  "]B-)":"Devilish",
  "]B->":"Devilish",
  "]:->":"Devilish",
  "];->":"Devilish",
  "]B-&gt;":"Devilish",
  "]:-&gt;":"Devilish",
  "];-&gt;":"Devilish",
  ";-P":"Yukky",
  "|-P":"Yukky",
  ":-P":"Yukky",
]));
}

string container_face_highlight(string t, mapping args, 
				string contents, object id)
{
  if(id->supports->images)
  {
//     werror("%O\n", replace_from);
    return replace(contents, replace_from, replace_to );
//     for(int i=0;i<sizeof(replace_from); i++)
//       contents = replace(contents, replace_from[i], replace_to[i]);
//     return contents;
  }
}

#define MI(X) MIME.decode_base64("R0lGODlhDAAMAKEAAAAAA"+(X))

object Faces = class
{
#define I(X) MI("P//////AAAAACH5BAEAAAEALAAAAAAMAAwAAAI"+(X))
  constant FaceAngry=
  I("jjAMJdykvUoM0GhApXvj1HoEf5FSaqJBIRlqr6SJgyFwKUwAAOw==");

  constant FaceDevilish=
  I("jlBCgCNZnnEuxnkBFsMw95Vlc81TkZ07fMmUigoGRgtXJYhcAOw==");

  constant FaceGoofy=
  I("jjAMJdykvUoM0GvBwzAhqHYFVholZGCqKZXrXyF2ixCAKUwAAOw==");

  constant FaceGrinning=
  I("jjAMJdykvUoM0GvBwzAhqHYFV9ilOmFFft7ULi3KXKDGIwhQAOw==");

  constant FaceHappy=
  I("jjAMJdykvUoM0GvBwzAhqHYFVholZSCpfFzoWOy6XKDGIwhQAOw==");

  constant FaceIronic=
  I("jjAMJdykvUoM0GvBwzAhqHYFVJlKYQyrcOS7daF2ixCAKUwAAOw==");

  constant FaceKOed=
  I("jjAMJdykvUoM0GhAj3gji/DiZ84mV951hpyhWpy5XqjGzdBQAOw==");

  constant FaceSad=
  I("ijAMJdykvUoM0GvBwzAhqHYFVJo4OeVqYuF5l2LALgyhMAQA7");

  constant FaceStartled=
  I("jjAMJdykvUoM0GvBwzAhqHYFVBirlR32diC1d6FgX6zImUwAAOw==");

  constant FaceStraight=
  I("hjAMJdykvUoM0GvBwzAhqHYFVJo4OeVqld43cJUoMojAFADs=");

  constant FaceTalking=
  I("ijAMJdykvUoM0GvBwzAhqHYFVJo4OqXBiunTe16wto8xBAQA7");

  constant FaceWinking=
  I("jjAMJdykvUoM0GvAwXTpG91WV00EYqCgZkqkWK75IKTFzbRQAOw==");

  constant FaceWry=
  I("ijAMJdykvUoM0GvBwzAhqHYFVJo4OpXCfuHTe17Ato8xBAQA7");



#undef I
#define I(X) MI("FVVVf//////ACH5BAEAAAIALAAAAAAMAAwAAAI"+(X))
  constant FaceNyah=
  I("klAUJdzk/UoM0GlDhwpG7nlFfCD4KZ3HB6l3QqjUYEHTMpTAFADs=");

  constant FaceTasty=
  I("llAUJdzk/UoM0GvBwzAhqHYFVBgajMwRqtWAKunSjdYkSgyhMAQA7");

  constant FaceYukky=
  I("llAUJdzk/UoM0GhApXvj1HoGVJ45OqEDcE7TfBbVqswUhcylMAQA7");
}();


