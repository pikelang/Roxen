/*
 * $Id$
 *
 * Certificate Database API.
 */

//! Certificate Database API

#ifdef SSL3_DEBUG
# define SSL3_WERR(X) report_debug("CertDB: %s\n", X)
#else
# define SSL3_WERR(X)
#endif



//!
array(mapping(string:int|string)) list_keys()
{
  Sql.Sql db = DBManager.cached_get("roxen");
  return db->typed_query("SELECT * "
			 "  FROM cert_keys "
			 " ORDER BY id ASC");
}

//!
array(mapping(string:int|string)) list_keypairs()
{
  Sql.Sql db = DBManager.cached_get("roxen");
  return db->typed_query("SELECT * "
			 "  FROM cert_keypairs "
			 " ORDER BY cert_id ASC, key_id ASC");
}

//!
mapping(string:int|string) get_cert(int cert_id)
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

protected void low_refresh_pem(int pem_id)
{
  Sql.Sql db = DBManager.cached_get("roxen");

  array(mapping(string:int|string)) tmp =
    db->typed_query("SELECT * "
		    "  FROM cert_pem_files "
		    " WHERE id = %d",
		    pem_id);
  if (!sizeof(tmp)) return;

  mapping(string:int|string) pem_info = tmp[0];

  array(mapping(string:int|string)) certs = ({});
  array(mapping(string:int|string)) keys = ({});

  string pem_file = pem_info->path;

  string raw_pem;
  string pem_hash;

  Stdio.Stat st = lfile_stat(pem_file);
  if (st) {
    // FIXME: Check if mtime hash changed before reading the file?

    SSL3_WERR (sprintf ("Reading cert file %O", pem_file));
    if( catch{ raw_pem = lopen(pem_file, "r")->read(); } )
    {
      werror("Reading PEM file %O failed: %s\n",
	     pem_file, strerror(errno()));
    } else {
      pem_hash = Crypto.SHA256.hash(raw_pem);
      if (pem_info->hash == pem_hash) {
	// No change.
	return;
      }
    }
  }

  // Mark the old certs and keys as no longer in the PEM file.
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

  if (!raw_pem) return;

  mixed err =
    catch {
      Standards.PEM.Messages messages = Standards.PEM.Messages(raw_pem);
      foreach(messages->fragments; int msg_no; string|Standards.PEM.Message msg) {
	if (stringp(msg)) continue;

	mapping(string:string|int) entry = ([
	  "pem_id": pem_id,
	  "msg_no": msg_no,
	]);

	string body = msg->body;

	if (msg->headers["dek-info"] && pem_info->pass) {
	  mixed err = catch {
	      body = Standards.PEM.decrypt_body(msg->headers["dek-info"],
						body, pem_info->pass);
	    };
	  if (err) {
	    werror("Invalid decryption password for %O.\n", pem_file);
	  }
	}

	switch(msg->pre) {
	case "CERTIFICATE":
	case "X509 CERTIFICATE":
	  Standards.X509.TBSCertificate tbs =
	    Standards.X509.decode_certificate(body);
          if (!tbs) continue;

	  entry->subject = tbs->subject->get_der();
	  entry->issuer = tbs->issuer->get_der();
	  entry->expires = tbs->not_after;
	  entry->data = body;

	  entry->keyhash =
	    Crypto.SHA256.hash(tbs->public_key->pkc->
			       pkcs_public_key()->get_der());
	  certs += ({ entry });
	  break;

	case "PRIVATE KEY":
	case "RSA PRIVATE KEY":
	case "DSA PRIVATE KEY":
	case "ECDSA PRIVATE KEY":
	  werror("CERTDB: Got %s.\n", msg->pre);
	  Crypto.Sign.State private_key =
	    Standards.X509.parse_private_key(body);

	  entry->keyhash =
	    Crypto.SHA256.hash(private_key->
			       pkcs_public_key()->get_der());

	  Crypto.AES.CCM.State ccm = Crypto.AES.CCM();
	  // NB: Using the server salt as a straight encryption key
	  //     is a BAD idea as CCM is a stream crypto.
	  ccm->set_encrypt_key(Crypto.SHA256.hash(roxenp()->query("server_salt") +
						  "\0" + entry->key_hash));
	  entry->data = ccm->crypt(body) + ccm->digest();

	  keys += ({ entry });
	  break;

	case "CERTIFICATE REQUEST":
	  // Ignore CSRs for now.
	  break;

	default:
	  werror("Unsupported PEM message: %O\n", msg->pre);
	  break;
	}
      }
    };
  if (err) {
    werror("Failed to handle PEM file:\n");
    master()->handle_error(err);
  }

  werror("New keys: %d\n", sizeof(keys));

  foreach(keys, mapping(string:string|int) key_info) {
    tmp = db->typed_query("SELECT * "
			  "  FROM cert_keys "
			  " WHERE keyhash = %s",
			  key_info->keyhash);
    if (!sizeof(tmp)) {
      db->query("INSERT INTO cert_keys "
		"       (pem_id, msg_no, keyhash, data) "
		"VALUES (%d, %d, %s, %s)",
		key_info->pem_id, key_info->msg_no,
		key_info->keyhash, key_info->data);
      key_info->id = db->master_sql->insert_id();

      // Check if we have any matching certificates that currently lack keys,
      // and add corresponding keypairs.
      foreach(db->typed_query("SELECT * "
			      "  FROM certs "
			      " WHERE keyhash = %s "
			      " ORDER BY id ASC",
			      key_info->keyhash),
	      mapping(string:string|int) cert_info) {
	if (sizeof(db->query("SELECT * "
			     "  FROM cert_keypairs "
			     " WHERE cert_id = %d",
			     cert_info->id))) {
	  // Keypair already exists.
	  continue;
	}
	db->query("INSERT INTO cert_keypairs "
		  "       (cert_id, key_id) "
		  "VALUES (%d, %d)",
		  cert_info->id, key_info->id);
      }
    } else {
      // Zap any stale or update in progress marker for the key.
      db->query("UPDATE cert_keys "
		"   SET pem_id = %d, "
		"       msg_no = %d "
		" WHERE id = %d",
		key_info->pem_id, key_info->msg_no,
		tmp[0]->id);
    }
  }

  foreach(certs, mapping(string:string|int) cert_info) {
    tmp = db->typed_query("SELECT * "
			  "  FROM certs "
			  " WHERE keyhash = %s "
			  "   AND subject = %s "
			  "   AND issuer = %s",
			  cert_info->keyhash,
			  cert_info->subject,
			  cert_info->issuer);
    if (!sizeof(tmp)) {
      db->query("INSERT INTO certs "
		"    (pem_id, msg_no, subject, issuer, expires, keyhash, data) "
		"VALUES (%d, %d, %s, %s, %d, %s, %s)",
		cert_info->pem_id, cert_info->msg_no,
		cert_info->subject, cert_info->issuer,
		cert_info->expires, cert_info->keyhash, cert_info->data);
      cert_info->id = db->master_sql->insert_id();

      // Check if we have a matching private key.
      tmp = db->typed_query("SELECT * "
			    "  FROM cert_keys "
			    " WHERE keyhash = %s "
			    " ORDER BY id ASC",
			    cert_info->keyhash);
      if (sizeof(tmp)) {
	// FIXME: Key selection policy.
	db->query("INSERT INTO cert_keypairs "
		  "       (cert_id, key_id) "
		  "VALUES (%d, %d)",
		  cert_info->id, tmp[0]->id);
      }

      if (cert_info->subject != cert_info->issuer) {
	// Not a self-signed certificate.

	// Check if we have the cert that this cert was signed by.
	tmp = db->typed_query("SELECT * "
			      "  FROM certs "
			      " WHERE subject = %s",
			      cert_info->issuer);
	if (sizeof(tmp)) {
	  db->query("UPDATE certs "
		    "   SET parent = %d "
		    " WHERE id = %d",
		    tmp[0]->id,
		    cert_info->id);
	}
      }

      // Update any cert that lacks a parent and
      // is signed by us.
      tmp = db->typed_query("UPDATE certs "
			    "   SET parent = %d "
			    " WHERE issuer = %s "
			    "   AND parent IS NULL "
			    "   AND subject != issuer",
			    cert_info->id,
			    cert_info->subject);
    } else if (tmp[0]->expires <= cert_info->expires) {
      // NB: Keep more recent certificates unmodified (even if stale).
      // NB: keyhash, subject and issuer are unmodified (cf above).
      db->query("UPDATE certs "
		"   SET pem_id = %d, "
		"       msg_no = %d, "
		"       expires = %d, "
		"       data = %s "
		" WHERE id = %d",
		cert_info->pem_id, cert_info->msg_no,
		cert_info->expires, cert_info->data,
		tmp[0]->id);
    }
  }
}

void refresh_pem(int pem_id)
{
  object privs = Privs("Reading cert file");

  low_refresh_pem(pem_id);
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

  array(mapping(string:int|string)) row =
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
  foreach(map(pem_files, String.trim_whites), string pem_file) {
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

  array(mapping(string:string|int)) tmp =
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
					  "\0" + tmp[0]->key_hash));
  string digest = tmp[0]->data[<Crypto.AES.CCM.digest_size()-1..];
  string raw = ccm->crypt(tmp[0]->data[..<Crypto.AES.CCM.digest_size()]);
  if (digest != ccm->digest()) {
    werror("Invalid key digest for key #%d. Has the server salt changed?\n",
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
    werror("Missing certificate (#%d) for keypair %d.\n", cert_id, keypair_id);
    return 0;
  }

  return ({ private_key, certs });
}
