array images;

void init_images()
{
  string dir = combine_path( __FILE__, "../left-images" );
  images = ({});
  foreach( glob("*.jpg",get_dir( dir )), string img )
    images += ({ Stdio.read_file( dir+"/"+img ) });
  images -= ({0});
}

mapping parse( RequestID id )
{
  if(!images)
    init_images();

  id->misc->cacheable = 0;
  
  mapping rv= Roxen.http_string_answer(
    Image.PNG.encode( Image._decode( images[random(sizeof(images))] )
		      ->img->scale( 162,112 ) ),
		      "image/png" );
  id->set_response_header ("Expires", Roxen.http_date( time(1) ));
  return rv;
}
