-module(ets_report).
-include("webserver.hrl").

-export([init/1]).
-export([insert/3]).
-export([info/1]).
-export([info/2]).
-export([update/2]).
-export([delete/1]).
-export([logtex/1]).

init(report) ->
    ets:new(report, [ordered_set, {keypos,#report.key}, named_table, public]),
    ets:new(pdflist,[bag,named_table, public]), %new table para key-pdf
    ets:new(logtex,[bag,named_table, public]),
    ok.
insert(Path,ReportName, User) ->
    %Ref=make_ref(),
    {Meg, Sec, Ms} = now(),
    Ref = integer_to_list(Meg * 1000000 + Sec + Ms),
    ets:insert(report, [#report{path=Path,reportname= ReportName, user=binary_to_list(User), key=Ref, status="wait"}]), 
    io:format("Ref is --~p~n",[Ref]),
    info(Ref),
    {ok, Ref}.
info(Key) ->
    case  ets:next(report,Key) of
        '$end_of_table' ->
            ok;
        _ ->
            info(ets:next(report, Key))
    end,     
    {ok, Cmd} = cmd(Key),
    {_, Message} = ws_handler:message(list_to_binary(Cmd),"command"),
    gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Message}), 
    ok.
info(Key, Pid) ->
    case  ets:next(report,Key) of
        '$end_of_table' ->
            ok;
        _ ->
            info(ets:next(report, Key), Pid)
    end,     
    {ok, Cmd} = cmd(Key),
    Pid!{command, Cmd},      
    ok.

update(Key, Status) ->
    ets:update_element(report,Key, {#report.status, Status}),
    ok.
delete(Key) ->
    %[[Path]] = ets:match(report, {report, '$1', '_',Key,'_'}),
    %io:format("Path is --~p~n",[Path]),
    Pdflist = ets:match(pdflist,{Key,'$1'}),
    lists:map(fun(H) -> file:delete(H) end, Pdflist),
    ets:match_delete(report, {report, '_', '_','_',Key,'_'}),
    ets:match_delete(pdflist, {Key,'_'}),
    Cmd = base64:encode_to_string("$('#"++Key ++"').remove()"),
    {_, Message} = ws_handler:message(list_to_binary(Cmd),"command"),
    gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Message}), 
    ok.
cmd(Key) ->
   [{report,_Path,ReportName,User,Key,Status}] = ets:lookup(report,Key),
   
    %io:format("~p--~p~n",[filename:basename(Name),Pri]),
    Cond = ets:match(pdflist,{Key,'$1'}),
    if Cond =/= [] ->
            Insert = lists:append(lists:map(fun(H) -> 
                                                    "<p><a target=\"_blank\" href=\"/pdf/"++
                                                        filename:basename(H)++"\">"++
                                                        unicode:characters_to_list(ReportName)++
                                                        "</a></p>" end, Cond)),
            Check="<form><input type=\"checkbox\" class=\"checked\" onchange=\"checkDel(this);\"></form>";
       true ->
            Insert = unicode:characters_to_list(ReportName),
            io:format("Insert is --~p~n",[Insert]),
            Check="",
            ok
    end,
    Cmd = base64:encode_to_string(unicode:characters_to_binary("$('#"++Key
                                  ++"').remove();$('#tblstatus').append('<tr id=\""++Key
                                  ++"\"><td class=\"lightbox1\" id=\""++User++Key++"\"onclick=\"checkInfo(this)\";>"++User++"</td><td>"
                                  ++Insert
                                  ++"</td><td>"++Status
                                  ++"</td><td>"++Check++"</td></tr>')")) ,
    {ok, Cmd}.

logtex(Key) ->
    Cond = ets:match(logtex,{Key,'$1'}),
    if Cond =/= [] ->
            Insert =  lists:append(lists:map(fun(H) -> "<p>" ++ binary_to_list(hd(H)) end, Cond));
       true ->
             Insert = ""
    end,
    Cmd = base64:encode_to_string("$('#texlogheader').empty();$('#texlog').empty();$('#texlogheader').append('Output for "++Key++"<label for=\"dva\">x</label>');$('#texlog').append('"++ Insert++"')"),
    {_,Message} = ws_handler:message(list_to_binary(Cmd),"command"),
    gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Message}), 
    ok.
