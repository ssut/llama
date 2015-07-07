require 'date'

module Llama
  class LlamaMessage
    # @return [String]
    attr_reader :raw

    attr_reader :id

    # @return [Time]
    attr_reader :time

    # @return [User] The user who sent this message
    attr_reader :user

    attr_reader :raw_target, :target

    # @return [Room] The room in which this message was sent
    attr_reader :room

    attr_reader :content_type

    attr_accessor :checked

    def initialize(service, msg)
      @service = service

      @msg = msg
      @id = msg.id
      @raw = msg.text ? msg.text : ''
      @time = DateTime.strptime((msg.createdTime / 1000).to_s, '%s')
      @type = msg.toType
      @has_content = false
      @content_type = case msg.contentType
      when ContentType::NONE
        :text
      when ContentType::IMAGE
        @has_content = true
        :image
      when ContentType::VIDEO
        @has_content = true
        :video
      when ContentType::AUDIO
        @has_content = true
        :audio
      when ContentType::STICKER
        :sticker
      end
      @content_preview = msg.contentPreview
      @content_metadata = msg.contentMetadata

      @raw_sender = msg.from
      @raw_receiver = msg.to
      @sender = service.get_anything_by_id(msg.from)
      @receiver = service.get_anything_by_id(msg.to)

      @checked = false

      # If sender is not found, check member list of group chat sent to
      if (@sender.nil? and @receiver.class.to_s.include?('LineGroup')) or 
         (@sender.nil? and @receiver.class.to_s.include?('LineRoom')) then
        sender = @service.contacts.find { |m| m.id == @raw_sender }
        @sender = sender unless sender.nil?
      end

      if @sender.nil? or @receiver.nil?
        @service.refresh_contacts()
        @service.refresh_groups()
        @service.refresh_rooms()

        @sender = service.get_anything_by_id(msg.from)
        @receiver = service.get_anything_by_id(msg.to)
      end

      # still one is nil
      if @sender.nil? or @receiver.nil?
        contacts = @service.get_contacts([@raw_sender, @raw_receiver])
        if contacts and contacts.size == 2
          @sender = Llama::Line::LineContact(@service, contacts[0])
          @receiver = Llama::Line::LineContact(@service, contacts[1])
        end
      end

      # message target
      @target = case @type
      when ToType::USER
        @user = @sender
        @room = @sender
        @sender
      when ToType::ROOM, ToType::GROUP
        @user = @sender
        @room = @receiver
        @receiver
      end
      @raw_target = @target.nil? ? '' : @target.id
    end

    def reply_user(type, content, &cb)
      @user ? self.reply(type, content, @user, &cb) : false
    end

    def reply(type, content, target=nil, &cb)
      target = @target if target.nil?
      if type == :text
        result = target.send_message(content, self)
      elsif type == :sticker
        result = target.send_sticker(*content, self)
      elsif type == :image
        method = content.include?('http') ? target.method(:send_image_url) : target.method(:send_image)
        method.call(content, self, &cb)
      end
    end

    def has_content?
      @msg.hasContent
    end

    def sticker
      return false unless @content_type == :sticker

      id = @content_metadata['STKID'].to_i
      version = @content_metadata['STKVER'].to_i
      ver = [(version / 1000000.0).floor, (version / 1000.0).floor, version % 1000].join('/')
      package = @content_metadata['STKPKGID'].to_i
      url = "http://dl.stickershop.line.naver.jp/products/#{ver}/#{package}/PC/stickers/#{id}.png"
      {
        "id" => id,
        "version" => version,
        "package" => package,
        "url" => url
      }
    end

    def download_content(&callback)
      callback.call(false, nil) if not @has_content and not callback.nil?
      url = "http://os.line.naver.jp/os/m/#{@id}"

      begin
        headers = @service.headers
        http = EM::HttpRequest.new(url, :connect_timeout => 3, :inactivity_timeout => 10).get(:head => headers)
        file = Tempfile.new(['image', '.jpg'])
        http.stream { |chunk|
          file.write(chunk)
        }
        http.callback {
          file.close
          callback.call(true, file)
        }
      rescue Exception => e
        callback.call(false, nil) unless callback.nil?
      end
    end
  end
end