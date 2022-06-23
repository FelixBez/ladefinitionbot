require 'twitter'
require 'net/http'
require 'i18n'
require './credentials.rb'

class DictionnaireBot
  credentials = Credentials.new()

  @client = Twitter::REST::Client.new do |config|
    config.consumer_key        = credentials.consumer_key
    config.consumer_secret     = credentials.consumer_secret
    config.access_token        = credentials.access_token
    config.access_token_secret = credentials.access_token_secret
  end


  def self.process
    @client.mentions_timeline.each do |mention|
      if !already_respond?(mention.id)
        save_log("New mention: "+mention.id.to_s)
        word = mention.text.split(" ").last
        save_log("Word : "+word)
        definitions = getDefinitionsFromApi(word)
        definitions.each do |definition|
          reply = "@"+mention.user.screen_name+" "+definition.gsub("&#160;", "")
          send_reply(reply, mention.id)
        end
        save_response(mention.id)
        save_log("---------------------------------------------------------------")
      end
    end
  end

  def self.already_respond?(id)
    result = false
    File.foreach("./test.txt") { |line| id.to_s == line.strip() ? result = true : "" }
    result
  end

  def self.getDefinitionsFromApi(word)
    definitions = []
    I18n.available_locales = [:en]
    url = 'https://dictionnaire.lerobert.com/definition/'+I18n.transliterate(word.downcase)
    uri = URI(url)
    resultat = Net::HTTP.get_response(uri)
    temp_array = resultat.body.split('<span class="d_dfn">').drop(1)
    elements = []
    temp_array.length == 1 ? ""  : temp_array.delete_at(temp_array.length-1)
    temp_array.each do |element|
      definitions.push(element.split('<')[0])
    end
    save_log(definitions.to_s)
    definitions.size == 0 ? ["Je ne trouve pas ce mot :("] : definitions
  end

  def self.save_response(id)
    myFile = File.open("./test.txt", "a")
    myFile.write "\n"
    myFile.write id.to_s
    myFile.close
  end

  def self.save_log(log)
    myFile = File.open("./log.txt", "a")
    myFile.write "\n"
    myFile.write log
    myFile.close
  end

  def self.send_reply(message, id)
    begin
      @client.update(message, in_reply_to_status_id: id)
    rescue => exception
      save_log("Definition is too long for a tweet : "+ id.to_s)
      save_log(exception.message)
    end
  end
end

DictionnaireBot.process