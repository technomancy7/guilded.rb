require 'faye/websocket'
require 'eventmachine'
require 'json'
require 'httparty'

# Master class of all Guilded objects
# Doesn't do anything yet, mostly just here to keep things organized, may do more later.
class GuildedObject
end

#@todo Channel, member, server objects

# Context object, used for events
class Context < GuildedObject

  def initialize(client, data, event_type)
    if client.debug then puts "DEBUG: Creating #{event_type} context out of #{data}" end
    @event_type = event_type
    @serverId = data["serverId"]
    @client = client
    @data = data
  end

  # If this a message-based event context, create a message object out of the data
  def create_message(data)
    @message = Message.new(data)
    @message.client = @client
    @message
  end

  #@todo reply shortcut for message.reply
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

  #@todo reply, delete, edit functions

  attr_accessor :data, :id, :serverId, :channelId, :content, :createdAt, :createdBy, :isPrivate, :client
end

# Storage of all methods that interact with the HTTP API
module API
  API_BASE = "https://www.guilded.gg/api/v1/"

  def send_message(channelId, content, replyTo = nil, private = false)
    endpoint = "#{API_BASE}channels/#{channelId}/messages"
    
    headers = {
      "Authorization" => "Bearer #{@token}",
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }

    body = {"content" => content}

    body["replyMessageIds"] = replyTo if replyTo != nil

    body["isPrivate"] = true if private

    response = HTTParty.post(endpoint, body: JSON.generate(body), headers: headers)
    p response if @debug
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
      :ChatMessageCreated => [],
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
