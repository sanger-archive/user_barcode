require 'rubygems'
require 'bundler'
require "rexml/document"
Bundler.setup
require 'sinatra'
require 'active_record'
require 'lib/barcode'

APP_ROOT = File.dirname(File.expand_path(__FILE__))
RAILS_ENV = (ENV['RAILS_ENV'] ||= 'development')
@@database = YAML::load(File.open( File.join(APP_ROOT,'config/database.yml') ))

helpers do
  def get_version_string
    require File.join(APP_ROOT,'lib/versionstrings')
    Deployed::VERSION_STRING
  end
end

class Person < ActiveRecord::Base
  set_table_name "PERSON"
  set_primary_key :id_person

  named_scope :current, :conditions => { :iscurrent => 1 }
  
  def self.find_user_login_from_barcode(barcode)
    user = self.find_user_from_barcode(barcode)
    user ? user.email : nil
  end
  
  def self.find_user_from_barcode(barcode)
    self.find(Barcode.number_to_human(barcode))
  end
  
  def self.find_barcode_id_from_user_login(user_login)
    person = Person.find_by_email(user_login)
    person ? person.id : nil
  end
  
end

get '/user_barcodes/lookup_user_login.xml' do
  Person.establish_connection(
    @@database["#{RAILS_ENV}_snp"]
  )
  content_type 'application/xml', :charset => 'utf-8'
  <<-_EOF_
<?xml version="1.0" encoding="UTF-8"?><user_barcodes><barcode_id>#{Person.find_barcode_id_from_user_login(params[:user_login])}</barcode_id><barcode>#{Barcode.calculate_barcode("ID", Person.find_barcode_id_from_user_login(params[:user_login]))}</barcode>
</user_barcodes>
_EOF_
end

get '/user_barcodes/lookup_scanned_barcode.xml' do
  Person.establish_connection(
    @@database["#{RAILS_ENV}_snp"]
  )
  content_type 'application/xml', :charset => 'utf-8'
  <<-_EOF_
<?xml version="1.0" encoding="UTF-8"?><user_barcodes><login>#{Person.find_user_login_from_barcode(params[:barcode])}</login></user_barcodes>
_EOF_
end

get '/' do
  content_type 'text/plain', :charset => 'utf-8'
  get_version_string
end
