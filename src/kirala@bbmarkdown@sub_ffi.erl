-module(kirala@bbmarkdown@sub_ffi).
-compile(export_all).

to_list(X) when is_tuple(X) -> tuple_to_list(X);
to_list(X) when is_list(X) -> X.

format(Format, Args) ->
    LArgs = to_list(Args),
    %list_to_binary( lists:flatten( io_lib:format(Format, LArgs) ) ).
    unicode:characters_to_binary( lists:flatten( io_lib:format(Format, LArgs) ) ).