# -*- coding: utf-8 -*-
# You need to get your Evernote API Keys
#

require 'nokogiri'
require 'oauth/consumer'
require 'oauth/signature/PLAINTEXT'
require "thrift"
require "Evernote/EDAM/user_store"
require "Evernote/EDAM/user_store_constants.rb"
require "Evernote/EDAM/note_store"
require "Evernote/EDAM/limits_constants.rb"
require "net/http"
require "pit"
require 'atomutil'
require './hatenadf'
require './db'

EVERNOTE_SERVER = "http://sandbox.evernote.com"

module OAuth #:nodoc:
  VERSION = '0.4.1'
end

class EverNote
  def initialize
    @key = Pit.get("evernote.api")["key"] 
    @pass = Pit.get("evernote.api")["secret"]
    @consumer=OAuth::Consumer.new(@key,
                                  @pass,
                                  {:site               => EVERNOTE_SERVER,
                                    :http_method        => :get,
                                    :signature_method => "plaintext", 
                                    :request_token_path => "/oauth",
                                    :access_token_path  => "/oauth",
                                    :authorize_path     => "/OAuth.action"
                                  })
    token = Token.new
    if token.access_token?
      @request_token = @consumer.get_request_token          
      puts @request_token.authorize_url(:oauth_callback => "http://sis-w.net:4567")
      oauth_token = gets.chomp.strip
      @access_token = @request_token.get_access_token.token  
      token.update_token(@access_token)
    else
      @access_token = token.get_token
    end
    
    noteStoreUrl = EVERNOTE_SERVER + "/edam/note/s1"
    noteStoreTransport = Thrift::HTTPClientTransport.new(noteStoreUrl)
    noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
    @noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)
  end
  
  def get_note(guid)
    return @noteStore.getNoteContent(@access_token, guid)
  end

  def get_tags(guid)
    return  @noteStore.getNoteTagNames(@access_token, guid)
  end

def find_notes(tag)
    filter_tag = tag.to_s
    filter = Evernote::EDAM::NoteStore::NoteFilter.new
    filter.words = "tag:#{ filter_tag}"
    return res = @noteStore.findNotes(@access_token, filter, 0, 100)
  end    
  
  def save_resources(resources)    
    files =[]
    resources.each do |resource|
      data = @noteStore.getResource(@access_token, resource.guid, true, true, true, true)
      hex = data.data.bodyHash.unpack('H*').first
      ext = case data.mime
            when 'image/png'
              'png'
            when 'image/jpeg'
              'jpg'
            else
              next
            end
      File.open("/Users/watura/Downloads/instev/#{hex}.#{ext}", 'w') { |f| f.write(data.data.body)}
      files << "#{hex}.#{ext}"
    end
    return files
  end
end

evernote = EverNote.new
hatena = HatenaDF.new
db = Entries.new
keyword = "Blog"
notes = evernote.find_notes(keyword)
content = Hash.new
notes.notes.each do |note|
  next if db.exist?(note.guid)
  content[:content] =evernote.get_note(note.guid)
  if note.resources
    imgtag = evernote.save_resources(note.resources).collect {|file| hatena.upload_fotolife(file)}
    imgtag.each{|tag| content[:content].gsub!(/<en-media.*?>/,tag)}
  end
  content[:content].gsub!(/<br.*?>/,"\n")
  content[:content].gsub!(/<.*?>/, "").strip!
  content[:title] = note.title
  tags =evernote.get_tags(note.guid)
  tags.each do |tag|
    content[:title] = "[#{tag}]" + content[:title]
  end
  url = hatena.write_diary(content)
  db.add({:url => url,:guid => note.guid})
end
