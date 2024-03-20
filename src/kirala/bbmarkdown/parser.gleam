import gleam/bit_array
import gleam/string
import gleam/list
import gleam/uri
import gleam/dynamic
import kirala/bbmarkdown/sub.{fmt}

pub type Align {
  AlignLeft
  AlignRight
  AlignCenter
}

pub type ListType {
  StdList
  OrderedList
  CheckedList
  UncheckedList
}

type ParseRes {
  ParseRes(String, BitArray)
}

pub type TokenRes {
  TokenRes(Token, BitArray)
}

pub type UrlData {
  UrlPlain(String)
  UrlFootNote(String)
}

pub type Token {
  Line(List(Token))
  LineIndent(Int, List(Token))
  Text(String)
  Bold(Token)
  Italic(Token)
  StrikeThrough(Token)
  MarkedText(Token)
  InsertedText(Token)
  Note(String, Token)
  H(Int, Int, Token)
  CodeBlock(String, String, String)
  CodeSpan(String)
  CodeLine(String)
  BlockQuote(Int, Token)
  ListItem(ListType, Int, Token)
  Url(UrlData)
  UrlLink(String, UrlData)
  ImgLink(String, String, UrlData)
  FootNote(String, Token)
  FootNoteUrlDef(String, String, String)
  Table(List(Token), List(Align), List(List(Token)))
  DefinitionOf(Token)
  Definition(List(Token))
  DefinitionIs(String, Token)
  HR
}

type SrcPos {
  SrcPos(line: Int, col: Int)
}

pub fn ret_string_trim(bitstr: BitArray) {
  let assert Ok(str) = bit_array.to_string(bitstr)
  str
  |> string.trim
}

pub fn ret_string(bitstr: BitArray) {
  fmt("~ts", #(bitstr))
}

fn get_indent_nextchar(indent: Int, src: BitArray) -> #(Int, String) {
  case src {
    <<>> -> #(0, "")
    <<" ":utf8, rest:bits>> | <<"\t":utf8, rest:bits>> ->
      get_indent_nextchar(indent + 1, rest)

    <<"\n\r":utf8, rest:bits>>
    | <<"\r\n":utf8, rest:bits>>
    | <<"\n":utf8, rest:bits>>
    | <<"\r":utf8, rest:bits>> -> #(0, "")
    <<chr, rest:bits>> -> #(
      indent,
      <<chr>>
        |> ret_string,
    )
    unhandable -> #(0, "<unhandable>")
  }
}

fn get_nextchar(src: BitArray) -> String {
  case src {
    <<>> -> ""
    <<" ":utf8, rest:bits>>
    | <<"\t":utf8, rest:bits>>
    | <<"\n\r":utf8, rest:bits>>
    | <<"\r\n":utf8, rest:bits>>
    | <<"\n":utf8, rest:bits>>
    | <<"\r":utf8, rest:bits>> -> get_nextchar(rest)
    <<chr, rest:bits>> ->
      <<chr>>
      |> ret_string
    unhandable -> "<unhandable>"
  }
}

fn get_line(src: BitArray, acc: BitArray) -> ParseRes {
  case src {
    <<>> -> ParseRes(ret_string_trim(acc), <<>>)
    <<"\n\r":utf8, rest:bits>>
    | <<"\r\n":utf8, rest:bits>>
    | <<"\n":utf8, rest:bits>>
    | <<"\r":utf8, rest:bits>> -> ParseRes(ret_string_trim(acc), rest)
    <<chr, rest:bits>> -> get_line(rest, <<acc:bits, chr>>)
    unhandable -> ParseRes(ret_string_trim(acc), <<>>)
  }
}

fn string_end_with(src: String, end_with: String) -> Bool {
  let slen = string.length(src)
  let elen = string.length(end_with)
  let endstr = string.slice(src, slen - elen, elen)
  endstr == end_with
}

fn string_skip_first(src: String) -> String {
  string.slice(src, 1, string.length(src) - 1)
}

fn is_img_url_(url: String, exts: List(String)) {
  case exts {
    [] -> False
    [ext, ..rest] ->
      case string_end_with(url, ext) {
        True -> True
        _ -> is_img_url_(url, rest)
      }
  }
}

fn is_img_url(url: String) {
  is_img_url_(url, [".jpg", ".jpeg", ".png", ".gif"])
}

fn decode_url_(src: BitArray, acc: BitArray) -> ParseRes {
  case src {
    <<>> -> ParseRes(ret_string_trim(acc), <<>>)
    <<" ":utf8, rest:bits>>
    | <<"\n\r":utf8, rest:bits>>
    | <<"\r\n":utf8, rest:bits>>
    | <<"\n":utf8, rest:bits>>
    | <<"\r":utf8, rest:bits>> -> ParseRes(ret_string_trim(acc), rest)
    <<chr, rest:bits>> -> decode_url_(rest, <<acc:bits, chr>>)
    unhandable -> ParseRes(ret_string_trim(acc), <<>>)
  }
}

fn decode_url(src: BitArray) -> TokenRes {
  let ParseRes(url, rest) = decode_url_(src, <<>>)
  let t = case is_img_url(url) {
    True -> ImgLink("", "", UrlPlain(url))
    _ -> Url(UrlPlain(url))
  }
  TokenRes(t, rest)
}

fn decode_codeblock_(src: BitArray, acc: BitArray) -> ParseRes {
  case src {
    <<"```":utf8, rest:bits>> -> {
      let ParseRes(_, rest2) = get_line(rest, <<>>)
      ParseRes(ret_string(acc), rest2)
    }
    <<chr, rest:bits>> -> decode_codeblock_(rest, <<acc:bits, chr>>)
    unhandable -> ParseRes(ret_string(acc), <<>>)
  }
}

fn decode_codeblock(src: BitArray) -> TokenRes {
  let ParseRes(inf, rest0) = get_line(src, <<>>)
  let #(syntax, filename) = case string.split(inf, ":") {
    [syntax] -> #(syntax, "")
    [syntax, filename] -> #(syntax, filename)
    _ -> #("", "")
  }
  let ParseRes(code, rest1) = decode_codeblock_(rest0, <<>>)
  TokenRes(CodeBlock(syntax, filename, code), rest1)
}

fn decode_note(src: BitArray) -> TokenRes {
  let ParseRes(title, rest0) = get_line(src, <<>>)
  let ParseRes(code, rest1) = get_until3(rest0, ":::")
  let TokenRes(t, _) =
    parse(
      0,
      code
        |> bit_array.from_string,
    )
  TokenRes(Note(title, t), rest1)
}

//fn decode_definition_(
//  nindent: Int,
//  src: BitArray,
//  acc: List(Token),
//) -> TokenRes {
//  let TokenRes(t, rest) = parser(0, src)
//  case t {
//    LineIndent(next_indent, tokens) if nindent == next_indent ->
//      decode_definition_(nindent, rest, [Line(tokens), ..acc])
//    _ -> TokenRes(Definition(list.reverse(acc)), src)
//  }
//}
fn decode_definition_(nindent: Int, src: BitArray, acc: List(Token)) -> TokenRes {
  case get_indent_nextchar(0, src) {
    #(next_indent, _) if next_indent != 0 -> {
      let TokenRes(t, rest) = decode_line(src)
      decode_definition_(nindent, rest, [t, ..acc])
    }
    #(next_indent, _) ->
      //log("indent = ~p / ~p", [nindent, next_indent])
      TokenRes(Definition(list.reverse(acc)), src)
  }
}

fn decode_definition(indent: Int, src: BitArray) -> TokenRes {
  let TokenRes(t, rest) = decode_line(src)
  //log("def = ~p", [t])
  decode_definition_(indent, rest, [t])
}

fn decode_definition_is(indent: Int, src: BitArray) -> TokenRes {
  let ParseRes(str, rest) = get_line(src, <<>>)
  //log("definition is ~p", [str])
  case string.split_once(str, " ") {
    Ok(#(left, right)) -> {
      //log("left = ~p", [left])
      //log("right = ~p", [right])
      let TokenRes(t, _) =
        decode_line(
          right
          |> string.trim
          |> bit_array.from_string,
        )
      //log("t = ~p", [t])
      TokenRes(DefinitionIs(string.trim(left), t), rest)
    }
    _ -> {
      let TokenRes(t, _) =
        decode_line(
          str
          |> string.trim
          |> bit_array.from_string,
        )
      TokenRes(Definition([t]), rest)
    }
  }
}

fn decode_ordered_list(indent: Int, src: BitArray) -> TokenRes {
  let TokenRes(t, rest) = decode_line(src)
  TokenRes(ListItem(OrderedList, indent, t), rest)
}

fn decode_list(indent: Int, src: BitArray) -> TokenRes {
  let TokenRes(t, rest) = decode_line(src)
  TokenRes(ListItem(StdList, indent, t), rest)
}

fn decode_checklist(indent: Int, check: Bool, src: BitArray) -> TokenRes {
  let TokenRes(t, rest) = decode_line(src)
  case check {
    True -> TokenRes(ListItem(CheckedList, indent, t), rest)
    _ -> TokenRes(ListItem(UncheckedList, indent, t), rest)
  }
}

fn decode_blockquote(indent: Int, src: BitArray) -> TokenRes {
  let TokenRes(t, rest) = decode_line(src)
  TokenRes(BlockQuote(indent, t), rest)
}

fn get_until1_(src: BitArray, acc: BitArray, nterm: Int) -> ParseRes {
  case src {
    <<>> -> ParseRes("", <<>>)
    <<str:size(8), rest:bits>> if str == nterm ->
      ParseRes(ret_string(acc), rest)
    <<chr, rest:bits>> -> get_until1_(rest, <<acc:bits, chr>>, nterm)
    unhandable -> ParseRes(ret_string(acc), <<>>)
  }
}

fn get_until1(src: BitArray, terminator: String) -> ParseRes {
  let assert <<nterm:size(8)>> = bit_array.from_string(terminator)
  get_until1_(src, <<>>, nterm)
}

fn get_until2_(src: BitArray, acc: BitArray, nterm: Int) -> ParseRes {
  case src {
    <<>> -> ParseRes("", <<>>)
    <<str:size(16), rest:bits>> if str == nterm ->
      ParseRes(ret_string(acc), rest)
    <<chr, rest:bits>> -> get_until2_(rest, <<acc:bits, chr>>, nterm)
    unhandable -> ParseRes(ret_string(acc), <<>>)
  }
}

fn get_until2(src: BitArray, terminator: String) -> ParseRes {
  let assert <<nterm:size(16)>> = bit_array.from_string(terminator)
  get_until2_(src, <<>>, nterm)
}

fn get_until3_(src: BitArray, acc: BitArray, nterm: Int) -> ParseRes {
  case src {
    <<>> -> ParseRes("", <<>>)
    <<str:size(24), rest:bits>> if str == nterm ->
      ParseRes(ret_string(acc), rest)
    <<chr, rest:bits>> -> get_until3_(rest, <<acc:bits, chr>>, nterm)
    unhandable -> ParseRes(ret_string(acc), <<>>)
  }
}

fn get_until3(src: BitArray, terminator: String) -> ParseRes {
  let assert <<nterm:size(24)>> = bit_array.from_string(terminator)
  get_until3_(src, <<>>, nterm)
}

fn get_until4_(src: BitArray, acc: BitArray, nterm: Int) -> ParseRes {
  case src {
    <<>> -> ParseRes("", <<>>)
    <<str:size(32), rest:bits>> if str == nterm ->
      ParseRes(ret_string(acc), rest)
    <<chr, rest:bits>> -> get_until4_(rest, <<acc:bits, chr>>, nterm)
    unhandable -> ParseRes(ret_string(acc), <<>>)
  }
}

fn get_until4(src: BitArray, terminator: String) -> ParseRes {
  let assert <<nterm:size(32)>> = bit_array.from_string(terminator)
  get_until4_(src, <<>>, nterm)
}

fn decode_codespan(src: BitArray) -> TokenRes {
  //let ParseRes(str, rest) = decode_codespan_(src, <<>>)
  let ParseRes(str, rest) = get_until1(src, "`")
  TokenRes(CodeSpan(str), rest)
}

fn decode_h(id: Int, n: Int, src: BitArray) -> TokenRes {
  let TokenRes(t, rest) = decode_line(src)
  //log("decode_h ~ts", [rest])
  TokenRes(H(id, n, t), rest)
}

fn decode_hr(src: BitArray) -> TokenRes {
  let ParseRes(str, rest) = get_line(src, <<>>)
  TokenRes(HR, rest)
}

fn decode_bold(src: BitArray, terminator: String) -> TokenRes {
  let ParseRes(str, rest) = get_until2(src, terminator)
  //log("bold1 = ~p", [str])
  let TokenRes(t, _) =
    decode_line(
      str
      |> bit_array.from_string,
    )
  //log("bold token = ~p", [t])
  TokenRes(Bold(t), rest)
}

fn decode_italic(src: BitArray, terminator: String) -> TokenRes {
  let ParseRes(str, rest) = get_until1(src, terminator)
  let TokenRes(t, _) =
    decode_line(
      str
      |> bit_array.from_string,
    )
  TokenRes(Italic(t), rest)
}

fn decode_strikethrough(src: BitArray) -> TokenRes {
  let ParseRes(str, rest) = get_until3(src, "~~ ")
  let TokenRes(t, _) =
    decode_line(
      str
      |> bit_array.from_string,
    )
  TokenRes(StrikeThrough(t), rest)
}

fn decode_marked_text(src: BitArray) -> TokenRes {
  let ParseRes(str, rest) = get_until3(src, "== ")
  let TokenRes(t, _) =
    decode_line(
      str
      |> bit_array.from_string,
    )
  TokenRes(MarkedText(t), rest)
}

fn decode_inserted_text(src: BitArray) -> TokenRes {
  let ParseRes(str, rest) = get_until3(src, "++ ")
  let TokenRes(t, _) =
    decode_line(
      str
      |> bit_array.from_string,
    )
  TokenRes(InsertedText(t), rest)
}

fn decode_footnote_urldef(src: BitArray) -> TokenRes {
  let ParseRes(line, rest) = get_line(src, <<>>)
  let ParseRes(id, lrest) =
    get_until2(
      line
        |> bit_array.from_string,
      "]:",
    )
  let ParseRes(xurl, lrest2) = get_line(lrest, <<>>)

  let #(url, alt) = case string.split(xurl, " \"") {
    [url] -> #(url, "")
    [url, alt] ->
      case string.split(alt, "\"") {
        [str] -> #(url, str)
        [str, ..] -> #(url, str)
        _ -> #(url, alt)
      }
    _ -> #(xurl, "")
  }
  TokenRes(FootNoteUrlDef(id, url, alt), rest)
}

fn decode_footnote(src: BitArray) -> TokenRes {
  let ParseRes(line, rest) = get_line(src, <<>>)
  let ParseRes(id, lrest) =
    get_until2(
      line
        |> bit_array.from_string,
      "]:",
    )
  let TokenRes(t, _) = decode_line(lrest)
  TokenRes(FootNote(id, t), rest)
}

fn decode_imglink(src: BitArray) -> TokenRes {
  let ParseRes(caption, rest) = get_until1(src, "]")
  case get_nextchar(rest) {
    "[" -> {
      let ParseRes(_, rest2) = get_until1(rest, "[")
      let ParseRes(url, rest3) = get_until1(rest2, "]")
      TokenRes(ImgLink(caption, "", UrlFootNote(url)), rest3)
    }
    _ -> {
      let ParseRes(_, rest2) = get_until1(rest, "(")
      let ParseRes(xurl, rest3) = get_until1(rest2, ")")
      let #(url, alt) = case string.split(xurl, " \"") {
        [url] -> #(url, "")
        [url, alt] ->
          case string.split(alt, "\"") {
            [str] -> #(url, str)
            _ -> #(url, alt)
          }
        _ -> #(xurl, "")
      }
      TokenRes(ImgLink(caption, alt, UrlPlain(url)), rest3)
    }
  }
}

fn decode_footnote_link(src: BitArray) -> TokenRes {
  let ParseRes(id, rest) = get_until1(src, "]")
  TokenRes(Url(UrlFootNote(id)), rest)
}

fn decode_urllink(src: BitArray) -> TokenRes {
  let ParseRes(sline, rest) = get_line(src, <<>>)
  let line = bit_array.from_string(sline)
  let ParseRes(urlid, rest) = get_until2(line, "]:")
  let ParseRes(caption, rest) = get_until1(line, "]")
  //log("urlid = ~p", [urlid])
  //log("caption = ~p", [caption])
  case #(urlid, caption) {
    #("", _) ->
      case get_nextchar(rest) {
        "[" -> {
          let ParseRes(_, rest2) = get_until1(rest, "[")
          let ParseRes(url, rest3) = get_until1(rest2, "]")
          TokenRes(UrlLink(caption, UrlFootNote(url)), rest3)
        }
        _ -> {
          let ParseRes(_, rest2) = get_until1(rest, "(")
          let ParseRes(url, rest3) = get_until1(rest2, ")")
          TokenRes(UrlLink(caption, UrlPlain(url)), rest3)
        }
      }
    _ -> decode_footnote_urldef(src)
  }
}

fn decode_text(src: BitArray, acc: BitArray) -> TokenRes {
  case src {
    <<>> -> TokenRes(Text(ret_string(acc)), <<>>)
    <<"https://":utf8, rest:bits>>
    | <<"http://":utf8, rest:bits>>
    | <<"![":utf8, rest:bits>>
    | <<"[":utf8, rest:bits>>
    | <<"`":utf8, rest:bits>>
    | <<" **":utf8, rest:bits>>
    | <<" *":utf8, rest:bits>>
    | <<"~~ ":utf8, rest:bits>> -> TokenRes(Text(ret_string(acc)), src)
    <<chr, rest:bits>> -> decode_text(rest, <<acc:bits, chr>>)
    unhandable -> TokenRes(Text(ret_string(acc)), <<>>)
  }
}

fn decode_line__(src: BitArray) -> TokenRes {
  case src {
    <<"`":utf8, rest:bits>> -> decode_codespan(rest)
    <<" **":utf8, rest:bits>> -> decode_bold(rest, "**")
    <<" __":utf8, rest:bits>> -> decode_bold(rest, "__")
    <<" *":utf8, rest:bits>> -> decode_italic(rest, "*")
    <<" _":utf8, rest:bits>> -> decode_italic(rest, "_")
    <<" ~~":utf8, rest:bits>> -> decode_strikethrough(rest)
    <<"https://":utf8, rest:bits>> -> decode_url(src)
    <<"http://":utf8, rest:bits>> -> decode_url(src)
    <<"![":utf8, rest:bits>> -> decode_imglink(rest)
    <<"[^":utf8, rest:bits>> -> decode_footnote_link(rest)
    <<"[":utf8, rest:bits>> -> decode_urllink(rest)
    <<" ==":utf8, rest:bits>> -> decode_marked_text(rest)
    <<" ++":utf8, rest:bits>> -> decode_inserted_text(rest)
    _ -> decode_text(src, <<>>)
  }
}

fn decode_line_(src: BitArray, acc: List(Token)) -> List(Token) {
  case src {
    <<>> -> list.reverse(acc)
    _ -> {
      let TokenRes(t, rest) = decode_line__(src)
      decode_line_(rest, [t, ..acc])
    }
  }
}

/// 最後尾に空白を追加して処理を単純化
fn decode_line(src: BitArray) -> TokenRes {
  let ParseRes(linestr, rest) = get_line(src, <<>>)
  let line =
    linestr
    |> bit_array.from_string
  let ts = decode_line_(<<" ":utf8, line:bits, " ":utf8>>, [])
  TokenRes(Line(ts), rest)
}

fn decode_line2(indent: Int, src: BitArray) -> TokenRes {
  case indent {
    i if i >= 2 -> {
      let ParseRes(linestr, rest) = get_line(src, <<>>)
      TokenRes(CodeLine(linestr), rest)
    }
    _ -> {
      let ParseRes(linestr, rest) = get_line(src, <<>>)
      let line =
        linestr
        |> bit_array.from_string
      let ts = decode_line_(<<" ":utf8, line:bits, " ":utf8>>, [])
      case get_nextchar(rest) {
        ":" -> TokenRes(DefinitionOf(Line(ts)), rest)
        _ -> TokenRes(LineIndent(indent, ts), rest)
      }
    }
  }
}

fn list_remove_last(l: List(a)) -> List(a) {
  let assert [_, ..tail] = list.reverse(l)
  tail
  |> list.reverse
}

fn decode_table_items(
  src: BitArray,
  acc: List(List(Token)),
) -> #(List(List(Token)), BitArray) {
  case src {
    <<"|":utf8, rest:bits>> -> {
      let #(trow, rest2) = decode_table_row(rest)
      decode_table_items(rest2, [trow, ..acc])
    }
    _ -> #(list.reverse(acc), src)
  }
}

fn decode_table_row(src: BitArray) -> #(List(Token), BitArray) {
  let ParseRes(header, rest) = get_line(src, <<>>)
  let splitted =
    string.split(header, "|")
    |> list_remove_last
  //log("splitted = ~p", [splitted])
  let tlist =
    list.map(splitted, fn(str) {
      let TokenRes(t, _) =
        decode_line(
          str
          |> bit_array.from_string,
        )
      t
    })
  #(tlist, rest)
}

fn decode_table(src: BitArray) -> TokenRes {
  let #(header, rest) = decode_table_row(src)
  let ParseRes(align_line, rest2) = get_line(rest, <<>>)
  let splitted_align =
    string.split(align_line, "|")
    |> list_remove_last
  let aligns =
    list.map(splitted_align, fn(a) {
      case string_end_with(a, "-:") {
        True -> AlignRight
        _ -> AlignLeft
      }
    })
  let #(lines, rest3) = decode_table_items(rest2, [])
  TokenRes(Table(header, aligns, lines), rest3)
}

fn parse_(lineno: Int, src: BitArray, indent: Int) -> TokenRes {
  case src {
    <<"  ":utf8, rest:bits>> -> parse_(lineno, rest, indent + 1)
    <<"#######":utf8, rest:bits>> -> decode_h(lineno, 7, rest)
    <<"######":utf8, rest:bits>> -> decode_h(lineno, 6, rest)
    <<"#####":utf8, rest:bits>> -> decode_h(lineno, 5, rest)
    <<"####":utf8, rest:bits>> -> decode_h(lineno, 4, rest)
    <<"###":utf8, rest:bits>> -> decode_h(lineno, 3, rest)
    <<"##":utf8, rest:bits>> -> decode_h(lineno, 2, rest)
    <<"#":utf8, rest:bits>> -> decode_h(lineno, 1, rest)
    <<"```":utf8, rest:bits>> -> decode_codeblock(rest)
    <<":::":utf8, rest:bits>> -> decode_note(rest)
    <<"---":utf8, rest:bits>> -> decode_hr(rest)
    <<"___":utf8, rest:bits>> -> decode_hr(rest)
    <<"***":utf8, rest:bits>> -> decode_hr(rest)
    <<"> > > ":utf8, rest:bits>> -> decode_blockquote(3, rest)
    <<">> ":utf8, rest:bits>> -> decode_blockquote(2, rest)
    <<"> ":utf8, rest:bits>> -> decode_blockquote(1, rest)
    <<"- [x] ":utf8, rest:bits>> -> decode_checklist(indent, True, rest)
    <<"- [ ] ":utf8, rest:bits>> -> decode_checklist(indent, False, rest)
    <<"[^":utf8, rest:bits>> -> decode_footnote(rest)
    <<"*[":utf8, rest:bits>> -> decode_footnote(rest)
    //<<"[":utf8, rest:bit_array>> -> decode_footnote_urldef(rest)
    <<dch1, ".":utf8, rest:bits>> if 0x30 <= dch1 && dch1 <= 0x39 ->
      decode_ordered_list(indent, rest)
    <<dch1, dch2, ".":utf8, rest:bits>> if 0x30 <= dch1
      && dch1 <= 0x39
      && 0x30 <= dch2
      && dch2 <= 0x39 -> decode_ordered_list(indent, rest)
    <<"* ":utf8, rest:bits>>
    | <<"+ ":utf8, rest:bits>>
    | <<"- ":utf8, rest:bits>> -> decode_list(indent, rest)
    <<"|":utf8, rest:bits>> -> decode_table(rest)
    <<": ":utf8, rest:bits>> -> decode_definition(indent, rest)
    <<":":utf8, rest:bits>> -> decode_definition_is(indent, rest)
    _ -> decode_line2(indent, src)
  }
}

pub fn parse(lineno: Int, src: BitArray) -> TokenRes {
  //log("parser - ~ts", [src])
  parse_(lineno, src, 1)
}

fn parse_all_(lineno: Int, src: BitArray, acc: List(Token)) -> List(Token) {
  case bit_array.byte_size(src) {
    0 -> list.reverse(acc)
    _ -> {
      let TokenRes(t, rest) = parse(lineno, src)
      parse_all_(lineno + 1, rest, [t, ..acc])
    }
  }
}

pub fn parse_all(src: String) -> List(Token) {
  parse_all_(1, bit_array.from_string(src), [])
}
