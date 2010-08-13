# -*- coding: utf-8 -*-
require "mongo_mapper"

class EntryPost
  include MongoMapper::Document
  
  key :guid, String, :required => true
  key :url, String
  timestamps! # created_at, updated_at を定義する
  
  
  connection Mongo::Connection.new('localhost')
  set_database_name 'hatena'
end

class AccessToken
  include MongoMapper::Document

  key :access_token, String, :required => true
  timestamps!

  connection Mongo::Connection.new('localhost')
  set_database_name 'evernote'
end


class Token
  def access_token?
    time = Time.now.to_i
    token = AccessToken.first
    if token == nil || time - token.updated_at.to_i > 24*60*60
      return true
    else
      return nil
    end
  end
  
  def get_token
    AccessToken.first[:access_token]
  end

  def update_token(token)
    puts "update_token  #{token}"
    ac = AccessToken.first

    ac = AccessToken.new if ac == nil
    ac[:access_token] = token
    ac.save
  end
end

class Entries
  def exist?(guid)
    #guid is note.guid given by evernote
    entry = EntryPost.all(:guid => guid)
    #puts guid
    #p entry
    return nil if entry == []
    return true
  end
  
  def add(content)
    #content ={
    #          :guid => note.guid,
    #          :url
    #          }
    entry = EntryPost.new(content)
    puts entry[:content]
    entry.save
  end
end
