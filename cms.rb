require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"



# Directory setup  =============================
CONTENT_DIRECTORY_NAME = "content"
TEST_FOLDER_NAME = "test"
ROOT_PATH = File.expand_path("..", __FILE__)

def content_path
  if ENV["RACK_ENV"] == "test"
    path = File.join(ROOT_PATH, TEST_FOLDER_NAME, CONTENT_DIRECTORY_NAME)
  else
    path = File.join(ROOT_PATH, CONTENT_DIRECTORY_NAME)
  end
  File.expand_path(path, __FILE__)
end

CONTENT_PATH = content_path


# Ruby helper Methods  =============================
def get_files_info
  files_info_hash = {}

  Dir.glob(File.join(CONTENT_PATH, "*")).each do |path|
    filename = File.basename(path)
    file_hash = { name: filename,
                  extension: File.extname(path), 
                  full_path: path,
                  url_view: "/#{filename}/view",
                  url_edit: "/#{filename}/edit"
    }
    files_info_hash[filename] = file_hash
  end
  files_info_hash
end

def render_markdown(md_text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(md_text)
end


# Sinatra Config =============================
configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end


# Sinatra Helper Methods =============================





# Sinatra Paths =============================
get "/" do
  @content_files = get_files_info
  erb :index, layout: :layout
end


get "/:filename/view" do  
  filename = params[:filename]
  
  if get_files_info.keys.include?(filename)
    file_path = File.join(CONTENT_PATH, filename)
    file_contents = File.read(file_path)
  
    if get_files_info[params[:filename]][:extension] == ".md"
      headers["Content-Type"] = "text/html"
      render_markdown(file_contents)
    else
      headers["Content-Type"] = "text/plain"
      file_contents
    end
  
  else
    session[:message] = "#{filename} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  @filename = params[:filename]
  file_path = File.join(CONTENT_PATH, @filename)
  @file_contents = File.read(file_path)
  erb :file_edit, layout: :layout
end

post "/:filename" do
  @filename = params[:filename]
  new_content = params[:content]
  file_path = File.join(CONTENT_PATH, @filename)

  File.write(file_path, new_content)
  session[:message] = "#{@filename} has been updated."
  redirect "/"
end



=begin ++++++++++++++++++


++++++++++++++++++
=end 






=begin ==========================================
Open items to address:
- What if given a file that doesnt exist
- When nav to index, does not pick up language as english

=end