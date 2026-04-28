require "rubygems"
if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start
end

require "bundler/setup"
require "minitest/autorun"
require "html2haml"
require 'html2haml/html'
require 'html2haml/html/erb'
require "haml2html"

class Minitest::Test
  protected
  def render(text, options = {})
    Html2haml::HTML.new(text, options).render.rstrip
  end

  def render_erb(text)
    render(text, :erb => true)
  end

  def render_html(text, options = {})
    Haml2html::Haml.new(text, options).render.rstrip
  end

  def render_html_erb(text)
    render_html(text, :erb => true)
  end
end
