// This is a roxen module which provides file upload and write capabilities.
// Copyright (c) 2001, Stephen R. van den Berg, The Netherlands.
//                     <srb@cuci.nl>
//
// See COPYING in the server directory for license information.
//

//<locale-token project="mod_writefile">_</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_writefile",X,Y)
#define _ok	id->misc->defines[" _ok"]

constant cvs_version =
 "$Id$";
constant thread_safe = 1;

#include <module.h>
#include <config.h>

inherit "module";


// ---------------- Module registration stuff ----------------

constant module_type = MODULE_TAG;
LocaleString module_name = _(1,"Tags: Writefile");
LocaleString module_doc  = _(2,
 "This module provides the writefile RXML tags.<br>"
 "<p>Copyright &copy; 2001-2002, by "
 "<a href='mailto:srb@cuci.nl'>Stephen R. van den Berg</a>, "
 "The Netherlands.</p>"
 "<p>See COPYING in the server directory for license information.</p>");

void create() {
  set_module_creator("Stephen R. van den Berg <srb@cuci.nl>");
  defvar ("onlysubdirs", 1,
	_(3,"Within tree only"), TYPE_FLAG,
        _(4,"Setting this will force all specified chroots and filenames "
	    "to be relative to the directory this tag is located in.  "
	    "It functions as an enforced dynamic chroot to constrain users in "
	    "e.g. a user filesystem.")
        );
}

protected string lastfile;

string status() {
  return sprintf(_(5,"Last file written: %s"),lastfile||"NONE");
}

#define IS(arg)	((arg) && sizeof(arg))

// ------------------- Containers ----------------

class TagWritefile {
  inherit RXML.Tag;
  constant name = "writefile";
  constant flags = RXML.FLAG_DONT_RECOVER;
  mapping(string:RXML.Type) req_arg_types = ([
   "filename" : RXML.t_text(RXML.PEnt)
  ]);
  mapping(string:RXML.Type) opt_arg_types = ([
   "from" : RXML.t_text(RXML.PEnt),
   "chroot" : RXML.t_text(RXML.PEnt),
   "append" : RXML.t_text(RXML.PEnt),
   "mkdirhier" : RXML.t_text(RXML.PEnt),
   "remove" : RXML.t_text(RXML.PEnt),
   "moveto" : RXML.t_text(RXML.PEnt),
   "max-size" : RXML.t_text(RXML.PEnt),
   "max-height" : RXML.t_text(RXML.PEnt),
   "max-width" : RXML.t_text(RXML.PEnt),
   "min-height" : RXML.t_text(RXML.PEnt),
   "min-width" : RXML.t_text(RXML.PEnt),
   "accept-type" : RXML.t_text(RXML.PEnt),
   "charset": RXML.t_text(RXML.PEnt),
   "encode-with-entities": RXML.t_text(RXML.PEnt),
  ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      CACHE(0);
      _ok = 1;
      if(!sizeof(args->filename)) {
	_ok = 0;
	return 0;
      }

      string real_filename,rootpath,path,schroot=args->chroot||"";

      path = id->not_query || "/";
      path=dirname(path)+"/";

      if (QUERY(onlysubdirs))
	rootpath = path;
      else
	rootpath = "/";

      string filename = 
	Stdio.append_path(((schroot+args->filename)[0]=='/'?
			   rootpath:path),
			  Stdio.append_path(schroot, args->filename));
      // Search for an existing real directory
      string d = dirname(filename);
      string real_dirname = id->conf->real_file(d+"/",id);
      string new_dir = "";
      while (!real_dirname && sizeof(d)) {
	new_dir = Stdio.append_path(basename(d), new_dir);
	d = dirname(d);
	if (d == "/") d = "";
	real_dirname = id->conf->real_file(d+"/",id);
      }
      if (!real_dirname)
	parse_error ("There is no file system for %O that supports this tag "
		     "(i.e. implements real_file).\n", dirname(filename));

      real_filename = Stdio.append_path(real_dirname, new_dir,
					basename(filename));

      if(args->remove) {
        if(!rm(real_filename))
	  _ok = 0;
      }
      else 
	if(IS(args->moveto)) {
	  string filename = 
	    Stdio.append_path(((schroot+args->moveto)[0]=='/'?
			       rootpath:path),
			      Stdio.append_path(schroot, args->moveto));
	  string real_dirname = id->conf->real_file(dirname(filename)+"/",id);
	  if (!real_dirname)
	    parse_error ("There is no file system for %O that supports this "
			 "tag (i.e. implements real_file).\n", 
			 dirname(filename));
	  string real_moveto = 
	    Stdio.append_path(real_dirname, basename(filename));

	  if(!mv(real_filename, real_moveto))
	    _ok = 0;
	} 
	else {
	  string towrite;
	  if(args->from) {
	    towrite=RXML.user_get_var(args->from, "form");
	    if(!towrite ||
	       IS(args["max-size"]) && sizeof(towrite)>(int)args["max-size"]) {
	      _ok = 0;
	      return 0;
	    }
	  }
	  else
	    towrite=content||"";

	  {
	    string charset = args->charset;

#ifdef WRITEFILE_UTF8_ENCODE
	    // Handle this define for 4.0 compat.
	    if (!charset) charset = "utf8";
#endif

	    if (charset ||
		(String.width (towrite) > 8 && args["encode-with-entities"])) {
	      charset = charset ? lower_case (charset - "-") : "iso88591";

	      // Optimize some special cases first.
	      if (charset == "utf8")
		towrite = string_to_utf8 (towrite);
	      else if (charset == "iso106461")
		towrite = string_to_unicode (towrite);
	      else if (charset == "iso88591" && String.width (towrite) == 8) {
		// Nothing to do.
	      }

	      else {
		string charset = args->charset || "iso-8859-1";
		Locale.Charset.Encoder enc;
		if (mixed err = catch (enc = Locale.Charset.encoder (charset)))
		  if (has_prefix (describe_error (err), "Unknown character encoding"))
		    parse_error ("Unknown charset %O.\n", charset);
		  else
		    throw (err);
		enc->set_replacement_callback (
		  args["encode-with-entities"] ?
		  lambda (string chr) {
		    return sprintf ("&#x%x;", chr[0]);
		  } :
		  lambda (string chr) {
		    run_error ("Encountered unencodable character %x (hex).\n", chr[0]);
		  });
		towrite = enc->feed (towrite)->drain();
	      }
	    }

	    else if (String.width (towrite) > 8) {
	      foreach (towrite; int pos; int chr)
		if (chr >= 256)
		  run_error ("Encountered wide character %x (hex) at position %d.\n",
			     chr, pos);
	    }
	  }

	  object privs;
	  ;{ Stat st;
	  string diro,dirn;
	  int domkdir=0;
	  for(dirn=real_filename;
	      diro=dirn, diro!=(dirn=dirname(dirn)) && !(st = file_stat(dirn));
	      domkdir=1);
	  if(st) {
	    privs = Privs("Writefile", st->uid, st->gid);
	    if(domkdir && args->mkdirhier)
	      Stdio.mkdirhier(dirname(real_filename));
	  }
	  }
	  _ok = 0;
	  object file=Stdio.File();
	  if(file->open(lastfile=real_filename, args->append?"wrca":"wrct")) {
	    _ok = 1;
#ifdef WRITEFILE_UTF8_ENCODE
	    towrite = string_to_utf8(towrite);
#endif
	    file->write(towrite);
	    object dims;
	    if (IS(args["min-height"])|| IS(args["max-height"])||
		IS(args["min-width"]) || IS(args["max-width"])) {
	      file->seek(0);
	      dims = Dims.dims();
	      array xy = dims->get(file);
	      if(xy && 
		 (IS(args["min-height"])&& xy[1] < (int)args["min-height"]||
		  IS(args["max-height"])&& xy[1] > (int)args["max-height"]||
		  IS(args["min-width"]) && xy[0] < (int)args["min-width"]||
		  IS(args["max-width"]) && xy[0] > (int)args["max-width"]))
		_ok = 0;
	    }
	    if (_ok && args["accept-type"]) {
	      file->seek(0);
	      array(string) types = args["accept-type"]/",";
	      _ok = 0;
	      catch {
		if (!dims) {
		  dims = Dims.dims();
		  dims->f = file;
		}
		if (0<=search(types, "jpeg") && dims->get_JPEG() ||
		    0<=search(types, "png") && (file->seek(0),dims->get_PNG()) ||
		    0<=search(types, "gif") && (file->seek(0),dims->get_GIF()))
		  _ok = 1;
	      };
	    }
	    file->close();
	  }
	  privs = 0;
	}
      return 0;
    }
  }
}

// --------------------- Documentation -----------------------

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"writefile":#"<desc type='cont'><p><short>
 Writes uploaded or direct content to a file.</short>
 You can either use an upload form or write the container content
 directly into a file.  The ownership of any newly created file is determined
 by the directory it is placed into.</p>

 <p>Additional functionality includes removal or renaming of already
  existing files.  This container tag will set the truth value depending
  on success or failure of the requested operation.</p>

 <p>This tag does not work on CMS filesystems. Insted we recommend
  using <xref href='../sitebuilder-internal/sb-edit-area.tag' /></p>
</desc>

<attr name='filename' value='string'>
 <p>Specifies the virtual filename to be created or operated on (relative
  to the current directory, or to the root of the virtual filesystem).</p>
</attr>

<attr name='chroot' value='string'>
 <p>Specifies the virtual root directory (sandbox) all file operations are
  contained under.</p>
</attr>

<attr name='from' value='string'>
<p>Specifies the type=file form field variable which uploaded the
     file to be written. If this attribute is omitted, the container
     content is what will be written instead. Given the example
     below, the parameter <i>from=wrapupafile</i> should be
     specified.</p>

<ex-box><form method='post'
   enctype='multipart/form-data'>
 <input type='file' name='wrapupafile' />
 <input type='submit' value='Upload file' />
</form>
File uploaded:
   <insert scope='form'
     variable='wrapupafile.filename'/>
</ex-box>
</attr>

<attr name='append'>
 <p>Append to the file instead of replacing it.</p>
</attr>

<attr name='mkdirhier'>
 <p>Create the directory hierarchy needed to store the file if needed.</p>
</attr>

<attr name='remove'>
 <p>Causes the specified filename or directory to be removed.</p>
</attr>

<attr name='moveto' value='string'>
 <p>Causes the specified filename to be moved to this new location.</p>
</attr>

<attr name='max-size' value='integer'>
 <p>Specifies the maximum upload file size in bytes which is accepted.</p>
</attr>

<attr name='charset' value='string'>
 <p>Specifies a character set to encode the file content with before
 writing it. This is only useful for text data, like when the source
 is a form variable which can contain characters from the full Unicode
 charset. A useful charset is \"utf-8\" which can encode all Unicode
 characters.</p>
</attr>

<attr name='encode-with-entities'>
 <p>Causes all characters that aren't encodable with the charset
 specified by the \"charset\" attribute to be written as numerical XML
 entity references (e.g. \"&amp;#x20ac;\"). If no \"charset\"
 attribute is given then all characters wider than 8 bits are written
 as entity references.</p>
</attr>

<attr name='max-height' value='integer'>
 <p>The maximum imageheight in pixels which is accepted.</p>
</attr>

<attr name='max-width' value='integer'>
 <p>The maximum imagewidth in pixels which is accepted.</p>
</attr>

<attr name='min-height' value='integer'>
 <p>The minimum imageheight in pixels which is accepted.</p>
</attr>

<attr name='min-width' value='integer'>
 <p>The minimum imagewidth in pixels which is accepted.</p>
</attr>

<attr name='accept-type' value='string'>
 <p>Comma separated list of file types which are accepted, currently
  supported types
  are jpeg, png and gif; the check is performed on the file content, not
  on the file extension.</p>
</attr>"

  ,

//----------------------------------------------------------------------

    ]);
#endif
