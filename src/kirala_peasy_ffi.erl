-module(kirala_peasy_ffi).
-compile(export_all).

%readline(Prompt) ->
%
%show(Any) ->
%
%println(Any) ->
%
%print(Any) ->
%
%read_file(Filepath) ->
%
%read_text_file(Filepath) ->
%
%http_get(Url,Headers) ->

now() ->
    timestamp( erlang:now() ).

timestamp({Mega, Secs, Micro}) ->
    (Mega*1000*1000*1000*1000 + Secs * 1000 * 1000 + Micro) / 1000000.0.
