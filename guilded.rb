require 'faye/websocket'
require 'eventmachine'
require 'json'
require 'httparty'

class GuildedObject
end

class Context < GuildedObject
  def initialize(client, data, event_type)
    puts "DEBUG: Creating #{event_type} context out of #{data}"
    @event_type = event_type
    @serverId = data["serverId"]
    @client = client
    @data = data
  end

  def create_message(data)
    @message = Message.new(data)
    @message.client = @client
    @message
  end

  attr_accessor :message, :serverId, :event_type, :client, :data
end

class Message < GuildedObject
  def initialize(data)
    @data = data
    @id = data["id"]
    @serverId = data["serverId"]
    @channelId = data["channelId"]
    @content = data["content"]
    @createdAt = data["createdAt"]
    @deletedAt = data["deletedAt"]
    @createdBy = data["createdBy"]
    @isPrivate = data["isPrivate"]
    @client = nil
  end

  attr_accessor :data, :id, :serverId, :channelId, :content, :createdAt, :createdBy, :isPrivate, :client
end

module API
  API_BASE = "https://www.guilded.gg/api/v1/"

  def send_message(channelId, content, replyTo = nil, private = false)
    endpoint = "#{API_BASE}channels/#{channelId}/messages"
    puts "Sending #{content} to #{endpoint}"
    headers = {
      "Authorization" => "Bearer #{@token}",
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }

    body = {"content" => content}

    if replyTo != nil
      body["replyMessageIds"] = replyTo
    end

    body["isPrivate"] = true if private
    #, "replyMessageIds" => replyTo

    response = HTTParty.post(endpoint, body: JSON.generate(body), headers: headers)
    p response
  end
end

class Guilded
  include API

  attr_accessor :websocket_addr, :debug

  def initialize()
    @websocket_addr = "wss://www.guilded.gg/websocket/v1"
    @token = nil
    @debug = false

    @events = {
      :ChatMessageCreated => [], #method(:default_on_message)
      :ClientStartup => [method(:default_startup)],
      :ClientStarted => [method(:default_started)]
    }

    @cache = {
      :messages => {},
      :channels => {},
      :members => {},
      :users => {},
      :guilds => {}
    }
  end

  def add_event(event_type, &block)
    @events[event_type] = [] if @events[event_type] == nil
    @events[event_type].append(block)
  end

  def default_startup(ctx)
    puts "Starting client..."
  end

  def default_started(ctx)
    puts "Client has started."
  end

  def dispatch_events(event_type, json = {})
    if @events[event_type] != nil then
      context = Context.new(self, json["d"] || {}, event_type)
      
      context.create_message(context.data["message"]) if context.data["message"] != nil
      #context.serverId = context.data["serverId"] 
      @events[event_type].each { |x| x.call(context) }
    else
      puts "DEBUG: No events hooked for #{event_type}"
      puts "Discarding event data: #{json}"
    end
  end

  def connect(token)
    @token = token
    dispatch_events(:ClientStartup)
    EM.run {
      @socket = Faye::WebSocket::Client.new(@websocket_addr, [], {
        :headers => {"Authorization" => "Bearer #{token}"}
        })
    
      @socket.on :open do |event|
        p [:open]
        #ws.send('Hello, world!')
        dispatch_events(:ClientStarted)
      end
    
      @socket.on :message do |event|
        json = JSON.parse(event.data)
        p [:message, json]
        if json["t"] != nil then
          event_type = json["t"].to_sym

          dispatch_events(event_type, json)

        end

      end
    
      @socket.on :close do |event|
        p [:close, event.code, event.reason]
        @socket = nil
      end
    }
  end

end
