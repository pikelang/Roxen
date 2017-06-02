// jshint esversion: 6

(function(window, document) {
  'use strict';

  const getCookie = function(name) {
    name += "=";
    const cookies = document.cookie.split(';');

    for (let c of cookies) {
      c = c.trim();
      // This means that c starts with `name`, i.e. our cookie
      if (!c.indexOf(name)) {
        return c.substring(name.length);
      }
    }
  };

  const getMethod = function() {
    const l = document.getElementById('list-type');
    return l.options[l.selectedIndex].value;
  };

  const getShowDeprecated = function() {
    return document.getElementById('deprecated_').checked &&
      '&deprecated=1' || '';
  };

  const wizid      = getCookie('RoxenWizardId')||'';
  const inp        = document.getElementById('mod-query');
  const spinner    = document.getElementById('mod-spinner');
  const defMods    = document.getElementById('mod_default');
  const resMods    = document.getElementById('mod_results');
  const queryDelay = 400;
  const queryUrl   = `add_module.pike?_roxen_wizard_id=${wizid}&config=`     +
                     `${document.querySelector('input[name=config]').value}` +
                     `&method=${getMethod()}${getShowDeprecated()}`          +
                     `&mod_query=`;

  let calloutId, cli, locked, lastQuery, spinnerCallout;

  const doSpinner = function(hide) {
    clearTimeout(spinnerCallout);

    if (hide) {
      spinner.style.display = 'none';
    }
    else {
      spinnerCallout = setTimeout(() => spinner.style.display = 'inline-block',
                                  queryDelay);
    }
  };

  const handleResult = function(res) {
    doSpinner(true);
    locked = false;

    const show = function(def) {
      if (def) {
        defMods.style.display = 'block';
        resMods.style.display = 'none';
      }
      else {
        defMods.style.display = 'none';
        resMods.style.display = 'block';
      }
    };

    // Set new search result
    if (typeof res === 'string') {
      resMods.innerHTML = res;
      show(false);
    }
    // Show default listing
    else if (res === 1) {
      show(true);
    }
    // Show previous search result
    else if (res === -1) {
      show(false);
    }
    else if (res === 0) {
      window.console.log('Show some search error?');
    }
  };

  const doQuery = function() {
    if (locked) {
      window.console.log('Query running, skipping');
      return;
    }

    if (inp.value) {
      if (lastQuery && inp.value === lastQuery) {
        handleResult(-1);
        return;
      }

      doSpinner();

      const q = queryUrl + encodeURIComponent(inp.value);
      const req = new Request(q, { credentials: 'same-origin' });

      locked = true;

      cli = fetch(req)
        .then(r => {
          if (r.status === 200) {
            return r.text();
          }
          window.console.error('bad status, propagate?: ', r);
          throw 'Bad status';
        })
        .then(r => {
          lastQuery = inp.value;
          handleResult(r);
        })
        .catch(e => {
          handleResult(0);
        });
    }
    else {
      handleResult(1);
    }
  };


  inp.addEventListener('keydown', e => clearTimeout(calloutId));
  inp.addEventListener('input', e => calloutId = setTimeout(doQuery, queryDelay));

}(window, document));
