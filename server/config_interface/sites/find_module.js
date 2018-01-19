//  Written by Jonas Walldén, jonasw@roxen.com

    function get_cookie(cookie_name)
    {
      cookie_name += "=";
      var cookies = document.cookie.split(';');
      var i;
      for (i = 0; i < cookies.length; i++) {
        var c = cookies[i];
        // Zap white space.
        while (c.charAt(0) == ' ')
          c = c.substring(1);
        if (!c.indexOf(cookie_name))
          return c.substring(cookie_name.length);
      }
      return "";
    }

    function get_wizard_id_cookie() {
      if (window.location.protocol == "https:") {
        return get_cookie("RoxenHttpsWizardId");
      }
      return get_cookie("RoxenHttpWizardId");
    }

    //  Query
    var query_old_txt = "";
    var query_callout = 0;
    var query_xml_req = 0;
    var query_query;
    var query_search_base = "add_module.pike?_roxen_wizard_id=" +
                            get_wizard_id_cookie() + "&mod_query=";
    var query_config = "";
    var query_method = "";

    function query_spinning_indicator(on)
    {
      var o = document.getElementById("mod_spinner");
      if (o) {
        o.style.display = "inline";
        var cur_on = o.style.visibility == "visible";
        if (cur_on != on)
          o.style.visibility = on ? "visible" : "hidden";
      }
    }

    function query_kill_request()
    {
      if (query_xml_req) {
        query_xml_req.abort();
        query_xml_req = 0;
      }
    }

    function query_display_result(xml)
    {
      var def = document.getElementById("mod_default");
      var res = document.getElementById("mod_results");
      if (!xml) {
        def.style.display = "block";
        res.style.display = "none";
        res.innerHTML = "";
      } else {
        def.style.display = "none";
        res.style.display = "block";
        res.innerHTML = xml;
      }
    }

    function query_send_request()
    {
      //  Flag that we're no longer waiting for a callout
      if (query_callout) {
        window.clearTimeout(query_callout);
        query_callout = 0;
      }

      //  Indicate to user that request will be sent to server
      query_spinning_indicator(1);

      //  Kill any other request that may be pending
      query_kill_request();

      //  Create a new one. We'll get rid of any Unicode characters in the
      //  query string since some browsers escape them incorrectly.
      var src = query_search_base + escape(query_query);

      //  Add config and method variables
      src += "&config=" + query_config + "&method=" + query_method;

      query_xml_req = 0;
      if (window.XMLHttpRequest) {
        //  Use XMLHttpRequest which is implemented in Safari and
        //  Mozilla/Firefox
        query_xml_req = new XMLHttpRequest();
      } else {
        //  Use ActiveX version for MSIE
        try {
          query_xml_req = new ActiveXObject("Msxml2.XMLHTTP");
        } catch (e) {
          try {
            query_xml_req = new ActiveXObject("Microsoft.XMLHTTP");
          } catch (e) {
            query_xml_req = 0;
          }
        }
      }
      if (query_xml_req) {
        query_xml_req.onreadystatechange = function() {
          if (query_xml_req.readyState == 4) {
            //  Stop spinning indicator
            query_spinning_indicator(0);

            //  Safari 1.3/2.0 reports "undefined" for repeated
            //  requests to the same URL. It's also over-cached even
            //  if the server sets expire headers correctly, but not
            //  much we can do about that.
            if (query_xml_req.status == 200 ||
                query_xml_req.status == undefined) {
              query_display_result(query_xml_req.responseText);
              query_xml_req = 0;
            }
          }
        };
        query_xml_req.open("GET", src, true);
        query_xml_req.send(null);
      }
    }

    function query_update_results(event)
    {
      window.setTimeout(query_update_results_internal, 10);
      return true;
    }

    function query_update_results_internal()
    {
      //  Get current query string and check whether it's changed
      //  compared to the last time.
      var inp = document.getElementById("mod_query");
      var cur_txt = inp.value;
      if (cur_txt != query_old_txt) {
        //  Yes, string has changed. We want to send it to the server,
        //  but to avoid excessive amounts of requests we'll postpone
        //  it for 0.5 seconds and only continue if the text field is
        //  left unchanged for this period. Otherwise we reset the timer
        //  and keep waiting.
        query_old_txt = cur_txt;
        if (query_callout) {
          window.clearTimeout(query_callout);
          query_callout = 0;
        }
        if (cur_txt == "") {
          //  No need to send anything. We also kill any outstanding
          //  request that's been made so far.
          query_display_result(0);
          query_spinning_indicator(0);
          query_kill_request();
        } else {
          //  Schedule a request 0.5 seconds from now
          query_query = cur_txt;
          query_callout =
            window.setTimeout(query_send_request, 500);
        }
      }
      return true;
    }
