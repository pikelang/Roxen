// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.
//
// Adds support for inline pike in documents.
//
// Example:
// <pike>
//  return "Hello world!\n";
// </pike>
 
constant cvs_version = "$Id$";
constant thread_safe=1;

inherit "module";
#include <module.h>

constant module_type = MODULE_TAG;
constant module_name = "Scripting: Pike tag";
constant module_doc =  #"
<p>This module adds a processing instruction tag, <code>&lt;?pike ...
?&gt;</code>, for evaluating Pike code directly in the document.</p>

<p><img src=\"internal-roxen-err_2\" align=\"left\" alt=\"Warning\">
NOTE: Enabling this module is the same thing as letting your users
run programs with the same right as the server!</p>

<p>Example:</p>

<pre>&lt;?pike write (\"Hello world!\\n\"); ?&gt;\n</pre>

<p>There are a few helper functions available:</p>

<dl>
  <dt><code>write(string fmt, mixed ... args)</code></dt>
    <dd>Formats a string in the same way as <code>printf</code> and
    appends it to the output buffer. If given only one string
    argument, it's written directly to the output buffer without being
    interpreted as a format specifier.</dd>

  <dt><code>flush()</code></dt>
    <dd>Returns the contents of the output buffer and resets it.</dd>

  <dt><code>rxml(string rxmlcode)</code></dt>
    <dd>Parses the string with the RXML parser.</dd>
</dl>

<p>When the pike tag returns, the contents of the output buffer is
inserted into the page. It is not reparsed with the RXML parser.</p>

<p>These special constructs are also recognized:</p>

<dl>
  <dt><code>//O ... </code> or <code>/*O ... */</code></dt>
    <dd>A Pike comment with an 'O' (the letter, not the number) as the
    very first character treats the rest of the text in the comment as
    output text that's written directly to the output buffer.</dd>

  <dt><code>//X ... </code> or <code>/*X ... */</code></dt>
    <dd>A Pike comment with an 'X' as the very first character treats
    the rest of the text in the comment as RXML code that's executed
    by the RXML parser and then written to the output buffer.</dd>

  <dt><code>#include \"...\"</code></dt>
    <dd>An <code>#include</code> preprocessor directive includes the
    specified file.</dd>

  <dt><code>#inherit \"...\"</code></dt>
    <dd>An <code>#inherit</code> preprocessor directive puts a
    corresponding inherit declaration in the class that's generated to
    contain the Pike code in the tag.</dd>
</dl>

<p>When files are included or inherited, they will be read from the
virtual filesystem in Roxen, relative to the location during whose
parsing the pike tag was encountered. Entities and scopes are
available as variables named like the entity/scope itself. The
RequestID object is available as <code>id</code>.</p>

<p>Note that every RXML fragment is parsed by itself, so you can't
have unmatched RXML tags in them. E.g. the following does not work:</p>

<p><pre>&lt;?pike
  //X &lt;gtext&gt;
  write (\"Foo\");
  //X &lt;/gtext&gt;
?&gt;\n</pre>

<p>Adjacent 'X' comments are concatenated however, so the following
works:</p>

<pre>&lt;?pike
  //X &lt;gtext&gt;
  //X Foo
  //X &lt;/gtext&gt;
?&gt;\n</pre>

<p>For compatibility this module also adds the Pike container tag,
<code>&lt;pike&gt;...&lt;/pike&gt;</code>. It behaves exactly as it
did in Roxen 2.0 and earlier and the functionality mentioned above
does not apply to it. The use of the container tag is deprecated.</p>";

void create()
{
  defvar("program_cache_limit", 256, "Program cache limit", TYPE_INT|VAR_MORE,
	 "Maximum size of the cache for compiled programs.");
}

// Helper functions, to be used in the pike script.
class Helpers
{
  string data = "";
  void output(mixed ... args) 
  {
    write( @args );
  }

  void write(mixed ... args) 
  {
    if(!sizeof(args)) 
      return;
    if(sizeof(args) > 1) 
      data += sprintf(@args);
    else 
      data += args[0];
  }

  string flush() 
  {
    string r = data;
    data ="";
    return r;
  }

  string rxml( string what )
  {
    return Roxen.parse_rxml( what, RXML.get_context()->id );
  }
  constant seteuid=0;
  constant setegid=0;
  constant setuid=0;
  constant setgid=0;
  constant call_out=0;
  constant all_constants=0;
  constant Privs=0;
}

class HProtos
{
  void output(mixed ... args);
  void write(mixed ... args);
  string flush();
  string rxml( string what, object id );

  constant seteuid=0;
  constant setegid=0;
  constant setuid=0;
  constant setgid=0;
  constant call_out=0;
  constant all_constants=0;
  constant Privs=0;
}

#define PREFN "pike-tag(preamble)"
#define POSTFN "pike-tag(postamble)"
#define PS(X) (compile_string( "mixed foo(){ return "+(X)+";}")()->foo())
#define SPLIT(X,FN) Parser.Pike.hide_whitespaces(Parser.Pike.tokenize(Parser.Pike.split(X),FN))
#define OCIP( )                                                 \
      if( cip )                                                 \
      {                                                         \
        cip->text=sprintf("write(rxml(%O));",cip->text);     \
        cip = 0;                                                \
      }

#define OCIPUP( )                                       \
      if( cipup )                                       \
      {                                                 \
        cipup->text=sprintf("write(%O);",cipup->text);  \
        cipup = 0;                                      \
      }

#define CIP(X) if( X )                                          \
        {                                                       \
          X->text += flat[i]->text[3..]+"\n";                   \
          flat[i]->text=flat[i]->trailing_whitespaces="";       \
        }                                                       \
        else                                                    \
        {                                                       \
          X = flat[i];                                          \
          flat[i]->text = flat[i]->text[3..]+"\n";              \
        }

#define R(X) Parser.Pike.reconstitute_with_line_numbers(X)

array helpers(function add_constant)
{
  add_constant( "__ps_magic_helpers", Helpers );
  add_constant( "__ps_magic_protos", HProtos );
  return SPLIT("inherit __ps_magic_helpers;\nimport Roxen;\n",PREFN);
}

array helper_prototypes( )
{
  return SPLIT("inherit __ps_magic_protos;\nimport Roxen;\n",PREFN);
}

private mapping(string:program) program_cache = ([]);

string simple_pi_tag_pike( string tag, mapping m, string s,RequestID id  )
{
  program p;
  object o;
  string res;
  mixed err;

  id->misc->__added_helpers_in_tree=0;
  id->misc->cacheable=0;

  object e = ErrorContainer();
  if(err=catch 
  {
    p = my_compile_string( s,id,1,"pike-tag("+id->not_query+")",e );
    if (sizeof(program_cache) > query("program_cache_limit")) 
    {
      array a = indices(program_cache);
      int i;

      // Zap somewhere between 25 & 50% of the cache.
      for(i = query("program_cache_limit")/2; i > 0; i--)
        m_delete(program_cache, a[random(sizeof(a))]);
    }
  })
  {
    master()->set_inhibit_compile_errors(0);
    if (e->get() && strlen(e->get()))
      RXML.parse_error ("Error while compiling Pike code:\n%s", e->get());
    else throw (err);
  }
  master()->set_inhibit_compile_errors(0);
  
  if(err = catch{
    (o=p())->parse(id);
  }) {
    catch {
      err = ({err[0], err[1][sizeof (backtrace())..]});
      err[1][0] = ({"top level", err[1][0][1]});
    };
    RXML.run_error ("Error in Pike code: %s", describe_backtrace (err));
  }

  res = (o && o->flush() || "");

  if(o) 
    destruct(o);

  return res;
}

string read_roxen_file( string what, object id )
{
  // let there be magic
  return id->conf->open_file(Roxen.fix_relative(what,id),"rR",id,1)
         ->read()[0]; 
}

program my_compile_string(string s, object id, int dom, string fn,
			  ErrorContainer e)
{
  if( program_cache[ s ] )
    return program_cache[ s ];

  object compile_handler = class( ErrorContainer e )
  {
    mapping constants = all_constants()+([]);
    void add_constant( string x, mixed v )
    {
      constants[x] = v;
    }
    mapping(string:mixed) get_default_module()
    {
      return constants;
    }
    mixed resolv(string id, void|string fn, void|string ch)
    {
      return constants[id] || master()->resolv( id, fn, ch );
    }
    void compile_error(string a, int b, string c)   {
      e->compile_error( a, b, c );
    }
    void compile_warning(string a, int b, string c) {
      e->compile_warning( a, b, c );
    }
  }(e);

  object key = Roxen.add_scope_constants( 0, compile_handler->add_constant );
  [array ip, array data] = parse_magic(s,id,dom,fn,e);

  int cnt;

  array pre;
  if( !id->misc->__added_helpers_in_tree && !sizeof(ip))
  {
    id->misc->__added_helpers_in_tree=1;
    pre = helpers(compile_handler->add_constant);
  } 
  else
  {
    helpers(compile_handler->add_constant);
    pre = helper_prototypes();
  }

  foreach( ip, program ipc )
  {
    compile_handler->add_constant( "____ih_"+cnt, ipc );
    pre += SPLIT("inherit ____ih_"+cnt++ + ";\n",PREFN);
  }

  if (dom)
    pre += SPLIT("void parse(RequestID id)\n{\n",PREFN) +
      data + SPLIT("}",POSTFN);
  else
    pre += data;
  program p = compile_string( R(pre), fn, compile_handler );
  if (query ("program_cache_limit") > 0)
    program_cache[ s ] = p;

  cnt=0;
  return p;
}

program handle_inherit( string what, RequestID id, ErrorContainer e )
{
  // ouch ouch ouch.
  return my_compile_string( read_roxen_file( what, id ),id,0,what,e);
}

array parse_magic( string data, RequestID id, int add_md, string filename,
		   ErrorContainer e )
{
  array flat=SPLIT(data,filename);
  object cip, cipup;
  array inherits = ({});
  for( int i = 0; i<sizeof( flat ); i++ )
  {
    switch( strlen(flat[i]->text) && flat[i]->text[0] )
    {
     case '.':
       OCIP(); OCIPUP();
       if( flat[i] == "." ) 
       {
         flat[i]->text = "[";
         flat[i+1]->text = "\"" + flat[++i]->text + "\"]";
       }
       break;

     case '/':
       if( strlen(flat[i]->text)>2 &&
	   (flat[i]->text[1]=='/' || flat[i]->text[1]=='*') )
       {
	 if( flat[i]->text[2] == 'X' )
	 {
	   if (flat[i]->text[1] == '*')
	     flat[i]->text = flat[i]->text[..sizeof (flat[i]->text) - 3];
	   OCIPUP();
	   CIP( cip );
	 }
	 else if( flat[i]->text[2] == 'O' )
	 {
	   if (flat[i]->text[1] == '*')
	     flat[i]->text = flat[i]->text[..sizeof (flat[i]->text) - 3];
	   OCIP();
	   CIP( cipup );
	 }
	 else 
	 {
	   OCIPUP();
	   OCIP();
	 }
       }
       else 
       {
	 OCIPUP();
	 OCIP();
       }
       break;

     case '#':  
       OCIP(); OCIPUP();
       if( sscanf( flat[i]->text, "#%*[ \t]inherit%[ \t]%s",
		   string ws, string fn) == 3 && sizeof (ws))
       {
	 flat[i]->text="";
         inherits += ({ handle_inherit( PS(fn), id, e ) });
       }
       else if( sscanf( flat[i]->text, "#%*[ \t]include%[ \t]%s",
			string ws, string fn) == 3 && sizeof (ws))
       {
         sscanf( fn, "%*s<%s>", fn );
         sscanf( fn, "%*s\"%s\"", fn );
         [array ih,flat[i]] = parse_magic(read_roxen_file(fn,id), id, 0, fn,e);
         inherits += ih;
       }
       break;
       
     default:
       OCIP();
       OCIPUP();
    }
  }
  OCIP();
  OCIPUP();
  return ({ inherits, flat });
}


// -------------------------------------------------------------------
// The old <pike> container, for compatibility.

// Helper functions, to be used in the pike script.
class CompatHelpers
{
  inherit "roxenlib";
  string data = "";
  void output(mixed ... args) 
  {
    if(!sizeof(args)) 
      return;
    if(sizeof(args) > 1) 
      data += sprintf(@args);
    else 
      data += args[0];
  }

  string flush() 
  {
    string r = data;
    data ="";
    return r;
  }

  constant seteuid=0;
  constant setegid=0;
  constant setuid=0;
  constant setgid=0;
  constant call_out=0;
  constant all_constants=0;
  constant Privs=0;
}

string functions(string page, int line)
{
  add_constant( "__magic_helpers", CompatHelpers );
  return 
    "inherit __magic_helpers;\n"
    "#"+line+" \""+replace(page,"\"","\\\"")+"\"\n";
}

// Preamble
string pre(string what, object id)
{
  if(search(what, "parse(") != -1)
    return functions(id->not_query, id->misc->line);
  if(search(what, "return") != -1)
    return functions(id->not_query, id->misc->line) + 
    "string|int parse(RequestID id, mapping defines, object file, mapping args) { ";
  else
    return functions(id->not_query, id->misc->line) +
    "string|int parse(RequestID id, mapping defines, object file, mapping args) { return ";
}

// Will be added at the end...
string post(string what) 
{
  if(search(what, "parse(") != -1)
    return "";
  if (!strlen(what) || what[-1] != ';')
    return ";}";
  else
    return "}";
}

// Compile and run the contents of the tag (in s) as a pike
// program. 
string container_pike(string tag, mapping m, string s, RequestID request_id,
                      object file, mapping defs)
{
  // COMPATIBILITY CODE, DO NOT CHANGE SEMANTICS

  program p;
  object o;
  string res;
  mixed err;

  request_id->misc->cacheable=0;

  object e = ErrorContainer();
  master()->set_inhibit_compile_errors(e);
  if(err=catch 
  {
    s = pre(s,request_id)+s+post(s);
    p = program_cache[s];

    if (!p) 
    {
      // Not in the program cache.
      p = compile_string(s, "Pike-tag("+request_id->not_query+":"+
                         request_id->misc->line+")");
      if (sizeof(program_cache) > query("program_cache_limit")) 
      {
	array a = indices(program_cache);
	int i;

	// Zap somewhere between 25 & 50% of the cache.
	for(i = query("program_cache_limit")/2; i > 0; i--)
	  m_delete(program_cache, a[random(sizeof(a))]);
      }
      if (query ("program_cache_limit") > 0)
	program_cache[s] = p;
    }
  })
  {
    master()->set_inhibit_compile_errors(0);
    if (e->get() && strlen(e->get()))
    {
      RXML.parse_error ("Error while compiling Pike code:\n%s",
			Roxen.html_encode_string( e->get()) );
    }
    else 
      throw (err);
  }
  master()->set_inhibit_compile_errors(0);
  
  if(err = catch{
    res = (o=p())->parse(request_id, defs, file, m);
  })
    RXML.run_error ("Error in Pike code: %s\n", describe_error (err));

  res = (res || "") + (o && o->flush() || "");

  if(o) 
    destruct(o);

  return res;
}

// --------------------- Documentation -----------------------

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"?pike":#"<desc type='pi'><p><short hide='hide'>
 Pike processing instruction tag.</short>This processing intruction
 tag allows for evaluating Pike code directly in the document.</p>

 <p>Note: With this tag, users are able to run programs with the same
 right as the server. This is a serious security hasard.</p>

 <p>When the pike tag returns, the contents of the output buffer is
 inserted into the page. It is not reparsed with the RXML parser.</p>

 <p>Use entities within the Pike code, scope.variable is handled like
 <ent>scope.variable</ent> in RXML.</p>

 <p>Note: It is still possible to use the
 <tag>pike</tag>...<tag>/pike</tag> container tag, though it behaves
 exactly as it did in Roxen 2.0 and earlier and the functionality
 mentioned below does not apply to it. The use of the container tag is
 deprecated.</p>

 <p>Below is a list of special helper functions and constructs which
 are only available within the <tag>?pike ?</tag> tag.</p>
</desc>

<attr name='write'><p>
 write(string fmt, mixed ... args) is a helper function. It formats a
 string in the same way as printf and appends it to the output buffer.
 If given only one string argument, it's written directly to the
 output buffer without being interpreted as a format specifier.</p>
</attr>

<attr name='flush'><p>
 flush() is a helper function. It returns the contents of the output
 buffer and resets it.</p>
</attr>

<attr name='rxml'><p>
 rxml(string rxmlcode) is a helper function. It parses the string with
 the RXML parser.</p>
</attr>


<attr name='\"//O ...\" or \"/*O ... */\"'><p>
 Pike comment with an 'O' (the letter, not the number) as the very
 first character treats the rest of the text in the comment as output
 text that's written directly to the output buffer.</p>
</attr>

<attr name='\"//X ...\" or \"/*X ... */\"'><p>
 A Pike comment with an 'X' as the very first character treats the
 rest of the text in the comment as RXML code that's executed by the
 RXML parser and then written to the output buffer.</p>
</attr>

<attr name='#include \"...\"'><p>
 An #include preprocessor directive includes the specified file.</p>
</attr>

<attr name='#inherit \"...\"'><p>
 An #inherit preprocessor directive puts a corresponding inherit
 declaration in the class that's generated to contain the Pike code in
 the tag, i.e. it inherits a specified file from the Roxen filesystem.</p>

 <ex-box><?pike
  //O <pre>
  int first = 1;
  for( var.counter=100; var.counter>1; var.counter--,first=0 )
  {
    if( !first )
    {
      //X &var.counter; bottles of beer on the wall
      //O
    }
    //X &var.counter; bottles of beer on the wall
    //X &var.counter; bottles of beer
    //O take one down, pass it around
  }
  //O one bottle of beer on the wall
  //O one bottle of beer
  //O take it down, pass it around
  //O no bottles of beer on the wall
  //O </pre>
?></ex-box>
</attr>",

    ]);
#endif
