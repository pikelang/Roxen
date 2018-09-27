inherit "http_common";

// NB: Keep in sync with RoxenTest_websockets.pike.
enum brokeness {
  REQUEST_OK,
  REQUEST_BAD_PATH,
  REQUEST_BAD_PATH_SUFFIX,
  REQUEST_HTTP_1_0,
  REQUEST_NO_HDR_CONNECTION,
  REQUEST_BAD_HDR_CONNECTION,
  REQUEST_NO_HDR_UPGRADE,
  REQUEST_BAD_HDR_UPGRADE,
  REQUEST_NO_HDR_VERSION,
  REQUEST_BAD_HDR_VERSION,
  REQUEST_NO_HDR_KEY,
  REQUEST_BAD_HDR_KEY,
  REQUEST_MAX_BROKENESS,
}

// websocket.pike <url> <path> <brokeness>
void main(int argc, array argv)
{
  string  sep = "\r\n";
  int     psize = 100000;
  if( argc < 4 )
    exit( BADARG );

  int broken = (int)argv[3];

  if ((broken < REQUEST_OK) || (broken >= REQUEST_MAX_BROKENESS))
    exit(BADARG);

  Stdio.File f = connect(  argv[1] );

  Standards.URI uri = Standards.URI(argv[1]);

  string http_path = argv[2];
  string http_version = "1.1";
  int http_status = Protocols.HTTP.HTTP_BAD;
  mapping(string:string) headers = ([
    "User-Agent": sprintf("Roxen WebSocket Testscript %d", broken),
    "Host": uri->host,
    "Connection": "UpGraDe",
    "Upgrade": "websocket",
    "Sec-WebSocket-Version": "13",
    "Sec-WebSocket-Key":
    MIME.encode_base64(Crypto.Random.random_string(16), 1),
  ]);

  switch(broken) {
  case REQUEST_OK:
    http_status = Protocols.HTTP.HTTP_SWITCH_PROT;
    break;
  case REQUEST_BAD_PATH:
    http_path = "/";
    break;
  case REQUEST_BAD_PATH_SUFFIX:
    http_path += "invalid";
    http_status = Protocols.HTTP.HTTP_NOT_FOUND;
    break;
  case REQUEST_HTTP_1_0:
    http_version = "1.0";
    break;
  case REQUEST_NO_HDR_CONNECTION:
    m_delete(headers, "Connection");
    break;
  case REQUEST_BAD_HDR_CONNECTION:
    headers["Connection"] = "close";
    break;
  case REQUEST_NO_HDR_UPGRADE:
    m_delete(headers, "Upgrade");
    break;
  case REQUEST_BAD_HDR_UPGRADE:
    headers["Upgrade"] = "Invalid";
    break;
  case REQUEST_NO_HDR_VERSION:
    m_delete(headers, "Sec-WebSocket-Version");
    break;
  case REQUEST_BAD_HDR_VERSION:
    headers["Sec-WebSocket-Version"] = "999";
    break;
  case REQUEST_NO_HDR_KEY:
    m_delete(headers, "Sec-WebSocket-Key");
    break;
  case REQUEST_BAD_HDR_KEY:
    headers["Sec-WebSocket-Key"] = "Invalid";
    break;
  default:
    werror("Missing handling of brokeness %d\n", broken);
    exit(BADARG);
  }

  string websocket_accept =
    MIME.encode_base64(Crypto.SHA1.hash(headers["Sec-WebSocket-Key"] +
					Protocols.WebSocket.websocket_id), 1);

  string tosend = sprintf("GET %s HTTP/%s\r\n",
			  http_path, http_version);
  foreach(sort(indices(headers)), string header) {
    tosend += sprintf("%s: %s\r\n", header, headers[header]);
  }
  tosend += "\r\n";

  write_fragmented( f, tosend, psize );

  string _d = "";

  while (!has_value(_d, "\r\n\r\n")) {
    _d += f->read(128, 1);
  }

  array q = _d/"\r\n\r\n";
  if( sizeof( q ) < 2 )
    exit( BADHEADERS );

  mapping ret_headers =
    verify_headers(q[0], -1, "HTTP/" + http_version, http_status, -1);

  if (!broken) {
    mapping expected_headers = ([
      "connection": "upgrade",
      "sec-websocket-accept": websocket_accept,
      // "sec-websocket-version": "13",
      "upgrade": "websocket",
    ]);
    foreach(sort(indices(expected_headers)), string header) {
      string value = ret_headers[header];
      if (header != "sec-websocket-accept") {
        value = value && lower_case(value);
      }
      if (value != expected_headers[header]) {
	werror("Bad headers (%O):\n"
	       "Got: %O\n"
	       "Expected: %O\n",
	       header, ret_headers, expected_headers);
	exit(BADHEADERS);
      }
    }
  }

  exit( OK );
}
