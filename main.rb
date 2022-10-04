require_relative "guilded.rb"
require "json"

# Opening our config file where we store the bot token
file = File.read('./config.json')
config = JSON.parse(file)

# Create our Guilded client
client = Guilded.new()

# Adding an event for ChatMessageCreated, run whenever the bot sees a new message
client.add_event(:ChatMessageCreated) { |ctx|
    # ctx is our "Context", which stores information about the event, every event will have this.
    # the message that was created is stored in ctx.message

    msg = ctx.message

    puts "[CHAT EVENT] #{msg.createdBy}: #{msg.content}"
    # createdBy is the ID of the message author (Will eventually be a Member object, not just their ID)
    
    # The author send a command
    if msg.content == "!test"
        # We reply to that message.
        # replyTo is optional, if omitted then it will be a standard message instead of a reply
        ctx.client.send_message(msg.channelId, "Hello!", replyTo = [msg.id])
        #@todo shortcut reply functions in context
    end

    if msg.content == "!priv"
        # Private reply!
        ctx.client.send_message(msg.channelId, "Hello!", replyTo = [msg.id], private = true)
    end
}

# Connecting to Guilded
client.connect(config["token"])
