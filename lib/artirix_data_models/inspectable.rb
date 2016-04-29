module ArtirixDataModels
  module Inspectable
    SPACE = ' '.freeze

    def inspect
      inspect_with_tab 1
    end

    def data_hash_for_inspect
      data_hash
    end

    def inspect_with_tab(tab_level = 0)
      insp = data_hash_for_inspect.map do |at, val|
        tab = SPACE * tab_level * 4

        if val.kind_of? Array
          nested = val.map do |vi|
            nested_tab = SPACE * (tab_level + 1) * 4
            nv         = vi.try(:inspect_with_tab, tab_level + 2) || val.inspect
            "#{nested_tab} - #{nv}"
          end

          "#{tab} - #{at}: [\n#{nested.join("\n")}\n#{tab}   ]"

        else
          v = val.try(:inspect_with_tab, tab_level + 1) || val.inspect
          "#{tab} - #{at}: #{v}"
        end
      end
      "#<#{self.class}\n#{insp.join("\n")}>"
    end
  end
end