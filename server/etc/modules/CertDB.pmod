/*
 * $Id$
 *
 * Certificate Database API.
 */

//! Certificate Database API

#ifdef SSL3_DEBUG
# define SSL3_WERR(X ...) report_debug("CertDB: " + X)
#else
# define SSL3_WERR(X ...)
#endif


// Some convenience constants.
protected local constant Compound = Standards.ASN1.Types.Compound;
protected local constant Identifier = Standards.ASN1.Types.Identifier;
protected local constant Sequence = Standards.ASN1.Types.Sequence;

protected typedef mapping(string:int|string) sql_row;

//!
array(sql_row) list_keys()
{
  Sql.Sql db = DBManager.cached_get("roxen");
  return db->typed_query("SELECT * "
			 "  FROM cert_keys "
			 " ORDER BY id ASC");
}

//!
array(sql_row) list_keypairs()
{
  Sql.Sql db = DBManager.cached_get("roxen");
  return db->typed_query("SELECT * "
			 "  FROM cert_keypairs "
			 " ORDER BY cert_id ASC, key_id ASC");
}

//!
sql_row get_cert(int cert_id)
{
  Sql.Sql db = DBManager.cached_get("roxen");
  array(mapping(string:int|string)) res =
    db->typed_query("SELECT * "
		    "  FROM certs "
		    " WHERE id = %d",
		    cert_id);
  if (!sizeof(res)) return 0;
  return res[0];
}

//! Attempt to create a presentable string from DN.
protected string format_dn(Sequence dn)
{
  mapping(Identifier:string) ids = ([]);
  foreach(dn->elements, Compound pair)
  {
    if(pair->type_name!="SET" || !sizeof(pair)) continue;
    pair = pair[0];
    if(pair->type_name!="SEQUENCE" || sizeof(pair)!=2)
      continue;
    if(pair[0]->type_name=="OBJECT IDENTIFIER" &&
       pair[1]->value && !ids[pair[0]])
      ids[pair[0]] = pair[1]->value;
  }

  string res;
  // NB: Loop backwards to join oun and on before cn.
  foreach(({ Standards.PKCS.Identifiers.at_ids.organizationUnitName,
	     Standards.PKCS.Identifiers.at_ids.organizationName,
	     Standards.PKCS.Identifiers.at_ids.commonName,
	  }); int i; Identifier id) {
    string val = ids[id];
    if (!val) continue;
    if (res) {
      if (i == 2) {
	res = "(" + res + ")";
      }
      res = val + " " + res;
    } else {
      res = val;
    }
  }
  return res || "<NO SUITABLE NAME>";
}

protected variant string format_dn(string(8bit) dn)
{
  // FIXME: Support X.509v2?
  Sequence seq = Standards.ASN1.Decode.secure_der_decode(dn, ([]));
  return format_dn(seq);
}

protected void refresh_cert(Sql.Sql db, int pem_id, int msg_no, string data)
{
  Standards.X509.TBSCertificate tbs =
    Standards.X509.decode_certificate(data);
  if (!tbs) return;

  string(8bit) subject = tbs->subject->get_der();
  string(8bit) issuer = tbs->issuer->get_der();
  int expires = tbs->not_after;

  string(8bit) keyhash =
    Crypto.SHA256.hash(tbs->public_key->pkc->pkcs_public_key()->get_der());

  array(sql_row) tmp =
    db->typed_query("SELECT * "
		    "  FROM certs "
		    " WHERE keyhash = %s "
		    "   AND subject = %s "
		    "   AND issuer = %s",
		    keyhash,
		    subject,
		    issuer);
  if (!sizeof(tmp)) {
    db->query("INSERT INTO certs "
	      "    (pem_id, msg_no, subject, issuer, expires, keyhash, data) "
	      "VALUES (%d, %d, %s, %s, %d, %s, %s)",
	      pem_id, msg_no, subject, issuer, expires, keyhash, data);
    int cert_id = db->master_sql->insert_id();

    // Check if we have a matching private key.
    tmp = db->typed_query("SELECT * "
			  "  FROM cert_keys "
			  " WHERE keyhash = %s "
			  " ORDER BY id ASC",
			  keyhash);
    if (sizeof(tmp)) {
      // FIXME: Key selection policy.
      string name = format_dn(subject);
      if (issuer == subject) {
	name += " (self-signed)";
      } else {
	name += " " + format_dn(issuer);
      }
      db->query("INSERT INTO cert_keypairs "
		"       (cert_id, key_id, name) "
		"VALUES (%d, %d, %s)",
		cert_id, tmp[0]->id, name);
    }

    if (subject != issuer) {
      // Not a self-signed certificate.

      // Check if we have the cert that this cert was signed by.
      tmp = db->typed_query("SELECT * "
			    "  FROM certs "
			    " WHERE subject = %s",
			    issuer);
      if (sizeof(tmp)) {
	db->query("UPDATE certs "
		  "   SET parent = %d "
		  " WHERE id = %d",
		  tmp[0]->id,
		  cert_id);
      }
    }

    // Update any cert that lacks a parent and
    // is signed by us.
    tmp = db->typed_query("UPDATE certs "
			  "   SET parent = %d "
			  " WHERE issuer = %s "
			  "   AND parent IS NULL "
			  "   AND subject != issuer",
			  cert_id,
			  subject);
  } else if (tmp[0]->expires <= expires) {
    // NB: Keep more recent certificates unmodified (even if stale).
    // NB: keyhash, subject and issuer are unmodified (cf above).
    SSL3_WERR("Updating cert #%d.\n", tmp[0]->id);
    db->query("UPDATE certs "
	      "   SET pem_id = %d, "
	      "       msg_no = %d, "
	      "       expires = %d, "
	      "       data = %s "
	      " WHERE id = %d",
	      pem_id, msg_no, expires, data,
	      tmp[0]->id);
  } else {
    SSL3_WERR("Got certificate older than that in db: %d < %d\n",
	      expires, tmp[0]->expires);
  }
}

protected void refresh_private_key(Sql.Sql db, int pem_id, int msg_no,
				   string raw)
{
  Crypto.Sign.State private_key = Standards.X509.parse_private_key(raw);

  string(8bit) keyhash =
    Crypto.SHA256.hash(private_key->pkcs_public_key()->get_der());

  Crypto.AES.CCM.State ccm = Crypto.AES.CCM();
  // NB: Using the server salt as a straight encryption key
  //     is a BAD idea as CCM is a stream crypto.
  ccm->set_encrypt_key(Crypto.SHA256.hash(roxenp()->query("server_salt") +
					  "\0" + keyhash));
  string(8bit) data = ccm->crypt(raw) + ccm->digest();

  array(sql_row) tmp =
    db->typed_query("SELECT * "
		    "  FROM cert_keys "
		    " WHERE keyhash = %s",
		    keyhash);
  if (!sizeof(tmp)) {
    db->query("INSERT INTO cert_keys "
	      "       (pem_id, msg_no, keyhash, data) "
	      "VALUES (%d, %d, %s, %s)",
	      pem_id, msg_no, keyhash, data);
    int key_id = db->master_sql->insert_id();
    SSL3_WERR("Added cert key #%d.\n", key_id);

    // Check if we have any matching certificates that currently lack keys,
    // and add corresponding keypairs.
    foreach(db->typed_query("SELECT * "
			    "  FROM certs "
			    " WHERE keyhash = %s "
			    " ORDER BY id ASC",
			    keyhash),
	    sql_row cert_info) {
      if (sizeof(db->query("SELECT * "
			   "  FROM cert_keypairs "
			   " WHERE cert_id = %d",
			   cert_info->id))) {
	// Keypair already exists.
	continue;
      }
      string name = format_dn(cert_info->subject);
      if (cert_info->issuer == cert_info->subject) {
	name += " (self-signed)";
      } else {
	name += " " + format_dn(cert_info->issuer);
      }
      db->query("INSERT INTO cert_keypairs "
		"       (cert_id, key_id, name) "
		"VALUES (%d, %d, %s)",
		cert_info->id, key_id, name);
    }
  } else {
    // Zap any stale or update in progress marker for the key.
    if (tmp[0]->data != data) {
      // The encrypted data string has changed; this may be due
      // to the server salt having been changed, or due to the
      // old value having been created with an old proken Pike.
      SSL3_WERR("Updating cert key #%d. Has the server salt changed?\n",
		tmp[0]->id);
      db->query("UPDATE cert_keys "
		"   SET pem_id = %d, "
		"       msg_no = %d, "
		"       data = %s "
		" WHERE id = %d",
		pem_id, msg_no, data,
		tmp[0]->id);
    } else {
      db->query("UPDATE cert_keys "
		"   SET pem_id = %d, "
		"       msg_no = %d "
		" WHERE id = %d",
		pem_id, msg_no,
		tmp[0]->id);
    }
  }
}

protected int low_refresh_pem(int pem_id, int|void force)
{
  Sql.Sql db = DBManager.cached_get("roxen");

  array(sql_row) tmp =
    db->typed_query("SELECT * "
		    "  FROM cert_pem_files "
		    " WHERE id = %d",
		    pem_id);
  if (!sizeof(tmp)) return 0;

  sql_row pem_info = tmp[0];

  string pem_file = pem_info->path;

  if (!sizeof(pem_file)) return 0;

  string raw_pem;
  string pem_hash;

  Stdio.Stat st = lfile_stat(pem_file);
  if (st) {
    // FIXME: Check if mtime has changed before reading the file?

    SSL3_WERR("Reading cert file %O\n", pem_file);
    if( catch{ raw_pem = lopen(pem_file, "r")->read(); } )
    {
      SSL3_WERR("Reading PEM file %O failed: %s\n",
		pem_file, strerror(errno()));
    } else {
      pem_hash = Crypto.SHA256.hash(raw_pem);
      if ((pem_info->hash == pem_hash) && !force) {
	// No change.
	SSL3_WERR("PEM file not modified since last import.\n");
	return 0;
      }
    }
  }

  if (!raw_pem) {
    // Mark any old certs and keys as stale.
    db->query("UPDATE certs "
	      "   SET pem_id = NULL, "
	      "       msg_no = NULL "
	      " WHERE pem_id = %d",
	      pem_id);
    db->query("UPDATE cert_keys "
	      "   SET pem_id = NULL, "
	      "       msg_no = NULL "
	      " WHERE pem_id = %d",
	      pem_id);
    return 0;
  }

  // Mark any old certs and keys as update in progress.
  db->query("UPDATE certs "
	    "   SET msg_no = NULL "
	    " WHERE pem_id = %d",
	    pem_id);
  db->query("UPDATE cert_keys "
	    "   SET msg_no = NULL "
	    " WHERE pem_id = %d",
	    pem_id);

  mixed err =
    catch {
      Standards.PEM.Messages messages = Standards.PEM.Messages(raw_pem);
      foreach(messages->fragments; int msg_no; string|Standards.PEM.Message msg) {
	if (stringp(msg)) continue;

	string body = msg->body;

	if (msg->headers["dek-info"] && pem_info->pass) {
	  mixed err = catch {
	      body = Standards.PEM.decrypt_body(msg->headers["dek-info"],
						body, pem_info->pass);
	    };
	  if (err) {
	    SSL3_WERR("Invalid decryption password for %O.\n", pem_file);
	  }
	}

	SSL3_WERR("Got %s.\n", msg->pre);

	switch(msg->pre) {
	case "CERTIFICATE":
	case "X509 CERTIFICATE":
	  refresh_cert(db, pem_id, msg_no, body);
	  break;

	case "PRIVATE KEY":
	case "RSA PRIVATE KEY":
	case "DSA PRIVATE KEY":
	case "ECDSA PRIVATE KEY":
	  refresh_private_key(db, pem_id, msg_no, body);
	  break;

	case "CERTIFICATE REQUEST":
	  // Ignore CSRs for now.
	  break;

	default:
	  SSL3_WERR("Unsupported PEM message: %O\n", msg->pre);
	  break;
	}
      }
    };
  if (err) {
    werror("Failed to handle PEM file %O:\n", pem_file);
    master()->handle_error(err);

    // NB: No return here. We want to zap the pem_id fields.
  }

  // Mark any old certs and keys that are still update in progress as stale.
  db->query("UPDATE certs "
	    "   SET pem_id = NULL "
	    " WHERE pem_id = %d "
	    "   AND msg_no IS NULL",
	    pem_id);
  db->query("UPDATE cert_keys "
	    "   SET pem_id = NULL "
	    " WHERE pem_id = %d "
	    "   AND msg_no IS NULL",
	    pem_id);

  // Update metadata about the imported PEM file.
  db->query("UPDATE cert_pem_files "
	    "   SET hash = %s, "
	    "       mtime = %d, "
	    "       itime = %d "
	    " WHERE id = %d",
	    pem_hash, st->mtime, time(1),
	    pem_id);

  return 1;
}

//! Refresh a single PEM file.
int refresh_pem(int pem_id)
{
  object privs = Privs("Reading cert file");

  return low_refresh_pem(pem_id);
}

//! Refresh all known PEM files.
int refresh_all_pem_files(int|void force)
{
  Sql.Sql db = DBManager.cached_get("roxen");
  int count = 0;

  object privs = Privs("Reading cert file");

  foreach(db->typed_query("SELECT id FROM cert_pem_files")->id, int pem_id) {
    count += low_refresh_pem(pem_id, force);
  }

  return count;
}

//! Register a single PEM file (no @[Privs]).
//!
//! @note
//!   Registering a certificate or key file twice is a noop.
//!
//! @returns
//!   Returns the id for the PEM file.
//!
//! @note
//!   Return value differs from that of @[register_pem_files()].
//!
//! @seealso
//!   @[register_pem_files()]
protected int low_register_pem_file(string pem_file, string|void password)
{
  Sql.Sql db = DBManager.cached_get("roxen");

  array(sql_row) row =
    db->typed_query("SELECT * "
		    "  FROM cert_pem_files "
		    " WHERE path = %s",
		    pem_file);
  int pem_id;
  if (sizeof(row)) {
    pem_id = row[0]->id;
    if (password && (row[0]->pass != password)) {
      db->query("UPDATE cert_pem_files "
		"   SET pass = %s "
		  " WHERE id = %d",
		password, pem_id);
    }
  } else {
    db->query("INSERT INTO cert_pem_files "
	      "       (path, pass) VALUES (%s, %s)",
	      pem_file, password);
    pem_id = db->master_sql->insert_id();
  }

  low_refresh_pem(pem_id);

  return pem_id;
}

//! Register a single PEM file.
//!
//! @note
//!   Registering a certificate or key file twice is a noop.
//!
//! @returns
//!   Returns the id for the PEM file.
//!
//! @note
//!   Return value differs from that of @[register_pem_files()].
//!
//! @seealso
//!   @[register_pem_files()], @[low_register_pem_file()]
int register_pem_file(string pem_file, string|void password)
{
  object privs = Privs("Reading cert file");
  return low_register_pem_file(pem_file, password);
}

//! Register a set of PEM files.
//!
//! @note
//!   Registering a certificate or key file twice is a noop.
//!
//! @returns
//!   Returns resulting keypair ids for the certificates (if any).
//!
//! @note
//!   Return value differs from that of @[register_pem_file()].
//!
//! @seealso
//!   @[register_pem_file()]
array(int) register_pem_files(array(string) pem_files, string|void password)
{
  Sql.Sql db = DBManager.cached_get("roxen");

  object privs = Privs("Reading cert file");

  array(int) pem_ids = ({});
  foreach(map(pem_files, String.trim_all_whites), string pem_file) {
    if (pem_file == "") continue;

    pem_ids += ({ low_register_pem_file(pem_file, password) });
  }

  privs = 0;

  // FIXME: Move the following code to a separate function to improve API?
  //        (And instead just return pem_ids)?
  array(int) keypairs = ({});

  foreach(Array.uniq(pem_ids), int pem_id) {
    keypairs +=
      db->typed_query("SELECT cert_keypairs.id AS id"
		      "  FROM cert_keys, cert_keypairs "
		      " WHERE pem_id = %d "
		      "   AND cert_keypairs.key_id = cert_keys.id",
		      pem_id)->id;
  }
  return sort(keypairs);
}

//! Get the private key and the list of certificates given a keypair id.
array(Crypto.Sign.State|array(string)) get_keypair(int keypair_id)
{
  // FIXME: Consider having a keypair lookup cache.

  Sql.Sql db = DBManager.cached_get("roxen");

  array(sql_row) tmp =
    db->typed_query("SELECT * "
		    "  FROM cert_keypairs "
		    " WHERE id = %d",
		    keypair_id);
  if (!sizeof(tmp)) return 0;

  int key_id = tmp[0]->key_id;
  int cert_id = tmp[0]->cert_id;

  tmp = db->typed_query("SELECT * "
			"  FROM cert_keys "
			" WHERE id = %d",
			key_id);
  if (!sizeof(tmp)) return 0;

  if (sizeof(tmp[0]->data) < Crypto.AES.CCM.digest_size()) return 0;
  Crypto.AES.CCM.State ccm = Crypto.AES.CCM();
  ccm->set_decrypt_key(Crypto.SHA256.hash(roxenp()->query("server_salt") +
					  "\0" + tmp[0]->keyhash));
  string digest = tmp[0]->data[<Crypto.AES.CCM.digest_size()-1..];
  string raw = ccm->crypt(tmp[0]->data[..<Crypto.AES.CCM.digest_size()]);
  if (digest != ccm->digest()) {
    SSL3_WERR("Invalid key digest for key #%d. Has the server salt changed?\n",
	      key_id);
    return 0;
  }
  Crypto.Sign.State private_key = Standards.X509.parse_private_key(raw);
  raw = "";

  array(string) certs = ({});
  while (cert_id) {
    tmp = db->typed_query("SELECT * "
			  "  FROM certs "
			  " WHERE id = %d",
			  cert_id);
    if (!sizeof(tmp)) break;
    certs += ({ tmp[0]->data });
    cert_id = tmp[0]->parent;
  }
  if (!sizeof(certs)) {
    SSL3_WERR("Missing certificate (#%d) for keypair %d.\n", cert_id, keypair_id);
    return 0;
  }

  return ({ private_key, certs });
}

//! Get metadata for a keypair id.
mapping(string:string|sql_row|array(sql_row)) get_keypair_metadata(int keypair_id)
{
  Sql.Sql db = DBManager.cached_get("roxen");

  array(sql_row) tmp =
    db->typed_query("SELECT * "
		    "  FROM cert_keypairs "
		    " WHERE id = %d",
		    keypair_id);
  if (!sizeof(tmp)) return 0;

  int key_id = tmp[0]->key_id;
  int cert_id = tmp[0]->cert_id;

  mapping(string:string|sql_row|array(sql_row)) res = ([
    "name": tmp[0]->name,
  ]);

  tmp = db->typed_query("SELECT id, pem_id, msg_no, HEX(keyhash) AS keyhash "
			"  FROM cert_keys "
			" WHERE id = %d",
			key_id);
  if (sizeof(tmp)) {
    res->key = tmp[0];

    if (tmp[0]->pem_id) {
      tmp = db->typed_query("SELECT path "
			    "  FROM cert_pem_files "
			    " WHERE id = %d",
			    tmp[0]->pem_id);
      if (sizeof(tmp)) {
	res->key->pem_path = tmp[0]->path;
      }
    }
  }

  while(cert_id) {
    tmp = db->typed_query("SELECT id, HEX(subject) AS subject, "
			  "       HEX(issuer) AS issuer, parent, "
			  "       pem_id, msg_no, expires, "
			  "       HEX(keyhash) AS keyhash "
			  "  FROM certs "
			  " WHERE id = %d",
			  cert_id);
    if (!sizeof(tmp)) break;

    res->certs += tmp;
    cert_id = tmp[0]->parent;

    if (tmp[0]->pem_id) {
      tmp = db->typed_query("SELECT path "
			    "  FROM cert_pem_files "
			    " WHERE id = %d",
			    tmp[0]->pem_id);
      if (sizeof(tmp)) {
	res->certs[-1]->pem_path = tmp[0]->path;
      }
    }
  }

  return res;
}
