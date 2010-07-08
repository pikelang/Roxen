#ifndef __NT__

int is_font( string f )
{
#if constant( Image.FreeType.Face )
  return !catch(Image.FreeType.Face( f ));
#elif constant( Image.TTF.`() )
  return !catch(Image.TTF( f )());
#endif
}

array font_dirs = ({});

void check_fpath( string d )
{
  catch {
    if( d[-1] != '/' ) d += "/";
    array dl = get_dir( d );
    // the user have to add huge dirs on her own..
    foreach( dl, string f )
      if( is_font( d+f ) )
      {
        if( sizeof( dl ) > 112 )
        {
          write( "     Skipping "+d+". Add it manually if you want it.\n");
          write( "     Please note that huge font-dirs can add to roxens "
		 "boot-time.\n");
          return;
        }
	write("      Usable font found in '"+d+"'.\n");
        font_dirs += ({ d });
        return;
      }
  };
}

void run(object env)
{
  if( getenv( "DISPLAY" ) && ((getenv("DISPLAY")/":")[0]=="" ))
  {
    write("   Searching for fonts...\n");
    string data = Process.popen( "xset q 2>/dev/null" );
    sscanf( data, "%*sFont%*s\n%*[ \t]%s\n", data );

    // avoid most of the open-windows locale specific fonts, and the
    // XFree bitmap ones (we will not be able to load them anyway)
    foreach( data / "," - ({""}), string path )
      if( search( path, ":unscaled" ) == -1 
          && (search( path, "locale/" ) == -1 ||
              search( path, "UTF-8" ) != -1 ) )
        check_fpath( path ); 
    env->set_separator("RX_FONTPATH", ",");
    env->append( "RX_FONTPATH", (font_dirs*",") );
  }
}
#endif


void main()
{
  run(0);
}
