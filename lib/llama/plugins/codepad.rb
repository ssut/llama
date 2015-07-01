require 'mechanize'

module Llama
  module EmbedPlugin
    class CodepadPlugin
      include Llama::Plugin
      match /^codepad (?<lang>[\w]+) (?<code>.+)/

      TYPES = {
        'c' => 'C',
        'cpp' => 'C++',
        'd' => 'D',
        'haskell' => 'Haskell',
        'lua' => 'Lua',
        'ocaml' => 'OCaml',
        'php' => 'PHP',
        'perl' => 'Perl',
        'python' => 'Python',
        'py' => 'Python',
        'ruby' => 'Ruby',
        'rb' => 'Ruby',
        'scheme' => 'Scheme',
        'tcl' => 'Tcl'
      }

      def init
        @agent = Mechanize.new
      end

      def fail(msg, e)
        msg.reply(:text, '코드를 실행하지 못했습니다: ' + e.inspect)
      end

      def execute(msg, captures)
        lang, code = captures
        msg.reply(:text, '지원하지 않는 언어입니다.') unless TYPES.include?(lang)

        data = {
          code: code,
          lang: TYPES[lang],
          submit: 'Submit',
          run: 'True'
        }
        begin
          res = @agent.post('http://codepad.org', data)
          result = res.body
          raise unless result.include?('<pre>')
          result = result.split('<a name="output">')[1].split('<pre>')[2].split('</pre>')[0]
        rescue Exception => e
          return self.fail(msg, e)
        end
        result = result.gsub('&lt;', '<').gsub('&gt;', '>')
        result += "\n(#{res.uri.to_s})"

        msg.reply(:text, result)
      end
    end
  end
end
