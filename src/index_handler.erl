-module(index_handler).
%% Cowboy_http_handler callbacks
-export([
         init/3,
         is_authorized/2,
         content_types_provided/2,
         to_html/2,
 %   handle/3,
         terminate/3
]).

init(_Type, _Req, []) ->
   % {ok, Req, undefined_state}.
{upgrade, protocol, cowboy_rest}.

is_authorized(Req, State) ->
    {ok, Auth, Req1} = cowboy_req:parse_header(<<"authorization">>, Req),
    case Auth of
        {<<"basic">>, {User, Passw}}  -> 
            case trypass(User) of
                {ok, Passw} ->
                    Req2 = cowboy_req:set_resp_cookie(
                             <<"username">>, User, [{path, <<"/">>}], Req1),
                    {true,Req2, User };
                _->
                    {{false, <<"Basic realm=\"cowboy\"">>}, Req1, State}
            end;
        _ ->
            {{false, <<"Basic realm=\"cowboy\"">>}, Req1, State}
    end.
trypass(User) ->
    case ets:lookup(passwd, binary_to_list(User)) of
        [{_, Passw}] -> 
     io:format("----~p~n",[list_to_binary(Passw)]),
            {ok, list_to_binary(Passw)};
        _->
            io:format("~s-~n",["Not User in ets"]),
            {false, User}
    end.
content_types_provided(Req, State) ->
    {[
      
      {<<"text/html">>, to_html}], Req, State}.

to_html(Req, User) ->
    Sname = "Print report manager",
    %#{username := User} = cowboy_req:match_cookies([username], Req),
    io:format("--Pid HTTP open --~p ~n", [self()]),
                                                % Формирование отсылаемого контента  со списком переменных (1 аргумент)
        %Содержимое в переменную HTML
    {ok, HTML} = index_dtl:render([{shortname, Sname},{currentUser, User}]), 
    {HTML, Req, User}.
    
terminate(_Reason, _Req, _State) ->
    ok.
