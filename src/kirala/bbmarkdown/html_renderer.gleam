import gleam/bit_array
import gleam/string
import gleam/list
import gleam/dict.{type Dict}
import gleam/uri
import gleam/dynamic
import kirala/bbmarkdown/sub.{fmt}
import kirala/bbmarkdown/parser.{
  type Token, type UrlData, BlockQuote, Bold, CheckedList, CodeBlock, CodeLine,
  CodeSpan, Definition, DefinitionIs, DefinitionOf, FootNote, FootNoteUrlDef, H,
  HR, ImgLink, InsertedText, Italic, Line, LineIndent, ListItem, MarkedText,
  Note, OrderedList, StdList, StrikeThrough, Table, Text, TokenRes,
  UncheckedList, Url, UrlFootNote, UrlLink, UrlPlain, parse, ret_string,
  ret_string_trim,
}

fn url_of(symbols: Dict(String, String), url: UrlData) -> String {
  case url {
    UrlPlain(str) -> str
    UrlFootNote(id) ->
      case dict.get(symbols, id) {
        Ok(str) -> str
        _ -> id
      }
  }
}

pub fn html_encode_(src: BitArray, acc: BitArray) -> BitArray {
  case src {
    <<>> -> acc
    _ -> {
      let #(newacc, rest) = case src {
        <<"&":utf8, rest:bits>> -> #(<<acc:bits, "&amp;":utf8>>, rest)
        <<"<":utf8, rest:bits>> -> #(<<acc:bits, "&lt;":utf8>>, rest)
        <<">":utf8, rest:bits>> -> #(<<acc:bits, "&gt;":utf8>>, rest)
        //<<160, rest:bit_array>> -> #(<<acc:bit_array, "&nbsp;":utf8>>, rest)
        <<chr, rest:bits>> -> #(<<acc:bits, chr>>, rest)
        unhandable -> {
          #(<<acc:bits>>, <<>>)
        }
      }
      html_encode_(rest, newacc)
    }
  }
}

pub fn html_encode(src: String) -> String {
  html_encode_(bit_array.from_string(src), <<>>)
  |> ret_string
  //let bits = html_encode_(bit_array.from_string(src), <<>>)
  //log("~p", [bits])
  //bits
  //|> ret_string
}

pub fn emit_text(symbols: Dict(String, String), t: Token) -> String {
  case t {
    Text(text) -> html_encode(fmt("~ts", [text]))
    Bold(t) | Italic(t) | StrikeThrough(t) | MarkedText(t) | InsertedText(t) ->
      emit(symbols, t)
    Line(ts) -> {
      let str =
        list.map(ts, fn(e) { emit(symbols, e) })
        |> string.concat
      case string.length(string.trim(str)) == 0 {
        True -> "<br>"
        _ -> fmt("~ts", [str])
      }
    }
    Url(UrlFootNote(url)) -> fmt("~ts", [url])
    Url(url) -> fmt("~ts", [url])
    UrlLink(caption, url) -> {
      let clen = string.length(caption) - 1
      let tcaption = case string.starts_with(caption, "\\") {
        True -> html_encode(string.slice(caption, 1, clen))
        _ -> caption
      }
      tcaption
    }
    _ -> ""
  }
}

pub fn emit(symbols: Dict(String, String), t: Token) -> String {
  case t {
    Text(text) -> html_encode(fmt("~ts", #(text)))
    Bold(t) -> fmt("<strong>~ts</strong>", #(emit(symbols, t)))
    Italic(t) -> fmt("<em>~ts</em>", #(emit(symbols, t)))
    StrikeThrough(t) -> fmt("<s>~ts</s>", #(emit(symbols, t)))
    MarkedText(t) -> fmt("<mark>~ts</mark>", #(emit(symbols, t)))
    InsertedText(t) -> fmt("<ins>~ts</ins>", #(emit(symbols, t)))
    LineIndent(_, ts) | Line(ts) -> {
      let str =
        list.map(ts, fn(e) { emit(symbols, e) })
        |> string.concat
      case string.length(string.trim(str)) == 0 {
        True -> "<br>"
        _ -> fmt("~ts", [str])
      }
    }
    H(id, level, title) ->
      fmt("<h~w id='H~w'>~ts</h~w>\n", #(level, id, emit(symbols, title), level))
    Url(UrlFootNote(url)) ->
      fmt("<sup><a href='#~ts'>~ts</a></sup>", #(url, url))
    Url(url) ->
      fmt("<a href='~ts'>~ts</a>", #(url_of(symbols, url), url_of(symbols, url)))
    UrlLink(caption, url) -> {
      let clen = string.length(caption) - 1
      let tcaption = case string.starts_with(caption, "\\") {
        True -> html_encode(string.slice(caption, 1, clen))
        _ -> caption
      }
      //log("tcaption = ~ts", [tcaption])
      fmt("<a href='~ts'>~ts</a>", #(url_of(symbols, url), tcaption))
    }
    ImgLink(caption, alt, url) ->
      fmt("<img src='~ts' alt='~ts'>~ts</a>", [
        url_of(symbols, url),
        alt,
        caption,
      ])
    FootNote(id, t) ->
      fmt("<div id='~ts'>※ ~ts</div>", [id, emit(symbols, t)])
    FootNoteUrlDef(id, url, alt) -> fmt("[~ts]:~ts \"~ts\"<br>", [id, url, alt])
    CodeLine(code) -> fmt("~ts\n", [code])
    CodeSpan(code) -> fmt("<code>~ts</code>", [code])
    CodeBlock(syntax, filename, code) ->
      case syntax {
        "csv" | "tsv" ->
          fmt(
            "<div><nav class='nav'>~ts</nav><pre class='~ts'>~ts</pre>\n</div>",
            [filename, syntax, code],
          )
        _ ->
          fmt(
            "<div class='highlight'><nav class='nav'>~ts</nav><pre><code class='~ts'>~ts</code></pre>\n</div>",
            [filename, syntax, code],
          )
      }
    DefinitionIs(obj, verb) ->
      fmt("<dl><dt class='line'>~ts</dt><dd class='line'>~ts</dd></dl>", [
        obj,
        emit(symbols, verb),
      ])
    Note(title, t) ->
      fmt("<div class='~ts'>~ts</div>", [title, emit(symbols, t)])
    BlockQuote(level, code) -> emit(symbols, code)
    ListItem(StdList, level, t) -> fmt("<li>~ts</li>\n", [emit(symbols, t)])
    ListItem(CheckedList, check, t) ->
      fmt("<li><input type='checkbox' checked='1'/>~ts</li>\n", [
        emit(symbols, t),
      ])
    ListItem(UncheckedList, check, t) ->
      fmt("<li><input type='checkbox' />~ts</li>\n", [emit(symbols, t)])
    ListItem(OrderedList, level, t) -> fmt("<li>~ts</li>\n", [emit(symbols, t)])
    Table(header, align, rows) -> {
      let theader =
        list.map(header, fn(t) { fmt("<th>~ts</th>", [emit(symbols, t)]) })
        |> string.concat
      let trows =
        list.map(rows, fn(row) {
          let cols = row
          let trow =
            list.map(cols, fn(col) { fmt("<td>~ts</td>", [emit(symbols, col)]) })
          fmt("<tr>~ts</th>", [trow])
        })
        |> string.concat
      fmt(
        "<section class='table'><table class='table table-light table-striped table-sm'><thead><tr>~ts</tr><thead><tbody>~ts<tbody></table></section>",
        [theader, trows],
      )
    }
    HR -> "<hr>"
    _ -> fmt("~p", [t])
  }
}

pub fn convert(src: String) -> String {
  convert_bytes(bit_array.from_string(src))
}

pub fn convert_outline(src: String) -> String {
  convert_bytes_outline(bit_array.from_string(src))
}

pub fn convert_digest(src: String) -> String {
  convert_bytes_digest(bit_array.from_string(src))
}

fn convert_(
  lineno: Int,
  bytes: BitArray,
  acc: List(Token),
  symbols: Dict(String, String),
) {
  case string.length(ret_string_trim(bytes)) {
    len if len == 0 -> #(list.reverse(acc), symbols)
    _ -> {
      let TokenRes(t, rest) = parse(lineno, bytes)
      let new_symbols = case t {
        FootNoteUrlDef(id, url, alt) -> dict.insert(symbols, id, url)
        _ -> symbols
      }
      convert_(lineno + 1, rest, [t, ..acc], new_symbols)
    }
  }
}

fn ntimes(n: Int, str: String) {
  list.map(list.range(0, n), fn(e) { str })
  |> string.concat
}

pub fn convert_bytes(bytes: BitArray) -> String {
  let #(tokens, symbols) = convert_(0, bytes, [], dict.new())
  convert_tokens_(tokens, symbols)
}

pub fn convert_tokens_(
  tokens: List(Token),
  symbols: Dict(String, String),
) -> String {
  let #(_, strlist) =
    list.fold(tokens, #(HR, []), fn(acx, t) -> #(Token, List(List(String))) {
      //log("-- ~p", [t])
      let #(prev, acc) = acx
      case #(prev, t) {
        // List
        #(ListItem(_, indent1, t1), ListItem(_, indent2, t2)) if indent1
          == indent2 -> #(t, [[emit(symbols, t)], ..acc])
        #(ListItem(_, indent1, t1), ListItem(_, indent2, t2)) if indent1
          > indent2 -> #(t, [
          [ntimes(indent1 - indent2, "</ul>"), emit(symbols, t)],
          ..acc
        ])
        #(ListItem(_, indent1, t1), ListItem(_, indent2, t2)) if indent1
          < indent2 -> #(t, [
          [ntimes(indent2 - indent1, "<ul>"), emit(symbols, t)],
          ..acc
        ])
        #(ListItem(_, indent1, t1), _) -> #(t, [
          [ntimes(indent1, "</ul>"), emit(symbols, t)],
          ..acc
        ])
        #(_, ListItem(_, indent2, t2)) -> #(t, [
          [ntimes(indent2, "<ul>"), emit(symbols, t)],
          ..acc
        ])

        // BlockQuote
        #(BlockQuote(indent1, t1), BlockQuote(indent2, t2)) if indent1
          == indent2 -> #(t, [[emit(symbols, t)], ..acc])
        #(BlockQuote(indent1, t1), BlockQuote(indent2, t2)) if indent1 > indent2 -> #(
          t,
          [
            [ntimes(indent1 - indent2, "</blockquote>"), emit(symbols, t)],
            ..acc
          ],
        )
        #(BlockQuote(indent1, t1), BlockQuote(indent2, t2)) if indent1 < indent2 -> #(
          t,
          [[ntimes(indent2 - indent1, "<blockquote>"), emit(symbols, t)], ..acc],
        )
        #(BlockQuote(indent1, t1), _) -> #(t, [
          [ntimes(indent1, "</blockquote>"), emit(symbols, t)],
          ..acc
        ])
        #(_, BlockQuote(indent2, t2)) -> #(t, [
          [ntimes(indent2, "<blockquote>"), emit(symbols, t)],
          ..acc
        ])

        // CodeLine
        #(CodeLine(t1), CodeLine(t2)) -> #(t, [[emit(symbols, t)], ..acc])
        #(CodeLine(t1), _) -> #(t, [["</code></pre>", emit(symbols, t)], ..acc])
        #(_, CodeLine(t2)) -> #(t, [["<pre><code>", emit(symbols, t)], ..acc])

        // Definition
        #(_, DefinitionOf(t2)) -> #(t, [
          ["<dl><dt>", emit(symbols, t2), "</dt>"],
          ..acc
        ])
        #(_, Definition(t2)) -> {
          let tlines =
            list.map(t2, fn(e) { [emit(symbols, e), "<br>"] })
            |> list.flatten
            |> string.concat
          #(t, [["<div><dd>", tlines, "</dd></div>"], ..acc])
        }
        #(Definition(t1), _) -> #(t, [["</dl>", emit(symbols, t)], ..acc])

        //
        _ -> #(t, [[emit(symbols, t)], ..acc])
      }
    })
  strlist
  |> list.reverse
  |> list.flatten
  |> string.concat
}

pub fn convert_bytes_outline(bytes: BitArray) -> String {
  let #(tokens, symbols) = convert_(0, bytes, [], dict.new())
  let filteredtokens =
    list.fold(tokens, [], fn(acc: List(Token), t) -> List(Token) {
      case t {
        H(id, level, title) -> [
          ListItem(
            StdList,
            level,
            UrlLink(emit_text(symbols, title), UrlPlain(fmt("#H~w", [id]))),
          ),
          ..acc
        ]
        _ -> acc
      }
    })
    |> list.reverse
  convert_tokens_(filteredtokens, symbols)
}

pub fn convert_bytes_digest(bytes: BitArray) -> String {
  let #(tokens, symbols) = convert_(0, bytes, [], dict.new())
  let filteredtokens: List(String) =
    list.fold(tokens, [], fn(acc: List(List(String)), t) -> List(List(String)) {
      case t {
        H(id, level, title) -> [[emit_text(symbols, title), "<br>\n"], ..acc]
        Line(_) -> [[emit_text(symbols, t), "<br>\n"], ..acc]
        //_ -> [emit_text(symbols, t), ..acc]
        _ -> acc
      }
    })
    |> list.reverse
    |> list.flatten
  //convert_tokens_(filteredtokens, symbols)
  string.concat(filteredtokens)
}
// ------------------------------------------------------------------------------------------------------------------------------------
