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

  def session
    last_request.env["rack.session"]
  end

  def signed_in_session
    { "rack.session" => { username: "admin" } }
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
    assert_equal error_message, session[:message]
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

    get "/#{filename}/edit", {}, signed_in_session

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Edit content of #{filename}:"
  end

  def test_must_be_signed_in_to_edit
    filename = "changes.txt"
    create_document(filename)

    get "/#{filename}/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_updating_file
    filename = "changes.txt"
    create_document(filename)
    content = "changed content"

    post "/#{filename}/edit", { file_content: content }, signed_in_session

    assert_equal 302, last_response.status
    assert_equal "#{filename} has been updated.", session[:message]

    get "/#{filename}"

    assert_equal 200, last_response.status
    assert_includes last_response.body, content
  end

  def test_must_be_signed_in_to_update
    filename = "changes.txt"
    create_document(filename)
    content = "changed content"

    post "/#{filename}/edit", file_content: content

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_new_document
    get "/new", {}, signed_in_session

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Add a new document:"
  end

  def test_must_be_signed_in_to_view_new_document
    get "/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_document
    filename = "new_file.txt"

    post "/new", { filename: filename }, signed_in_session

    assert_equal 302, last_response.status
    assert_equal "#{filename} has been created!", session[:message]

    get "/"

    assert_includes last_response.body, filename
  end

  def test_must_be_signed_in_to_create_new_document
    filename = "new_file.txt"

    post "/new", filename: filename

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_nil_filename
    post "/new", {}, signed_in_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
  end

  def test_create_no_filename
    post "/new", { filename: "" }, signed_in_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
  end

  def test_delete_file
    filename = "document.txt"
    create_document(filename)

    post "/#{filename}/delete", {}, signed_in_session

    assert_equal 302, last_response.status
    assert_equal "#{filename} has been deleted.", session[:message]

    get "/"

    refute_includes last_response.body, "href=\"/#{filename}\""
  end

  def test_must_be_signed_in_to_delete_file
    filename = "document.txt"
    create_document(filename)

    post "/#{filename}/delete"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_delete_non_existent_file
    filename = "document.txt"

    post "/#{filename}/delete", {}, signed_in_session

    assert_equal 302, last_response.status
    assert_equal "#{filename} does not exist.", session[:message]
  end

  def test_not_signed_in
    get "/"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Sign In"
  end

  def test_sign_in
    username = "admin"
    pw = "123"

    post "/users/signin", username: username, password: pw

    assert_equal 302, last_response.status
    assert_equal "Welcome #{username}", session[:message]
  end

  def test_bad_credentials
    username = "tom"
    pw = "123"

    post "/users/signin", username: username, password: pw

    assert_nil session[:username]
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid credentials."
    assert_includes last_response.body, "Sign In"
  end

  def test_sign_out
    post "/sign_out"

    assert_equal 302, last_response.status
    assert_equal "You have been signed out.", session[:message]
  end

  def test_sets_session_value
    username = "admin"
    pw = "123"

    post "/users/signin", username: username, password: pw

    assert_equal "admin", session[:username]
  end
end
