function renderLink(text, action, base, target)
{
  return "<br>&nbsp;&nbsp;&nbsp;<a href='"+base+"?action="+action+"' "+
    (target != ""?" target='"+target+"' ":"")+
    "onMouseOver=\"setStatus('"+text+"');\" "+
    "onMouseOut=\"setStatus('');\""+
    ">"+text+"</a>&nbsp;&nbsp;\n";
}

function renderStyle(id)
{
  return "<style>#"+id+
    " {position:absolute; left:0; top:0; visibility:hidden}</style>\n";
}

function renderIcon(id, icon, text)
{
  return "<div id='"+id+"'><img border=0 src='"+icon+"' alt=''>"+text+"</div>";
}

function doDrop()
{
  if(modifiers & Event.CONTROL_MASK) {
    if(!(src_actions>>11&1)) {
      alert("Can not copy this file/directory");
      return;
    }
    if(confirm('Copy '+src_path+' to '+dest_name+'.'))
      window.location = (src_url+'?&action=copy.pike'+
			 '&destdir='+dest_name+
			 '&destname='+src_name);
    return;
  }
  if(!(src_actions>>12&1)) {
    alert("Can not move this file/directory, try to commit it first");
    return;
  }
  if(confirm('Move '+src_path+' to '+dest_name+'.'))
    window.location = (src_url+'?&action=move.pike'+
		       '&destdir='+dest_name+
		       '&destname='+src_name);
}

function setPStat()
{
  setStatus("Click on icon to raise action menu.");
}

// Function to possition a netscape layer.
function bound_me_nicely()
{
  if( (this.left + this.clip.width - window.pageXOffset) > (window.innerWidth - 16) )
    this.left = window.innerWidth - this.clip.width + window.pageXOffset - 16;
  if( this.left < window.pageXOffset )
    this.left = Math.max(0, window.pageXOffset);
  if( (this.top + this.clip.height - window.pageYOffset) > (window.innerHeight) )
    this.top = window.innerHeight - this.clip.height + window.pageYOffset;
  if( this.top < window.pageYOffset )
  {
    this.top = Math.max(0, this.top);
    window.scrollTo(window.pageXOffset,this.top);
  }
  //window.alert(this.width+'×'+this.height+'@'+this.left+'×'+this.top);
  this.visibility = "show";
}

// Function to show the netscape layer named 'popup'.
function showLayer(path, e)
{
  var l = document.layers['popup'];
  l = document.layers['popup'];
  l.top = e.target.y - 6;
  l.left = e.target.x - 6;
  l.onload = bound_me_nicely;
  l.zIndex = 1;
  l.src = path;
  return false;
}

// Function to render Internet Explorer popup.
function ieShowPopup(lang, path, url, url_target, actions)
{
  getObject("popup").innerHTML
    = renderPopup("popup", lang, path, url, url_target, actions, 1);
  return showPopup("popup", "none", 1, 1, 0);
}
