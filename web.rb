require "bundler"
Bundler.setup(:default)
Bundler.require

require "./betarun/zipreader"
require "./betarun/paperclip"

Mongoid.load!("mongoid.yml")

class User
	include Mongoid::Document

	has_many :appcasts

	field :email, type: String
	field :fullName, type: String
	field :callingName, type: String
	field :picture, type: String
	field :facebookToken, type: String
	field :facebookTokenExpires, type: Time

	index({ email: 1 }, { unique: true })
end

class Appcast
    include Mongoid::Document

		belongs_to :user
    embeds_many :versions

    field :name, type: String
    field :url, type: String
    field :description, type: String
    field :language, type: String, default: 'en'

    index({ name: 1 }, { unique: true })
end

class Version
		include Mongoid::Document
		include Mongoid::Paperclip

		embedded_in :appcast

		field :title, type: String, default: "Version 1"
		field :description, type: String
		field :minimumSystemVersion, type: String
		field :pubDate, type: Time, default: -> { Time.now }
		field :versionNumber, type: Integer
		field :versionString, type: String
		field :draft, type: Boolean, default: true
		field :downloads, type: Integer, default: 0

		has_mongoid_attached_file :binary,
		    :path           => ':class/:attachment/:hash/:filename',
		    :hash_secret		=> ENV['PAPERCLIP_HASH_SECRET'],
		    :storage        => :s3,
		    :s3_credentials => { :access_key_id => ENV['AWS_ACCESS_KEY_ID'], :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'], :bucket => ENV['S3_BUCKET_NAME']}

		def serializable_hash(options={})
			json = super
			json[:binary_url] = self.binary.url
			return json
		end

		# process_in_background :binary
end

class App < Sinatra::Base
	set :root, File.dirname(__FILE__)
	set :assets, Sprockets::Environment.new(root)
	set :precompile,    [ /\w+\.(?!js|css).+/, /application.(css|js)$/ ]
	set :assets_prefix, "/assets"
	set :digest_assets, true
	set :base_url, ENV['BASE_URL']
	set(:assets_path)   { File.join public_folder, assets_prefix }

	register Sinatra::CompassSupport
	register Sinatra::Contrib
	register Sinatra::Namespace

	helpers Sinatra::ContentFor
	helpers Split::Helper

	# See https://developers.facebook.com/docs/reference/api/permissions/
	# for a full list of permissions
	FACEBOOK_SCOPE = 'email,publish_actions,publish_stream'

	configure do
		set :appname, ENV['APP_NAME']
	  set :public_dir, File.dirname(__FILE__) + '/public'
	  set :assets, Sprockets::Environment.new

	  Zip.setup do |c|
	    c.unicode_names = true
	  end

	  Split.configure do |config|
	    config.allow_multiple_experiments = true
	  end

	  %w{javascripts stylesheets images}.each do |type|
      assets.append_path "assets/#{type}"
    end

    %w{ng-time-relative/dist}.each do |dir|
    	assets.append_path "vendor/#{dir}"
  	end

    %w{angular-filters/build angular-ui-tinymce/src tinymce}.each do |dir|
    	assets.append_path "bower_components/#{dir}"
  	end

  	%w{vendor/bootstrap-datatimepicker}.each do |dir|
  		assets.append_path "#{dir}/css"
  		assets.append_path "#{dir}/js"
  	end

    Sprockets::Helpers.configure do |config|
      config.environment = assets
      config.prefix      = assets_prefix
      config.digest      = digest_assets
      config.public_path = public_folder
      config.debug       = true if development?
    end

	  set :haml, { :format => :html5, :escape_html => true }
	  set :scss, { :style => :compact, :debug_info => false }

	  Compass.add_project_configuration(File.join(Sinatra::Application.root, 'config', 'compass.rb'))
	end

	configure :production, :development do
    enable :logging
  end

	configure :production do
		set :raise_errors, false
		set :show_exceptions, false

		assets.js_compressor = Closure::Compiler.new
		Csso.install(assets)
		assets.css_compressor = :csso
		uid = Digest::MD5.hexdigest(File.dirname(__FILE__))[0,8]
		assets.cache = Sprockets::Cache::FileStore.new("/tmp/sinatra-#{uid}")
	end

	before do
	  # HTTPS redirect
	  # if settings.environment == :production && request.scheme != 'https'
	    # redirect "https://#{request.env['HTTP_HOST']}"
	  # end
	end

	helpers do
		include Sprockets::Helpers

	  def host
	    request.env['HTTP_HOST']
	  end

	  def scheme
	    request.scheme
	  end

	  def url_no_scheme(path = '')
	    "//#{host}#{path}"
	  end

	  def url(path = '')
	    "#{scheme}://#{host}#{path}"
	  end

	  def authenticator
	    @authenticator ||= Koala::Facebook::OAuth.new(ENV["FACEBOOK_APP_ID"], ENV["FACEBOOK_SECRET"], url("/auth/facebook/callback"))
	  end

	  # allow for javascript authentication
	  def access_token_from_cookie
	    authenticator.get_user_info_from_cookies(request.cookies)['access_token']
	  rescue => err
	    warn err.message
	  end

	  def access_token
	  	if session and session[:access_token]
	  		return session[:access_token]
	  	end
	  	access_token_from_cookie
	  end

	  def user_id
	  	return session[:user_id]
	  end

	  def appcast
	  	@appcast ||= Appcast.find(params[:appcast_id]) || halt(404)
	  end

	  def version
	  	@version ||= appcast.versions.find(params[:version_id]) || halt(404)
	  end

	  def mandrill
	  	@mandrill ||= Mandrill::API.new ENV['MANDRILL_KEY']
	  end
	end

	# the facebook session expired! reset ours and restart the process
	error(Koala::Facebook::APIError) do
	  session[:access_token] = nil
	  redirect "/auth/facebook"
	end

	get '/' do
		redirect '/dashboard' if user_id
		expires 500, :public, :must_revalidate
		haml :index
	end

	get '/how-to-*' do
		haml :howto
	end

	get '/partials/versions' do
		redirect '/' if not user_id
		haml :versions, {:layout => false}
	end

	get '/partials/edit-version' do
		redirect '/' if not user_id
		haml :editVersion, {:layout => false}
	end

	get '/dashboard' do
		redirect '/' if not user_id
		user = User.find(user_id)
		appcast = Appcast.find(user.appcast_ids[0])
		haml :dashboard, :locals => {:user => user, :appcast => appcast}
	end

	# Allows for direct oauth authentication
	get "/auth/facebook" do
	  session[:access_token] = nil
	  session[:user_id] = nil
	  redirect authenticator.url_for_oauth_code(:permissions => FACEBOOK_SCOPE)
	end

	get '/auth/facebook/callback' do
	  session[:access_token] = authenticator.get_access_token(params[:code])

	  # Get base API Connection
	  graph = Koala::Facebook::API.new(access_token)

	  profile = graph.get_object("me")
	  if not profile
	  	redirect '/'
	  	return nil
	  end

	  profile = profile.with_indifferent_access

	  user = User.where(email: profile[:email]).first
	  if not user
	  	finished("header")
	  	finished("login")
	  	finished("subheader")

	  	logger.info("User was not found " + profile[:email])
	  	picture = graph.get_picture("me")
	  	user = User.create!(email: profile[:email], fullName: profile[:name], callingName: profile[:first_name], picture: picture)

	  	begin
	  		message = {
	  			:subject=> "New User for BetaRun.it",
	  			:text=>"You have a new user #{user.email}",
	  			:from_name=> "BetaRun.it",
	  			:from_email=> "root@betarun.it",
	  			:to=>[
	  				{:email => "pawelniewiadomski@me.com", :name => "Pawel Niewiadomski"}
	  			]
	  		}
	  		mandrill.messages.send message
	  	rescue Mandrill::Error => e
	  		logger.error("A mandrill error occurred: #{e.class} - #{e.message}")
	  	end
	  end

	  if not user.facebookToken
	  	logger.info("Facebook token was not found " + profile[:email])
	  	new_access_info = authenticator.exchange_access_token_info(access_token).with_indifferent_access
	  	user.facebookToken = new_access_info[:access_token]
	  	user.facebookTokenExpires = DateTime.now + new_access_info[:expires].to_i.seconds
	  	user.save
	  else
	  	logger.info("Facebook token was found " + profile[:email])
	  end
	  if not user.appcasts.exists?
	  	user.appcasts.push(Appcast.new(name: "Awesome Appcast"))
	  end
	  session[:user_id] = user._id.to_s
	  redirect '/dashboard'
	end

	get '/auth/logout' do
		session.delete(:user_id)
		redirect '/'
	end

	['/appcasts/*', '/appcasts'].each do |path|
		before path do
		  halt 401, "Not authorized\n" if not user_id
		  content_type :json
		  cache_control :'no-cache'
		end
	end

	# get '/appcasts' do
		# appcasts = Appcast.all
		# appcasts.to_json
	# end

	# post '/appcasts' do
		# Appcast.create!(params.slice(Appcast.fields.keys)).to_json
	# end

	put '/appcasts/:appcast_id' do
		data = JSON.parse(request.body.read)
		if appcast.update_attributes(data)
			Appcast.find(params[:appcast_id]).to_json
		else
			appcast.to_json
		end
	end

	get '/appcasts/:appcast_id' do
		appcast.to_json
	end

	post '/appcasts/:appcast_id/versions' do
		versions = []
		if params[:files].kind_of?(Array)
			params[:files].each do |file|
				if (!file[:filename].nil? and !file[:tempfile].nil?)
					info = InfoFile::get_info_from_zip(file[:tempfile])
					if info
						error = nil
						info = info.with_indifferent_access

						if not info[:CFBundleVersion]
							error = "CFBundleVersion is not set in Info.plist"
						elsif not info[:CFBundleShortVersionString]
							error = "CFBundleShortVersionString is not set in Info.plist"
						elsif not info[:SUFeedURL]
							error = "SUFeedURL is not set in Info.plist"
						elsif settings.production? and info[:SUFeedURL].casecmp(ENV['BASE_URL'] + "/feed/" + appcast._id) != 0
							error = "SUFeedURL points to a wrong address"
						end

						unless error
							version = Version.new()
							begin
								# then update details
								appcast.versions.push(version)
								version.title = "Please upgrade to version #{info[:CFBundleShortVersionString]}" % info
								version.versionNumber = info[:CFBundleVersion]
								version.versionString = info[:CFBundleShortVersionString]
								version.minimumSystemVersion = info[:LSMinimumSystemVersion] unless info[:LSMinimumSystemVersion]
								version.binary = file
								version.save()
								versions.push({
										name: file[:filename],
										url: "#/edit/" + version._id,
										deleteType: "DELETE",
										deleteUrl: "/appcasts/" + appcast._id + "/versions/" + version._id
									})
							rescue Exception => e
								logger.error("Error saving version: #{e.class} - #{e.message}")
								versions.push({
										name: file[:filename],
										error: "Error uploading file to AWS S3"
									})
								appcast.versions.delete(version)
							end
						else
							versions.push({
									name: file[:filename],
									error: error
								})
						end
					else
						versions.push({
								name: file[:filename],
								error: "Cannot find <PutYourAppNameHere>.app/Contents/Info.plist"
							})
					end
				end
			end
		end
		{ :files => versions }.to_json
	end

	get '/appcasts/:appcast_id/versions/:version_id' do
		version.to_json
	end

	delete '/appcasts/:appcast_id/versions/:version_id' do
		version.binary.destroy
		appcast.versions.delete(version)
		true.to_json
	end

	put '/appcasts/:appcast_id/versions/:version_id' do
		data = JSON.parse(request.body.read)
		if version.update_attributes(data)
			Appcast.find(params[:appcast_id]).versions.find(params[:version_id]).to_json
		else
			version.to_json
		end
	end

	get '/appcasts/:appcast_id/versions' do
		appcast.versions.to_json
	end

	get '/feed/:appcast_id' do
		content_type :xml
		erb :appcast, :locals => { :appcast => appcast, :versions => appcast.versions.where(:draft => false, :pubDate.lt => Time.now()).desc(:versionNumber) }
	end

	get '/download/:appcast_id' do
		version = appcast.versions.where(:draft => false, :pubDate.lt => Time.now()).desc(:versionNumber).first

		halt 404 if not version

		redirect "/download/#{appcast._id}/#{version._id}"
	end

	get '/download/:appcast_id/:version_id' do
		halt 404 if not version

		version.downloads += 1
		version.save
		redirect version.binary.url
	end
end