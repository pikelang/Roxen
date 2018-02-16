// jshint esversion: 5

(function() {
  'use strict';

  var lib = {};

  /* Find `what` in `ctx` and call `fun` for every match
   *
   * @param DOMElement ctx
   * @param string what
   *  A query selector pattern
   * @param function fun
   *  Will be called with the matched element as context (this).
   *  First argument is the counter, second is the matched element, same
   *  as jQuery's `each`.
   */
  lib.every = function(ctx, what, fun) {
    var r = ctx.querySelectorAll(what);

    if (r) {
      var i = 0;
      [].forEach.call(r, function(e) {
        fun.call(e, i++, e);
      });
    }
  };

  /* Find the next node of `what` from `el`
   *
   * @param DOMElement el
   * @param string what.
   *  This should be a tag name
   */
  lib.next = function(el, what) {
    var next = el.nextSibling;
    what = what.toUpperCase();

    while (next && next.nodeName !== what) {
      next = next.nextSibling;
    }

    return next;
  };

  /* Find the closest parent with tagname `tag` of `node`.
   *
   * @param DOMElement node
   * @param string tag
   *  Tag name ot find
   */
  lib.closest = function(node, tag) {
    tag = tag.toUpperCase();

    do {
      node = node.parentNode;

      if (node && node.nodeName === tag) {
        return node;
      }
    } while (node);
  };


  // Trigger a custom `event` on `el`
  lib.trigger = function(el, event, options) {
    var ev;

    if (window.CustomEvent) {
      ev = new window.CustomEvent(event, options);
    }
    else {
      ev = document.createEvent('CustomEvent');
      ev.initCustomEvent(ev, true, true, options);
    }

    el.dispatchEvent(ev);
    return ev.returnValue;
  };

  /* Run `fn` on DOMContentLoaded
   */
  lib.domready = function(fn) {
    document.addEventListener('DOMContentLoaded', fn);
  };


  lib.getCookie = function(name) {
    name += "=";
    var cookies = document.cookie.split(';');

    for (var i = 0; i < cookies.length; i++) {
      var c = cookies[i];
      c = c.trim();
      // This means that c starts with `name`, i.e. our cookie
      if (!c.indexOf(name)) {
        return c.substring(name.length);
      }
    }
  };

  lib.getWizardId = function() {
    var wizinp = document.querySelector('input[name="_roxen_wizard_id"]');
    return (wizinp && wizinp.value) || lib.getCookie('RoxenWizardId') || '';
  };

  var AJX = function() {
    var client, isPending, _ = this;

    this.abort = function() {
      if (client && client.abort()) {
        client = 0;
      }
    };

    this.get = function(url, onok, onfail) {
      if (isPending) {
        _.abort();
      }

      client = new XMLHttpRequest();
      client.withCredentials = true;

      isPending = true;

      client.onreadystatechange = function() {
        if (client.readyState === 4) {
          isPending = false;

          if (client.status === 200 || client.status === undefined) {
            if (onok) {
              var d = client.responseText;

              if (client.responseType && client.responseType === 'json') {
                try { d = JSON.parse(d); }
                catch (ignore) {}
              }

              onok(d);
            }
          }
          else if (onfail) {
            onfail(client.status, client.statusText);
          }

          client = null;
        }
      };

      client.open('GET', url, true);
      client.send(null);
    };
  };

  lib.fetchInto = function(what, where, cb) {
    new AJX().get(what,
      function(r) {
        if (r === '-1') {
          setTimeout(function() {
            lib.fetchInto(what, where, cb);
          }, 300);
        }
        else {
          var el = document.getElementById(where);
          el.innerHTML = r;

          if (cb) {
            cb(true);
          }
        }
      },
      function(code, text) {
        window.console.error('Fetch error: ',  code, text);
        if (cb) {
          cb(false);
        }
      });
  };

  lib.wget = new AJX().get;

  window.rxnlib = lib;

}(window, document));
