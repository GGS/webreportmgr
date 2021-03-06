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
    'connected': '[sys][time]%time%[/time]:[user]%name%[/user][/sys] соединился с сервером',
    'messageSent': '[out][time]%time%[/time]: [user]%name%[/user]: %text%[/out]',
    'info': '[out][time]%time%[/time]: [info]%name%[/info]: %text%[/out]',
    'error': '[out][time]%time%[/time]: [error]%name%[/error]: %text%[/out]',
    'messageReceived': '[in][time]%time%[/time]: [user]%name%[/user]: %text%[/in]',
    'userSplit': '[sys][time]%time%[/time]: Пользователь [user]%name%[/user] покинул чат.[/sys]'
};
var $client = {};
$client.on = function onclient(evt, callback) // JSON formatter
{
    //console.log("Client On");
           console.log("msg: " +    evt.data);
   try {  msg = JSON.parse(evt.data);
           //console.log("parsing: " +    msg.data);
          if (typeof callback == 'function' && msg.data) {callback(msg.data)};
          if (msg.eval) try { eval( utf8_decode(String(dec(msg.eval)))); }
          catch (e) { return { status: "error", desc: e }; console.log(e)};
       } catch (ex) { return { status: "error", desc: ex }; }
    return { status: "ok" };
};
$client.do = function doclient(msg) {
    console.log('Text ' + String(dec(msg)));
    obj = JSON.parse(String(dec(msg)));
    showScreen(strings[obj.event].replace(/\[([a-z]+)\]/g, '<span class="$1">').replace(/\[\/[a-z]+\]/g, '</span>').replace(/\%time\%/, obj.time).replace(/\%name\%/, obj.name).replace(/\%text\%/, unescape(utf8_decode(obj.text)).replace('<', '&lt;').replace('>', '&gt;')) + '<br>');
        
    return "done";
};


