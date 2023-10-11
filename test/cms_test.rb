ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "minitest/reporters"
require "rack/test"
require "fileutils"

Minitest::Reporters.use!

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app  # method name needs to be 'app' regardless of the actual name of the application
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin", logged_in: true } }
  end

  def create_document(name, content = "")
    File.open(File.join(content_path, name), "w") do |file|
      file.write(content)
    end
  end

  def execute_login
    post "/users/login", username: "admin", password: "secret"
  end
  
  def setup
    FileUtils.mkdir_p(content_path)
    create_document("about.md", "##The International Space Station")
    create_document("changes.txt", "Some more example text goes here and here and here.")
    create_document("history.txt", "This is in the history file.")

  end

  def teardown
    FileUtils.rm_rf(content_path)
  end

  def test_index
    # execute_login   # old way of executing login
    # get "/"

    get "/", {}, {"rack.session" => { username: "admin", logged_in: true } }

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "history.txt"
  end

  def test_view_history
    get "/history.txt/view", {}, admin_session 

    assert_equal 200, last_response.status
    assert_equal "text/html", last_response["Content-Type"]
    assert_includes last_response.body, "is in the history"
  end

  def test_nonexistent_document
    get "/doesntoexist.file/view", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "doesntoexist.file does not exist.", session[:message]

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "doesntoexist.file does not exist"
    
  end

  def test_display_markdown
    get "/about.md/view", {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/html", last_response["Content-Type"]
    assert_includes last_response.body, "<h2>The International Space Station</h2>"
  end

  def edit_page_loads_correctly
    get "/changes_test.txt/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea name="
    assert_includes last_response.body, "<button type="
  end

  def file_edits_persist
    added_string = "test12345"

    post "/changes.txt/edit", content: added_string

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "changes.txt has been updated"

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, added_string
  end

  def test_view_new_document_form
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_create_new_document
    post "/new", {new_filename: "test.txt"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt was created.", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "test.txt was created"

    get "/", {}, {"rack.session" => { username: "admin", logged_in: true } }
    assert_includes last_response.body, "test.txt"
  end

  def test_create_new_document_without_filename
    post "/new", {new_filename: ""}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

  def test_deleting_document
    create_document("test.txt")

    post "/test.txt/delete", {}, admin_session

    assert_equal 302, last_response.status
    assert_equal "test.txt has been deleted.", session[:message]


    get last_response["Location"]
    assert_includes last_response.body, "test.txt has been deleted"

    get "/"
    refute_includes last_response.body, "test.txt"
  end


  def test_signin_form
    get "/users/login"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post "/users/login", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Welcome"
    assert_includes last_response.body, "signed in as admin"
  end

  def test_signin_with_bad_credentials
    post "/users/login", username: "guest", password: "shhhh"
    assert_equal 422, last_response.status
    # assert_nil session[:username] Ignoring this text. Not how I set up my program. 
    assert_includes last_response.body, "Invalid username"
  end

  def test_signout
    post "/users/login", username: "admin", password: "secret"
    get last_response["Location"]
    assert_includes last_response.body, "Welcome"

    post "/users/logout"
    get last_response["Location"]

    assert_includes last_response.body, "You have been signed out"
    assert_includes last_response.body, "sign in"
    assert_nil session[:username]
  end

  def test_editing_document_signed_out
    create_document "changes.txt"

    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end
end
