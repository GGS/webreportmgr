-module(webreportmgr_app).
-behaviour(application).
%% Application callbacks
-export([
    start/2,
    stop/1
]).

%% API
-export([dispatch_rules/0]).

%% ===================================================================
%% API functions
%% ===================================================================
mime() -> [{mimetypes,cow_mimetypes,all}].
dispatch_rules() ->
   Static = fun(Filetype) ->
   {lists:append(["/", Filetype, "/[...]"]), cowboy_static, 
     {priv_dir, webreportmgr, [list_to_binary(Filetype)], mime()}}
            end,
    cowboy_router:compile([
                           {'_', [
                                  Static("css"),
                                  Static("js"),
                                  Static("img"),
                                  Static("pdf"),
                                  %{"/css/[...]", cowboy_static, {priv_dir, webreportmgr, "/css"}},
                                  {"/", login_handler, []},
                                  {"/login", login_handler, []},
                                  {"/index", index_handler, []},
                                  {"/upload", upload_handler, []},
                                  {"/websocket", ws_handler, []},
                                  {'_', notfound_handler, []}
                                 ]}
                          ]). 
    

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
    Dispatch = dispatch_rules(),
    Env = [{env, [{dispatch, Dispatch}]}],
    Port = 7007,
    Hooks = [{onresponse, fun webreportmgr_log:access_log_hook/4}],
    cowboy:start_http(?MODULE, 10, [{port, Port}], Env ++ Hooks),
    %{ok, _} = cowboy:start_http(http_listener, 100,
    %    [{port, Port}],
    %    [{env, [{dispatch, Dispatch}]}]
    %),
 %{ok,CWD} = file:get_cwd(),
 %{_,Passw} = file:read_file(filename:join([CWD,"priv","passw.txt"])),
  %  io:format("~p~n",[string:tokens(binary_to_list(Passw),"\r\n")]),
   % Listpass = string:tokens(binary_to_list(Passw),"\r\n"),
    Listpass = ["Operator1::oper1"],
    ets:new(passwd,[set, named_table]),
    lists:map(fun(X) ->  [H|T] = string:tokens(X,"::"),
              ets:insert(passwd,{H,hd(T)}),
              io:format("~p~n",ets:lookup(passwd, H))
              end, Listpass),
    task_queue:start_link(texreport_worker, [], [{workers_num, 4},{unique_tasks, false}]),
    ets_report:init(report),
    webreportmgr_sup:start_link().

stop(_State) ->
    ok.
