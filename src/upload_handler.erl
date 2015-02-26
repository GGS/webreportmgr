%% @doc Upload handler.
-module(upload_handler).
-export([init/3]).
-export([handle/2]).
-export([terminate/3]).

init(_Type, Req, []) ->
    {ok, Req, undefined}.

handle(Req, State) ->
    {ok, CType, Req1} = cowboy_req:parse_header(<<"content-type">>, Req),
    io:format("---Content:--- ~p ---~n",[CType]),
    {ok, Req2, Key} =  multipart(Req1, maps:new()),
    {ok, Req3}  = cowboy_req:reply(302,
		[{<<"location">>,<<"/index">>},{<<"idreport">>,Key}], Req2),
    {ok, Req3, State}.
 
terminate(_Reason, _Req, _State) ->
    ok.

multipart(Req,OldForm) ->
    case cowboy_req:part(Req) of
        {ok, Headers, Req2} ->
            io:format("Headers~p~n",[cow_multipart:form_data(Headers)]),
            {Req4,{A,B}} = case cow_multipart:form_data(Headers) of
                               {data, _FieldName} ->
                                   {ok, _Body, Req3} = cowboy_req:part_body(Req2),
                                   io:format("---Parsing:--- ~p ---~p~n",[_FieldName, _Body]),
                                   {Req3,{_FieldName,_Body}};  %normal field has atom - data
                               {file, _FieldName, Filename, _CType, _CTransferEncoding} ->
                                   {ok, CWD} = file:get_cwd(),
                                   io:format("---Parsing:--- ~p ---~p~n",[_FieldName, Filename]),
                                   User = maps:get(<<"user">>,OldForm),
                                   ReportName = maps:get(<<"reportname">>, OldForm),
                                   Path = filename:join([CWD, "priv","users", binary_to_list(User)]),
                                   {ok, Dirname, FullFilename} = assert_config(Path, binary_to_list(Filename), lists:seq(1, 100)),
                                   {ok, Xmlreport} = file:open(FullFilename, [write]),
                                   Req3 = stream_file(Req2,Xmlreport), %stream for file
                                   Ext =  string:to_upper(filename:extension(FullFilename)),
                                   if Ext =:= ".ZIP" ->
                                           zip:unzip(FullFilename,[{cwd,filename:dirname(FullFilename)}]);
                                      true ->
                                           ok
                                   end,
                                   {ok, Key} = ets_report:insert(Dirname, binary_to_list(Filename),ReportName, User),
                                   io:format("---Dirname-~p-Key-~p~n",[Dirname, Key]),
                                   lager:log(notice, [{pid, self()}], "File uploaded!--Dirname-~p-Key-~p~n", [Dirname, Key]),
                                   Cond = erlang:whereis(task_queue_manager),
                                   task_queue:in({gen_report, Dirname, Key}, Cond),
                                   {Req3,{<<"key">>, Key}}
                           end,
            Form = maps:put(A,B,OldForm),
            io:format("---Lookup-~p--~n",[Form]),
            io:format("---Next part--- ~n"),
            multipart(Req4,Form);
        {done, Req2} ->
            Key = maps:get(<<"key">>, OldForm),
            io:format("---All parts parsing--- ~p~n",[Key]),
            {ok, Req2, Key}
    end.

stream_file(Req, Xmlreport) ->
    case cowboy_req:part_body(Req) of
        {ok, _Body, Req2} ->
            io:format("---stream Ok--- ~n"),
            ok = file:write(Xmlreport, _Body),
            ok = file:close(Xmlreport), %need try catch
            Req2;
        {more, _Body, Req2} ->
            io:format("---more Ok--- ~n"),
            ok = file:write(Xmlreport, _Body),
            stream_file(Req2, Xmlreport)
    end.

assert_config(Path, Filename, Listnum) ->
    [H|T]=Listnum,
    Dirname = filename:join([Path, "report"++integer_to_list(H)]), %for report.exe
    case  string:to_upper(filename:extension(Filename)) of
        ".ZIP" ->
            FullFilename = filename:join([ Dirname, "dynamic", Filename]);
        _->
            FullFilename = filename:join([ Dirname, "dynamic", "ForTex", Filename])
    end,
    case filelib:is_dir(Dirname) of
        true ->
            assert_config(Path, Filename, T);  
        _ ->
            filelib:ensure_dir(FullFilename),
            {ok, Dirname, FullFilename}

    end.
