require "bundler"
Bundler.setup(:default)
Bundler.require

Mongoid.load!("mongoid.yml")

configure do
  set :public_dir, File.dirname(__FILE__) + '/public'
  set :static, true

  set :haml, { :format => :html5, :escape_html => true }
  set :scss, { :style => :compact, :debug_info => false }

  Compass.add_project_configuration(File.join(Sinatra::Application.root, 'config', 'compass.rb'))
end

class AppCast
    include Mongoid::Document

    field :name, type: String

    index({ name: 1 }, { unique: true })
end

helpers do

end

get '/' do
	haml :index
end

get '/queued/?' do
	haml :queued
end

get '/appcasts.json' do
	content_type :json
	appcasts = AppCast.all
	appcasts.to_json
end

post '/appcasts.json' do
	content_type :json
	AppCast.create!(name: params[:name]).to_json
end

put '/appcasts.json/:id' do |id|
	content_type :json
	data = JSON.parse(request.body.read)
	AppCast.find(id).update(data).to_json
end

get '/appcasts.json/:id' do |id|
	content_type :json
	AppCast.find(id).to_json
end