require 'active_support/core_ext/hash'

module Llama
  module EmbedPlugin
    class GoogleImagesPlugin
      include Llama::Plugin
      match '짤', :help
      match /^(.+) 짤/
      match /^(.+) 사진/

      def random_ip
        '121.170.' + Array.new(2){rand(256)}.join('.') # south korea ip addrs
      end

      def help(msg, captures)
        msg.reply(:text, '구글 이미지 검색')
      end

      def fail(msg)
        msg.reply(:text, '이미지를 다운받지 못했습니다.')
      end

      def execute(msg, captures)
        query = {
          start: (rand(5) + 1).to_s,
          rsz: '8',
          v: '1.0',
          ipaddr: self.random_ip,
          safe: 'off',
          imgsz: 'small|medium|large',
          q: captures.join
        }
        url = 'http://ajax.googleapis.com/ajax/services/search/images?' + query.to_query

        resp = Net::HTTP.get_response(URI.parse(url))
        result = JSON.parse(resp.body)
        return self.fail(msg) if result.nil?

        response_data = result['responseData']
        return self.fail(msg) if response_data.nil?

        result_size = response_data['results'].count
        return self.fail(msg) unless result_size > 0
        url = result['responseData']['results'][rand(result_size)]['url']

        msg.reply(:image, url) do |success, _|
          fail(msg) unless success
        end
      end
    end
  end
end
