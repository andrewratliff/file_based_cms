require "bcrypt"
require "pry"
require "redcarpet"
require "sinatra"
require "sinatra/content_for"
require "sinatra/reloader"
require "tilt/erubis"
require "yaml"

# Some next steps:
# Validate that document names contain an extension that the application supports.
# Add a "duplicate" button that creates a new document based on an old one.
# Extend this project with a user signup form.
# Add the ability to upload images to the CMS (which could be referenced within markdown files).
# Modify the CMS so that each version of a document is preserved as changes are made to it.

configure do
  enable :sessions
  set :session_secret, "secret"
end

get "/users/signin" do
  erb :sign_in
end

post "/users/signin" do
  username = params[:username]
  password = params[:password]

  if valid_credentials?(username, password)
    session[:username] = username
    session[:message] = "Welcome #{username}"
    redirect "/"
  else
    status 422
    session[:message] = "Invalid credentials."
    erb :sign_in
  end
end

post "/sign_out" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map { |file| File.basename(file) }

  erb :index
end

get "/new" do
  authenticate!

  erb :new
end

post "/new" do
  authenticate!

  filename = params[:filename]

  if filename.nil? || filename.empty?
    status 422
    session[:message] = "A name is required."
    erb :new
  else
    create_document(filename)
    session[:message] = "#{filename} has been created!"
    redirect "/"
  end
end

get "/:filename" do
  file_path = File.join(data_path, params[:filename])

  render_file(file_path)
end

get "/:filename/edit" do
  authenticate!

  file_path = File.join(data_path, params[:filename])

  if File.exists?(file_path)
    @content = File.read(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end

  erb :edit
end

post "/:filename/edit" do
  authenticate!

  file_path = File.join(data_path, params[:filename])
  content = params[:file_content]

  if File.exists?(file_path)
    File.write(file_path, content)
    session[:message] = "#{params[:filename]} has been updated."
  else
    session[:message] = "#{params[:filename]} does not exist."
  end

  redirect "/"
end

post "/:filename/delete" do
  authenticate!

  file_path = File.join(data_path, params[:filename])

  if File.exists?(file_path)
    File.delete(file_path)
    session[:message] = "#{params[:filename]} has been deleted."
  else
    session[:message] = "#{params[:filename]} does not exist."
  end

  redirect "/"
end

private

def create_document(name, content = "")
  File.open(File.join(data_path, name), "w") do |file|
    file.write(content)
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("test/data", __dir__)
  else
    File.expand_path("data", __dir__)
  end
end

def render_file(file_path)
  extension = File.extname(file_path)

  if File.exists?(file_path)
    content = File.read(file_path)

    if extension == ".md"
      erb render_markdown(content)
    else
      content_type :text
      content
    end
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

def render_markdown(content)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(content)
end

def signed_in_user?
  session.key?(:username)
end

def valid_credentials?(username, password)
  if users.key?(username)
    bcrypt_pw = BCrypt::Password.new(users[username])
    return bcrypt_pw == password
  end

  false
end

def authenticate!
  unless signed_in_user?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

def users
  users_file = if ENV["RACK_ENV"] == "test"
                 File.expand_path("test/users.yml", __dir__)
               else
                 File.expand_path("users.yml", __dir__)
               end

  @users ||= Psych.load_file(users_file)
end
