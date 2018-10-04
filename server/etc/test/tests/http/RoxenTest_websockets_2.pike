inherit "../pike_test_common";

class Connection {
  inherit Protocols.WebSocket.Connection;

  Concurrent.Promise p;
  array(string) tosend = ({});
  array received = ({});

  void send_next()
  {
    if (sizeof(tosend)) {
      send_text(tosend[0]);
      tosend = tosend[1..];
      return;
    }
    close();
  }

  void got_open(mixed id)
  {
    received += ({ -1 });
    send_next();
  }

  void got_close(int reason, mixed id)
  {
    received += ({ reason });
    p->success(received);
  }

  void got_message(Protocols.WebSocket.Frame frame, mixed id)
  {
    if (frame->opcode == Protocols.WebSocket.FRAME_TEXT) {
      received += ({ frame->text });
      send_next();
    }
  }

  protected void create(Concurrent.Promise p)
  {
    this::p = p;
    onclose = got_close;
    onopen = got_open;
    onmessage = got_message;

    ::create();
  }
}

void run_tests(Configuration c)
{
  foreach(c->query("URLs"), string url) {
    if (!has_prefix(url, "http://") && !has_prefix(url, "https://")) {
      continue;
    }
    url = (url/"#")[0];

    Standards.URI uri = Standards.URI("websocket_example/", url);

    Concurrent.Promise p = Concurrent.Promise();
    Connection ws = Connection(p);

    array expect = ({ -1 });
    for (int i = 0; i < 5; i++) {
      ws->tosend += ({ sprintf("%d %d", 17, i+1) });
      expect += ({ sprintf("%d %d", i+1, 17) });
    }
    expect += ({ Protocols.WebSocket.CLOSE_NORMAL });
    if (test_true(ws->connect, uri)) {
      test_equal(expect, p->future()->get);
    }

    p = Concurrent.Promise();
    ws = Connection(p);

    expect = ({ -1 });
    for (int i = 0; i < 5; i++) {
      ws->tosend += ({ sprintf("%d %d", 18, i+1) });
      expect += ({ sprintf("%d %d", i+1, 18) });
    }
    // Sending a message with the wrong id should trigger
    // a remote close.
    ws->tosend += ({ sprintf("%d %d", 19, 7) });
    expect += ({ Protocols.WebSocket.CLOSE_NORMAL });
    // NB: The following two should not generate any messages
    //     (or even be sent).
    ws->tosend += ({ sprintf("%d %d", 18, 8) });
    ws->tosend += ({ sprintf("%d %d", 18, 9) });
    array expected_trailers = ws->tosend[sizeof(ws->tosend)-2..];
    if (test_true(ws->connect, uri)) {
      test_equal(expect, p->future()->get);
      test_equal(expected_trailers, `->, ws, "tosend");
    }
  }
}
