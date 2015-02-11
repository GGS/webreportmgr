-module(notfound_handler).
%% Cowboy_http_handler callbacks
-export([
         init/3,handle/2,terminate/3
        ]).

init(_Type,Req, []) ->
    {ok, Req, undefined}.

handle(Req, State) ->
    {URL, Req2} = cowboy_req:url(Req),
    {ok, HTML} = '404_dtl':render([{url, URL}]),
    {ok, Req3} = cowboy_req:reply(404, [
                                        {<<"content-type">>, <<"text/html">>}
                                       ], HTML, Req2),
    {ok, Req3, State}.

terminate(_Reason, _Req, _State) ->
    ok.
