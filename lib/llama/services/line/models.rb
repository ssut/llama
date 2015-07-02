require 'open-uri'

# Don't allow downloaded files to be created as StringIO. Force a tempfile to be created.
# http://stackoverflow.com/q/10496874
OpenURI::Buffer.send :remove_const, 'StringMax' if OpenURI::Buffer.const_defined?('StringMax')
OpenURI::Buffer.const_set 'StringMax', 0

module Llama
  module Line
    class LineBase
      include Llama::Utils
      attr_reader :service
      attr_reader :id

      def send_message(text)
        begin
          message = Message.new(to: @id, text: text)
          message = @service.send_message(message)
        rescue Exception => e
          raise e
        end

        message
      end

      def send_sticker(id='13', package='1', version='100', text='[null]')
        begin
          message = Message.new(to: @id, text: '')
          message.contentType = ContentType::STICKER

          message.contentMetadata = {
            'STKID' => id,
            'STKPKGID' => package,
            'STKVER' => version,
            'STKTXT' => text
          }
          @service.send_message(message)
        rescue Exception => e
          raise e
        end

        true
      end

      def send_image(path)
        message = Message.new(to: @id, text: nil)
        message.contentType = ContentType::IMAGE
        message.contentPreview = nil
        message.contentMetadata = nil

        @service.send_message(message) do |msg|
          msg_id = msg.id
          params = {
            'name' => 'media',
            'oid' => msg_id,
            'size' => File.size(path),
            'type' => 'image',
            'ver' => '1.0'
          }
          data = {
            'params' => JSON.dump(params),
            :file => UploadIO.new(File.open(path), 'image/jpeg')
          }

          'http://os.line.naver.jp/talk/m/upload.nhn'.to_uri.post_multipart_async(data, @service.headers) do |cb|
            cb.on(200..201) do |resp|
            end
          end
        end

        true
      end

      def send_image_url(url)
        begin
          f = open(url, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE, read_timeout: 5})
        rescue
          return false
        end

        self.send_image(f.path)
      end
    end

    class LineGroup < LineBase
      attr_reader :name
      attr_reader :is_joined
      attr_reader :creator
      attr_reader :members
      attr_reader :invitee

      def initialize(service, group=nil, is_joined=true)
        @service = service
        @group = group
        @id = group.id
        @name = group.name

        @is_joined = is_joined

        begin
          @creator = LineContact.new(service, group.creator)
        rescue
          @creator = nil
        end

        @members = []
        @invitee = []
        group.members.each { |m| @members << LineContact.new(service, m) } unless group.members.nil?
        group.invitee.each { |m| @invitee << LineContact.new(service, m) } unless group.invitee.nil?
      end

      def accept_group_invitation
        result = false
        unless @is_joined
          @service.client.acceptGroupInvitation(self)
        end

        result
      end

      def leave
        result = false
        if @is_joined
          begin
            @service.client.leaveGroup(self)
          rescue
          end
        end

        result
      end

      def get_member_ids
        @members.map { |m| m.id }
      end

      def to_s
        "<LineGroup #{@name}(#{@id}) members=#{@members.size}>"
      end
    end

    class LineRoom < LineBase
      attr_reader :room

      attr_reader :name

      def initialize(service, room)
        @service = service

        @room = room
        @name = ''
        @id = room.mid

        @contacts = []
        room.contacts.each { |c| @contacts << LineContact.new(service, c) }
      end

      def leave
        result = false
        begin
          @service.client.leaveRoom(self)
        rescue
        end

        result
      end

      def get_contact_ids
        @contacts.map { |c| c.id }
      end

      def to_s
        "<LineRoom #{@id} contacts=#{@contacts.size}>"
      end
    end

    class LineContact < LineBase
      attr_reader :contact

      attr_reader :name
      attr_reader :status_message

      def initialize(service, contact)
        @service = service

        @contact = contact
        @id = contact.mid
        @name = contact.displayName
        @status_message = contact.statusMessage

        service.contacts << self unless service.contacts.include?(self)
      end

      def reload!
        begin
        info = @service.client.getContacts([@id]).first
        if info
          @name = info.displayName
          @status_message = info.statusMessage
        end
        rescue
        end
      end

      def profile_image
        "#http://dl.profile.line.naver.jp{@contact.picturePath}"
      end

      def rooms
        @service.rooms.delete_if { |r| not r.get_contact_ids.include?(@id) }
      end

      def groups
        @service.groups.delete_if { |g| not g.get_member_ids.include?(@id) }
      end

      def to_s
        "<LineContact #{@name}(#{@id}) status=#{@status_message}>"
      end
    end
  end
end
