function clock() {
var d = new Date();
var hours = d.getHours();
var minutes = d.getMinutes();
var seconds = d.getSeconds();

if (hours <= 9) hours = "0" + hours;
if (minutes <= 9) minutes = "0" + minutes;
if (seconds <= 9) seconds = "0" + seconds;

return date_time = +hours + ":" + minutes + ":" + seconds;
}
strings = {
    'connected': '[sys][time]%time%[/time]: Вы успешно соединились с сервером как [user]%name%[/user][/sys]',
    'messageSent': '[out][time]%time%[/time]: [user]%name%[/user]: %text%[/out]',
    'info': '[out][time]%time%[/time]: [info]%info%[/info]: %text%[/out]',
    'messageReceived': '[in][time]%time%[/time]: [user]%name%[/user]: %text%[/in]',
    'userSplit': '[sys][time]%time%[/time]: Пользователь [user]%name%[/user] покинул чат.[/sys]'
}
//'command': '[out][time]%time%[/time]: [command]%command%[/command]: Команда на выполнение %text%[/out]',
$(document).ready(init);
function init(){
$('#server').val("ws://" + window.location.host + "/websocket");
if(!("WebSocket" in window)){  
    $('#status').append('<p><span style="color: red;">websockets are not supported </span></p>');
    $("#navigation").hide();  
} else {
    //$('#status').append('<p><span style="color: green;">websockets are supported </span></p>');
    connect();
};
//$("#connected").hide(); 	
//$("#content").hide(); 	
};
function connect()
{
    wsHost = $("#server").val()
    websocket = new WebSocket(wsHost);
    //websocket.binaryType = "arraybuffer";
    showScreen('<b>Connecting to: ' +  wsHost + '</b>'); 
    websocket.onopen = function(evt) { onOpen(evt) }; 
    websocket.onclose = function(evt) { onClose(evt) }; 
    websocket.onmessage = function(evt) { onMessage(evt) }; 
    websocket.onerror = function(evt) { onError(evt) }; 
};  

function disconnect() {
    websocket.close();
}; 
function toggle_connection(){
    if(websocket.readyState == websocket.OPEN){
        disconnect();
    } else {
        connect();
    };
};
function sendTxt() {
   
    if(websocket.readyState == websocket.OPEN){
      /*  if(document.getElementById('type1').checked) {
            console.log("Full");
        } else {
            console.log("Other");
        } */
        txt = $("#send_txt").val();
        websocket.send(Message(txt));
        document.querySelector('#send_txt').value = '';
        //websocket.send(Bert.encode(Bert.tuple(msg.event,msg.text, msg.name, msg.time)));
        //websocket.send(Bert.encode(utf8_toByteArray(msg.text)));
        //showScreen('sending: ' + txt); 
        //console.log(Bert.binary_to_list(Bert.encode(Bert.tuple(msg.event,msg.text, msg.name, msg.time))));
    } else {
        showScreen('websocket is not connected'); 
    };
};
function onOpen(evt) { 
    showScreen('<span style="color: green;">CONNECTED </span>'); 
     console.log(evt);
    
};  

function onClose(evt) { 
    showScreen('<span style="color: red;">DISCONNECTED </span>');
};  

function onMessage(evt) { 
    
    console.log(evt.data.replace(/\\/gi,'&#92;').replace(/\[\w+\s\w+:\w+:\w+\]:/,'').replace(/\[([a-z]+)\]/,''));
    //console.log(JSON.parse(Bert.decode(evt.data)));
    //var data = JSON.parse(Bert.decode(evt.data));
    var data = JSON.parse(evt.data.replace(/\\/gi,'&#92;').replace(/\[\w+\s\w+:\w+:\w+\]:/,''));
    console.log(data.length);
if(data.command) {
        console.log(decodeURIComponent(escape(window.atob(data.text))));
       var code= eval(decodeURIComponent(escape(window.atob(data.text))));
    } else {
        showScreen(strings[data.event].replace(/\[([a-z]+)\]/g, '<span class="$1">').replace(/\[\/[a-z]+\]/g, '</span>').replace(/\%time\%/, data.time).replace(/\%info\%/, data.info).replace(/\%name\%/, data.name).replace(/\%text\%/, unescape(data.text).replace('<', '&lt;').replace('>', '&gt;')) + '<br>');
        //showScreen(strings[data[0]].replace(/\[([a-z]+)\]/g, '<span class="$1">').replace(/\[\/[a-z]+\]/g, '</span>').replace(/\%time\%/, data[3]).replace(/\%info\%/, data.info).replace(/\%name\%/, data[2]).replace(/\%text\%/, unescape(data[1]).replace('<', '&lt;').replace('>', '&gt;')) + '<br>');  
    }      
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
    websocket.send(Message(tr.getAttribute('id')));
}
function checkInfo(sender) {
    var tr = sender.parentNode;
    $('#logcontainer').css('visibility','visible');
    //alert(tr.getAttribute('id'));
   }
function delLog(sender) {
    $(sender).css('visibility','hidden');
    //alert(tr.getAttribute('id'));
   }
function Message (txt) {
var msg = {
            event: "messageSent",
            text: txt,
            name:   getCookie("username"),
            time: clock()
    };
    return JSON.stringify(msg);
   }

