
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
