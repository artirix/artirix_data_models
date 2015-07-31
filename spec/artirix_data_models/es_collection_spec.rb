require 'spec_helper'

RSpec.describe ArtirixDataModels::EsCollection, type: :model do

  describe "with an ES response" do

    Given(:model_class){
      Class.new do
        attr_reader :data

        def initialize(data)
          @data = { given: data }
        end
      end
    }
    Given(:es_response){ ArtirixDataModels::EsCollection::EMPTY_RESPONSE }

    When(:es_collection){ ArtirixDataModels::EsCollection.new(model_class, response: es_response) }

    Then { es_collection.total == 0 }
    Then { es_collection.results == [] }
  end

  describe "coerced from an array" do

    Given(:model_class){
      Class.new do
        attr_reader :number

        def initialize(number)
          @number = number
        end
      end
    }

    Given(:results_array){ [model_class.new(1), model_class.new(2), model_class.new(3)] }

    When(:es_collection){ ArtirixDataModels::EsCollection.from_array(results_array) }

    Then { es_collection.total == 3 }
    Then { es_collection.results == results_array }
    Then { es_collection.aggregations == [] }
  end

end
