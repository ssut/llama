module Llama
  module Line
    class LineBase
      include Llama::Utils
      attr_reader :service
      attr_reader :id

      def send_message(text, refer)
        begin
          message = Message.new(to: @id, text: text)
          message = @service.send_message(message, refer)
        rescue Exception => e
          raise e
        end

        message
      end

      def send_sticker(id='13', package='1', version='100', text='[null]', refer)
        begin
          message = Message.new(to: @id, text: '')
          message.contentType = ContentType::STICKER

          message.contentMetadata = {
            'STKID' => id,
            'STKPKGID' => package,
            'STKVER' => version,
            'STKTXT' => text
          }
          @service.send_message(message, refer)
        rescue Exception => e
          raise e
        end

        true
      end

      def send_image(path, refer, &callback)
        message = Message.new(to: @id, text: nil)
        message.contentType = ContentType::IMAGE
        message.contentPreview = nil
        message.contentMetadata = nil

        @service.send_message(message, refer) do |msg|
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
              callback.call(true, msg) unless callback.nil?
            end
          end
        end
      end

      def send_image_url(url, refer, &cb)
        begin
          http = EM::HttpRequest.new(url, :connect_timeout => 2, :inactivity_timeout => 5).get
          file = Tempfile.new('')
          http.stream { |chunk|
            file.write(chunk)
          }
          http.callback {
            file.close
            type = FastImage.type(file.path)
            if %i(jpeg png gif).include?(type)
              self.send_image(file.path, refer, &cb)
            else
              cb.call(false) unless cb.nil?
            end
          }
        rescue Exception => e
          return false
        end
        true
      end
    end

    class LineGroup < LineBase
      attr_accessor :name
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

      attr_accessor :name
      attr_accessor :status_message

      def initialize(service, contact)
        @service = service

        @contact = contact
        @id = contact.mid
        @name = contact.displayName
        @status_message = contact.statusMessage

        service.contacts << self unless service.contacts.include?(self)
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
