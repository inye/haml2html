# encoding: UTF-8
require 'test_helper'

# Inverse of html2haml_test.rb: every assertion takes Haml input and verifies the
# HTML output produced by Haml2html. Cases that were lossy in html2haml (e.g.
# multiple HTML doctypes mapping to a single Haml `!!!`) are tested with the
# canonical HTML output here.
class Haml2HtmlTest < Minitest::Test
  def test_empty_render_should_remain_empty
    assert_equal '', render_html('')
  end

  def test_doctype
    assert_equal '<!DOCTYPE html>', render_html('!!!')
    assert_equal '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">',
      render_html('!!! 1.1')
    assert_equal '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">',
      render_html('!!! Strict')
    assert_equal '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">',
      render_html('!!! Frameset')
    assert_equal '<!DOCTYPE html PUBLIC "-//WAPFORUM//DTD XHTML Mobile 1.2//EN" "http://www.openmobilealliance.org/tech/DTD/xhtml-mobile12.dtd">',
      render_html('!!! Mobile 1.2')
    assert_equal '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.1//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic11.dtd">',
      render_html('!!! Basic 1.1')
  end

  def test_id_and_class
    assert_equal '<span id="foo" class="bar"></span>', render_html('%span#foo.bar')
  end

  def test_no_tag_name_for_div_if_class_or_id_is_present
    assert_equal '<div id="foo"></div>', render_html('#foo')
    assert_equal '<div class="foo"></div>', render_html('.foo')
  end

  def test_multiple_class_names
    assert_equal '<div class="foo bar baz"></div>', render_html('.foo.bar.baz')
  end

  def test_pretty_attributes
    assert_equal '<input name="login" type="text" />',
      render_html('%input{:name => "login", :type => "text"}/')
    assert_equal '<meta content="text/html" http-equiv="Content-Type" />',
      render_html('%meta{:content => "text/html", "http-equiv" => "Content-Type"}/')
  end

  def test_html_style_attributes
    assert_equal '<input name="login" type="text" />',
      render_html('%input(name="login" type="text")/')
    assert_equal '<meta content="text/html" http-equiv="Content-Type" />',
      render_html('%meta(content="text/html" http-equiv="Content-Type")/')
  end

  def test_ruby_19_hash_style_attributes
    assert_equal '<input name="login" type="text" />',
      render_html('%input{name: "login", type: "text"}/')
    assert_equal '<meta content="text/html" http-equiv="Content-Type" />',
      render_html('%meta{content: "text/html", "http-equiv" => "Content-Type"}/')
  end

  def test_attributes_without_values
    assert_equal '<input disabled="disabled" />',
      render_html('%input{:disabled => "disabled"}/')
  end

  def test_class_with_dot_and_hash
    assert_equal '<div class="foo.bar"></div>',
      render_html('%div{:class => "foo.bar"}')
    assert_equal '<div class="foo#bar"></div>',
      render_html('%div{:class => "foo#bar"}')
    assert_equal '<div class="foo bar foo#bar foo.bar"></div>',
      render_html('.foo.bar{:class => "foo#bar foo.bar"}')
  end

  def test_id_with_dot_and_hash
    assert_equal '<div id="foo.bar"></div>',
      render_html('%div{:id => "foo.bar"}')
    assert_equal '<div id="foo#bar"></div>',
      render_html('%div{:id => "foo#bar"}')
  end

  def test_class_shorthand_merges_with_dynamic_class_hash
    # In non-ERB mode the dynamic class collapses to empty; static must still be emitted alone.
    assert_equal '<li class="pb-2"></li>',
      render_html('%li.pb-2{:class => is_current ? "bg-orange-500" : "bg-white"}')
  end

  def test_id_shorthand_merges_with_dynamic_id_hash
    assert_equal '<li id="a"></li>',
      render_html('%li#a{:id => suffix}')
  end

  def test_interpolation
    assert_equal 'Foo #{bar} baz', render_html('Foo \#{bar} baz')
  end

  def test_self_closing_tag
    assert_equal '<img />', render_html('%img/')
  end

  def test_inline_text
    assert_equal '<p>foo</p>', render_html('%p foo')
  end

  def test_inline_comment
    assert_equal '<!-- foo -->', render_html('/ foo')
    assert_equal(<<HTML.rstrip, render_html(<<HAML))
<!-- foo -->
<p>bar</p>
HTML
/ foo
%p bar
HAML
  end

  def test_non_inline_comment
    assert_equal(<<HTML.rstrip, render_html(<<HAML))
<!--
  Foo
  Bar
-->
HTML
/
  Foo
  Bar
HAML
  end

  def test_non_inline_text
    assert_equal(<<HTML.rstrip, render_html(<<HAML))
<p>
  foo
</p>
HTML
%p
  foo
HAML
  end

  def test_minus_in_tag
    assert_equal '<p>- foo bar -</p>', render_html('%p - foo bar -')
  end

  def test_equals_in_tag
    assert_equal '<p>= foo bar =</p>', render_html('%p = foo bar =')
  end

  def test_hash_in_tag
    assert_equal '<p># foo bar #</p>', render_html('%p # foo bar #')
  end

  def test_conditional_comment_inline
    assert_equal '<!--[if foo]> bar baz <![endif]-->',
      render_html('/[if foo] bar baz')
  end

  def test_conditional_comment_block
    assert_equal(<<HTML.rstrip, render_html(<<HAML))
<!--[if foo]>
  bar
  baz
<![endif]-->
HTML
/[if foo]
  bar
  baz
HAML
  end

  def test_haml_comment_is_omitted
    assert_equal '<p>foo</p>', render_html("-# silent\n%p foo")
  end

  def test_html_document_without_doctype
    assert_equal(<<HTML.rstrip, render_html(<<HAML))
<!DOCTYPE html>
<html>
  <head>
    <meta content="text/html; charset=UTF-8" http-equiv="Content-Type" />
    <title>Hello</title>
  </head>
  <body>
    <p>Hello</p>
  </body>
</html>
HTML
!!!
%html
  %head
    %meta{:content => "text/html; charset=UTF-8", "http-equiv" => "Content-Type"}/
    %title Hello
  %body
    %p Hello
HAML
  end
end
