/*
 * Map of the Earth.
 */

#define ERR(msg) throw(({ msg+"\n", backtrace() }))

mapping(string:string) aliases =
  ([ "usa":"United States of America",
     "us":"United States of America",
     "russia":"Russian Federation",
     "united kingdom":"England",
     "uk":"England",
     "vietnam":"Viet Nam"
  ]);

mapping(string:string) domain_to_country =
  ([ /* 132 elements */
    "af":"afghanistan",
    "al":"albania",
    "dz":"algeria",
    "ao":"angola",
    "ar":"argentina",
    "am":"armenia",
    "aw":"aruba",
    "au":"australia",
    "at":"austria",
    "az":"azerbaijan",
    "bs":"bahamas",
    "bd":"bangladesh",
    "be":"belgium",
    "bj":"benin",
    "bm":"bermuda",
    "bt":"bhutan",
    "bo":"bolivia",
    "ba":"bosnia and herzegovina",
    "burma":"burma",
    "bw":"botswana",
    "br":"brazil",
    "bg":"bulgaria",
    "bf":"burkina faso",
    "bi":"burundi",
    "cm":"cameroon",
    "ca":"canada",
    "cf":"central african republic",
    "td":"chad",
    "cl":"chile",
    "cn":"china",
    "hk":"china",
    "co":"colombia",
    "cg":"congo",
    "cr":"costa rica",
    "ci":"côte d'ivoire",
    "hr":"croatia",
    "cu":"cuba",
    "cy":"cyprus",
    "cz":"czechoslovakia",
    "dk":"denmark",
    "djibouti":"djibouti",
    "do":"dominican republic",
    "eg":"egypt",
    "sv":"el salvador",
    "vg":"england",
    "gb":"england",
    "uk":"england",
    "gq":"equatorial guinea",
    "ee":"estonia",
    "et":"ethiopia",
    "fi":"finland",
    "fr":"france",
    "fx":"france",
    "nc":"france",
    "gf":"french guiana",
    "ga":"gabon",
    "gm":"gambia",
    "ge":"georgia",
    "de":"germany",
    "gh":"ghana",
    "gr":"greece",
    "gl":"greenland",
    "gt":"guatemala",
    "gn":"guinea",
    "gw":"guinea-bissau",
    "gy":"guyana",
    "hu":"hungary",
    "is":"iceland",
    "in":"india",
    "ir":"iran",
    "iq":"iraq",
    "ie":"ireland",
    "il":"israel",
    "va":"italy",
    "it":"italy",
    "jm":"jamaica",
    "jp":"japan",
    "jo":"jordan",
    "kh":"cambodia",
    "ec":"ecuador",
    "ht":"haiti",
    "kh":"kampuchea",
    "kg":"kyrgyzstan",
    "hn":"honduras",
    "by":"belarus",
    "kz":"kazakhstan",
    "ke":"kenya",
    "kw":"kuwait",
    "la":"laos",
    "lv":"latvia",
    "lb":"lebanon",
    "ls":"lesotho",
    "lr":"liberia",
    "ly":"libya",
    "lt":"lithuania",
    "mg":"madagascar",
    "my":"malaysia",
    "ml":"mali",
    "mr":"mauritania",
    "mx":"mexico",
    "md":"moldavia",
    "mn":"mongolia",
    "ma":"morocco",
    "mz":"mozambique",
    "na":"namibia",
    "np":"nepal",
    "nl":"netherlands",
    "nz":"new zealand",
    "ni":"nicaragua",
    "ne":"niger",
    "ng":"nigeria",
    "kp":"north korea",
    "no":"norway",
    "om":"oman",
    "pk":"pakistan",
    "pa":"panama",
    "pg":"papua new guinea",
    "py":"paraguay",
    "pe":"peru",
    "ph":"philippines",
    "pl":"poland",
    "pt":"portugal",
    "qa":"qatar",
    "ro":"romania",
    "rw":"rwanda",
    "sa":"saudi arabia",
    "sn":"senegal",
    "sl":"sierra leone",
    "so":"somalia",
    "za":"south africa",
    "kr":"south korea",
    "es":"spain",
    "lk":"sri lanka",
    "sd":"sudan",
    "sr":"suriname",
    "sz":"swaziland",
    "se":"sweden",
    "ch":"switzerland",
    "sy":"syria",
    "tw":"taiwan",
    "tj":"tajikistan",
    "tz":"tanzania",
    "th":"thailand",
    "tg":"togo",
    "tt":"trinidad and tobago",
    "tn":"tunisia",
    "tr":"turkey",
    "tm":"turkmenistan",
    "ug":"uganda",
    "ua":"ukraine",
    "ae":"united arab emirates",
    "uy":"uruguay",
    "vi":"united states of america",
    "us":"united states of america",
    "gu":"united states of america",
    "com":"united states of america",
    "net":"united states of america",
    "org":"united states of america",
    "edu":"united states of america",
    "gov":"united states of america",
    "mil":"united states of america",
    "nato":"united states of america",
    "su":"russian federation",
    "ru":"russian federation",
    "uz":"uzbekistan",
    "ve":"venezuela",
    "vn":"viet nam",
    "eh":"western sahara",
    "ye":"yemen",
    "yu":"yugoslavia",
    "zr":"zaire",
    "zm":"zambia",
    "zw":"zimbabwe",
  ]);

class Legend {
  static private string state_color_scheme = "white-to-red";
  
  static private mapping color_schemes = ([ "white-to-red":
					    ([ 0:({ 0xff,0xff,0xff }),
					       1:({ 0xe0,0xc0,0x80 }),
					       2:({ 0xe0,0x80,0x40 }),
					       3:({ 0xd0,0x40,0x00 }),
					       4:({ 0x80,0x00,0x00 }) ]),
					    "white-to-green":
					    ([ 0:({ 0xff,0xff,0xff }),
					       1:({ 0xe0,0xe0,0x80 }),
					       2:({ 0x80,0xe0,0x40 }),
					       3:({ 0x40,0xd0,0x00 }),
					       4:({ 0x00,0x80,0x00 }) ]),
					    "white-to-purpur":
					    ([ 0:({ 0xff,0xff,0xff }),
					       1:({ 0xe0,0xc0,0xe0 }),
					       2:({ 0xe0,0x80,0xe0 }),
					       3:({ 0xd0,0x40,0xd0 }),
					       4:({ 0x80,0x00,0x80 }) ]) ]);

  object scheme(string color_scheme)
  {
    state_color_scheme = color_scheme;
    return this_object();
  }
  
  array(string) schemes()
  {
    return sort(indices(color_schemes));
  }
  
  array(int) color_blend(float x, array(int) c1, array(int) c2)
  {
    array(int) c = allocate(3);
    for(int i = 0; i < 3; i++)
      c[i] = (int) ((1.0-x)*c1[i] + x*c2[i]);
    return c;
  }

  array(int) color_scale(float x, string|void color_scheme)
  {
    if(x < 0.0 | x > 1.0)
      ERR(sprintf("Value of the scale (%f).", x));
    color_scheme = color_scheme || state_color_scheme;
    if(x == 0 || x == 0.0)
      return color_schemes[color_scheme][0];
    float adj = (float)sizeof(color_schemes[color_scheme])-2.01;
    int i = (int)(x*adj);
    return color_blend(x*adj-(float)i,
		       color_schemes[color_scheme][i+1],
		       color_schemes[color_scheme][i+2]);
  }

  string float_to_eng(float x)
  {
    array(string) suffix = ({ "a", "f", "p", "n", "u", "m", "",
			      "k", "M", "G", "T", "P", "E" });
    
    float y = floor(log(x)/log(1000.0));
    if((0.1 <= x && x <= 1.0) || y < -6.0 || 6.0 < y)
      y = 0.0;
    return sprintf("%g%s", x/exp(y*log(1000.0)), suffix[(int)y+6])-" ";
  }
  
  object image(int fixed_width, int fixed_height, mapping|void opt)
  {
    opt = opt || ([]);

    for(int i = 0; i < sizeof(opt->titles||({})); i++)
      if(floatp(opt->titles[i]) || intp(opt->titles[i]))
	opt->titles[i] = float_to_eng((float)opt->titles[i]);
    
    opt->color_scheme = opt->color_scheme || state_color_scheme;
    opt->border = opt->border || 20;
    opt->title = opt->title || "";
    opt->title_color = opt->title_color || ({ 0xff,0xff,0xff });
    opt->background_color = opt->background_color || ({ 0x10,0x10,0x40 });
    opt->titles = ({ "1" })+ (opt->titles || ({ "" }));
  
    object font = opt->font; // Image.font("default");
    int nom = font->height();
    int title_h = nom*sizeof(opt->title/"\n")+nom/2;
    int bar_h = 6*nom;
    int width = max(font->text_extents(@opt->title/"\n")[0],
		    font->text_extents(@opt->titles)[0] + nom+nom/2);
    int height = title_h + bar_h + 2*nom + nom;
    
    object img = Image.image(width, height+100, @opt->background_color);

    img->paste_alpha_color(font->write(@(opt->title/"\n")),
			   @opt->title_color, 0, 0);

    for(int i = 0; i < bar_h; i++)
      img->line(0, title_h+i, nom, title_h+i,
		@color_scale(1.0 - i/(float)(bar_h), opt->color_scheme));
    img->box(0, title_h+bar_h+nom/2, nom, title_h+bar_h+nom/2+(int)(nom*0.8),
	     @color_scale(0, opt->color_scheme));
    img->paste_alpha_color(font->write("0")->scale(0.8),
			   @opt->title_color, nom+nom/2, title_h+bar_h+nom/2);

    for(int i = 0; i < sizeof(opt->titles); i++) {
      int y = title_h + ((bar_h-1)*i)/((sizeof(opt->titles)-1)||1);
      img->paste_alpha_color(font->write(reverse(opt->titles)[i])->scale(0.8),
			     @opt->title_color,
			     nom+nom/2, y-(int) (0.8*nom/2));
    }

    img = img->autocrop()->setcolor(@opt->background_color);
    img = img->copy(-opt->border, -opt->border,
		    img->xsize()+opt->border-1, img->ysize()+opt->border-1);
    return img->scale(min(min(fixed_width/(float)img->xsize(), 1.0),
			  min(fixed_height/(float)img->ysize(), 1.0)));
  }
}

static private mapping map_of_the_earth =
            decode_value(Stdio.read_bytes(combine_path(__FILE__,"../")+"map"));

class Earth {
  static private string state_region, state_country;
    
  // Aliases.
  mapping(string:array(string)) country_name_aliases =
  ([ "United States of America":({ "USA", "US" }),
     "Russian Federation":({ "Russia" }),
     "England":({ "United Kingdom", "UK" }),
     "Viet Nam":({ "Vietnam" }),
  ]);

  // Official names.
  mapping(string:string) official_country_names =
  ([ "Iran":"Iran (Islamic Republic of)",
     "England":"United Kingdom of Great Britain and Northern Ireland",
     "Tanzania":"United Republic of Tanzania",
     "Libya":"Libyan Arab Jamahiriya",
     "North Korea":"Democratic People's Republic of Korea",
     "Syria":"Syrian Arab Republic",
     "Laos":"Lao People's Democratic Republic",
     "South Korea":"Republic of Korea" ]);
  
  object region(string new_region)
  {
    mapping opt = ([ "region":new_region, "country":state_country ]);
    return object_program(this_object())(opt);
  }
  
  array(string) regions()
  {
    return sort(({ "World", "Europe", "Asia", "Africa", "Arab States",
		   "North America", "South America", "Oceania" }));
  }

  object country(string new_country)
  {
    mapping opt = ([ "region":state_region, "country":new_country ]);
    return object_program(this_object())(opt);
  }

  static private string capitalize_country(string s)
  {
    return Array.map(s/" ",
		     lambda(string w)
		     {
		       switch(w) {
		       case "of":
		       case "and":
			 return w;
		       default:
			 return capitalize(w);
		       }
		     })*" ";
  }
  
  array(string) countries()
  {
    return sort(Array.map(indices(map_of_the_earth), capitalize_country));
  }

  mixed polygons()
  {
    if(state_country)
      return map_of_the_earth[state_country];
  }

  static private array(float) transform(float x, float y, mapping opt)
  {
    y = 1.0-y;

    switch(lower_case(opt->region||state_region||"")) {
    case "europe":
      x = (x-0.33)*3.0;
      y = (y-0.05)*3.0;
      break;
    case "africa":
      x = (x-0.20)*1.5;
      y = (y-0.25)*1.5;
      break;
    case "arab states":
      x = (x-0.46)*3.0;
      y = (y-0.20)*3.0;
      break;
    case "north america":
      x = (x-0.00)*2.0;
      y = (y-0.05)*2.0;
      break;
    case "south america":
      x = (x-0.00)*1.5;
      y = (y-0.40)*1.5;
      break;
    case "south east asia":
      x = (x-0.57)*2.0;
      y = (y-0.17)*2.0;
      break;
    case "oceania":
      x = (x-0.63)*2.0;
      y = (y-0.47)*2.0;
      break;
    default:
    }
    
    return ({ x, y });
  }
  
  object image(int width, int height, mapping|void opt)
  {
    opt = opt || ([]);
    opt->color_sea = opt->color_sea || ({ 0x10,0x10,0x40 });
    opt->color_fu = opt->color_fu || lambda() { return ({ 0xff,0xff,0xff }); };

    object map = Image.image(width, height, @opt->color_sea);
    foreach(indices(map_of_the_earth), string cntry) {
      map->setcolor(@opt->color_fu(cntry, @(opt->fu_args||({}))));
      foreach(map_of_the_earth[cntry], array(float) original_vertices) {
	array(float) vertices = copy_value(original_vertices);
	
	for(int v = 0; v < sizeof(vertices); v += 2) {
	  array(float) a = transform(vertices[v+0], vertices[v+1], opt);
	  vertices[v+0] = a[0]*width;
	  vertices[v+1] = a[1]*height;
	}
	
	map->polyfill(vertices);
      }
    }
    
    // Apply borders.
    if(opt->border)
      map = Image.image(map->xsize()+2*opt->border,
			map->ysize()+2*opt->border,
			@opt->color_sea)->paste(map, opt->border, opt->border);
    
    return map;
  }
  
  void create(mapping|void opt)
  {
    opt = opt||([]);
    
    state_region = opt->region;
    state_country = opt->country;
  }
}
