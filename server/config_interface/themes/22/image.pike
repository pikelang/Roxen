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
  

  mapping rv= Roxen.http_string_answer( images[random(sizeof(images))],
					"image/jpeg" );
  rv["extra_heads"] = ([]);
  rv["extra_heads"]->Expires = Roxen.http_date( time(1) );
  return rv;
}
