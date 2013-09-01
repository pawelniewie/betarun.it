$stdout.sync = true

require 'rubygems'
require 'bundler'

Bundler.require

set :root, File.dirname(__FILE__)

require './web.rb'
run Sinatra::Application
