module Llama
  module Utils
    def class_from_string(str)
      str.split('::').inject(Object) do |mod, class_name|
        mod.const_get(class_name)
      end
    end
    module_function :class_from_string
  end
end