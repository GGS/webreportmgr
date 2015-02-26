-module(ets_report).
-include("webserver.hrl").

-export([init/1]).
-export([insert/4]).
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
%% @doc Заполнение таблиц ets. Создаётся уникальный 
%% идентификатор Ref значение которого присваивается заданию.  
insert(Path,Filename,ReportName, User) ->
    %%Ref=make_ref(),
    {Meg, Sec, Ms} = now(),
    Ref = integer_to_list(Meg * 1000000 + Sec + Ms),
    ets:insert(report, [#report{path=Path, filename=Filename, reportname= ReportName, user=binary_to_list(User), key=Ref, status="wait"}]), 
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
    Message  = term_to_binary({eval,{Cmd}}),
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
    Message = term_to_binary({eval,{Cmd}}),
    Pid!{binary, Message},
    ok.

update(Key, Status) ->
    ets:update_element(report,Key, {#report.status, Status}),
    ok.
delete(Key) ->
    Pdflist = ets:match(pdflist,{Key,'$1'}),
    lists:map(fun(H) -> file:delete(H) end, Pdflist),
    ets:match_delete(report, {report, '_','_', '_','_',Key,'_'}),
    ets:match_delete(pdflist, {Key,'_'}),
    Cmd =  binary_to_list(unicode:characters_to_binary("$('#"++Key ++"').remove()")),
    Message  = term_to_binary({eval,{Cmd}}),
    gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Message}), 
    ok.
cmd(Key) ->
    [{report,Path, Filename, ReportName,User,Key,Status}] = ets:lookup(report,Key),
    case Status of
        "done" -> 
            Cond = ets:match(pdflist,{Key,'$1'}),
            Insert = lists:append(lists:map(fun(H) -> 
                                                    "<p><a target=\"_blank\" href=\"/pdf/"++filename:basename(H)++"\">"++unicode:characters_to_list(ReportName)++ "</a></p>" end, Cond)),
            Check="<form><input type=\"checkbox\" class=\"checked\" onchange=\"checkDel(this);\"></form>",
            Class = "success",
            CheckInfo="";
        "error" ->
            Url = filename:join(["users",User,filename:basename(Path),"dynamic", Filename]),
            Insert = "<p><a target=\"_blank\" href=\""++Url++"\">"++unicode:characters_to_list(ReportName)++ "</a></p>", 
            Check="<form><input type=\"checkbox\" class=\"checked\" onchange=\"checkDelErr(this);\"></form>",
            Class = "danger",
            CheckInfo="class=\"lightbox1\" id=\""++User++Key++"\"onclick=\"checkInfo(this)\"";
        _ ->
            Insert = unicode:characters_to_list(ReportName),
            io:format("Insert is --~ts~n",[Insert]),
            Check="",
            Class = "info",
            CheckInfo="class=\"lightbox1\" id=\""++User++Key++"\"onclick=\"checkInfo(this)\";"   
    end,
    Cmd = binary_to_list(unicode:characters_to_binary("$('#"++Key
                                                      ++"').remove();$('#tblstatus').append('<tr class=\""
                                                      ++Class++"\" id=\""++Key
                                                      ++"\"><td "++CheckInfo++">"++User++"</td><td>"
                                                      ++Insert
                                                      ++"</td><td>"++Status
                                                      ++"</td><td>"++Check++"</td></tr>')")),
    %io:format("Command_ets is --~ts~n",[Cmd]),
    {ok, Cmd}.

logtex(Key) ->
    Cond = ets:match(logtex,{Key,'$1'}),
    if Cond =/= [] ->
            Insert =  lists:append(lists:map(fun(H) -> "<p>" ++ binary_to_list(hd(H)) end, Cond));
       true ->
             Insert = ""
    end,
    Cmd = binary_to_list(unicode:characters_to_binary("$('#texlogheader').empty();$('#texlog').empty();$('#texlogheader').append('Output for "++Key++"<label for=\"dva\">x</label>');$('#texlog').append('"++ Insert++"')")),
    %io:format("Log --~tp~n",[Cmd]),
    Message  = term_to_binary({eval,{Cmd}}),
    gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Message}), 
    ok.
