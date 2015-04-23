-module(ets_report).
-include("webserver.hrl").

-export([init/1]).
-export([close_tables/0]).
-export([insert/4]).
-export([info/1]).
-export([info/2]).
-export([update/2]).
-export([delete/1]).
-export([restore_backup/0]).
-export([uniq_user/0]).
-export([total_stat/0]).
-export([logtex/1]).

init(DbFile) ->
    ets:new(report, [ordered_set, {keypos,#report.key}, named_table, public]),
    dets:open_file(reportDisk, [{type, set},{file,DbFile},{keypos,#report.key}]),
    dets:open_file(statReportDisk, [{type, bag},{file,"statReport"}]),
    Size = proplists:get_value(size,(dets:info(reportDisk))),
    if Size =/= 0 ->
            restore_backup();
       true ->
            ok
    end,
    ets:new(ospid, [set, named_table, public]),
    ets:new(logtex,[bag,named_table, public]),
    ok.
close_tables() ->
    ets:delete(report),
    ets:delete(ospid),
    ets:delete(logtex),
    dets:close(statReportDisk),
    dets:close(reportDisk).

%% @doc Заполнение таблиц ets. Создаётся уникальный 
%% идентификатор Ref значение которого присваивается заданию.  
insert(Path, Filename, ReportName, User) ->
    {ok, Digest} = lib_md5:file(filename:join([Path,"dynamic", Filename])),
    Ref = lib_md5:digest2str(Digest),
    Timeref = calendar:datetime_to_gregorian_seconds(calendar:now_to_universal_time(now())),
    ets:insert(report, [{report,Timeref, Path,Filename,ReportName,User,Ref,"wait"}]),
    dets:insert(reportDisk,[{report,Timeref, Path,Filename,ReportName,User,Ref,"restoring"}]),
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
    {ok, Message} = js:cmd(Key),
    %%Message  = term_to_binary({eval,{Cmd}}),
    gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Message}), 
    ok.
info(Key, Pid) ->
    case  ets:next(report,Key) of
        '$end_of_table' ->
            ok;
        _ ->
            info(ets:next(report, Key), Pid)
    end,     
    {ok, Message} = js:cmd(Key),
    %%Message = term_to_binary({eval,{Cmd}}),
    Pid!{binary, Message},
    ok.

update(Key, Status) ->
    ets:update_element(report,Key, {#report.status, Status}),
    ok.
delete(Key) ->
    {ok, CWD} = file:get_cwd(),
    Pdflist = filelib:wildcard(filename:join([CWD, "priv","pdf"])++"/"++Key++"*.{pdf,zip}"),
    lists:map(fun(H) -> file:delete(H) end, Pdflist),
    ets:match_delete(report, {report,'_', '_','_', '_','_',Key,'_'}),
    dets:match_delete(reportDisk, {report, '_','_','_', '_','_',Key,'_'}),
    Cmd =  binary_to_list(unicode:characters_to_binary("$('#"++Key ++"').remove()")),
    Message  = term_to_binary({eval,{Cmd}}),
    gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Message}), 
    ok.

restore_backup() ->
    Insert = fun(Rec) ->
                     ets:insert(report, Rec),
                     continue
             end,
    dets:traverse(reportDisk, Insert).
    %%info(ets:first(report)).

%% @doc Составление списка пользователей и подсчёт числа заданий и времени на них
%% затраченного.  
uniq_user() ->
    List = ets:foldl((fun ({report, _,_,_,_,User,_,_}, Sum) -> 
                       Cond= lists:member(User, Sum), 
                       if Cond == false -> 
                               [User|Sum]; 
                          true-> Sum 
                       end 
               end), [], report),

    lists:map(fun(H) -> 
                      Sum = lists:foldl(fun([Key],[Sum,Count]) ->
                                                [[Bt,Et]] = ets:match(report, {report, '$1','_','$2','_','_',Key,'_'}),
                                                [Et-Bt+Sum,Count+1]
                                                
                                        end, [0,0], ets:match(report, {report, '_','_','_','_',H,'$1',"done"})), 
                      {H, Sum}
              end,List).

total_stat() ->
    List = dets:foldl((fun ({_,_,_,User,_}, Sum) -> 
                       Cond= lists:member(User, Sum), 
                       if Cond == false -> 
                               [User|Sum]; 
                          true-> Sum 
                       end 
                       end), [], statReportDisk),
    lists:map(fun(H) -> 
                      Sum = lists:foldl(fun(Key,[Sum_t,Count_t]) ->
                                                [X,Y] = lists:foldl(fun([Bt,Et],[Sum,Count]) ->
                                                                    [Et-Bt+Sum,Count+1] 
                                                            end, [0,0], dets:match(statReportDisk, {Key,'$1','$2',H,'_'})),
                                                [Sum_t+X,Count_t+Y]
                                        end, [0,0], lists:foldl((fun([Key], Acc) -> Cond= lists:member(Key, Acc), if Cond == false -> [Key|Acc]; true-> Acc end  end),[], dets:match(statReportDisk,{'$1','_','_',H,'_'}))), %% уникальный ключ для юзера
                      {H, Sum}
              end,List).
logtex(Key) ->
    Cond = ets:match(logtex,{Key,'$1'}),
    if Cond =/= [] ->
            Insert =  lists:append(lists:map(fun(H) -> "<p>" ++ binary_to_list(hd(H)) end, Cond));
       true ->
             Insert = ""
    end,
    %%Cmd = binary_to_list(unicode:characters_to_binary("$('#texlogheader').empty();$('#texlog').empty();$('#texlogheader').append('Output for "++Key++"<label for=\"dva\">x</label>');$('#texlog').append('"++ Insert++"')")),
    Cmd= binary_to_list(unicode:characters_to_binary(Insert)),
    Message  = term_to_binary({logtask,{Cmd}}),
    gproc:send({p, l, {pubsub,wsbroadcast}}, {self(), {pubsub,wsbroadcast}, Message}), 
    ok.

