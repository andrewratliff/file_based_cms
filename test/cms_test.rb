ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "pry"

require_relative "../cms.rb"

class CmsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]

    filenames.each do |filename|
      assert_includes last_response.body, filename
    end
  end

  def test_files
    filenames.each do |filename|
      get "/#{filename}"
      assert_equal 200, last_response.status
      assert_equal "text/plain;charset=utf-8", last_response["Content-Type"]
      assert_includes last_response.body, history_text(filename)
    end
  end

  def test_non_existent_file
    get "/not_here.txt"

    assert_equal 302, last_response.status

    follow_redirect!
    assert_equal 200, last_response.status
    assert_includes last_response.body, "not_here.txt does not exist."

    get "/"
    refute_includes last_response.body, "not_here.txt does not exist."
  end

  def test_markdown_file
    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_editing_file
    get "/changes.txt/edit"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Edit content of changes.txt:"
  end

  def test_updating_file
    post "/changes.txt/edit", file_content: "changed content"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "changes.txt has been updated."

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "changed content"
  end

  def history_text(filename)
    File.read(ROOT + "/data/" + filename)
  end

  def filenames
    ["about.txt", "history.txt"]
  end
end
