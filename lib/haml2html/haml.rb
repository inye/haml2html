require "cgi"
require "ruby_parser"
require "ruby2ruby"

module Haml2html
  # Converts Haml templates into HTML. Mirrors Html2haml::HTML for the inverse direction.
  # Walks the AST produced by Haml::Parser and emits HTML, optionally preserving ERB tags
  # for `=`/`-`/`!=` script nodes and `#{...}` interpolations when :erb is set.
  class Haml
    DOCTYPE_HTML5 = '<!DOCTYPE html>'.freeze

    DOCTYPES = {
      [nil, ""]         => DOCTYPE_HTML5,
      [nil, "strict"]   => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">',
      [nil, "frameset"] => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">',
      [nil, "mobile"]   => '<!DOCTYPE html PUBLIC "-//WAPFORUM//DTD XHTML Mobile 1.2//EN" "http://www.openmobilealliance.org/tech/DTD/xhtml-mobile12.dtd">',
      [nil, "basic"]    => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.1//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic11.dtd">',
      ["1.1", ""]       => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">',
      [nil, "xml"]      => '<?xml version="1.0" encoding="utf-8" ?>',
    }.freeze

    MID_BLOCK_KEYWORDS = %w[else elsif when rescue ensure].freeze

    # Initialize from a String or IO.
    #
    # @option options :erb [Boolean] (false) Whether to emit ERB tags for
    #   `=`/`-`/`!=` scripts and `#{...}` interpolations
    def initialize(template, options = {})
      template = template.read if template.respond_to?(:read)
      @template = template.to_s
      @options = options
    end

    def render
      ast = ::Haml::Parser.new(escape_html: true).call(@template)
      lines = []
      ast.children.each { |c| render_node(c, 0, lines) }
      lines.reject(&:nil?).join("\n")
    end
    alias_method :to_html, :render

    private

    def ind(n)
      "  " * n
    end

    def render_node(node, indent, lines)
      case node.type
      when :tag           then render_tag(node, indent, lines)
      when :plain         then render_plain(node, indent, lines)
      when :doctype       then render_doctype(node, indent, lines)
      when :comment       then render_comment(node, indent, lines)
      when :haml_comment  then nil
      when :script        then render_script(node, indent, lines)
      when :silent_script then render_silent_script(node, indent, lines)
      when :filter        then render_filter(node, indent, lines)
      else raise "Unsupported Haml node type: #{node.type}"
      end
    end

    # Doctype

    def render_doctype(node, indent, lines)
      v = node.value
      key = [v[:version], (v[:type] || "").downcase]
      lines << "#{ind(indent)}#{DOCTYPES[key] || DOCTYPE_HTML5}"
    end

    # Comments

    def render_comment(node, indent, lines)
      v = node.value
      cond = v[:conditional]
      open_tok  = cond ? "<!--#{cond}>" : "<!--"
      close_tok = cond ? "<![endif]-->" : "-->"
      text = v[:text].to_s

      if node.children.empty?
        if text.empty?
          lines << "#{ind(indent)}#{open_tok} #{close_tok}"
        else
          lines << "#{ind(indent)}#{open_tok} #{text} #{close_tok}"
        end
      else
        lines << "#{ind(indent)}#{open_tok}"
        node.children.each { |c| render_node(c, indent + 1, lines) }
        lines << "#{ind(indent)}#{close_tok}"
      end
    end

    # Plain text

    def render_plain(node, indent, lines)
      text = node.value[:text].to_s
      lines << "#{ind(indent)}#{render_text(text)}"
    end

    # Convert haml-text (potentially with #{} interpolation) to HTML/ERB output.
    # In erb mode: `#{expr}` → `<%= expr %>`; `\#{expr}` → literal `#{expr}`.
    # Otherwise: only unescape `\#{` → `#{`.
    def render_text(text)
      out = +""
      i = 0
      while i < text.length
        if text[i] == "\\" && text[i + 1] == "#" && text[i + 2] == "{"
          j, expr = scan_braces(text, i + 2)
          out << "\#{" << expr << "}"
          i = j + 1
        elsif text[i] == "#" && text[i + 1] == "{"
          j, expr = scan_braces(text, i + 1)
          out << (@options[:erb] ? "<%= #{expr} %>" : "\#{#{expr}}")
          i = j + 1
        else
          out << text[i]
          i += 1
        end
      end
      out
    end

    # Find matching close brace starting at position of `{`, returning [end_index, inner_expr]
    def scan_braces(text, start)
      depth = 0
      i = start
      while i < text.length
        c = text[i]
        if c == "{"
          depth += 1
        elsif c == "}"
          depth -= 1
          return [i, text[(start + 1)...i]] if depth.zero?
        end
        i += 1
      end
      [text.length - 1, text[(start + 1)..-1]]
    end

    # Render an inline tag value (text after a tag) which may be a parsed Ruby string
    def render_inline_value(value, parse)
      if parse && value.start_with?('"') && value.end_with?('"')
        render_text(value[1..-2])
      else
        render_text(value)
      end
    end

    # Scripts: = expr (and != expr); also Haml's "implicit script" form for
    # plain text containing `#{...}` interpolation (escape_interpolation: true).

    def render_script(node, indent, lines)
      v = node.value
      if v[:escape_interpolation]
        inner = unquote(v[:text].to_s)
        lines << "#{ind(indent)}#{render_text(inner)}"
        return
      end

      text = v[:text].to_s.sub(/\A /, "")
      tag = v[:escape_html] ? "<%=" : "<%=="
      lines << "#{ind(indent)}#{tag} #{text} %>"
      render_block_children(node, indent, lines)
    end

    def unquote(text)
      (text.start_with?('"') && text.end_with?('"')) ? text[1..-2] : text
    end

    # Silent scripts: - stmt

    def render_silent_script(node, indent, lines)
      text = node.value[:text].to_s.sub(/\A /, "")
      lines << "#{ind(indent)}<% #{text} %>"
      render_block_children(node, indent, lines)
    end

    # Render children of a script/silent_script, handling mid-block keywords (elsif/else/when/...)
    # and explicit `end` keywords (e.g. `- end.bip`) at the parent indent.
    def render_block_children(node, indent, lines)
      kw = node.value[:keyword]
      closed_by_child = false

      node.children.each do |c|
        if c.type == :silent_script
          ckw = c.value[:keyword]
          if MID_BLOCK_KEYWORDS.include?(ckw)
            render_silent_script(c, indent, lines)
            next
          elsif ckw == "end"
            render_silent_script(c, indent, lines)
            closed_by_child = true unless block_opener?(c.value[:text].to_s)
            next
          end
        end
        render_node(c, indent + 1, lines)
      end

      return if MID_BLOCK_KEYWORDS.include?(kw) || kw == "end"
      return if closed_by_child
      return if node.children.empty?
      lines << "#{ind(indent)}<% end %>"
    end

    def block_opener?(text)
      !!(text =~ /\bdo(\s*\|[^|]*\|)?\s*\z/)
    end

    # Tags

    VOID_ELEMENTS = %w[area base br col embed hr img input link meta param source track wbr].freeze

    def render_tag(node, indent, lines)
      v = node.value
      name = v[:name]
      attr_str = render_attributes(v[:attributes], v[:dynamic_attributes])

      if v[:self_closing]
        lines << "#{ind(indent)}<#{name}#{attr_str} />"
        return
      end

      open_tag  = "<#{name}#{attr_str}>"
      close_tag = "</#{name}>"
      inline    = render_tag_inline(v)

      if node.children.empty?
        if inline.nil? || inline.empty?
          lines << "#{ind(indent)}#{open_tag}#{close_tag}"
        else
          lines << "#{ind(indent)}#{open_tag}#{inline}#{close_tag}"
        end
        return
      end

      lines << "#{ind(indent)}#{open_tag}"
      lines << "#{ind(indent + 1)}#{inline}" if inline && !inline.empty?
      node.children.each { |c| render_node(c, indent + 1, lines) }
      lines << "#{ind(indent)}#{close_tag}"
    end

    # Render a tag's inline value, distinguishing between:
    #   `%p= foo`  → inline `=` script  (escape_html: true)
    #   `%p!= foo` → inline `!=` script (preserve_script: false)
    #   `%p Foo #{bar} baz` → plain text with interpolation
    #   `%p hello` → plain text
    def render_tag_inline(v)
      value = v[:value]
      return nil if value.nil? || value.empty?

      if v[:parse]
        if v[:preserve_script] == false
          @options[:erb] ? "<%== #{value.strip} %>" : value.strip
        elsif v[:escape_html]
          @options[:erb] ? "<%= #{value.strip} %>" : value.strip
        else
          render_text(unmung_escape_html(unquote(value)))
        end
      else
        render_text(value)
      end
    end

    # Strip Haml::Util.escape_html_safe wrappers that the parser injects when
    # escape_html: true and a plain interpolation `#{...}` appears in tag text.
    def unmung_escape_html(text)
      text.gsub(/Haml::Util\.escape_html_safe\(\((.*?)\)\.to_s\)/) { $1 }
    end

    # Attribute rendering

    # `class` and `id` from .class/#id shorthand and from `:class`/`:id` hash
    # entries must collapse to a single attribute (HTML5 forbids duplicate
    # attribute names — browsers keep the first and drop the rest). Haml itself
    # merges these: classes join with " ", ids with "_".
    MERGED_ATTRS = { "class" => " ", "id" => "_" }.freeze

    def render_attributes(static, dynamic)
      parts = []
      index = {}
      push = lambda do |name, quoted|
        if (sep = MERGED_ATTRS[name]) && (i = index[name])
          parts[i] = [name, merge_quoted_values(parts[i][1], quoted, sep)]
        else
          index[name] = parts.length
          parts << [name, quoted]
        end
      end
      (static || {}).each { |name, value| push.call(name, %("#{html_escape(value.to_s)}")) }
      if dynamic
        parse_dynamic_attr_pairs(dynamic.old).each { |n, v| push.call(n, v) } if dynamic.old
        parse_dynamic_attr_pairs(dynamic.new).each { |n, v| push.call(n, v) } if dynamic.new
      end
      parts.empty? ? "" : " " + parts.map { |n, v| "#{n}=#{v}" }.join(" ")
    end

    def merge_quoted_values(a, b, sep)
      inner_a = a[1..-2]
      inner_b = b[1..-2]
      return a if inner_b.empty?
      return b if inner_a.empty?
      %("#{inner_a}#{sep}#{inner_b}")
    end

    def html_escape(str)
      CGI.escapeHTML(str.to_s)
    end

    # Parse a Ruby hash literal source into [name, quoted_value] pairs,
    # converting dynamic Ruby values into ERB interpolations when in erb mode.
    def parse_dynamic_attr_pairs(src)
      ruby = parse_hash_source(src)
      return [] unless ruby
      hash_pairs(ruby).map { |k, v| [attr_name_from_sexp(k), attr_value_from_sexp(v)] }
    end

    def parse_hash_source(src)
      ::RubyParser.for_current_ruby.parse(src)
    rescue Racc::ParseError, ::RubyParser::SyntaxError
      nil
    end

    def hash_pairs(sexp)
      return [] unless sexp.respond_to?(:sexp_type) && sexp.sexp_type == :hash
      pairs = []
      i = 1
      while i < sexp.length
        pairs << [sexp[i], sexp[i + 1]]
        i += 2
      end
      pairs
    end

    def attr_name_from_sexp(sexp)
      case sexp.sexp_type
      when :lit then sexp[1].to_s
      when :str then sexp[1]
      else sexp[1].to_s
      end
    end

    def attr_value_from_sexp(sexp)
      case sexp.sexp_type
      when :str
        %("#{html_escape(sexp[1])}")
      when :lit
        %("#{html_escape(sexp[1].to_s)}")
      when :dstr
        %("#{render_dstr(sexp)}")
      when :nil
        %("")
      else
        if @options[:erb]
          %("<%= #{ruby_source(sexp)} %>")
        else
          %("")
        end
      end
    end

    # Render a Ruby :dstr sexp (string with interpolation) as an attribute value
    # mixing literal text and ERB tags.
    def render_dstr(sexp)
      out = +""
      sexp[1..-1].each do |part|
        case part
        when String
          out << html_escape(part)
        when Sexp
          if part.sexp_type == :str
            out << html_escape(part[1])
          elsif part.sexp_type == :evstr
            inner = part[1]
            inner_src = inner ? ruby_source(inner) : ""
            out << (@options[:erb] ? "<%= #{inner_src} %>" : "")
          end
        end
      end
      out
    end

    def ruby_source(sexp)
      ::Ruby2Ruby.new.process(sexp.deep_clone).strip
    end

    # Filters

    def render_filter(node, indent, lines)
      name = node.value[:name]
      text = node.value[:text].to_s
      case name
      when "javascript"
        emit_filter_block("script", "text/javascript", text, indent, lines)
      when "css"
        emit_filter_block("style", "text/css", text, indent, lines)
      when "cdata"
        emit_cdata(text, indent, lines)
      when "preserve"
        emit_preserve(text, indent, lines)
      else
        raise "Unsupported filter: :#{name}"
      end
    end

    def emit_filter_block(tag, type_attr, text, indent, lines)
      lines << %(#{ind(indent)}<#{tag} type="#{type_attr}">)
      text.to_s.split("\n").each { |l| lines << "#{ind(indent + 1)}#{render_text(l)}" }
      lines << "#{ind(indent)}</#{tag}>"
    end

    def emit_cdata(text, indent, lines)
      lines << "#{ind(indent)}<![CDATA["
      text.to_s.split("\n").each { |l| lines << "#{ind(indent + 1)}#{render_text(l)}" }
      lines << "#{ind(indent)}]]>"
    end

    def emit_preserve(text, indent, lines)
      text.to_s.split("\n").each { |l| lines << "#{ind(indent)}#{render_text(l)}" }
    end
  end
end
