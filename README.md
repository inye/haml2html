# haml2html

This project is **haml2html**: a fork of the original
[html2haml](https://github.com/haml/html2haml) that adds conversion in the
opposite direction — turning Haml templates back into HTML/ERB.

The original `html2haml` direction continues to work as before. A new
`haml2html` executable and library handle the inverse conversion.

> **This fork is vibe-coded.** The added haml-to-html/erb conversion was
> produced through informal, exploratory AI-assisted coding rather than careful
> hand-engineering. Treat the output accordingly: it works on the cases covered
> by the test suite, but it has not been audited for correctness on arbitrary
> Haml input. No copyright is asserted over the additions in this fork; use
> them however you like.

## Authors and credit

The original `html2haml` was written and maintained by:

- Hampton Catlin
- Natalie Weizenbaum
- Norman Clarke
- Akira Matsuda
- Stefan Natchev

…along with the many contributors listed in the project's git history. All
credit for the original tool, its design, and the bulk of the parsing
infrastructure belongs to them. This fork only adds the inverse direction on
top of their work.

## Installation

Add this line to your application's Gemfile:

    gem 'html2haml'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install html2haml

## Usage

### HTML/ERB → Haml (original direction)

    $ html2haml input.html.erb output.html.haml

To convert an entire project from `.erb` to `.haml`, if your system has `sed`
and `xargs` available and none of your `.erb` file names have whitespace in
them:

    find . -name \*.erb -print | sed 'p;s/.erb$/.haml/' | xargs -n2 html2haml

If some of your file names have whitespace or you need finer-grained control
over the process, you can convert your files using `gsed` or multi-line script
techniques discussed [here](http://stackoverflow.com/questions/17576814/).

### Haml → HTML/ERB (added by this fork)

    $ haml2html input.html.haml output.html.erb

See `html2haml --help` and `haml2html --help` for available options.

#### `html2haml` options

    Usage: html2haml [options] [INPUT] [OUTPUT]

    Description: Transforms an HTML file into corresponding Haml code.

    Options:
        -e, --erb                        Parse ERB tags.
            --no-erb                     Don't parse ERB tags.
            --html-attributes            Use HTML style attributes instead of Ruby hash style.
            --ruby19-attributes          Use Ruby 1.9-style attributes when possible.
        -E ex[:in]                       Specify the default external and internal character encodings.
        -s, --stdin                      Read input from standard input instead of an input file
            --trace                      Show a full traceback on error
            --unix-newlines              Use Unix-style newlines in written files.
        -?, -h, --help                   Show this message
        -v, --version                    Print version

### About html2haml 2.0

Html2haml 2.0 differs from 1.x primarily in that it uses Nokogiri as its HTML
parser rather than Hpricot. At the current time however, there are some
problems running Html2haml 2.0 on JRuby due to differences in the way the Java
version of Nokogiri parses HTML. If you are using JRuby you may wish to run
HTML2Haml on MRI or use a 1.x version until these problems have been resolved.

## License

The original `html2haml` is distributed under the MIT license; see the
`MIT-LICENSE` file for the original copyright notice held by Hampton Catlin,
Natalie Weizenbaum and Norman Clarke.

The additions made in this fork (the `haml2html` direction) are released
without any copyright claim by the fork author. Do whatever you want with
them. The MIT license on the original code is unaffected.
