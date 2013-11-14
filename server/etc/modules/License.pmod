// Roxen License framework.
//
// Created 2002-02-18 by Marcus Wellhardh.
//
// $Id$

#if constant(roxen)
#define INSIDE_ROXEN
#endif

constant have_feature_locking = 1;

int is_active(string license_dir)
// Returns true if the license system is enabled.
{
  return Stdio.is_dir(license_dir);
}

array(Configuration) get_configurations_for_license(Key key)
{
  array(Configuration) confs = ({ });
  foreach(roxen.list_all_configurations(), string conf_name)
    if(Configuration conf = roxen.get_configuration(conf_name)) {
      Key _key = conf->getvar("license")->get_key();
      if(_key && _key->number() == key->number())
	confs += ({ conf });
    }
  return confs;
}

protected mapping(string:Key) license_keys = ([]);
protected mapping(string:int) license_keys_time = ([]);

// Returns the key object for the specified filename/directory. If a
// known error occures an error mapping is returned. The returned key
// is cached until restart.
Key|mapping get_license(string license_dir, string filename)
{
  if(!filename || !Stdio.is_file(Stdio.append_path(license_dir, filename)))
    return 0;
  //werror("License.get_license(%O) ", filename);
  string path = Stdio.append_path(license_dir, filename);
  int mtime = file_stat(path)->mtime;
  if(license_keys[path] && mtime > license_keys_time[path])
    m_delete(license_keys, path);
	      
  if(!license_keys[path]) {
    Key key = Key(license_dir, filename);

    // Check if the license # has been used in a previously loaded license.
    foreach(values(license_keys), Key other_key)
    {
      if(key->number() == other_key->number()) {
	return ([ "filename": filename,
		  "message":  "Can't load license.",
		  "reason":   ("Same license number as in license "+
			       other_key->filename()+".") ]);
      }
    }
    //werror("new %O.\n", key);
    license_keys[path] = key;
    license_keys_time[path] = mtime;
  } else { 
    //werror("cached %O.\n", license_keys[path]);
  }
  return license_keys[path];
}

// Returns an array with all keys in the specified directory. If an
// error occures during loading a key an error mapping is returned
// instead of that key.
array(Key|mapping) get_licenses(string license_dir)
{
  array(Key|mapping) licenses = ({});
  foreach(glob("*.lic", get_dir(license_dir)), string filename)
  {
    object(Key)|mapping key;
    if(mixed err = catch { key = get_license(license_dir, filename); } )
    {
      report_debug(describe_backtrace(err));
      
      licenses += ({ ([ "filename":  filename,
			"message":   "Can't load license.",
			"reason":    describe_error(err) ]) });
    }
    else licenses += ({ key });
  }
  return licenses;
}


protected int key_count;  // How many licenses has been created, used for debug.

//!  License key created from a key file.
class Key
{
  protected mapping content;
  protected string license_dir, _filename;
  protected mapping warnings;
  protected int key_id;  // This licenses create id, used for debug.
  
  class WarningEntry
  {
    int t;
    string msg, type;

    mapping to_mapping()
    {
      return ([ "time":t, "msg":msg, "type":type ]);
    }

    string _sprintf()
    {
      return sprintf("WarningEntry(%O, %O, %O)", type, time, msg);
    }
    
    void create(string _msg, string _type)
    {
      msg = _msg;
      type = _type;
      t = time();
    }
  }

  void report_warning(string type, string msg)
  {
    //werror("License.Key->report_warning(%O, %O) for key %O\n",
    //	   type, msg, this_object());
    warnings[type] = WarningEntry(msg, type);
  }

  void clear_warning(string type)
  {
    m_delete(warnings, type);
  }
  
  array(mapping(string:string)) get_warnings()
  {
    array(mapping(string:string)) res = values(warnings)->to_mapping();
    return sort(res, res->time);
  }
  
  mapping(string:string) get_warning(string type)
  {
    return warnings[type] && warnings[type]->to_mapping();
  }
  
  protected array(Gmp.mpz) read_public_key()
  {
    string key_name = combine_path(license_dir, "public.key");
    string s = Stdio.read_bytes(key_name);
    if(!s)
      error("Can't read public license key %s.\n", key_name);
    sscanf(s, "%d:%d", int n, int e);
    if(!n || !e)
      error("Malformed %s.\n", key_name);
    return ({ Gmp.mpz(n), Gmp.mpz(e) });
  }
  
  protected Gmp.mpz read_private_key()
  {
    string key_name = combine_path(license_dir, "private.key");
    string s = Stdio.read_bytes(key_name);
    if(!s)
      error("Can't read private license key %s.\n", key_name);
    sscanf(s, "%d", int d);
    if(!d)
      error("Malformed %s.\n", key_name);
    return Gmp.mpz(d);
  }

  // NB: The sha_sign() and sha_verify() functions
  //     have been deprecated in Pike 8.0.
#pragma no_deprecation_warnings
  protected string encrypt(string msg)
  {
    Crypto.RSA rsa = Crypto.RSA()->
		     set_public_key(@read_public_key())->
		     set_private_key(read_private_key());
    string sign = rsa->sha_sign(msg);
    return sprintf("%d:%s%s", sizeof(sign), msg, sign);
  }
  
  protected string decrypt(string gibberish)
  {
    string s;
    int size;
    
    if(sscanf(gibberish, "%d:%s", size, s) != 2)
      return 0;
    
    string msg = s[..sizeof(s)-size-1];
    string sign = s[sizeof(msg)..];

    Crypto.RSA rsa = Crypto.RSA()->set_public_key(@read_public_key());
    return rsa->sha_verify(msg, sign) && msg;
  }
#pragma deprecation_warnings

  int write()
  {
    string license_name = Stdio.append_path(license_dir, _filename);
    string s = sprintf("Roxen License:\n %O\n-START-\n%s\n-END-\n",
		       content,
		       MIME.encode_base64(encrypt(encode_value(content))));
    int bytes = Stdio.write_file(license_name, s);
    chmod(license_name, 384);
    if(sizeof(s) != bytes)
      error("Can't write license file %s.\n", license_name);
    return bytes;
  }

  int read()
  {
    string license_name = Stdio.append_path(license_dir, _filename);
    string s = Stdio.read_bytes(license_name);
    if(!s)
      error("Can't read license file %s.\n", license_name);
    int bytes = sizeof(s);

    // Fix newline incompatibility.
    s = replace(s, "\r\n", "\n");
    s = replace(s, "\r", "\n");

    // Parse license file.
    if(sscanf(s, "%*sRoxen%*s\n-START-\n%s\n-END-%*s", s) < 4)
      error("Malformed license file %s.\n", license_name);
    s = MIME.decode_base64(s);
    string msg = decrypt(s);
    if(!msg)
      error("Error reading license file %s. Signature verification failed.\n",
	    license_name);
    content = decode_value(msg);
    return bytes;
  }
  
  string company_name() { return content->company_name; }
  int number()          { return (int)content->number; }
  string type()         { return content->type; }
  string expires()      { return content->expires; }
  string hostname()     { return content->hostname; }
  string sites()        { return type() == "evaluation"? "*":(content->sites || "1"); }
  int is_enterprise()   { return sites() == "*"; }
  int sites_i()         { return is_enterprise()? 100000: (int)sites(); }
  
  string created()      { return content->created; }
  string creator()      { return content->creator; }
  string license_version()   { return content->license_version; }
  string comment()      { return content->comment; }
  string filename()     { return _filename; }
  
  int is_module_unlocked(string m, string|void mode)
  //! Returns true if the module @[m] with optional mode @[mode] is
  //! unlocked in the license file.
  {
    if(mode)
      m += "::"+mode;
    return !!content->modules[m];
  }

  mixed get_module_feature(string m, string feature, string|void mode)
  //! Returns the feature @[feature] for module @[m] with optional
  //! mode @[mode]. Returns false if the module/feature don't exists in the
  //! license file.
  {
    if(mode)
      m += "::"+mode;
    return mappingp(content->modules[m]) && content->modules[m][feature];
  }

  mapping get_modules()
  //! Returns the modules mapping. Note, this function should only be
  //! used for display purposes NOT for module/feature
  //! verification. Use @[is_module_unlocked] or @[get_module_feature]
  //! instead.
  {
    return copy_value(content->modules);
  }
  
#ifdef INSIDE_ROXEN
  Configuration used_in(Configuration|void configuration)
  // Returns the first configuration the license key is used in. If a
  // configuration is supplied that one is not checked.
  {
    array(string) configurations = roxen.list_all_configurations();
    if(configuration)
      configurations -= ({ configuration->name });
    foreach(configurations, string conf_name)
      if(Configuration conf = roxen.get_configuration(conf_name)) {
	Key key = conf->getvar("license")->get_key();
	if(key && key->number() == number())
	  return conf;
      }
  }
  
  string name(Configuration|void configuration)
  // Returns the name of the license key. If a configuration is
  // supplied that one is omited from the "used by other configuration"
  // check.
  {
    return sprintf("%s (%s #%d)%s", _filename, type(), number(),
		   used_in(configuration)?"!":"");
  }
#endif

  string|void verify(int verify_mode, object /*Configuration*/|void configuration,
		     int|void time, string|void _hostname)
  // Verifies if the license complies with the current setup. Returns
  // an error message if a breach was found.

  // verify_mode: Only return error messages if set.
  // configuration: The configuration to verify the license for.
  // time: The time to verify license expiration for.
  // hostname: The hostname to verify the license for.
    
  {
    array(object /*Configuration*/) confs =
      get_configurations_for_license(this_object());
    
    if(!is_enterprise())
    {
      array conflicting_confs = (confs | ({ configuration }));
      // verify configuration integrity.
      if(sizeof(conflicting_confs) > sites_i()) {
	if(verify_mode)
	  return sprintf("The license "+filename()+" is already used in the following "
			 "configurations: %s. License permits only "
			 "%d concurrent sites.",
			 String.implode_nicely((conflicting_confs -
						({ configuration }))->name),
			 sites_i());
	else
	  report_warning("Configuration",
			 sprintf("License used in too many configurations: %s. "
				 "License permits only %d concurrent sites.",
				 String.implode_nicely((conflicting_confs - ({ 0 }))
						       ->name), sites_i()));
      }
    }
    
    if(time)
    {
      // verify expiration integrity.
      if(expires() != "*" && Calendar.ISO->dwim_day(expires())->unix_time() < time)
	if(verify_mode)
	  return sprintf("The license "+filename()+" has expired.");
	else
	  report_warning("Expiration", sprintf("License expired"));
    }

    if(_hostname && configuration)
    {
      // verify hostname integrity.
      if(!glob(hostname(), _hostname))
	if(verify_mode)
	  sprintf("The license "+filename()+" hostname %O does not match "
		  "primary server url %O.",
		  _hostname, hostname());
	else
	  report_warning("Hostname", sprintf("Hostname mismatch: %O does not match %O",
					     hostname(), _hostname));
    }
  }
  
  string _sprintf()
  {
    return sprintf("License.Key(#%O, %O, %O)", key_id, _filename, sizeof(warnings));
  }

  void create(string _license_dir, string __filename, mapping|void _content)
  {
    key_id = key_count++;
    warnings = ([]);
    license_dir = _license_dir;
    _filename = __filename;
    if(!_content)
      read();
    else
      content = _content;
  }
}

#ifdef INSIDE_ROXEN
class LicenseVariable
{
  inherit Variable.MultipleChoice;
  Configuration configuration;
  string license_dir;
  protected Key license_key;
  protected int verify_mode;
  
  Key get_key()
  {
    return license_key;
  }
  
  array get_choice_list()
  {
    return ({ 0 }) + Array.filter(get_licenses(license_dir), objectp)->filename();
  }
  
  mapping get_translation_table()
  {
    return mkmapping(get_choice_list(),
		     ({ "None" }) +
		     map(get_choice_list() - ({ 0 }),
			 lambda(string file)
			 { return Key(license_dir, file)->
			     name(configuration); }));
  }
  
  array(string|mixed) verify_set(mixed new_value)
  // Return error if the license file is invalid or if the license is
  // used by another configuration.
  {
    if(new_value == "0")
      new_value = 0;
    
    if(new_value && new_value != query())
    {
      Key key;
      if(mixed err = catch { key = get_license(license_dir, new_value); }) {
	report_debug("License error: %s\n", describe_backtrace(err));
	return ({ sprintf("Error reading license: %O\n  %s", new_value, err[0]),
		  query() });
      }

      if(!key) {
	report_debug("Error: Trying to load a nonexisting license: %s\n", new_value);
	return ({ sprintf("License %s does not exist.\n", new_value),
		  query() });
      }
      
      if(mappingp(key)) {
	report_debug("Error: %s Filename: %s, Reason: %s\n",
		     key["message"], key["filename"], key["reason"]);
	
	return ({ sprintf("Error reading license: %O\n"
			  "  %s Filename: %s, Reason: %s\n",
			  new_value, key["message"], key["filename"], key["reason"]),
		  query() });
      }
      
      string url = configuration && configuration->get_url();
      string hostname = url && sizeof(url) && Standards.URI(url)->host;
      if(string err = key->verify(verify_mode, configuration, time(), hostname))
	return ({ err, query() });
    }
    return ({ 0, new_value });
  }

  int low_set(mixed to)
  {
    license_key = get_license(license_dir, to);
    //werror("Updating key to %O for configuration %O\n", license_key, configuration);
    return ::low_set(to);
  }
  
  protected int invisibility_check(RequestID id, Variable.Variable var)
  {
    return !Stdio.is_dir(license_dir);
  }
  
  protected void create(string _license_dir, void|int _flags,
			void|LocaleString std_name, void|LocaleString std_doc,
			Configuration _configuration, int|void _verify_mode)
  {
    license_dir = _license_dir;
    configuration = _configuration;
    verify_mode = _verify_mode;
    ::create(0, 0, _flags, std_name, std_doc);
    set_invisibility_check_callback(invisibility_check);
  }
}
#endif
