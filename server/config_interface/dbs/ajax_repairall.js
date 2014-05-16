var xmlHttp;

function callPike()
{
	xmlHttp = GetXMLHttpObject();
	if( xmlHttp == null )
	{
		document.getElementById("result").innerHTML = "<font color='red'><b>Error:</b></font> Your browser does not support AJAX.";
		return;
	}
	
	document.getElementById("result").innerHTML = "<table cellspacing='0' cellpadding='2'><tr><td><img src=\"/internal-roxen-spinner-white\" width=\"17\" height=\"17\"/></td><td class='df_text'><b>Executing...</b></td></tr></table>";
	
	var url = "/dbs/db_repairall_ajax.pike";
	xmlHttp.onreadystatechange = stateChanged;
	xmlHttp.open( "GET", url, true );
	xmlHttp.send( null );
}

function stateChanged()
{
	if( xmlHttp.readyState == 4 || xmlHttp.readyState == "Complete" ) {
		document.getElementById("result").innerHTML = xmlHttp.responseText;
	}
}

function GetXMLHttpObject()
{
	var objXmlHttp = null;
	if( window.XMLHttpRequest )
		objXmlHttp = new XMLHttpRequest();
	else if( window.ActiveXObject ) {
		try {
			objXmlHttp = new ActiveXObject( "Msxml2.XMLHTTP" );
		} catch (e) {
			objXmlHttp = new ActiveXObject( "Microsoft.XMLHTTP" );
		}
	}

	return objXmlHttp;
}
