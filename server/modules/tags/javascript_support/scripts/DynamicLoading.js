// -*- java -*-
// This file is part of ChiliMoon. Copyright (c) 2001, Roxen IS.

// DynamicLoading: A component for dynamic loading of documents into layers. 
// different methods are used to accomplish this. For Netscape 4 the layer/src
// method is used. For IE4/Mozilla the iframe/iframe/src method is used.
// Unfortunately Mozilla has some problems with iframe creation and the onload event.
// The workaround is to add "onLoad='file_loader = new FileLoader(layerLoadHandler)'"
// to the base document body tag and onLoad="var fl = top.FileLoader.elements[0];
// fl.loaded = true; fl.document = document; fl.onload(fl);" to the popup document
// body tag.
// In Mozilla 0.9.1 the popup document body patch is not neaded.

// FileLoader: Constructor for the FileLoader class.
// Creates a FileLoader object who calls the <onload> function when the
// document is loaded.
function FileLoader(onload)
{
  this.id = FileLoader.cnt;
  FileLoader.elements[FileLoader.cnt++] = this;
  this.onload = onload;
  this.createIFRAME();
}

// FileLoader.createIFRAME: Creates an iframe att the bottom of the current document.
FileLoader.prototype.createIFRAME = function()
{
  this.frameName = 'FileLoader' + this.id;
  if (document.all) { // IE
    var html = '';
    html += '<iframe id="' + this.frameName + '"';
    html += ' name="' + this.frameName + '"';
    html += ' style="display: none;"';
    html += ' src="about:blank">';
    html += '<\/iframe>';
    document.body.insertAdjacentHTML('beforeEnd', html);
  }
  else if (document.getElementById) { // Mozilla
    var ifr = document.createElement('iframe');
    ifr.id = ifr.name = this.frameName;
    ifr.style.visibility = 'hidden'; // just for testing
    ifr.width = 1; ifr.height = 1;
    ifr.src = 'about:blank';
    document.body.appendChild(ifr);
  }
}

// FileLoader.loadDocument: Creates an iframe inside the current documents bottom
// iframe with an external src <url> who loads the document and calls .
FileLoader.prototype.loadDocument = function(url)
{
  this.loaded = false;
  this.document = null;
  var ifrWin = 
    document.all ? document.frames[this.frameName] :
    window.frames[this.frameName];
  var html = '';
  html += '<html><body ';
  html += 'onLoad="';
  html += 'var fl = top.FileLoader.elements[' + this.id + '];';
  html += 'fl.loaded = true;';
  html += 'fl.document = window.frames[0].document;';
  html += 'fl.onload(fl);"';
  html += '>';
  html += '<iframe src="' + url + '"><\/iframe>';
  html += '<\/body><\/html>';
  ifrWin.document.open();
  ifrWin.document.write(html);
  ifrWin.document.close();
}

FileLoader.cnt = 0;
FileLoader.elements = new Array();

// layerLoadHandler: Handles a loaded document from the file loader <file_loader>.
// Sets the layers content to the loaded documents content and displays the layer.
// The argument <file_loader> is not present if Nav4.
function layerLoadHandler(file_loader)
{
  var layer = (isNav4? this.name: file_loader.layer_name);
  var properties = (isNav4? this.properties: file_loader.properties);

  if(!isNav4) {
    var o = getObject(layer);
    o.innerHTML = "";
    o.innerText = "";
    o.innerHTML = file_loader.document.body.innerHTML;
  }
  boundPopup(layer);
  addPopup(layer, properties);
  captureMouseEvent(popupMove);
  show(layer);
}

var file_loader;

// loadLayer: Loads document <src> into the layer <layer_name> with the
// properties <properties>. 
function loadLayer(e, layer_name, src, properties, parent)
{
  if(popups.length != 0 &&
     popups[popups.length - 1].name == layer_name &&
     properties.hide_2nd_click) {
    clearToPopup(parent);
    return retFromEvent(false);
  }

  if(!properties.stay_put)
    clearToPopup(parent);
  else if(popups.length)
    popups.length--;

  if(isNav4)
  {
    var l = getObject(layer_name);
    if(!l)
      alert("Unknown layer '"+layer_name+"'.");
    l.name = layer_name;
    l.onload = layerLoadHandler;
    l.src = src;
    l.properties = properties;
  }
  else
  {
    if(!file_loader || isMacIE50)
      file_loader = new FileLoader(layerLoadHandler);
    
    file_loader.layer_name = layer_name;
    file_loader.properties = properties;
    file_loader.loadDocument(src);
  }
  var pos = new properties.LayerPosition(new TriggerCoord(e, 0), 0, properties);
  if(!properties.stay_put)
    shiftTo(layer_name, pos.x, pos.y);
  return retFromEvent(false);
}
