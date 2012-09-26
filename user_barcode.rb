require 'rubygems'
require 'bundler'
Bundler.setup
require 'sinatra'
require 'active_record'
require 'lib/barcode'

APP_ROOT = File.dirname(File.expand_path(__FILE__))
RAILS_ENV = (ENV['RAILS_ENV'] ||= 'development')

helpers do
  def get_version_string
    require File.join(APP_ROOT,'lib/versionstrings')
    Deployed::VERSION_STRING
  end
end

class Person < ActiveRecord::Base
  set_table_name "PERSON"
  set_primary_key :id_person
  establish_connection(YAML::load(File.open(File.join(APP_ROOT,'config/database.yml')))[RAILS_ENV])

  # Exceptions & errors that can be raised
  Error              = Class.new(StandardError)
  NoSuchLoginError   = Class.new(Error)
  NoSuchBarcodeError = Class.new(Error)

  def barcode
    Barcode.calculate_barcode("ID", barcode_id)
  end

  def barcode_id
    self.id
  end

  def login
    self.email
  end

  def present_in_xml
    Presenter.new(self)
  end

  class << self
    def find_barcode_id_from_user_login(user_login)
      connect do
        user = find_by_email(user_login) or raise NoSuchLoginError, user_login
        yield(user)
      end
    end

    def find_user_login_from_barcode(barcode)
      connect do
        user = find(Barcode.number_to_human(barcode)) or raise NoSuchBarcodeError, barcode
        yield(user)
      end
    end

    # Ensure that the connections are properly managed, releasing them once the block
    # has completed.
    def connect(&block)
      yield
    ensure
      connection_pool.release_connection
    end
    private :connect
  end

  # XML presenter for users
  require 'builder'
  class Presenter
    def initialize(user)
      @user = user
    end

    def write(output)
      output.content_type('application/xml', :charset => 'utf-8')
      output.body(to_xml)
    end

    def to_xml
      xml = Builder::XmlMarkup.new
      xml.instruct!
      xml.user_barcodes {
        xml.barcode_id(@user.barcode_id)
        xml.barcode(@user.barcode)
        xml.login(@user.login)
      }
      xml.target!
    end
  end
end


# Ensure that the act of not finding something returns the correct response
error(Person::NoSuchLoginError)   { not_found }
error(Person::NoSuchBarcodeError) { not_found }
set :show_exceptions, false

get '/user_barcodes/lookup_user_login.xml' do
  Person.find_barcode_id_from_user_login(params[:user_login]) do |user|
    user.present_in_xml.write(self)
  end
end

get '/user_barcodes/lookup_scanned_barcode.xml' do
  Person.find_user_login_from_barcode(params[:barcode]) do |user|
    user.present_in_xml.write(self)
  end
end

get '/' do
  content_type 'text/plain', :charset => 'utf-8'
  get_version_string
end
