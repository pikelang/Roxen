function XHRPromiseJSON(method, url, data)
{
  return new Promise(function (resolve, reject) {
      var xhr = new XMLHttpRequest();
      xhr.open(method, url);
      xhr.setRequestHeader("Content-Type", "application/json");
      xhr.setRequestHeader("X-Roxen-API", "true");
      xhr.onload = resolve;
      xhr.onerror = reject;

      // Create blob with JSON body if present
      var blob = null;
      if (data) {
        blob = new Blob( [ JSON.stringify(data, null, 2) ],
                         { type: "application/json" } );
        blob = JSON.stringify(data);
      }
      xhr.send(blob);
    });
}


function get_conf_and_mod()
{
  var url = window.location.pathname;
  var re = RegExp("^/sites/site.html/(.+)/.+/(.+)/");
  var parts = re.exec(url);
  if (parts && (parts.length === 3)) {
    return { conf: parts[1], mod: parts[2] };
  }
  return undefined;
}


function mod_var_api(method, v, data)
{
  return new Promise(function(resolve, reject) {
      var ctx = get_conf_and_mod();
      if (ctx) {
        var url =
          "/rest/configurations/" + ctx.conf +
          "/modules/" + ctx.mod +
          "/variables/" + v;
        XHRPromiseJSON(method, url, data)
          .then(function(ok_res) {
              resolve(ok_res.target.response);
            },
            function(err_res) {
              console.log("XHR promise failed: ", err_res);
              reject(0);
            });
      } else {
        reject(0);
      }
    });
}


function get_mod_var(v)
{
  return mod_var_api("GET", v);
}


function set_mod_var(v, data)
{
  return mod_var_api("PUT", v, data);
}


//  -------------------------------------------------------------------


var notesEl;

function notes_dirty()
{
  return notesEl && notesEl.classList.contains("dirty");
}

function toggle_collapsed()
{
  if (notesEl)
    notesEl.classList.toggle("collapsed");
}

function save_notes()
{
  var msgEl = notesEl && notesEl.getElementsByClassName("msg")[0];
  var saveEl = notesEl.getElementsByClassName("save")[0];
  if (msgEl && notes_dirty()) {
    var msg = msgEl.value;
    flag_dirty(false);
    set_mod_var("_notes", msg)
      .then(function(res) {
          notesEl.classList.add("collapsed");
        })
      .catch(function(err) {
          flag_dirty(true);
          window.alert("Failed to save notes.");
        });
  }
}


function flag_dirty(is_dirty)
{
  if (notesEl)
    notesEl.classList.toggle("dirty", !!is_dirty);
}


function msg_changed()
{
  flag_dirty(true);
  check_empty_msg();
}


function check_empty_msg()
{
  if (notesEl) {
    var msgEl = notesEl.getElementsByClassName("msg")[0];
    var is_empty = msgEl && !msgEl.value.length;
    notesEl.classList.toggle("empty-msg", !!is_empty);
  }
}


function create_notes_widget()
{
  var siteEl = document.getElementById("_site");
  if (siteEl && !notesEl) {
    notesEl = document.createElement("div");
    notesEl.id = "_notes";
    notesEl.className = "collapsed";
    notesEl.innerHTML =
      "<span class='icon dirty'>&#xf14b;</span>" +    //  fa-pencil-square
      "<span class='icon got-msg'>&#xf0e5;</span>" +  //  fa-comment-o
      "<div class='title'>Module Notes</div>" +
      "<div class='body'>" +
      "<textarea class='msg'></textarea>" +
      "<div class='actions'>" +
      "<span class='button save disabled'>Save</span>" +
      "</div>";
    siteEl.appendChild(notesEl);

    var titleEl = notesEl.getElementsByClassName("title")[0];
    titleEl.addEventListener("click", toggle_collapsed, false);

    var saveEl = notesEl.getElementsByClassName("save")[0];
    saveEl.addEventListener("click", save_notes, false);

    var msgEl = notesEl.getElementsByClassName("msg")[0];
    if (msgEl)
      msgEl.addEventListener("input", msg_changed, false);
    check_empty_msg();

    get_mod_var("_notes")
      .then(function(res) {
          var msgEl = notesEl.getElementsByClassName("msg")[0];
          if (msgEl) {
            var msg_decoded = JSON.parse(res);
            if (msg_decoded && (typeof msg_decoded === "string")) {
              msgEl.value = msg_decoded;
              check_empty_msg();
            }
          }
        }).
      catch(function(err) {
        });;
  }
}



if (get_conf_and_mod()) {
  create_notes_widget();
}
