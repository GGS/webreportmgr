%% @doc Status handler.
-module(status_handler).

%% Standard callbacks.
-export([init/3]).
-export([content_types_provided/2]).
-export([terminate/3]).

%% Custom callbacks.
-export([to_text/2]).
-export([to_html/2]).
-export([to_json/2]).
-export([status/1]).

init(_Type, _Req, []) ->
	{upgrade, protocol, cowboy_rest}.

content_types_provided(Req, State) ->
    
    {[
      {<<"text/plain">>, to_text},
      {<<"text/html">>, to_html},
      {<<"application/json">>, to_json}
     ], Req, State}.

status(Key) ->
    %%io:format("Path - ~p",[Key]),
    case  Key of
        [] ->
            "not id";
        _->
             try ets:lookup(report,binary_to_list(hd(Key))) of
                          [{report,_,_,_,_,_,_,Status}] ->
                              Status;
                          _->  
                              "failid"
             catch 
                          error:Reason ->
                              {'EXIT',{Reason,erlang:get_stacktrace()}}
                         
                      end
    end.

to_text(Req, State) ->
    {Key, Req2} = cowboy_req:path_info(Req),
    {list_to_binary(status(Key)), Req2, State}.
     
to_json(Req, State) ->
%% 62167219200 (1.1.1970) Unix epoch from gregorian year (0 year)   
    {Key, Req2} = cowboy_req:path_info(Req),
    Cond =  status(Key),
    if Cond ==  "not id" ->
            Acc = ets:foldl((fun(X, Sum)-> [X|Sum] end), [], report),
            Body = lists:map(fun({report,Time,_,_,Rn,User,Id,Status}) -> 
                                     io_lib:format("{\"time\":~s,\"id\":\"~s\",\"user\": \"~s\",\"reportname\": \"~s\",\"status\": \"~s\"}",[integer_to_list(Time-62167219200),Id,User, Rn, Status]) end, Acc),
            {ok, Re} = re:compile("}{"),
            {re:replace(list_to_binary(io_lib:format("[~s]",[Body])), Re,"},{",[global,{return, list}]), Req2, State};
       true ->
            Body = "{\"status\": \""++status(Key)++"\"}",
            {list_to_binary(Body), Req2, State}
    end.   

to_html(Req, State) ->
    {Key, Req2} = cowboy_req:path_info(Req),
    Cond =  status(Key),
    Str = if Cond ==  "not id" ->
                  Acc = ets:foldl((fun(X, Sum)-> [X|Sum] end), [], report),
                  lists:map(fun({report,_,_,_,Rn,User,Id,Status}) -> io_lib:format("<p>~s --- ~s-- ~s --- <b>~s</b></p>",[ Id,User,Rn, Status]) end, Acc);
             
             true ->
                  status(Key)
          end,
    Body = "<html><head><meta charset=\"utf-8\"><title>Status task!</title>
                       </head>
                         <body>"++Str++"</body></html>",
    {list_to_binary(Body), Req2, State}.
terminate(_Reason, _Req, _State) ->
	ok.

