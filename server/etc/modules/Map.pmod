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
  ([
    "ac":"ascension island",
    "ad":"andorra",
    "ae":"united arab emirates",
    "af":"afghanistan",
    "ag":"antigua and barbuda",
    "ai":"anguilla",
    "al":"albania",
    "am":"armenia",
    "an":"netherlands antilles",
    "ao":"angola",
    "aq":"antarctica",
    "ar":"argentina",
    "as":"american samoa",
    "at":"austria",
    "au":"australia",
    "aw":"aruba",
    "ax":"åland islands",
    "az":"azerbaijan",
    "ba":"bosnia and herzegovina",
    "bb":"barbados",
    "bd":"bangladesh",
    "be":"belgium",
    "bf":"burkina faso",
    "bg":"bulgaria",
    "bh":"bahrain",
    "bi":"burundi",
    "bj":"benin",
    "bm":"bermuda",
    "bn":"brunei darussalam",
    "bo":"bolivia",
    "br":"brazil",
    "bs":"bahamas",
    "bt":"bhutan",
    "bu":"burma",
    "bv":"bouvet island",
    "bw":"botswana",
    "by":"belarus",
    "bz":"belize",
    "ca":"canada",
    "cc":"cocos (keeling) islands",
    "cd":"congo, the democratic republic of the",
    "cf":"central african republic",
    "cg":"congo",
    "ch":"switzerland",
    "ci":"côte d'ivoire",
    "ck":"cook islands",
    "cl":"chile",
    "cm":"cameroon",
    "cn":"china",
    "co":"colombia",
    "cr":"costa rica",
    "cs":"serbia and montenegro",
    "cu":"cuba",
    "cv":"cape verde",
    "cx":"christmas island",
    "cy":"cyprus",
    "cz":"czech republic",
    "de":"germany",
    "dj":"djibouti",
    "dk":"denmark",
    "dm":"dominica",
    "do":"dominican republic",
    "dz":"algeria",
    "ec":"ecuador",
    "ee":"estonia",
    "eg":"egypt",
    "eh":"western sahara",
    "er":"eritrea",
    "es":"spain",
    "et":"ethiopia",
    "fi":"finland",
    "fj":"fiji",
    "fk":"falkland islands (malvinas)",
    "fm":"micronesia, federal state of",
    "fo":"faroe islands",
    "fr":"france",
    "fx":"france",
    "ga":"gabon",
    "gb":"england",
    "gd":"grenada",
    "ge":"georgia",
    "gf":"french guiana",
    "gg":"guernsey",
    "gh":"ghana",
    "gi":"gibraltar",
    "gl":"greenland",
    "gm":"gambia",
    "gn":"guinea",
    "gp":"guadeloupe",
    "gq":"equatorial guinea",
    "gr":"greece",
    "gs":"south georgia and the south sandwich islands",
    "gt":"guatemala",
    "gu":"guam",
    "gw":"guinea-bissau",
    "gy":"guyana",
    "hk":"hong kong",
    "hm":"heard and mcdonald islands",
    "hn":"honduras",
    "hr":"croatia",
    "ht":"haiti",
    "hu":"hungary",
    "id":"indonesia",
    "ie":"ireland",
    "il":"israel",
    "im":"isle of man",
    "in":"india",
    "io":"british indian ocean territory",
    "iq":"iraq",
    "ir":"iran",
    "is":"iceland",
    "it":"italy",
    "je":"jersey",
    "jm":"jamaica",
    "jo":"jordan",
    "jp":"japan",
    "ke":"kenya",
    "kg":"kyrgyzstan",
    "kh":"cambodia",
    "ki":"kiribati",
    "km":"comoros",
    "kn":"saint kitts and nevis",
    "kp":"north korea",
    "kr":"south korea",
    "kw":"kuwait",
    "ky":"cayman islands",
    "kz":"kazakhstan",
    "la":"laos",
    "lb":"lebanon",
    "lc":"saint lucia",
    "li":"liechtenstein",
    "lk":"sri lanka",
    "lr":"liberia",
    "ls":"lesotho",
    "lt":"lithuania",
    "lu":"luxembourg",
    "lv":"latvia",
    "ly":"libya",
    "ma":"morocco",
    "mc":"monaco",
    "md":"moldova",
    "mg":"madagascar",
    "mh":"marshall islands",
    "mk":"macedonia, the former yugoslav republic of",
    "ml":"mali",
    "mm":"myanmar",
    "mn":"mongolia",
    "mo":"macao",
    "mp":"northern mariana islands",
    "mq":"martinique",
    "mr":"mauritania",
    "ms":"montserrat",
    "mt":"malta",
    "mu":"mauritius",
    "mv":"maldives",
    "mw":"malawi",
    "mx":"mexico",
    "my":"malaysia",
    "mz":"mozambique",
    "na":"namibia",
    "nc":"new caledonia",
    "ne":"niger",
    "nf":"norfolk island",
    "ng":"nigeria",
    "ni":"nicaragua",
    "nl":"netherlands",
    "no":"norway",
    "np":"nepal",
    "nr":"nauru",
    "nu":"niue",
    "nz":"new zealand",
    "om":"oman",
    "pa":"panama",
    "pe":"peru",
    "pf":"french polynesia",
    "pg":"papua new guinea",
    "ph":"philippines",
    "pk":"pakistan",
    "pl":"poland",
    "pm":"saint pierre and miquelon",
    "pn":"pitcairn island",
    "pr":"puerto rico",
    "ps":"palestinian territory, occupied",
    "pt":"portugal",
    "pw":"palau",
    "py":"paraguay",
    "qa":"qatar",
    "re":"reunion island",
    "ro":"romania",
    "ru":"russian federation",
    "rw":"rwanda",
    "sa":"saudi arabia",
    "sb":"solomon islands",
    "sc":"seychelles",
    "sd":"sudan",
    "se":"sweden",
    "sg":"singapore",
    "sh":"saint helena",
    "si":"slovenia",
    "sj":"svalbard and jan mayen islands",
    "sk":"slovakia",
    "sl":"sierra leone",
    "sm":"san marino",
    "sn":"senegal",
    "so":"somalia",
    "sr":"suriname",
    "st":"sao tome and principe",
    "su":"russian federation",
    "sv":"el salvador",
    "sy":"syria",
    "sz":"swaziland",
    "tc":"turks and caicos islands",
    "td":"chad",
    "tf":"french southern territories",
    "tg":"togo",
    "th":"thailand",
    "tj":"tajikistan",
    "tk":"tokelau",
    "tl":"timor-leste",
    "tm":"turkmenistan",
    "tn":"tunisia",
    "to":"tonga",
    "tp":"east timor",
    "tr":"turkey",
    "tt":"trinidad and tobago",
    "tv":"tuvalu",
    "tw":"taiwan",
    "tz":"tanzania",
    "ua":"ukraine",
    "ug":"uganda",
    "uk":"england",
    "um":"united states minor outlying islands",
    "us":"united states of america",
    "uy":"uruguay",
    "uz":"uzbekistan",
    "va":"italy",
    "vc":"saint vincent and the grenadines",
    "ve":"venezuela",
    "vg":"virgin islands, british",
    "vi":"virgin islands, u.s.",
    "vn":"viet nam",
    "vu":"vanuatu",
    "wf":"wallis and futuna islands",
    "ws":"western samoa",
    "ye":"yemen",
    "yt":"mayotte",
    "yu":"yugoslavia",
    "za":"south africa",
    "zm":"zambia",
    "zr":"zaire",
    "zw":"zimbabwe",

    "com":"united states of america",
    "net":"united states of america",
    "org":"united states of america",
    "edu":"united states of america",
    "gov":"united states of america",
    "mil":"united states of america",
    "nato":"united states of america",
  ]);

class Legend {
  private string state_color_scheme = "white-to-red";
  
  private mapping color_schemes = ([ "white-to-red":
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
    
    Image.Image img = Image.Image(width, height+100, @opt->background_color);

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

private mapping map_of_the_earth =
            decode_value(Stdio.read_bytes("etc/maps/worldmap"));

class Earth {
  protected string state_region;
  protected string state_country;
    
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
    return object_program(this_object())(new_region, state_country);
  }
  
  array(string) regions()
  {
    return sort(({ "World", "Europe", "Asia", "Africa", "Arab States",
		   "North America", "South America", "Oceania" }));
  }

  object country(string new_country)
  {
    return object_program(this_object())(state_region, new_country);
  }

  private string capitalize_country(string s)
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

  private array(float) transform(float x, float y, mapping opt)
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
    case "asia":
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
  
  Image.Image image(int width, int height, mapping|void opt)
  {
    opt = opt || ([]);
    opt->color_sea = opt->color_sea || ({ 0x10,0x10,0x40 });
    opt->color_fu = opt->color_fu || lambda() { return ({ 0xff,0xff,0xff }); };

    Image.Image map = Image.Image(width, height, @opt->color_sea);
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

    // Add markers
    if(opt->markers)
      foreach(opt->markers, mapping marker) {
	int x1 = marker->x - marker->size/2;
	int x2 = marker->x + marker->size/2;
	int y1 = marker->y - marker->size/2;
	int y2 = marker->y + marker->size/2;
	switch(marker->style) {
	case "box":
	  map->box(x1, y1, x2, y2,
		   @marker->color);
	case "diamond":
	default:
	  map->setcolor(@marker->color);
	  map->polyfill( ({ x1, marker->y,
			    marker->x, y1,
			    x2, marker->y,
			    marker->x, y2 }) );
	}
      }
    
    // Apply borders.
    if(opt->border)
      map = Image.Image(map->xsize()+2*opt->border,
			map->ysize()+2*opt->border,
			@opt->color_sea)->paste(map, opt->border, opt->border);
    
    return map;
  }
  
  void create(void|string _state_region, void|string _state_country)
  {
    state_region = _state_region;
    state_country = _state_country;
  }
}
