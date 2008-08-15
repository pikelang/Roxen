inherit .Upload;

// Locale macros
//<locale-token project="roxen_config"> LOCALE </locale-token>

#define LOCALE(X,Y)    \
  ([string](mixed)Locale.translate("roxen_config",roxenp()->locale->get(),X,Y))

constant type="Image";

array(Image.Layer) get_layers() 
//! Returns the image as an array of layers
{
  string data = query();
  if(!data || !sizeof(data)) return 0;
  catch{
    return Image.decode_layers( data );
  };
}

Image.Image get_image()
//! Returns the image as a image object.
{
  return Image.lay( Image.decode_layers( query() ) )->image();
}

mapping get_imagealpha()
//! Returns a mapping ([ "image":img object, "alpha":alpha channel ])
{
  return Image._decode( query() );
}

protected int _ivi;
int is_valid_image()
{
  if( _ivi )  return _ivi > 0 ? 1 : 0;
  if( get_layers() )  _ivi = 1;   else   _ivi = -1;
  return _ivi > 0 ? 1 : 0;
}

array(string) verify_set( string newval )
{
  _ivi = 0;
  return ::verify_set( newval );
}

array(string) verify_set_from_form( string newval )
{
  string warning;
  if( catch{
    if( !Image._decode( newval ) )
      warning = LOCALE(345,"Cannot decode this file as an image")+"\n";
  } )
    warning = LOCALE(346,"Error while decoding image")+"\n";
  return ({ warning, newval });
}

string render_view( RequestID id, int|void thumb )
{
  if( is_valid_image() )
  {
    if( id->conf->modules->cimg )
    {
      RXML.get_context()->set_var( "___imagedata", query(), "var" );
      if( thumb )
        return Roxen.parse_rxml("<cimg max-width='90' max-height='90' "
                                "data='&var.___imagedata:none;' "
                                "format='gif' quant='255' dither='fs'/>",id );
      else
        return Roxen.parse_rxml("<cimg data='&var.___imagedata:none;' "
                                "format='png'/>",id );
    }
    else 
    {
      return LOCALE(347,"Valid image set (no cimg module available, "
		    "cannot show it)")+"\n";
    }
  } else {
    return LOCALE(348,"No image set");
  }
}

string render_form( RequestID id )
{
  return render_view( id, 1  ) + " " + ::render_form( id );
}
