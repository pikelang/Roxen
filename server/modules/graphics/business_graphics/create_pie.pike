#!/usr/local/bin/pike
#define max(i, j) (((i)>(j)) ? (i) : (j))
#define min(i, j) (((i)<(j)) ? (i) : (j))
#define abs(arg) ((arg)*(1-2*((arg)<0)))

#define PI 3.14159265358979
//inherit Stdio;

import Image;
import Array;
import Stdio;
inherit "polyline.pike";
constant LITET = 1.0e-40;
constant STORT = 1.0e40;

inherit "create_graph.pike";



mapping(string:mixed) create_pie(mapping(string:mixed) diagram_data)
{
  //Supportar bara xsize>=100
  int si=diagram_data["fontsize"];

  string where_is_ax;

  object(image) barsdiagram;

  if (diagram_data["bgcolor"])
    barsdiagram=image(diagram_data["xsize"],diagram_data["ysize"],
		@(diagram_data["bgcolor"]));
  else
    barsdiagram=diagram_data["image"];

  diagram_data["image"]=barsdiagram;
  set_legend_size(diagram_data);

  write("ysize:"+diagram_data["ysize"]+"\n");
  diagram_data["ysize"]-=diagram_data["legend_size"];
  write("ysize:"+diagram_data["ysize"]+"\n");
  
  //Bestäm största och minsta datavärden.
  init(diagram_data);

  //Initiera värden
  int|void  size=diagram_data["xsize"];
  array(int|float) numbers=diagram_data["data"][0];
  void | array(string) names=diagram_data["xnames"];
  void|int twoD=
   void|array(array(int)) colors,
   array(int)bg, 
   array(int)fg,
   int tone









  diagram_data["ysize"]-=diagram_data["legend_size"];
  diagram_data["image"]=barsdiagram;
  return diagram_data;



}

int main(int argc, string *argv)
{
  write("\nRitar axlarna. Filen sparad som test.ppm\n");

  mapping(string:mixed) diagram_data;
  diagram_data=(["type":"bars",
		 "textcolor":({0,0,0}),
		 "subtype":"box",
		 "orient":"vert",
		 "data": 
		 ({ ({91.2, 102.3, -94.01, 100.0, 94.3, 102.0 })/*,
		     ({91.2, 101.3, 91.5, 101.7,  -91.0, 101.5}),
		    ({91.2, 103.3, -91.5, 100.1, 94.3, 95.2 }),
		    ({93.2, -103.3, 93.5, 103.7, 94.3, -91.2 }) */}),
		 "fontsize":32,
		 "axcolor":({0,0,0}),
		 "bgcolor":({255,255,255}),
		 "labelcolor":({0,0,0}),
		 "datacolors":({({0,255,0}),({255,255,0}), ({0,255,255}), ({255,0,255}) }),
		 "linewidth":2.2,
		 "xsize":400,
		 "ysize":200,
		 "xnames":({"jan", "feb", "mar", "apr", "maj", "jun"}),
		 "fontsize":16,
		 "labels":({"xstor", "ystor", "xenhet", "yenhet"}),
		 "legendfontsize":12,
		 "legend_texts":({"streck 1", "streck 2", "foo", "bar gazonk foobar illalutta!" }),
		 "labelsize":12,
		 "xminvalue":0.1,
		 "yminvalue":0

  ]);
  /*
  diagram_data["data"]=({({ 
     101.858620,
    146.666672,
    101.825584,
    146.399109,
    101.728462,
    146.147629,
    101.573090,
    145.927322,
    101.368790,
    145.751419,
    95.240158,
    141.665649,
    109.106468,
    137.043549,
    109.606232,
    136.701111,
    109.848892,
    136.145996,
    109.760834,
    135.546616,
    109.368790,
    135.084732,
    101.858620,
    130.077972,
    101.858719,
    2.200001,
    101.792381,
    1.823779,
    101.601372,
    1.492934,
    101.308723,
    1.247373,
    100.949730,
    1.116712,
    100.567711,
    1.116711,
    100.208717,
    1.247372,
    99.916069,
    1.492933,
    99.725060,
    1.823777,
    99.658722,
    2.199999,
    99.658623,
    130.666672,
    99.691658,
    130.934219,
    99.788780,
    131.185715,
    99.944160,
    131.406036,
    100.148453,
    131.581924,
    106.277084,
    135.667679,
    92.410774,
    140.289780,
    91.911018,
    140.632217,
    91.668350,
    141.187317,
    91.756401,
    141.786713,
    92.148453,
    142.248581,
    99.658623,
    147.255371,
    99.658623,
    397.799988,
    99.724960,
    398.176208,
    99.915970,
    398.507050,
    100.208618,
    398.752625,
    100.567612,
    398.883270,
    100.949631,
    398.883270,
    101.308624,
    398.752625,
    101.601273,
    398.507050,
    101.792282,
    398.176208,
    101.858620,
    397.799988

})});
  */

  object o=Stdio.File();
  o->open("test.ppm", "wtc");
  o->write(create_bars(diagram_data)["image"]->toppm());
  o->close();

};
