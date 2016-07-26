
//var transition = {pid: '', port:'7007'};
var transition = {pid: ''};
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
    var sng = window.sng = window.sng || {};
    sng.avg =[];
    var numproc = 6;
    initproc(numproc);
    initdraw();
    };
 	


function sendTxt() {
    txt = $("#send_txt").val();
    msg = Message("messageSent", txt);
    document.querySelector('#send_txt').value = '';
    ws.send(enc(tuple(atom(msg.event), utf8_toByteArray(msg.text), msg.name, msg.time)));
    //showScreen('sending: ' +  utf8_toByteArray(msg.text)); 
  
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
function checkStop(sender) {
var tr = sender.parentNode.parentNode;
msg = Message("delPid", tr.getAttribute('id'));
ws.send(enc(tuple(atom(msg.event), utf8_toByteArray(msg.text), msg.name, msg.time)));
}
function checkDel(sender) {
    var tr = sender.parentNode.parentNode;
    msg = Message("delReport", tr.getAttribute('id'));
    ws.send(enc(tuple(atom(msg.event), utf8_toByteArray(msg.text), msg.name, msg.time)));
    }
function checkDelErr(sender) {
    var tr = sender.parentNode.parentNode;
    msg = Message("delErr", tr.getAttribute('id'));
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
function checkRest(sender) {
    var tr = sender.parentNode.parentNode;
    msg = Message("restTask", tr.getAttribute('id'));
    ws.send(enc(tuple(atom(msg.event), utf8_toByteArray(msg.text), msg.name, msg.time)));
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
function loadCpu (data) {
    dd =[];
    for(var i=0; i < data.length; i++) {
        CpuLoad  =(((sng.procs[i][1]-data[i][1])-(sng.procs[i][2]-data[i][2]))/(sng.procs[i][1]-data[i][1]))*100;
        dd.push(Math.round(CpuLoad));
        //dd.push(CpuLoad);
       //console.log(CpuLoad);
    }
    sng.procs = data;
    draw(dd);
    
}
function loadAvg (data) {
    $('#loadavg').empty();
    $('#loadavg').append('<strong>'+data[0]+' - '+data[1]+' - '+data[2]+'</strong>');  
   if (sng.avg.length < 30) {
       sng.avg[sng.avg.length]=data[0];
   } else {
       sng.avg.shift();
       sng.avg[sng.avg.length]=data[0];
   }
    //redraw(sng.avg)
}
function loadUptime (data) {
    $('#uptime').empty();
    $('#uptime').append('<strong>'+data[0]+" : "+Doubl(data[1])+":"+Doubl(data[2])+":"+Doubl(data[3])+'</strong>'); 
/*Fill table */
}
function loadTotalstat(data)  {
    for (i=0; i < data.length; i++) {
        //console.log(data[i].value[0][0]);
    }
}
function loadOstype(data) {
    $('#ostype').empty();
    $('#ostype').append('<strong>'+ data+ '</strong>');
}

function fillTbl (data) {
    var Key = data[5];
    var Class ='';
    var Insert ='';
    var CheckInfo='';
    var Check='';
    switch (data[6]) {
    case 'done':
        for (i=0; i < data[7].length; i++) {
            Insert = Insert.concat('<p><a target="_blank" href="/pdf/'+data[7][i][2]+'">'+dataUnix(data[0])+'--'+utf8_decode(data[3])+'---Ext-'+data[7][i][1]+'---size, kb:-'+data[7][i][0]+'---total time:-'+Doubl(data[7][i][3])+':'+Doubl(data[7][i][4])+':'+Doubl(data[7][i][5])+'</a></p>');
        }
        Class = 'success';
        CheckInfo=data[4];;
        Check='<button class="btn btn-link" onclick="checkDel(this)">Удалить</button>';
        break;
    case 'working':
        Insert = dataUnix(data[0])+'--'+utf8_decode(data[3]);
        Check='<button class="btn btn-link" onclick="checkStop(this)">Остановить</button>';
        Class = 'info';
        //CheckInfo='class="lightbox1" id="'+data[4]+Key+'" onclick="checkInfo(this)"';
        CheckInfo=data[4]+'--<a target="_blank" href="/'+data[7]+'/logreport.txt">Logreport</a>--<a target="_blank" href="/'+data[7]+'/rlog.txt">Rlog</a>';
        break;
    case 'error':
        Insert = '<p><a target="_blank" href="'+data[7]+'/'+data[2]+'">'+ dataUnix(data[0])+'--'+utf8_decode(data[3])+'</a></p>'; 
        Check='<button class="btn btn-link "onclick= "checkDelErr(this)">Удалить</button>';
        Class = 'danger';
        CheckInfo=data[4]+'--<a target="_blank" href="/'+data[7]+'/logreport.txt">Logreport</a>--<a target="_blank" href="/'+data[7]+'/rlog.txt">Rlog</a>';
        break;
     case 'restoring':
        Insert = dataUnix(data[0])+'--'+utf8_decode(data[3]);
        Check='<button class="btn btn-link" onclick="checkRest(this)">Восстановить</button>';
        Class = 'warning';
        CheckInfo=data[4];
        break;
    default:
        Insert = dataUnix(data[0])+'--'+utf8_decode(data[3]);
        Class = 'info';
        Check='';
        CheckInfo=data[4];
    }
    $('#'+Key).remove();
    $('#tblstatus').append('<tr class='+Class+' id='+Key+'><td >'+CheckInfo+'</td><td>'+Insert+'</td><td>'+data[6]+'</td><td>'+Check+'</td></tr>');
}

function dataUnix(unix_time) {
    var date = new Date(unix_time*1000);
    var hours = Doubl(date.getHours());
    var minutes = Doubl(date.getMinutes());
    var seconds = Doubl(date.getSeconds());
    var Str = hours+':'+ minutes + ':'+seconds;
    return Str
}
function Doubl (num) {
    if (num < 10) {
        num ="0"+num;
    }
return num;
}
function initdraw()  {
    var w = 150;
    var barPadding = 4;
    var h = 140;
    var xPadding = 25;
    var yPadding = 10;
    sng.svg = d3.select("#graf")
        .append("svg:svg")
        .attr("class","chart")
        .attr("width", w*1.2)
	.attr("height", h);
   
    data =['1','1','1','1','1','1'];
    var scale = d3.scale.linear()
        .domain([100, 0])
        .range([0, 100]);
    sng.svg.append("g")
        .attr("class", "axis") 
        .attr("transform", "translate(0," + (h-yPadding-scale(0)) + ")")
        .call(d3.svg.axis()
              .scale(scale)
              .orient("right")
              .ticks(2));
    var svgData = sng.svg
        .selectAll('rect')
        .data(data);
     
    sng.svg.selectAll('.proc')
        .data(data)
        .enter()
        .append("text")
        .attr("class","proc")
        .attr("x", function(d, i) {
            console.log(i)
            return (i * (w / data.length))+xPadding
        })
        .attr("y", function(d) {
            return ((h)-(scale(100)))})
        .text(function(d) {
            return d+"%";
        })
        .attr("font-family", "sans-serif")
	.attr("font-size", "8px")
        .attr("fill","grey");
          
    svgData
        .enter()
        .append("svg:rect")
        .attr("x", function(d, i) {
	    return (i * (w / data.length))+xPadding;
        })
        .attr("y", function(d) {
            return ((h-yPadding)-(scale(d)));
        })
        .attr("width", w / data.length - barPadding)
        .attr("height", function(d) {
	  return scale(d) ;
        })
        .attr("fill", "steelblue")
            
}

function draw(data) {
    var h = 140;
     var scale = d3.scale.linear()
        .domain([0, 100])
        .range([0, 100]); 
    sng.svg.selectAll('rect')
        .data(data)
        .transition()
        .attr("y", function(d) {
            return ((h-10)-(scale(d)));
        })
        .attr("height", function(d) {
	    return scale(d) ;
        })
    sng.svg.selectAll('.proc')
        .data(data)
        .text(function( d) {
            return d+"%";
        })
} 

function initproc(numproc){
sng.procs = [];
 for(var i=0; i < numproc; i++) {
     sng.procs[i] = [];
     sng.procs[i][0] = '-';
     sng.procs[i][1] = 0;
     sng.procs[i][2] = 0;
 }
    console.log(sng.procs);
}
