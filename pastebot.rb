
  #######################################
  # Pastebot created by Bryn Walker     #
  # For use by the Unity Security Force #
  # Version 0.1.4                       #
  # Last modified 29/3/16               #
  #######################################


require 'slack-ruby-client'
require 'faye/websocket'
require 'openssl'
require_relative './data/auth'
require_relative './data/methods'
require 'sinatra'

class Pastebot < Sinatra::Base

  # Initial configuration of the client.
  Slack.configure do |config|
    config.token = AUTH_TOKEN
    fail "No authorisation token!\n
          Perhaps auth.rb is missing or you haven't updated it since
          generating a new token?" unless config.token
  end

  client = Slack::RealTime::Client.new(websocket_ping: 42)

  # Initialises pastebot, ensures necessary files exist and defaults
  # pastebot to non-listening mode.
  listen = startup
  admin_enabled = false
  new_command_admin = false

  # Pastebot begins to read messages from this point.
  client.on :message do |data|
    message = data.text.downcase
    if message.include?("!paste")
      listen = true
      client.typing channel: data.channel
      client.message channel: data.channel, text: "Paste has been activated."
    elsif message.include?("!unpaste")
      listen = false
      client.typing channel: data.channel
      client.message channel: data.channel, text: "Switching off the paste."
    end

    if message == "!admin"
      admin_enabled = true
      client.typing channel: data.channel
      client.message channel: data.channel, text: "Admin checking is now enabled."
    elsif message == "!unadmin"
      admin_enabled = false
      client.typing channel: data.channel
      client.message channel: data.channel, text: "Admin checking has been disabled."
    end

    if listen
      commands = File.open("./data/commands.txt", "r")
      case

      # Check if !help command is entered. !help is a multiline response
      # and due to multilines in hashes not being handled well by the API,
      # it must be explicitly executed.
      when message.include?("!help")
        help(data.channel, client)

      when message == "!admin new command"
        new_command_admin = true
        client.typing channel: data.channel
        client.message channel: data.channel, text: "Admin privileges now required for new command creation."

      when message == "!unadmin new command"
        new_command_admin = false
        client.typing channel: data.channel
        client.message channel: data.channel, text: "Admin privileges no longer required for new command creation."

      when message.include?("!new command")

        # Runs checks to ensure the validity of a new command.
        if new_command_admin == false
          if new_command_check(client, message, data.channel, data.user)
            new_command(data.channel, client, data.user, message)
          end
        else
          if admin_check(data.user, client, data.channel, admin_enabled)
            if new_command_check(client, message, data.channel, data.user)
              new_command(data.channel, client, data.user, message)
            end
          else
            client.typing channel: channel
            client.message channel: channel, text: "Sorry <@#{user}>, you're not authorised to do that!"
          end
        end

      # Deletes all custom commands.
      when message.include?("!purge")
        if admin_check(data.user, client, data.channel, admin_enabled)
          purge(data.channel, client, data.user)
        end

      # Posts the current UTC time.
      when message.include?("!zulu")
        check_time(data.channel, client)

      # Checks to see if the USEC website is up.
      when message.include?("!website")
        website_check(data.channel, client)

      # Reads commands.txt to see if the message contains any trigger words.
      else
        commands.readlines.each do |line|
          if message.include? line[/\$(.*)\s\=/, 1]
            respond(data.channel, client, line)
          end
        end
        commands.close

        # Checks to see if the message contains any custom command keywords,
        # and responds appropriately.
        read_custom_commands(data.channel, client, data.user, message)

        # Responds with a random response drawn from a text file.
        respond_random(data.channel, client, data.user)
      end
    end
  end

  client.on :close do |data|
    puts 'Connection closed, exiting.'
    EM.stop
  end

  client.start!
end