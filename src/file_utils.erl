-module(file_utils).
-export([recursively_list_dir/1,
         recursively_list_dir/2,
         del_dir/1, 
         zip_dir/2]).
 
%%%https://gist.github.com/mrinalwadhwa/1059710 
%% src https://erlangcentral.org/wiki/index.php?title=Delete_a_File
-type name() :: string() | atom() | binary().
 
 
%% API
%% @type name() = string() | atom() | binary(). 
%% @spec (Dir::name()) -> {ok, [string()]} | {error, atom()}
%% @equiv recursively_list_dir(Dir, false)
%% 
%% @doc Lists all the files in a directory and recursively in all its
%% sub directories. Returns {ok, Paths} if successful. Otherwise,
%% it returns {error, Reason}. Paths is a list of Paths of all the
%% files and directories in the input directory's subtree. The paths are not
%% sorted in any order.
 
-spec recursively_list_dir(Dir::name()) ->
        {ok, [string()]} | {error, atom()}.
        
recursively_list_dir(Dir) ->
    recursively_list_dir(Dir, false). % default value of FilesOnly is false
  
%% @spec (Dir::name(), FilesOnly::boolean()) -> {ok, [string()]} |
%%                                                   {error, atom()}
%% 
%% @doc Lists all the files in a directory and recursively in all its
%% sub directories. Returns {ok, Paths} if successful. Otherwise,
%% it returns {error, Reason}. If FilesOnly is false, Paths is a list of paths
%% of all the files <b>and directories</b> in the input directory's subtree.
%% If FilesOnly is true, Paths is a list of paths of only the files in the
%% input directory's subtree. The paths are not sorted in any order.
 
-spec recursively_list_dir(Dir::name(), FilesOnly::boolean()) ->
        {ok, [string()]} | {error, atom()}.
 
recursively_list_dir(Dir, FilesOnly) ->
    case filelib:is_file(Dir) of
        true ->
            case filelib:is_dir(Dir) of
                true -> {ok, recursively_list_dir([Dir], FilesOnly, [])};
                false -> {error, enotdir}
            end;
        false -> {error, enoent}
    end.


%% @doc Для удаления директорий вместе с содержимым 
%%-spec del_dir(Dir::string()) -> ok | [string()]. 

 del_dir(Dir) ->
   lists:foreach(fun(D) ->
                    ok = file:del_dir(D)
                 end, del_all_files([Dir], [])). 

%% @doc Для архивирования (.zip)  директорий вместе с содержимым 
-spec zip_dir(Name::string(),Dir::string()) -> ok. 

zip_dir(Name, Dir) ->
    {ok,Cwd} = file:get_cwd(),
    file:set_cwd(Dir),
    {ok, Files} = recursively_list_dir("result", true),
    zip:create(Name, Files),
    ok = file:set_cwd(Cwd).  
 
%% Internal
 
recursively_list_dir([], _FilesOnly, Acc) -> Acc;
recursively_list_dir([Path|Paths], FilesOnly, Acc) ->
    recursively_list_dir(Paths, FilesOnly,
        case filelib:is_dir(Path) of
            false -> [Path | Acc];
            true ->
                {ok, Listing} = file:list_dir(Path),
                SubPaths = [filename:join(Path, Name) || Name <- Listing],
                recursively_list_dir(SubPaths, FilesOnly,
                    case FilesOnly of
                        true -> Acc;
                        false -> [Path | Acc]
                    end)
        end).
 

 
del_all_files([], EmptyDirs) ->
   EmptyDirs;
del_all_files([Dir | T], EmptyDirs) ->
   {ok, FilesInDir} = file:list_dir(Dir),
   {Files, Dirs} = lists:foldl(fun(F, {Fs, Ds}) ->
                                  Path = Dir ++ "/" ++ F,
                                  case filelib:is_dir(Path) of
                                     true ->
                                          {Fs, [Path | Ds]};
                                     false ->
                                          {[Path | Fs], Ds}
                                  end
                               end, {[],[]}, FilesInDir),
   lists:foreach(fun(F) ->
                         ok = file:delete(F)
                 end, Files),
   del_all_files(T ++ Dirs, [Dir | EmptyDirs]).

 
%% Tests
 
-ifndef(TEST).
-include_lib("eunit/include/eunit.hrl").
 
non_existing_file_returns_error_test() ->
    ?assertEqual({error, enoent},
                 recursively_list_dir("UnUSuAalfIlEnaMe")),
    ok.
 
non_directory_input_returns_error_test() ->
    cleanup(),
    file:write_file("f1.test", <<"temp test file">>),
    ?assertEqual({error, enotdir}, 
                 recursively_list_dir("f1.test")),
    cleanup(),
    ok.
 
simple_test() ->
    cleanup(),
    filelib:ensure_dir("a/b/c/"),
    ?assertEqual({ok, ["a/b/c", "a/b", "a"]}, 
                 recursively_list_dir("a")),
    file:write_file("a/b/f.test", <<"temp test file">>),
    ?assertEqual({ok, ["a/b/f.test","a/b/c","a/b","a"]}, 
                 recursively_list_dir("a")),
    cleanup(),
    ok.
 
filesonly_test() ->
    cleanup(),
    filelib:ensure_dir("a/b/f.test"),
    file:write_file("a/b/f.test", <<"hello">>),
    ?assertEqual({ok, ["a/b/f.test"]}, 
                 recursively_list_dir("a", true)),
    cleanup(),
    ok.

simple2_test() ->
    filelib:ensure_dir("a/b/c/"),
    file:write_file("a/b/f.test", <<"hello">>),
    ?assertEqual(ok, del_dir("a")),
    ok.

cleanup() ->
    file:delete("f1.test"),
    file:delete("a/b/f.test"),
    file:del_dir("a/b/c"),
    file:del_dir("a/b"),
    file:del_dir("a"),
    ok.
 
-endif.
