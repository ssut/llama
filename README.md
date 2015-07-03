# llama (라마, ラマ)

![](http://i.imgur.com/b4cAIvF.png)

Llama is a simple bot framework written in [Ruby](https://www.ruby-lang.org/) and [EventMachine](http://www.rubyeventmachine.com/). It will prettttty much do whatever you want it to do, and it provides a simple interface based on plugins and listeners.

It is very easy to get up and running! Let's try!

## Features

* You don't need to make a event listener - and even a thread - to say "hello" to the room.
* Use Ruby code to make your own, or include a Plugin class and then make a plugin if you need it
* Basic HTTP API support (with [em-http-request](https://github.com/igrigorik/em-http-request))
* Event loop: Unlike a lot of bots, llama is running in event-loop. It provides: to make itself faster, non-blocking I/O operations, and you will be free from restrictions of the thread.

## Implemented Services

* LINE – You can't do it without a thirft code I used here, you could check the **.gitignore** file if you want.
* Telegram (WIP)
* KakaoTalk (WIP, as far as I can tell, it is so far away.)


## Installation

This project is currently in **"develop"**. By this is meant a gem package or installation is not avilable.

### Manually

You need to grab a clone of this repo. To do this you should have **git** installed on your system. Once that is installed you can execute:

```bash
$ git clone https://github.com/ssut/llama.git
```

### From the Repository

In your Gemfile:

```ruby
gem 'llama', :github => 'ssut/llama'
```

Then run:

```bash
$ bundle install
```
## Usage

To use llama, create a file like this:

Note that in this example: I assume that you've created *a file* in your cloned directory, so you don't need to write two lines of code as below when you've installed with bundler.

```ruby
lib = File.join(File.dirname(__FILE__), 'lib')
$:.unshift lib unless $:.include?(lib)

require 'llama'
# import plugins that you want to use for a script.
require 'llama/plugins/google_images'
require 'llama/plugins/codepad'

bot = Llama::Bot.new do
    service :line do |c|
        c.username = ''
        c.password = ''
        c.name ='computer-name'
        
        # This code is used if saved token is available
        File.open('.line-token', 'r') { |f| c.auth_token = f.read() } if File.exist?('token.tmp')
    end
    
    # these two lines are too long,
    # I recommend you to include Llama::EmbedPlugin and just write plugin's class name.
    # also, you can declare multiple plugins on a single line, separated by commas:
    # => plugin GoogleImagesPlugin, CodepadPlugin
    plugin Llama::EmbedPlugin::GoogleImagesPlugin
    plugin Llama::EmbedPlugin::CodepadPlugin
    
    # write your own bot code
    on 'Hello' do |msg, captures|
        # ...
        # and this code shows you how to send a reply to just the sender of a message or the room.
        msg.reply(:text, "Hello #{msg.user.name}!")
        msg.reply_user(:text, "Helllo there!")
    end
    
    # If you ask something like "can I use regular expression for listens?"
    # I would reply, "Yes, exactly!"
    on /^Say (?<message>.+)/i do |msg, captures|
        text = captures.join
        msg.reply(:text, text)
    end
    
    # even with llama you can send multiple messages by doing:
    on /^Say (?<message>.+) (?<times>[\d]+) time/i do |msg, captures|
        text, count = captures.first, captures.last
        count.times do |i|
            msg.reply(:text, "[#{i}] #{text}")
        end
    end
end

# Start your own bot!
bot.start! do |service|
    # * LOW-LEVEL ACCESS
    # You can access to the service by doing so,
    # I wrote this code to get LINE authenticated token for authentication when next time I log on.
    File.open('.line-token', 'w') { |f| f.write(service.cert) } unless service.cert.nil?
end
```

## Contributing

If there are bugs or things you would like to improve, fork the project, and implement your awesome feature or patch in its own branch, then send me a pull request here!

## License

**llama** is licensed under the GNU General Public License (GPL) version 2.0, which provides legal permission to copy, charge, distribute and/or modify the software.

Please check the LICENSE file for more details.
