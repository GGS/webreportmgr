%% @doc Status handler.
-module(status_handler).

-export([init/3]).
-export([handle/2]).
-export([terminate/3]).

init(_Type, Req, []) ->
	{ok, Req, undefined}.

handle(Req, State) ->
    {Key, Req2} = cowboy_req:qs_val(<<"id">>, Req),
    {ok, Req3} =     
        try ets:lookup(report,binary_to_list(Key)) of
            [{report,_,_,_,_,Status}] ->
                cowboy_req:reply(200, [
                                       {<<"content-type">>, <<"text/plain">>}
                                      ], Status, Req2);
            _->  
                cowboy_req:reply(200, [
                                       {<<"content-type">>, <<"text/plain">>}
                                       ], <<"failid">>, Req2)
        catch 
            error:Reason ->
                {'EXIT',{Reason,erlang:get_stacktrace()}}
        end,
    {ok, Req3, State}.

terminate(_Reason, _Req, _State) ->
	ok.
