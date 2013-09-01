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

    embeds_many :items

    field :name, type: String
    field :url, type: String
    field :description, type: String
    field :language, type: String, default: 'en'

    index({ name: 1 }, { unique: true })
end

class Item
		include Mongoid::Document

		embedded_in :appcast

		field :title, type: String
		field :description, type: String
		field :minimumSystemVersion, type: String
		field :pubDate, type: Time, default: -> { Time.now }
		field :url, type: String
		field :versionNumber, type: Integer
		field :versionString, type: String
		field :size, type: Integer
end

helpers do

end

get '/' do
	haml :index
end

get '/queued/?' do
	haml :queued
end

get '/appcasts' do
	content_type :json
	appcasts = AppCast.all
	appcasts.to_json
end

post '/appcasts' do
	content_type :json
	AppCast.create!(params).to_json
end

put '/appcasts/:id' do |id|
	content_type :json
	data = JSON.parse(request.body.read)
	AppCast.find(id).update(data).to_json
end

get '/appcasts/:id' do |id|
	content_type :json
	AppCast.find(id).to_json
end

post '/appcasts/:id/items' do |id|
	content_type :json
	AppCast.find(id).items.push(Item.new(params)).to_json
end

get '/appcasts/:id/items' do |id|
	content_type :json
	AppCast.find(id).items.to_json
end

get '/appcasts/:id/feed' do |id|
	content_type :xml
	erb :appcast, :locals => { :appcast => AppCast.find(id) }
end