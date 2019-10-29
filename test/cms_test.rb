ENV["RACK_ENV"] = "test"

require "fileutils"
require "minitest/autorun"
require "rack/test"
require "pry"

require_relative "../cms.rb"

class CmsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_index
    filenames = ["about.txt", "history.txt"]
    filenames.each { |filename| create_document(filename) }

    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    filenames.each do |filename|
      assert_includes last_response.body, filename
    end
  end

  def test_files
    filename = "history.txt"
    content = "2000 - Y2K"
    create_document(filename, content)

    get "/#{filename}"

    assert_equal 200, last_response.status
    assert_equal "text/plain;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, content
  end

  def test_non_existent_file
    filename = "not_here.txt"
    error_message = "#{filename} does not exist."
    get "/#{filename}"

    assert_equal 302, last_response.status

    follow_redirect!
    assert_equal 200, last_response.status
    assert_includes last_response.body, error_message

    get "/"
    refute_includes last_response.body, error_message
  end

  def test_markdown_file
    filename = "history.md"
    content = "# Ruby is..."
    create_document(filename, content)

    get "/#{filename}"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_editing_file
    filename = "changes.txt"
    create_document(filename)

    get "/#{filename}/edit"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Edit content of #{filename}:"
  end

  def test_updating_file
    filename = "changes.txt"
    create_document(filename)
    content = "changed content"

    post "/#{filename}/edit", file_content: content

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "#{filename} has been updated."

    get "/#{filename}"
    assert_equal 200, last_response.status
    assert_includes last_response.body, content
  end
end
