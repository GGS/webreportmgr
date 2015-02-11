-module(directory).
-export([del_dir/1, zip_dir/2]).
%Для удаления директорий вместе с содержимым
% src https://erlangcentral.org/wiki/index.php?title=Delete_a_File
del_dir(Dir) ->
   lists:foreach(fun(D) ->
                    ok = file:del_dir(D)
                 end, del_all_files([Dir], [])).
 
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

zip_dir(Name, Dir) ->
    {ok,Cwd} = file:get_cwd(),
    file:set_cwd(Dir),
    {ok, Files} = file_utils:recursively_list_dir("result", true),
    %io:format("~p",[Files]),
    zip:create(Name, Files),
    ok = file:set_cwd(Cwd).

