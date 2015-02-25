-module(js).

-export([index/0]).

index() ->
    Str = "$('body').append('<div class = row id=\"metacontainer\">');$('body').append('<div  class = row id=\"container1\">');$('#metacontainer').append('<div class = \"col-lg-8\" id=\"container2\">');$('#metacontainer').append('<div class = \"col-lg-4\" id=\"container3\">');$('#container2').append('<div id=\"tbl\">');$('#tbl').append('<table class=\"table table-bordered\"><col style=\"width:20%\"><col style=\"width:50%\"><col style=\"width:20%\"><col style=\"width:10%\"><thead><tr><th>User</th><th>Report</th><th>Status</th><th>Del</th></tr></thead><tbody id=\"tblstatus\"></tbody></table>');$('#container3').append('<div id=\"content\">');$('#content').append('<table><thead><tr><th><button class=\"btn btn-default\" id=\"clear\" onclick=\"clearScreen()\">Clear text</button></th></tr></thead></table>');$('#content').append('<div id=\"output\">');$('#output').css(\"margin-top\",\"20px\");$('#container1').append('<div id=\"logcontainer\" onclick=\"delLog(this)\">');$('#logcontainer').append('<div class=\"logblock\">');$('.logblock').append('<div id=\"texlogheader\">');$('.logblock').append('<div id=\"texlog\">')",
    Str.
    %ws_handler:message("eval",Str).
    
