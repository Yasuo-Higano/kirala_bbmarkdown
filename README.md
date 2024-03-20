# kirala_bbmarkdown

markdown parser and html renderer written in Gleam language ver 1.0.0.

## parse markdown
```
import kirala/bbmarkdown/parser

fn parse_markdown(markdown: String) {
  let ast = parser.parse(1, bit_array.from_string(markdown))
}
```

## markdown to html
```
import kirala/bbmarkdown/html_renderer

fn markdown_to_html(markdown: String) -> String {
  let html = html_renderer.convert(markdown)
}
```

## example
- https://github.com/Yasuo-Higano/example_gleam_markdown_server