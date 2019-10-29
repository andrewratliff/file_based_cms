require "pry"
require "redcarpet"
require "sinatra"
require "sinatra/content_for"
require "sinatra/reloader"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, "secret"
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map { |file| File.basename(file) }

  erb :index
end

get "/:filename" do
  file_path = File.join(data_path, params[:filename])

  render_file(file_path)
end

get "/:filename/edit" do
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

private

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
    contents = File.read(file_path)

    if extension == ".md"
      markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
      markdown.render(contents)
    elsif extension == ".txt"
      content_type :text
      contents
    end
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end
