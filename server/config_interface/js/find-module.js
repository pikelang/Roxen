// jshint esversion: 5

(function(window, document, R) {
  'use strict';

  var getMethod = function() {
    var l = document.getElementById('list-type');
    return l.options[l.selectedIndex].value;
  };

  var getShowDeprecated = function() {
    return document.getElementById('deprecated_').checked &&
      '&deprecated=1' || '';
  };

  var wizid      = R.getWizardId();
  var inp        = document.getElementById('mod-query');
  var spinner    = document.getElementById('mod-spinner');
  var defMods    = document.getElementById('mod_default');
  var resMods    = document.getElementById('mod_results');
  var queryDelay = 400;
  var queryUrl   =
    'add_module.pike?_roxen_wizard_id=' + wizid + '&config='  +
    document.querySelector('input[name=config]').value        +
    '&method=' + getMethod() + getShowDeprecated() + '&mod_query=';

  var calloutId, lastQuery, spinnerCallout;

  var doSpinner = function(hide) {
    clearTimeout(spinnerCallout);

    if (hide) {
      spinner.style.display = 'none';
    }
    else {
      spinnerCallout = setTimeout(function() {
        spinner.style.display = 'inline-block';
      }, queryDelay);
    }
  };

  var handleResult = function(res) {
    doSpinner(true);

    var show = function(def) {
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

  var doQuery = function() {
    if (inp.value) {
      if (lastQuery && inp.value === lastQuery) {
        handleResult(-1);
        return;
      }

      doSpinner();

      R.wget(queryUrl + encodeURIComponent(inp.value),
        function(r) {
          lastQuery = inp.value;
          handleResult(r);
        },
        function(code, text) {
          window.console.log('fetch error: ', code, text);
          handleResult(0);
        });
    }
    else {
      handleResult(1);
    }
  };

  inp.addEventListener('keydown', function() { clearTimeout(calloutId); });
  inp.addEventListener('input', function() { calloutId = setTimeout(doQuery, queryDelay); });

}(window, document, rxnlib));
