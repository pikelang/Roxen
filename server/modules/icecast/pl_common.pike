#!NO MODULE
static array md_callbacks = ({});
static mapping md; // ID3 etc.

mapping metadata()
{
  return md;
}

string query_provides()
{
  return "icecast:playlist";
}

void add_md_callback( function f )
{
  md_callbacks += ({ f });
}

void remove_md_callback( function f )
{
  md_callbacks -= ({ f });
}

void call_md_callbacks( )
{
  foreach( md_callbacks, function f )
    if( catch( f( md ) ) )
      md_callbacks -= ({f});
}

void fix_metadata( string path,
		   Stdio.File fd )
{
  md = ([]);
  if( path ) md->path = path;
  // FIXME
  call_md_callbacks(  );
}
