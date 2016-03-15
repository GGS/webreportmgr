-module(texreport_worker).
-behaviour(task_queue).

-export([
        init/1,
        process_task/2,
        terminate/2,
        code_change/3
    ]).

-record(state, {}).

init(_Args) ->
    #state{}.

 process_task({gen_report, Dirname, Key}, State) ->
    io:format("Dirname from worker--~p----Key---~p ~n",[Dirname,Key]),
     {_,[[Home]]} = init:get_argument(home),
    Cmd = Home++"/ReportCraft/report dir="++Dirname++"  type=nogui",
    ets_report:update(Key, "working"),
    ets_report:info(ets:first(report)),
    case run(Cmd,Key) of
        {error,timeout} ->
            Msg="Причина: - timeout",
            lager:log(error, [{pid, self()}], "Failed for timeout"),
            del_error(Key),
            js:send_msg(error, Msg);
        {error, Status, _} ->
            Msg="Код ошибки: - "++ integer_to_list(Status),
            lager:log(error, [{pid, self()}], "Failed for reason --~s",[integer_to_list(Status)]),
            del_error(Key),
            js:send_msg(error, Msg);
        _ ->
            {_, FileList} = filedir(Dirname,Key),
            lager:log(notice, [{pid, self()}], "File ready for use --~s", [FileList]),
            ets:update_element(report,Key, {4,calendar:datetime_to_gregorian_seconds(calendar:now_to_universal_time(now()))}),%%меням имя файла на время выполнения
            ets_report:update(Key, "done"), %%Здесь меняется статус задания
            dets:insert(reportDisk, ets:lookup(report,Key)),
            %%print_stat:update(Key),
            ets:match_delete(ospid, {Key,'_'}),%% убираем из ospid
            ets_report:info(ets:first(report)),
            ok
    end,
    %%test(Dirname),
    {ok, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
%%%===================================================================
%%% Internal functions
%%%===================================================================
filedir(Dirname, Key) ->
    {ok, CWD} = file:get_cwd(),
    Fdest = filename:join([CWD, "priv","pdf"]),
    filelib:ensure_dir(Fdest++"/1"),
    file_utils:zip_dir("result.zip", Dirname),
    List = filelib:wildcard(Dirname++"/*.{pdf,zip}"),
    FileList = lists:map(fun(X) -> filename:basename(X) end,List),
    lists:map(fun(Z) -> file:copy(Dirname++"/"++Z,Fdest++"/"++Key++"-"++Z) end,FileList), 
    file_utils:del_dir(Dirname),%kill dir
    Msg="Отчёт - "++ Key ++ " готов",
    js:send_msg(info, Msg),
    ets:match_delete(logtex, {Key,'_'}),
    {ok, FileList}.

run(Command, Key) ->
    Port = open_port({spawn, Command},
                     [{line, 160}, exit_status, stderr_to_stdout, in, binary]),
    ets:insert(ospid,[{Key, proplists:get_value(os_pid,erlang:port_info(Port))}]),
    %%io:format("Proc est ~p~n",[proplists:get_value(os_pid,erlang:port_info(Port))]),
    run(Port, [], <<>>, Key).
run(Port, Lines, OldLine, Key) ->
     {ok, Re} = re:compile("erlang]:.+"),
    receive
        {Port, {data, Data}} ->
            case Data of
                {eol, Line} ->
                     case re:run(Line, Re,[{capture,[0], list}]) of
                         {match, [Match]}  ->
                             [Rname, Page, Type] = tl(string:tokens(Match," ")),
                             print_stat:update(Key,Rname, Page, Type),
                             io:format("Report- ~s, Pages -~s, Type -~s~n",[Rname, Page, Type]);
                         _-> nomatch
                    end,
                    ets:insert(logtex,{Key, Line}),
                    run(Port, [<<OldLine/binary, Line/binary>> | Lines], <<>>, Key);
                {noeol, Line} ->
                    ets:insert(logtex,{Key, Line}),
                    run(Port, Lines, <<OldLine/binary, Line/binary>>, Key)
            end;
        {Port, {exit_status, 0}} ->
            {ok, Lines};
        {Port, {exit_status, Status}} ->
            {error, Status, Lines}
    after
        86400000 ->
            {error, timeout}
    end.
    
del_error(Key) ->
    ets_report:update(Key, "error"),
    dets:insert(reportDisk, ets:lookup(report,Key)),
    ets:match_delete(ospid, {Key,'_'}),
    ets_report:info(ets:first(report)).
    
