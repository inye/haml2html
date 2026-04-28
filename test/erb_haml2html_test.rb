require 'test_helper'

# Inverse of erb_test.rb: every assertion takes Haml input and verifies the
# ERB-flavored HTML output produced by Haml2html with :erb enabled.
class ErbHaml2HtmlTest < Minitest::Test
  def test_silent_script
    assert_equal '<% foo = bar %>', render_html_erb('- foo = bar')
  end

  def test_loud_script
    assert_equal '<%= h @item.title %>', render_html_erb('= h @item.title')
  end

  def test_inline_erb
    assert_equal '<p><%= foo %></p>', render_html_erb('%p= foo')
    assert_equal(<<ERB.rstrip, render_html_erb(<<HAML))
<p>
  <%= foo %>
</p>
ERB
%p
  = foo
HAML
  end

  def test_erb_in_line
    assert_equal 'foo bar <%= baz %>', render_html_erb('foo bar #{baz}')
    assert_equal 'foo bar <%= baz %>! Bang.', render_html_erb('foo bar #{baz}! Bang.')
  end

  def test_erb_multi_in_line
    assert_equal 'foo bar <%= baz %>! Bang <%= bop %>.',
      render_html_erb('foo bar #{baz}! Bang #{bop}.')
    assert_equal 'foo bar <%= baz %><%= bop %>!',
      render_html_erb('foo bar #{baz}#{bop}!')
  end

  def test_erb_with_html_special_chars
    assert_equal '<%= 3 < 5 ? "OK" : "Your computer is b0rken" %>',
      render_html_erb('= 3 < 5 ? "OK" : "Your computer is b0rken"')
  end

  def test_erb_in_class_attribute
    assert_equal '<div class="<%= dyna_class %>">I have a dynamic attribute</div>',
      render_html_erb('%div{:class => dyna_class} I have a dynamic attribute')
  end

  def test_erb_in_id_attribute
    assert_equal '<div id="<%= dyna_id %>">I have a dynamic attribute</div>',
      render_html_erb('%div{:id => dyna_id} I have a dynamic attribute')
  end

  def test_erb_in_attribute_results_in_string_interpolation
    assert_equal '<div id="item_<%= i %>">Ruby string interpolation FTW</div>',
      render_html_erb('%div{:id => "item_#{i}"} Ruby string interpolation FTW')
  end

  def test_erb_in_attribute_with_trailing_content
    assert_equal '<div class="<%= 12 %>!">Bang!</div>',
      render_html_erb('%div{:class => "#{12}!"} Bang!')
  end

  def test_static_string_attribute
    assert_equal '<div class="foo">Bang!</div>',
      render_html_erb('%div{:class => "foo"} Bang!')
  end

  def test_symbol_attribute
    assert_equal '<div class="foo">Bang!</div>',
      render_html_erb('%div{:class => :foo} Bang!')
  end

  def test_empty_attribute
    assert_equal '<div class=""></div>',
      render_html_erb('%div{:class => ""}')
  end

  def test_attribute_with_multiple_interpolations
    assert_equal '<div class="<%= 12 %> + <%= 13 %>">Math is super</div>',
      render_html_erb('%div{:class => "#{12} + #{13}"} Math is super')
  end

  def test_interpolation_in_erb
    assert_equal '<%= "Foo #{bar} baz" %>', render_html_erb('= "Foo #{bar} baz"')
  end

  ### Block parsing

  def test_block_parsing
    assert_equal(<<ERB.rstrip, render_html_erb(<<HAML))
<% foo do %>
  <p>bar</p>
<% end %>
ERB
- foo do
  %p bar
HAML
  end

  def test_block_parsing_with_args
    assert_equal(<<ERB.rstrip, render_html_erb(<<HAML))
<% foo do |a, b, c| %>
  <p>bar</p>
<% end %>
ERB
- foo do |a, b, c|
  %p bar
HAML
  end

  def test_block_parsing_with_equals
    assert_equal(<<ERB.rstrip, render_html_erb(<<HAML))
<%= foo do %>
  <p>bar</p>
<% end %>
ERB
= foo do
  %p bar
HAML
  end

  def test_block_parsing_with_modified_end
    assert_equal(<<ERB.rstrip, render_html_erb(<<HAML))
<% foo do %>
  blah
<% end.bip %>
ERB
- foo do
  blah
- end.bip
HAML
  end

  def test_block_parsing_with_modified_end_with_block
    assert_equal(<<ERB.rstrip, render_html_erb(<<HAML))
<% foo do %>
  blah
<% end.bip do %>
  brang
<% end %>
ERB
- foo do
  blah
- end.bip do
  brang
HAML
  end

  def test_if_elsif_else_parsing
    assert_equal(<<ERB.rstrip, render_html_erb(<<HAML))
<% if foo %>
  <p>bar</p>
<% elsif bar.foo("zip") %>
  <div id="bang">baz</div>
<% else %>
  <strong>bibble</strong>
<% end %>
ERB
- if foo
  %p bar
- elsif bar.foo("zip")
  #bang baz
- else
  %strong bibble
HAML
  end

  def test_case_when_parsing
    assert_equal(<<ERB.rstrip, render_html_erb(<<HAML))
<% case foo.bar %>
<% when "bip" %>
  <p>bip</p>
<% when "bop" %>
  <p>BOP</p>
<% when bizzle.bang.boop.blip %>
  <em>BIZZLE BANG BOOP BLIP</em>
<% end %>
ERB
- case foo.bar
- when "bip"
  %p bip
- when "bop"
  %p BOP
- when bizzle.bang.boop.blip
  %em BIZZLE BANG BOOP BLIP
HAML
  end

  def test_begin_rescue_ensure
    assert_equal(<<ERB.rstrip, render_html_erb(<<HAML))
<% begin %>
  <p>a</p>
<% rescue FooException => e %>
  <p>b</p>
<% ensure %>
  <p>c</p>
<% end %>
ERB
- begin
  %p a
- rescue FooException => e
  %p b
- ensure
  %p c
HAML
  end

  def test_tag_inside_block
    assert_equal(<<ERB.rstrip, render_html_erb(<<HAML))
<table>
  <% foo.each do %>
    <tr></tr>
  <% end %>
</table>
ERB
%table
  - foo.each do
    %tr
HAML
  end

  def test_silent_inside_block_inside_tag
    assert_equal(<<ERB.rstrip, render_html_erb(<<HAML))
<table>
  <% foo.each do %>
    <% haml_puts "foo" %>
  <% end %>
</table>
ERB
%table
  - foo.each do
    - haml_puts "foo"
HAML
  end

  def test_erb_with_double_equals
    assert_equal '<%== link_to "https://github.com/haml/html2haml/issues/44" %>',
      render_html_erb('!= link_to "https://github.com/haml/html2haml/issues/44"')
  end

  def test_javascript_filter
    assert_equal(<<ERB.rstrip, render_html_erb(<<HAML))
<script type="text/javascript">
  function foo() {
    return <%= foo.to_json %>;
  }
</script>
ERB
:javascript
  function foo() {
    return \#{foo.to_json};
  }
HAML
  end

  def test_css_filter
    assert_equal(<<ERB.rstrip, render_html_erb(<<HAML))
<style type="text/css">
  foo {
      bar: <%= "baz" %>;
  }
</style>
ERB
:css
  foo {
      bar: \#{"baz"};
  }
HAML
  end

  def test_cdata_filter
    assert_equal(<<ERB.rstrip, render_html_erb(<<HAML))
<![CDATA[
  Foo <%= bar %> baz
]]>
ERB
:cdata
  Foo \#{bar} baz
HAML
  end
end
