//@external(erlang, "kirala_peasy_ffi", "readline")
//pub fn readline(prompt: String) -> String
//
//@external(erlang, "kirala_peasy_ffi", "show")
//pub fn show(any) -> String
//
//@external(erlang, "kirala_peasy_ffi", "println")
//pub fn println(any) -> String
//
//@external(erlang, "kirala_peasy_ffi", "print")
//pub fn print(any) -> String
//
//@external(erlang, "kirala_peasy_ffi", "read_file")
//pub fn read_file(filepath: String) -> Result(BitArray, String)
//
//@external(erlang, "kirala_peasy_ffi", "read_text_file")
//pub fn read_text_file(filepath: String) -> Result(BitArray, String)
//
//@external(erlang, "kirala_peasy_ffi", "http_get")
//pub fn http_get_text(
//  url: String,
//  headers: List(#(String, String)),
//) -> Result(String, String)

@external(erlang, "kirala_peasy_ffi", "now")
pub fn now() -> Float
