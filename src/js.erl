-module(js).

-export([index/0, send_msg/2, message/2, wr_to_json/3, cmd/1, os_type/0, ncpu/1]).

index() ->
    Str = "$('body').append('<div class = row id=\"metacontainer\">');$('body').append('<div  class = row id=\"container1\">');$('#metacontainer').append('<div class = \"col-lg-8\" id=\"container2\">');$('#metacontainer').append('<div class = \"col-lg-4\" id=\"container3\">');$('#container2').append('<div id=\"tbl\">');$('#tbl').append('<table class=\"table table-bordered\"><col style=\"width:20%\"><col style=\"width:50%\"><col style=\"width:20%\"><col style=\"width:10%\"><thead><tr><th>User</th><th>Report</th><th>Status</th><th>Action</th></tr></thead><tbody id=\"tblstatus\"></tbody></table>');$('#container3').append('<div id=\"content\">');$('#content').append('<table><thead><tr><th><button class=\"btn btn-default\" id=\"clear\" onclick=\"clearScreen()\">Clear text</button></th></tr></thead></table>');$('#content').append('<div id=\"output\">');$('#output').css(\"margin-top\",\"20px\");$('#container1').append('<div id=\"logcontainer\" onclick=\"delLog(this)\">');$('#logcontainer').append('<div class=\"logblock\">');$('.logblock').append('<div id=\"texlogheader\">');$('.logblock').append('<div id=\"texlog\">')",
    Str.
    %ws_handler:message("eval",Str).
    
send_msg(Type, Msg) ->
    {_,Str} = wr_to_json(Type, Type, binary_to_list(unicode:characters_to_binary(Msg))),
    Message = term_to_binary({messageSent,{Str}}),
    gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Message}). 



message (Type, Data) ->
    Term = binary_to_list(term_to_binary(Data)),
    {ok, list_to_binary(io_lib:format("{~p:~p}",[Type,Term]))}.

wr_to_json(Event,Username,Text) ->
    {_,Time_event} = time_info(),
    Str =  unicode:characters_to_list(io_lib:format("{\"event\":\"~s\", \"name\":\"~s\",\"text\":\"~s\",\"time\":\"~s\"}",[Event, Username,  Text, Time_event])),
    io:format("Json is --~s~n",[Str]),
    {ok, Str}.

cmd(Key) ->
    [{report,Timeref, Path, Filename, ReportName,User,Key,Status}] = ets:lookup(report,Key),
    case Status of
        "done" -> 
            {ok, CWD} = file:get_cwd(),
            Cond = filelib:wildcard(filename:join([CWD, "priv","pdf"])++"/"++Key++"*.{pdf,zip}"),
            [[Bt,Et]] = ets:match(report, {report,'$1', '_','$2', '_','_',Key,'_'}),
            {_,{M1,M2,M3}} = calendar:seconds_to_daystime(Et-Bt),
            Insert = lists:append(lists:map(fun(H) -> 
                                                    Size = float_to_list(filelib:file_size(H)/1024,[{decimals, 0}]),
                                                    Ext = string:to_upper(filename:extension(H)),
                                                
                                                    [[Size,Ext, filename:basename(H),M1,M2,M3]]  end, Cond));
       
        _ ->
            UrlReport = filename:join(["users",User,filename:basename(Path)]),
            Insert = unicode:characters_to_list(UrlReport)
             
    end,
     
    Cmd  = term_to_binary({tbl,[Timeref, Path, Filename, binary_to_list(unicode:characters_to_binary(ReportName)), User, Key, Status, Insert]}),
    {ok, Cmd}.

%%%
%%%%% Internal
%%%
time_info() ->
    {{_,_,_},{Hr,Min,Sec}} = calendar:now_to_local_time(now()),
    A = io_lib:format("~p:~p:~p", [Hr,Min,Sec]),
    {ok, A}.

os_type() ->
    Ostype = string:tokens(os:cmd("uname"),"\n"),
    {Ostype}.

ncpu(Ostype) ->
    if Ostype == "Linux" ->
            Ncpu = os:cmd("cat /proc/cpuinfo | grep ^processor |wc -l");
       true ->
            [V1] = string:tokens(os:cmd("sysctl -a | egrep -i 'hw.ncpu'"),"\n"),
            [V2, Ncpu] = string:tokens(V1," ")
    end,
    Ncpu.
