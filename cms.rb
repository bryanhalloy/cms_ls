require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"
require 'yaml'
require 'bcrypt'



# Directory setup  =============================
CONTENT_DIRECTORY_NAME = "content"
TEST_FOLDER_NAME = "test"
ROOT_PATH = File.expand_path("..", __FILE__)


def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

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
                  url_edit: "/#{filename}/edit",
                  url_delete: "/#{filename}/delete"
    }
    files_info_hash[filename] = file_hash
  end
  files_info_hash
end

def render_markdown(md_text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(md_text)
end

def create_document(name, content = "")
  File.open(File.join(content_path, name), "w") do |file|
    file.write(content)
  end
end

def logged_in?(session_hash)
  !!session_hash[:logged_in]
end

def redirect_if_not_signedin(session_hash)
  unless logged_in?(session_hash)
    session_hash[:message] = "You must be signed in to do that."
    redirect "/"
  end
end



# Sinatra Config =============================
configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end


# Sinatra Helper Methods =============================





# Sinatra Paths =============================
get "/" do
  if logged_in?(session)
    @content_files = get_files_info
    erb :index, layout: :layout
  else
    erb :user_login_prompt, layout: :layout
  end
end


get "/:filename/view" do  
  redirect_if_not_signedin(session)
  
  filename = params[:filename]
  
  if get_files_info.keys.include?(filename)
    file_path = File.join(CONTENT_PATH, filename)
    file_contents = File.read(file_path)

    headers["Content-Type"] = "text/html"
    if get_files_info[params[:filename]][:extension] == ".md"
      render_markdown(file_contents)
    else
      erb file_contents
    end
  
  else
    session[:message] = "#{filename} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  redirect_if_not_signedin(session)
  
  @filename = params[:filename]
  file_path = File.join(CONTENT_PATH, @filename)
  @file_contents = File.read(file_path)
  erb :file_edit, layout: :layout
end

post "/:filename/edit" do
  redirect_if_not_signedin(session)
  
  @filename = params[:filename]
  new_content = params[:content]
  file_path = File.join(CONTENT_PATH, @filename)

  File.write(file_path, new_content)
  session[:message] = "#{@filename} has been updated."
  redirect "/"
end

get "/new" do
  redirect_if_not_signedin(session)
  
  erb :file_new, layout: :layout
end

post "/new" do
  redirect_if_not_signedin(session)
  
  new_filename = params[:new_filename].to_s
  if new_filename.size == 0
    session[:message] = "A name is required."
    status 422
    erb :file_new, layout: :layout
  else
    create_document(new_filename, content = "")
    session[:message] = "#{new_filename} was created."

    redirect "/"
  end
end

post "/:filename/delete" do
  redirect_if_not_signedin(session)
  
  filename_to_delete = params[:filename]
  file_path = File.join(CONTENT_PATH, filename_to_delete)
  File.delete(file_path)
  session[:message] = "#{filename_to_delete} has been deleted."

  redirect "/"
end

get "/users/login" do
  erb :user_login_input
end

post "/users/login" do
  username = params[:username]
  session[:username] = username

  users_hash = load_user_credentials

  if !users_hash.keys.include?(username)
    session[:message] = "Invalid username"
    status 422
    erb :user_login_input
  else
    if valid_credentials?(username, params[:password])
      session[:logged_in] = true
      session[:message] = "Welcome!"
      redirect "/"
    else
      session[:logged_in] = false
      session[:message] = "Invalid credentials"
      status 422
      erb :user_login_input
    end
  end
end

post "/users/logout" do
  session[:logged_in] = false
  session[:username] = nil
  session[:message] = "You have been signed out."
  redirect "/"
end
