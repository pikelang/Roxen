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
