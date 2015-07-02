require 'mechanize'

module Llama
  module EmbedPlugin
    class CodepadPlugin
      include Llama::Plugin
      include Llama::Utils
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


      def fail(msg)
        msg.reply(:text, '코드를 실행하지 못했습니다.')
      end

      def execute(msg, captures)
        lang, code = captures
        msg.reply(:text, '지원하지 않는 언어입니다.') unless TYPES.include?(lang)

        data = {
          'code' => code,
          'lang' => TYPES[lang],
          'submit' => 'Submit',
          'run' => 'True'
        }
        HTTP::Request.new('http://codepad.org', data, 'post').call(Proc.new { |resp|
          begin
            result = resp.body
            raise unless result.include?('<pre>')
            result = result.split('<a name="output">')[1].split('<pre>')[2].split('</pre>')[0]
            result = result.gsub('&lt;', '<').gsub('&gt;', '>')
            result += "\n(#{resp.url})"
          rescue Exception => e
            fail(msg)
          else
            msg.reply(:text, result)
          end
        }) { |e|
          fail(msg)
        }
      end
    end
  end
end
