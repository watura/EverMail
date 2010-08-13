require 'atomutil'
require 'pit'

module Atompub
  class HatenaClient < Client
    def publish_entry(uri)
      @hatena_publish = true
      update_resource(uri, ' ', Atom::MediaType::ENTRY.to_s)
    ensure
      @hatena_publish = false
    end

    private
    def set_common_info(req)
      req['X-Hatena-Publish'] = 1 if @hatena_publish
      super(req)
    end
  end
end

class HatenaDF
  def initialize
    @user = Pit.get("hatena")["id"]
    passwd = Pit.get("hatena")["passwd"]
    @client = Atompub::Client.new({:auth => Atompub::Auth::Wsse.new(:username => @user, :password => passwd)})
  end
  
  def upload_fotolife(file)
    #file should be image/jpeg    
    file = Pathname.new(file)
    entry = Atom::Entry.new({
                              :title => file.basename.to_s,
                              :updated => Time.now,
                              :content => Atom::Content.new { |c|
                                c.body = [file.read].pack('m')
                                c.type = "image/jpeg"
                                c.set_attr(:mode, "base64")},
                            })
    post_uri = "http://f.hatena.ne.jp/atom/post"
    pic =  @client.create_entry(post_uri, entry, file.basename.to_s).scan(/edit\/(\d.*)/).flatten[0]
    return "[f:id:#{@user}:#{pic}:image]"
  end
  
  def write_diary(content)
    #content must be hash
    #content={:title=> string,
    #         :content => string
    #        }
    
    #    auth = Atompub::Auth::Wsse.new :username => user, :password => Pit.get("hatena")["passwd"]
    #    client = Atompub::HatenaClient.new :auth => auth
    service = @client.get_service 'http://d.hatena.ne.jp/%s/atom' % @user
    collection_uri = service.workspace.collections[1].href
    entry = Atom::Entry.new(
                            :title => content[:title].to_s,
                            :updated => Time.now
                            )
    entry.content = content[:content].strip
    puts ret = @client.create_entry(collection_uri, entry)
    return ret 
  end
end
