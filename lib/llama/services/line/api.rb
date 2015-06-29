require 'llama/services/line/models'

module Llama
  module Line
    class LineAPI
      attr_reader :client

      attr_reader :profile
      attr_reader :contacts
      attr_reader :rooms
      attr_reader :groups

      def initialize
        raise 'This class cannot be used directly.'
      end

      def send_message(message, seq=0)
        begin
          return @client.sendMessage(seq, message)
        rescue TalkException => e
          self.revive()
          begin
            return @client.sendMessage(seq, message)
          rescue Exception => e
            puts "send error"
            return false
          end
        end
      end

      def get_profile
        profile = self.client.getProfile()
        @profile = LineContact.new(self, profile)
      end

      def get_contact_by_name(name)
        find = @contacts.select { |c| c.name == name }
        find.first
      end

      def get_contact_by_id(id)
        if @profile
          return @profile if @profile.id == id
        end

        find = @contacts.select { |c| c.id == id }
        find.first
      end

      def get_room_by_id(id)
        find = @rooms.select { |r| r.id == id }
        find.first
      end

      def get_group_by_id(id)
        find = @groups.select { |g| g.id == id }
        find.first
      end

      def get_anything_by_id(id)
        self.get_contact_by_id(id) or self.get_room_by_id(id) or self.get_group_by_id(id)
      end

      def refresh_groups
        @groups = []

        # fetch all groups
        joined = @client.getGroupIdsJoined()
        joined = @client.getGroups(joined)
        invited = @client.getGroupIdsInvited()
        invited = @client.getGroups(invited)

        joined.each { |g| @groups << LineGroup.new(self, g, true) }
        invited.each { |g| @groups << LineGroup.new(self, g, false) }
      end

      def refresh_contacts
        @contacts = []
        
        # fetch all contacts
        contact_ids = @client.getAllContactIds()
        contacts = @client.getContacts(contact_ids)

        contacts.each { |c| @contacts << LineContact.new(self, c) }
      end

      def refresh_rooms
        start, count = 1, 50
        @rooms = []

        loop do
          channel = @client.getMessageBoxCompactWrapUpList(start, count)
          channel.messageBoxWrapUpList.each do |box|
            if box.messageBox.midType == ToType::ROOM
              room = @client.getRoom(box.messageBox.id)
              @rooms << LineRoom.new(self, room)
            end
          end

          if channel.messageBoxWrapUpList.size == count
            start += count
          else
            break
          end
        end
      end
    end
  end
end