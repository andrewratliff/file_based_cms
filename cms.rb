require "pry"
require "redcarpet"
require "sinatra"
require "sinatra/content_for"
require "sinatra/reloader"
require "tilt/erubis"

ROOT = File.expand_path(__dir__)

configure do
  enable :sessions
  set :session_secret, "secret"
end

get "/" do
  @files = Dir.glob(ROOT + "/data/*").map { |file| File.basename(file) }

  erb :index
end

get "/:filename" do
  file_path = ROOT + "/data/" + params[:filename]

  render_file(file_path)
end

get "/:filename/edit" do
  file_path = ROOT + "/data/" + params[:filename]

  if File.exists?(file_path)
    @content = File.read(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end

  erb :edit
end

post "/:filename/edit" do
  file_path = ROOT + "/data/" + params[:filename]
  content = params[:file_content]

  if File.exists?(file_path)
    File.write(file_path, content)
    session[:message] = "#{params[:filename]} has been updated."
  else
    session[:message] = "#{params[:filename]} does not exist."
  end

  redirect "/"
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
