// jshint esversion: 5
/*
  This is a consolidation of the the two scripts dbs/ajax_optimizeall.js
  and dbs/ajax_repairall.js

  This script is referenced in dbs/db_optimizeall.html and dbs/db_repairall.html
*/

(function(window, document, R) {
  'use strict';

  var resTarget   = document.querySelector('#result'),
    resTargetText = resTarget.querySelector('.text'),
    href          = resTarget.dataset.dbHref,
    action        = resTarget.dataset.dbAction,
    wizid         = resTarget.dataset.wizid,
    typeStr       = resTarget.dataset.progressMsg,
    args          = [];

  if (!href) {
    resTarget.innerHTML =
      '<div class="notify error">No <code>data-db-href</code> attribute' +
      ' found on the result target. Something is really wrong!</div>';

    return;
  }

  if (action) {
    args.push('action=' + action);
  }

  if (wizid) {
    args.push(wizid);
  }

  if (args.length) {
    href += '?' + args.join('&');
  }

  resTargetText.innerHTML = typeStr || 'Doing things...';

  R.wget(href,
    function(res) {
      resTarget.innerHTML = res;
    },
    function(err) {
      resTarget.innerHTML =
        '<div class="notify error">' + err + '</div>';
    });

}(window, document, rxnlib));
