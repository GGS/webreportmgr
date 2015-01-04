
var transition = {pid: '', port:'7007'};
var active = false,
    protocol    = window.location.protocol == 'https:' ? "wss://" : "ws://",
    querystring = window.location.pathname + window.location.search,
    host        = null == transition.host ? window.location.hostname : transition.host,
    port        = null == transition.port ? window.location.port : transition.port,
    protos = [ $bert, $client ];

$(document).ready(init);
function init(){
    $('#server').val("ws://" + window.location.host + "/websocket");
    ws = new bullet(protocol + host + ":" + port + "/websocket");
    ws.onmessage = function (evt) { for (var i=0;i<protos.length;i++) { p = protos[i]; if (p.on(evt,p.do).status == "ok") return; } };
    ws.onopen = function() { if (!active) { console.log('Connect'); ws.send(['N2O', transition.pid]); active=true; } };
    ws.ondisconnect = function() { active = false; console.log('Disconnect'); };
};
 	

function toggle_connection(){
    if(websocket.readyState == websocket.OPEN){
        disconnect();
    } else {
        connect();
    };
};
function sendTxt() {
    txt = $("#send_txt").val();
    msg = Message("messageSent", txt);
    document.querySelector('#send_txt').value = '';
    ws.send(enc(tuple(atom(msg.event), utf8_toByteArray(msg.text), msg.name, msg.time)));
    //showScreen('sending: ' +  utf8_toByteArray(msg.text)); 
  
};

function onOpen(evt) { 
    showScreen('<span style="color: green;">CONNECTED </span>'); 
     console.log(evt);
    
};  

function onClose(evt) { 
    showScreen('<span style="color: red;">DISCONNECTED </span>');
};  


function onError(evt) {
    showScreen('<span style="color: red;">ERROR: ' + evt.data+ '</span>');
};

function showScreen(txt) { 
    $('#output').prepend('<p>' + txt + '</p>');
};

function clearScreen() 
{ 
    $('#output').html("");
};

function getCookie(cname) {
    var name = cname + "=";
    var ca = document.cookie.split(';');
    for(var i=0; i<ca.length; i++) {
        var c = ca[i];
        while (c.charAt(0)==' ') c = c.substring(1);
        if (c.indexOf(name) != -1) return c.substring(name.length,c.length);
    }
    return "";
}
function checkDel(sender) {
    var tr = sender.parentNode.parentNode.parentNode;
    msg = Message("delReport", tr.getAttribute('id'));
    ws.send(enc(tuple(atom(msg.event), utf8_toByteArray(msg.text), msg.name, msg.time)));
    }
function checkInfo(sender) {
    var tr = sender.parentNode;
    msg = Message("viewLog", tr.getAttribute('id'));
    ws.send(enc(tuple(atom(msg.event), utf8_toByteArray(msg.text), msg.name, msg.time)));
    $('#logcontainer').css('visibility','visible');
}
function delLog(sender) {
    $(sender).css('visibility','hidden');
    //alert(tr.getAttribute('id'));
   }
function Message (event, txt) {
    var msg = {
        event: event,
        text: txt,
        name:   getCookie("username"),
        time: clock()
    };
    return msg;
}

