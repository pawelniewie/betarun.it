require "bundler"
Bundler.setup(:default)
Bundler.require

configure do
  set :public_dir, File.dirname(__FILE__) + '/public'
  set :static, true

  set :haml, { :format => :html5, :escape_html => true }
  set :scss, { :style => :compact, :debug_info => false }

  Compass.add_project_configuration(File.join(Sinatra::Application.root, 'config', 'compass.rb'))
end


get '/' do
	haml :index
end

get '/queued/?' do
	haml :queued
end
