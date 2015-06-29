lib = File.join(File.dirname(__FILE__), 'thrift')
$:.unshift lib unless $:.include?(lib)

require 'thrift'
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
      attr_reader :bot

      attr_reader :client
      attr_reader :agent

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

        @user = conf.username
        @pass = conf.password

        version = '4.0.3'
        os_version = '10.9.4-MAVERICKS-x64'
        user_agent = "DESKTOP:MAC:#{os_version}(#{version})"
        app = "DESKTOPMAC\t#{version}\tMAC\t\t#{os_version}"

        hostname = Socket.gethostname()
        @ip = IPSocket.getaddress(Socket.gethostbyname(hostname).first)
        @name = conf.name

        @headers = {
          'User-Agent' => user_agent,
          'X-Line-Application' => app
        }

        @agent = Mechanize.new
        @agent.request_headers = @headers

        @transport = Thrift::HTTPClientTransport.new(LineService::LINE_HTTP_URL)
        @transport.add_headers(@headers)

        # this code is not useful any more
        # @transport = Thrift::BufferedTransport.new(@transport)
        @protocol = Thrift::CompactProtocol.new(@transport)
        @client = TalkService::Client.new(@protocol)

        @transport_in = nil
        @protocol_in = nil
        @client_in = nil

        if conf.auth_token
          @cert = conf.auth_token
          self.login_token()
        else
          @provider = IdentityProvider::LINE
          self.login()
        end

        self.get_profile()

        begin; self.refresh_groups(); rescue; end
        begin; self.refresh_contacts(); rescue; end
        begin; self.refresh_rooms(); rescue; end
      end

      def login_token()
        @headers['X-Line-Access'] = @cert

        # close exists transport
        @transport.close

        # make new transport layer
        @transport = Thrift::HTTPClientTransport.new(LineService::LINE_HTTP_URL)
        @transport_in = Thrift::HTTPClientTransport.new(LineService::LINE_HTTP_IN_URL)
        # reset headers
        @transport_in.add_headers(@headers)
        @transport.add_headers(@headers)
        # make protocol
        @protocol = Thrift::CompactProtocol.new(@transport)
        @protocol_in = Thrift::CompactProtocol.new(@transport_in)
        # finally make client
        @client = TalkService::Client.new(@protocol)
        @client_in = TalkService::Client.new(@protocol_in)
        # open
        @transport.open
        @transport_in.open

        @revision = @client.getLastOpRevision() if @revision == 0
      end

      def login()
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
            puts "wrong"
          ensure
            @cert = msg.authToken
            self.login_token()
          end
        else
          puts 'something wrong'
        end
      end

      def revive
        if @cert
          self.login()
          self.login_token()
        else
          raise 'You need to login first'
        end

        true
      end

      def start
        loop do
          begin
            ops = @client_in.fetchOperations(@revision, 100)
          rescue
            self.revive()
          end

          if ops.nil?
            p 'next'
            next
          end
          ops.each do |op|
            p op
            case op.type
            when OpType::END_OF_OPERATION
            when OpType::ADD_CONTACT
            when OpType::BLOCK_CONTACT
            when OpType::NOTIFIED_READ_MESSAGE
            when OpType::SEND_CHAT_CHECKED
            when OpType::LEAVE_ROOM
            when OpType::LEAVE_GROUP
            when OpType::SEND_MESSAGE
            when OpType::RECEIVE_MESSAGE
              self.handle_message(op)
            end

            @revision = op.revision if op.revision > @revision
          end
        end
      end

      def handle_message(op)
        if msg = op.message
          msg = LlamaMessage.new(self, msg)
          @bot.listeners.dispatch(:message, msg)
        end
      end
    end
  end
end
