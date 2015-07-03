lib = File.join(File.dirname(__FILE__), 'thrift')
$:.unshift lib unless $:.include?(lib)

require 'thrift'
require 'thrift_client'
require 'openssl'
require 'socket'
require 'base64'
require 'mechanize'

# LINE
require 'line_types'
require 'talk_service'

# Implementation
require_relative './api'
require_relative './models'

# Llama
require_relative './message'

module Llama
  module Line
    class LineService < LineAPI
      include Logging

      attr_reader :bot

      attr_reader :client
      attr_reader :agent
      attr_reader :headers
      attr_reader :cert

      attr_reader :profile
      attr_reader :contacts
      attr_reader :rooms
      attr_reader :groups

      LINE_DOMAIN = 'http://gd2.line.naver.jp'
      
      LINE_HTTP_URL = LINE_DOMAIN + '/api/v4/TalkService.do'
      LINE_HTTP_IN_URL = LINE_DOMAIN + '/P4'
      LINE_CERTIFICATE_URL = LINE_DOMAIN + '/Q'
      LINE_SESSION_LINE_URL = LINE_DOMAIN + '/authct/v1/keys/line'

      def initialize(bot, conf)
        if not (conf.username and conf.password) and not conf.auth_token
          raise 'username and password or auth_token is needed' 
        end

        @bot = bot

        # Init
        @rooms = []
        @contacts = []
        @groups = []

        # Revision
        @revision = 0

        # Certificate
        @cert = nil

        # Message Queue
        @queue = EM::Queue.new
        @ops = EM::Queue.new

        @name = conf.name
        @user = conf.username
        @pass = conf.password

        self.init_agent()

        if conf.auth_token
          @cert = conf.auth_token
          begin
            self.login_token()
          rescue
            @cert = nil
            puts 'trying to another way..'
            if @user and @pass
              self.login()
              self.login_token()
            else
              raise 'failed to login with token'
            end
          end
        else
          @provider = IdentityProvider::LINE
          self.login()
        end
        logger.info("You have successfully logged in to the LINE")

        self.get_profile()

        begin; self.refresh_contacts(); rescue; end
        begin; self.refresh_groups(); rescue; end
        begin; self.refresh_rooms(); rescue; end
      end

      def init_agent
        version = '4.0.3'
        os_version = '10.9.4-MAVERICKS-x64'
        user_agent = "DESKTOP:MAC:#{os_version}(#{version})"
        app = "DESKTOPMAC\t#{version}\tMAC\t\t#{os_version}"

        hostname = Socket.gethostname()
        @ip = IPSocket.getaddress(Socket.gethostbyname(hostname).first)

        @headers = {
          'User-Agent' => user_agent,
          'X-Line-Application' => app
        }

        @agent = Mechanize.new
        @agent.request_headers = @headers

        # close exists transport
        @transport.close unless @transport.nil?

        @transport = Thrift::HTTPClientTransport.new(LineService::LINE_HTTP_URL)
        @transport.add_headers(@headers)

        # this code is not useful any more
        @transport = Thrift::BufferedTransport.new(@transport)
        @protocol = Thrift::CompactProtocol.new(@transport)
        @client = TalkService::Client.new(@protocol)

        @transport.open

        @options = {
          :retries => 5,
          :protocol => Thrift::CompactProtocol,
          :transport => Thrift::HTTPClientTransport
        }

        @transport_in = nil
        @client_in = nil
      end

      def login_token
        logger.info("Trying to log in with given credentials")
        @headers['X-Line-Access'] = @cert

        @transport.close unless @transport.nil?
        @client_in.close unless @client_in.nil?

        # close existing transport
        @transport = Thrift::HTTPClientTransport.new(LineService::LINE_HTTP_URL)
        @transport.add_headers(@headers)

        # this code is not useful any more
        @transport = Thrift::BufferedTransport.new(@transport)
        
        # make new cli
        @protocol = Thrift::CompactProtocol.new(@transport)
        @client = TalkService::Client.new(@protocol)

        @transport.open
        @revision = @client.getLastOpRevision() if @revision == 0

        @client_in = ThriftClient.new(TalkService::Client, LineService::LINE_HTTP_IN_URL, @options)
        @client_in.connect!
        @transport_in = @client_in.current_server.connection.transport
        @transport_in.add_headers(@headers)

        logger.info("Revision is #{@revision}")
      end

      def login()
        logger.info("Trying to log in with given username and password")
        @headers.delete('X-Line-Access')
        json = JSON.parse(@agent.get(LineService::LINE_SESSION_LINE_URL).body)
        data = OpenStruct.new(json)
        
        passphrase = data.session_key.size.chr + data.session_key + \
                     @user.size.chr + @user + @pass.size.chr + @pass
        rsa = data.rsa_key.split(',')
        keyname, n, e = rsa[0], rsa[1].hex, rsa[2].hex
        pub = OpenSSL::PKey::RSA.new
        pub.n = n
        pub.e = e
        cipher = pub.public_encrypt(passphrase).unpack('H*').first

        msg = @client.loginWithIdentityCredentialForCertificate(
          @user, @pass, keyname, cipher, true, @ip, @name, @provider, '')
        case msg.type
        when LoginResultType::SUCCESS
          @cert = msg.authToken
          self.login_token()
        when LoginResultType::REQUIRE_DEVICE_CONFIRM
          puts "Input following code on your mobile LINE app in 2 minutes: #{msg.auth_digit}"

          @headers['X-Line-Access'] = msg.verifier
          @agent.request_headers = @headers
          data = JSON.parse(agent.get(LINE_CERTIFICATE_URL).body)
          verifier = data['result']['verifier']

          begin
            msg = @client.loginWithVerifierForCertificate(verifier)
          rescue
            logger.error("Failed")
          ensure
            @cert = msg.authToken
            self.login_token()
          end
        else
          logger.error("Maybe there is something wrong during the authentication")
        end
      end

      def revive
        if @cert
          logger.debug("Trying to revive to continuously")
          self.login()
          self.login_token()
        else
          raise "You need to login first"
        end

        true
      end

      def start!
        EM.next_tick { handle_message }
        EM.next_tick { handle_ops }
        loop do
          begin
            ops = @client_in.fetchOperations(@revision, 50)
          rescue SystemExit, Interrupt
            break
          rescue Net::ReadTimeout => e
            logger.debug("Timeout occurred while waiting for a operation")
            next
          rescue Exception => e
            p e
            self.revive()
          end

          next if ops.nil?

          ops.each do |op|
            logger.debug("A new operation is retrieved: #{op.inspect}")
            case op.type
            when OpType::END_OF_OPERATION
            when OpType::ADD_CONTACT
            when OpType::BLOCK_CONTACT
            when OpType::NOTIFIED_READ_MESSAGE
            when OpType::SEND_CHAT_CHECKED
            when OpType::LEAVE_ROOM
            when OpType::LEAVE_GROUP
            when OpType::NOTIFIED_UPDATE_PROFILE
              @ops << op
            when OpType::NOTIFIED_UPDATE_GROUP
              @ops << op
            when OpType::NOTIFIED_INVITE_INTO_ROOM
            when OpType::SEND_MESSAGE
            when OpType::RECEIVE_MESSAGE
              if msg = op.message
                @bot.messages << LlamaMessage.new(self, msg)
                @ops << op
              end
            end

            @revision = op.revision if op.revision > @revision
          end
        end
      end

      def handle_ops
        handler = Proc.new do |op|
          case op.type
          when OpType::RECEIVE_MESSAGE
            target = case op.message.toType
            when ToType::USER
              op.message.from
            when ToType::ROOM, ToType::GROUP
              op.message.to
            end
            send_checked(target, op.message.id)

          when OpType::NOTIFIED_UPDATE_PROFILE
            if id = op.param1
              user = @client.getContacts([id]).first
              if user and current = @contacts.find { |c| c.id == id }
                current.name = user.displayName
                current.status_message = user.statusMessage
              end
            end

          when OpType::NOTIFIED_UPDATE_GROUP
            if id = op.param1
              group = @client.getGroup(id)
              if group and current = @groups.find { |g| g.id == id }
                current.name = group.name
              end
            end
          end
          EM.next_tick { @ops.pop(&handler) }
        end
        @ops.pop(&handler)
      end

      def handle_message
        sender = Proc.new do |bl|
          res = _send_message(bl.msg)
          bl.cb.call(res) unless bl.cb.nil?
          EM.next_tick { @queue.pop(&sender) }
        end
        @queue.pop(&sender)
      end

      MessageBlock = Struct.new(:msg, :cb)
      def send_message(msg, &cb)
        @queue << MessageBlock.new(msg, cb)
      end
    end
  end
end
