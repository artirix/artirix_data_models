module ArtirixDataModels
  module Inspectable
    def inspect
      inspect_with_tab 1
    end

    def data_hash_for_inspect
      data_hash
    end

    def inspect_with_tab(tab_level = 0)
      insp = data_hash_for_inspect.map do |at, val|
        v   = val.try(:inspect_with_tab, tab_level + 1) || val.inspect
        tab = ' ' * tab_level * 4
        "#{tab} - #{at}: #{v}"
      end
      "#<#{self.class} \n#{insp.join("\n")}>"
    end
  end
end