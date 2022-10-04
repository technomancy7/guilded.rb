require_relative "guilded.rb"
require "json"

file = File.read('./config.json')
config = JSON.parse(file)

client = Guilded.new()

client.add_event(:ChatMessageCreated) { |ctx|
    msg = ctx.message
    puts "[CHAT EVENT] #{msg.createdBy}: #{msg.content}"
    
    if msg.content == "!test"
        ctx.client.send_message(msg.channelId, "Hello!", replyTo = [msg.id])
    end
    
    if msg.content == "!priv"
        ctx.client.send_message(msg.channelId, "Hello!", replyTo = [msg.id], private = true)
    end
}

client.connect(config["token"])
