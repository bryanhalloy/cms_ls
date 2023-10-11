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

  def create_document(name, content = "")
    File.open(File.join(content_path, name), "w") do |file|
      file.write(content)
    end
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
    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "history.txt"
  end

  def test_view_history
    get "/history.txt/view"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "is in the history"
  end

  def test_nonexistent_document
    get "/doesntoexist.file/view"
    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "doesntoexist.file does not exist"
  end

  def test_display_markdown
    get "/about.md/view"

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

    get last_response["Location"]
    assert_includes last_response.body, "changes.txt has been updated"

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, added_string
  end

end
