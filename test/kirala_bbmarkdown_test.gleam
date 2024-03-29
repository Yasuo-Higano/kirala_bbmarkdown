import gleeunit
import gleeunit/should
import kirala/bbmarkdown/parser
import kirala/bbmarkdown/html_renderer
import gleam/io
import gleam/result
import kirala/peasy
import gleam/list
import gleam/float
import gleam/bit_array

pub fn main() {
  gleeunit.main()
}

pub fn sample() {
  // markdown sample from https://markdown-it.github.io/
  let markdown =
    "
---

# h1 Heading
## h2 Heading
### h3 Heading
#### h4 Heading
##### h5 Heading
###### h6 Heading

## Horizontal Rules

___

---

***


## Emphasis

**This is bold text**

__This is bold text__

*This is italic text*

_This is italic text_

~~Strikethrough~~


## Blockquotes


> Blockquotes can also be nested...
>> ...by using additional greater-than signs right next to each other...
> > > ...or with spaces between arrows.


## Lists

Unordered

+ Create a list by starting a line with `+`, `-`, or `*`
+ Sub-lists are made by indenting 2 spaces:
  - Marker character change forces new list start:
    * Ac tristique libero volutpat at
    + Facilisis in pretium nisl aliquet
    - Nulla volutpat aliquam velit
+ Very easy!

Ordered

1. Lorem ipsum dolor sit amet
2. Consectetur adipiscing elit
3. Integer molestie lorem at massa


1. You can use sequential numbers...
1. ...or keep all the numbers as `1.`

Start numbering with offset:

57. foo
1. bar


## Code

Inline `code`

Indented code

    // Some comments
    line 1 of code
    line 2 of code
    line 3 of code

```
Sample text here...
```

Syntax highlighting

``` js
var foo = function (bar) {
  return bar++;
};

console.log(foo(5));
```

## Tables

| Option | Description |
| ------ | ----------- |
| data   | path to data files to supply the data that will be passed into templates. |
| engine | engine to be used for processing templates. Handlebars is the default. |
| ext    | extension to be used for dest files. |

Right aligned columns

| Option | Description |
| ------:| -----------:|
| data   | path to data files to supply the data that will be passed into templates. |
| engine | engine to be used for processing templates. Handlebars is the default. |
| ext    | extension to be used for dest files. |


## Links

[link text](http://dev.nodeca.com)

Autoconverted link https://github.com/nodeca/pica (enable linkify to see)


## Images

![Minion](https://octodex.github.com/images/minion.png)

Like links, Images also have a footnote style syntax

![Alt text][id]

With a reference later in the document defining the URL location:
  "
}

pub fn run_test() {
  let markdown = sample()

  io.println(
    "\n\n# AST ----------------------------------------------------------------",
  )
  let ast =
    parser.parse(
      1,
      markdown
      |> bit_array.from_string,
    )
  io.debug(ast)

  io.println(
    "\n\n# HTML ---------------------------------------------------------------",
  )
  let html = html_renderer.convert(markdown)
  io.println(html)
  True
}

pub fn benchmark() {
  let start = peasy.now()
  let markdown = sample()
  list.each(list.range(1, 1000), fn(_) {
    let html = html_renderer.convert(markdown)
    Nil
  })
  let stop = peasy.now()
  let elapsed = stop -. start
  io.print("elapsed: " <> float.to_string(elapsed) <> "seconds\n")
}
