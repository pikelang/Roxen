array images;

void init_images()
{
  string dir = combine_path( __FILE__, "../left-images" );
  images = ({});
  foreach( glob("*.jpg",get_dir( dir )), string img )
    images += ({ Image._decode(Stdio.read_file( dir+"/"+img ))
		 ->img->scale( 160, 0) });
  images -= ({0});
}

mapping parse( RequestID id )
{
  if(!images)
    init_images();

  id->misc->cacheable = 0;
  
  mapping rv= Roxen.http_string_answer(
    Image.JPEG.encode( images[random(sizeof(images))] ),
    "image/jpeg" );
  id->set_response_header ("Expires", Roxen.http_date( time(1) ));

  return rv;
}
