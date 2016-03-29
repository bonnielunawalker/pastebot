# Checks to see if the various required files exist. If they don't it creates them.
def startup
  smeac = "https://docs.google.com/document/d/1Zo2Id7PWoxF3xQ7B3OFgWhxHhihCxY0Pvl5VCQJcXcQ/edit?usp=sharing"
  squad_doc = "https://docs.google.com/spreadsheets/d/1N6ukUF0i5c4inlLaN5XbZ2gj_A8fqDJRRVpi7O3pGts/edit?usp=sharing"
  default_responses = {"paste" => "Paste.",
                       "spaghetti" => ":spaghetti:",
                       "rip" => "REST IN PEPPERONI",
                       "!smeac" => "I got chu fam: #{smeac}",
                       "!squad doc" => "I got chu fam: #{squad_doc}"}

  unless File.exist?("./data/commands.txt")
    commands = File.open("./data/commands.txt", "a+")

    # If it doesn't exist fills the commands.txt file with a number of default commands.
    default_responses.each_pair do |key, value|
      commands.print("$", key, " = ", value, "$\n")
    end
  commands.close
  end
  unless File.exist?("./data/custom_commands.txt")
    File.open("./data/custom_commands.txt", "a+")
  end
  unless File.exist?("./data/random_responses.txt")
    File.open("./data/random_responses.txt", "a+")
  end
  return false
end

# Checks if the user has admin privileges.
def admin_check (user, client, channel, admin_enabled)
  if admin_enabled == false
    return true
  else
    admins = File.open("./data/admins.txt", "r")
    admins.readlines.each do |line|
      if line.include?(user)
        admins.close
        return true
      end
    end
    admins.close
    return false
  end
end

# Runs various checks before the new_command method to ensure proper format
# for creation of a user generated command.
def new_command_check (client, message, channel, user)
  unless message.include?("|") && message.include?("$")
    client.typing channel: channel
    client.message channel: channel, text: "<@#{user}>, you're a bloody paste eater. Make sure you've actually got a keyword and response."
    return false
  else
    if message[/\$\s?(.*)\s?\|/, 1] == "" || message[/\|\s?(.*)\s?/, 1] == ""
      client.typing channel: channel
      client.message channel: channel, text: "<@#{user}>, you're a bloody paste eater. Make sure you've actually got a keyword and response."
      return false
    else
      return true
    end
  end
end

# Reads user input and prints that input to the custom_commands.txt document.
# This allows for long-term storage of user-generated commands.
def new_command (channel, client, user, message)
  custom_commands = File.open("./data/custom_commands.txt", "a+")

  keyword = message[/\$\s*(.*)\s*\|/, 1].strip # matches any characters including whitespace between
                                         # $ and |. Strips leading and trailing whitespace.
  custom_commands.readlines.each do |line|

    # Checks to see if the entered keyword is already a command. If it is, it breaks out of
    # the method.
    if keyword.downcase == line[/\$(.*)\s*\=/, 1]
      client.typing channel: channel
      client.message channel: channel, text: "<@#{user}>, you're a bloody paste eater. This command already exists."
      return
    end
  end
  response = message[/\|\s?(.*)\s?/, 1].strip # matches any characters including whitespace between |
                                        # and end of line. Strips leading and trailing whitespace.

  # Writes the keyword and response to file in the same format as the commands.txt file for
  # easy reading by the response method.
  custom_commands.print("$", keyword, "=", response, "$\n")
  custom_commands.close
  client.typing channel: channel
  client.message channel: channel, text: "<@#{user}>, new command has been added! Keyword: #{keyword}, response: #{response}"
end

# Reads all custom commands to see if the message contains any
# custom keywords.
def read_custom_commands (channel, client, user, message)
  custom_commands = File.open("./data/custom_commands.txt", "r")
  custom_commands.readlines.each do |line|
    if message.include? line[/\$(.*)\s*\=/, 1]
      respond(channel, client, line)
    end
  end
  custom_commands.close
end

# Basic response method. Takes the current channel and the message it's responding to.
# It then reads the commands.txt file and responds according to the line it recieved.
def respond (channel, client, line)
  client.typing channel: channel
  response = line[/\=\s*(.*)\$/, 1]
  client.message channel: channel, text: "#{response}"
end

# Chooses a random response from the random_responses.txt file and posts that response.
def respond_random (channel, client, user)
  rand_range = 300
  random_responses = File.open("./data/random_responses.txt", "r")
  random_responses.readlines.each do |line|

    # Generates a random integer between 0 and RAND_RANGE and if that number is a
    # key in the random_responses file, it posts the corresponding response.
    if line[/\$(.*)\s\=/, 1].include? rand(rand_range).to_s
      client.typing channel: channel
      response = line[/\=(.*)\$/, 1]
      client.message channel: channel, text: "<@#{user}>#{response}"
    end
  end
  random_responses.close
end

# Posts the current UTC/GMT time.
def check_time (channel, client)
  time = Time.now.utc
  client.typing channel: channel
  client.message channel: channel, text: "The current Zulu time is #{time.strftime('%A %B %e %H:%M %p')}."
end

# Attempts to connect to the USEC website. If a 200 code is recieved,
# pastebot informs the channel. Channel is also informed if connection
# fails.
def website_check (channel, client)
  client.typing channel: data.channel
  if Faraday.get("http://www.usecforce.com/").success?
    client.message channel: channel, text: "The USEC website is up and running!"
  else
    client.message channel: channel, text: "The USEC website is eating paste."
  end
end

# Deletes all custom commands.
def purge (channel, client, user)
  client.typing channel: channel
  File.truncate("./data/custom_commands.txt", 0)
  client.message channel: channel, text: "All custom commands have been deleted!"
end

# Since the !help command triggers a multi-line reply, it needs its own method. Multi-
# line replies are not stored well in text documents, and require explicit methods.
def help (channel, client)
  client.typing channel: channel
  client.message channel: channel, text: "Pastebot v0.1.3\n!paste: Enables listening.\n!unpaste: Disables listening.\n!smeac: Posts the smeac\n!squad doc: Posts the squad doc\n!new command $ trigger | response : Creates a new command. Ensure you seperate the keyword and response with |."
end