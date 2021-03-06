require 'spec_helper'

RSpec.describe ArtirixDataModels::EsCollection, type: :model do

  describe "with an ES response" do

    Given(:model_class) {
      Class.new do
        attr_reader :data

        def initialize(data)
          @data = { given: data }
        end
      end
    }
    Given(:es_response) { ArtirixDataModels::EsCollection::EMPTY_RESPONSE }

    When(:es_collection) { ArtirixDataModels::EsCollection.new(model_class, response: es_response) }

    Then { es_collection.total == 0 }
    Then { es_collection.results == [] }
  end

  describe "coerced from an array" do

    Given(:model_class) {
      Class.new do
        attr_reader :number

        def initialize(number)
          @number = number
        end
      end
    }

    Given(:results_array) { [model_class.new(1), model_class.new(2), model_class.new(3)] }

    When(:es_collection) { ArtirixDataModels::EsCollection.from_array(results_array) }

    Then { es_collection.total == 3 }
    Then { es_collection.results == results_array }
    Then { es_collection.aggregations == [] }

    # :first, :drop, :take, :last, :[], :each, :present?, :blank?, to: :results
    Then { !es_collection.blank? }
    Then { es_collection.present? }
    Then { es_collection[1] == results_array[1] }
    Then { es_collection.first == results_array.first }
    Then { es_collection.last == results_array.last }
    Then { es_collection.take(2) == results_array.take(2) }
    Then { es_collection.drop(2) == results_array.drop(2) }
  end

  describe 'aggregations' do

    Given(:model_class) do
      Class.new do
        attr_reader :data

        def initialize(data)
          @data = { given: data }
        end
      end
    end

    Given(:es_response) { Oj.load(File.read(fixture_file), symbol_keys: true) }

    context 'with Data Layer conversion into array' do
      Given(:fixture_file) { fixture_pathname('articles_search_dl.json') }

      When(:es_collection) { ArtirixDataModels::EsCollection.new(model_class, response: es_response) }

      Then { es_collection.total == 11477 }
      Then { es_collection.results == [] }

      Then { es_collection.aggregations.size == 2 }

      Then { es_collection.aggregations.first.name == :primary_category_slug }
      Then { es_collection.aggregations.first.buckets.size == 10 }
      Then { es_collection.aggregations.first.buckets.first.name == 'yacht-market-intelligence' }
      Then { es_collection.aggregations.first.buckets.first.count == 7794 }
      Then { es_collection.aggregations.first.buckets.last.name == 'brokerage' }
      Then { es_collection.aggregations.first.buckets.last.count == 7 }

      Then { es_collection.aggregations.last.name == :location_slug }
      Then { es_collection.aggregations.last.buckets.size == 10 }
      Then { es_collection.aggregations.last.buckets.first.name == 'americas' }
      Then { es_collection.aggregations.last.buckets.first.count == 3 }
      Then { es_collection.aggregations.last.buckets.last.name == 'italy' }
      Then { es_collection.aggregations.last.buckets.last.count == 1 }
    end

    context 'with Raw ES with single aggregation' do
      Given(:fixture_file) { fixture_pathname('articles_search_raw_es.json') }

      When(:es_collection) { ArtirixDataModels::EsCollection.new(model_class, response: es_response) }

      Then { es_collection.total == 14974 }
      Then { es_collection.results == [] }

      Then { es_collection.aggregations.size == 1 }

      Then { es_collection.aggregations.first.name == :disease_slug }
      Then { es_collection.aggregations.first.buckets.size == 6 }
      Then { es_collection.aggregations.first.buckets.first.name == 'sickle-cell-anemia' }
      Then { es_collection.aggregations.first.buckets.first.count == 5754 }
      Then { es_collection.aggregations.first.buckets.last.name == 'fabry-disease' }
      Then { es_collection.aggregations.first.buckets.last.count == 742 }
    end

    context 'with Raw ES with single nested aggregation' do
      Given(:fixture_file) { fixture_pathname('articles_search_nested_single_raw_es.json') }

      When(:es_collection) { ArtirixDataModels::EsCollection.new(model_class, response: es_response) }

      Then { es_collection.total == 11492 }
      Then { es_collection.results == [] }

      Then { es_collection.aggregations.size == 2 }

      Then { es_collection.aggregations.first.name == :category_slug }
      Then { es_collection.aggregations.first.buckets.size == 24 }
      Then { es_collection.aggregations.first.buckets.first.name == 'brokerage-sales-news' }
      Then { es_collection.aggregations.first.buckets.first.count == 7792 }
      Then { es_collection.aggregations.first.buckets.last.name == 'why-charter-a-superyacht' }
      Then { es_collection.aggregations.first.buckets.last.count == 1 }

      Then { es_collection.aggregations.last.name == :location_slug }
      Then { es_collection.aggregations.last.buckets.size == 19 }
      Then { es_collection.aggregations.last.buckets.first.name == 'americas' }
      Then { es_collection.aggregations.last.buckets.first.count == 4 }
      Then { es_collection.aggregations.last.buckets.last.name == 'tahiti' }
      Then { es_collection.aggregations.last.buckets.last.count == 1 }
    end

    context 'with Raw ES with nested aggregations' do
      Given(:fixture_file) { fixture_pathname('articles_search_nested_raw_es.json') }

      Given(:model_class) {
        Class.new do
          attr_reader :data

          def initialize(data)
            @data = { given: data }
          end
        end
      }
      Given(:es_response) { Oj.load(File.read(fixture_file), symbol_keys: true) }

      When(:es_collection) { ArtirixDataModels::EsCollection.new(model_class, response: es_response) }

      Then { es_collection.total == 4512 }
      Then { es_collection.results == [] }

      Then { es_collection.aggregations.size == 1 }

      Then { es_collection.aggregations.first.name == :level1_taxonomy }
      Then { es_collection.aggregations.first.buckets.size == 4 }

      Then { es_collection.aggregations.first.buckets.first.name == 'Treatment' }
      Then { es_collection.aggregations.first.buckets.first.count == 2404 }
      Then { es_collection.aggregations.first.buckets.first.aggregations.size == 1 }
      Then { es_collection.aggregations.first.buckets.first.aggregations.first.name == :level2_taxonomy }
      Then { es_collection.aggregations.first.buckets.first.aggregations.first.buckets.size == 7 }
      Then { es_collection.aggregations.first.buckets.first.aggregations.first.buckets.first.name == 'Drug Treatments' }
      Then { es_collection.aggregations.first.buckets.first.aggregations.first.buckets.first.count == 977 }
      Then { es_collection.aggregations.first.buckets.first.aggregations.first.buckets.last.name == 'Complementary and Alternative Therapies' }
      Then { es_collection.aggregations.first.buckets.first.aggregations.first.buckets.last.count == 14 }


      Then { es_collection.aggregations.first.buckets.last.name == 'Living' }
      Then { es_collection.aggregations.first.buckets.last.count == 365 }
      Then { es_collection.aggregations.first.buckets.last.aggregations.size == 1 }
      Then { es_collection.aggregations.first.buckets.last.aggregations.first.name == :level2_taxonomy }
      Then { es_collection.aggregations.first.buckets.last.aggregations.first.buckets.size == 8 }
      Then { es_collection.aggregations.first.buckets.last.aggregations.first.buckets.first.name == 'Emotional Impact' }
      Then { es_collection.aggregations.first.buckets.last.aggregations.first.buckets.first.count == 104 }
      Then { es_collection.aggregations.first.buckets.last.aggregations.first.buckets.last.name == 'Cognitive Impact' }
      Then { es_collection.aggregations.first.buckets.last.aggregations.first.buckets.last.count == 3 }
    end

    context 'with Raw ES with multiple nested aggregations' do
      Given(:fixture_file) { fixture_pathname('articles_search_multiple_nested_raw_es.json') }

      Given(:model_class) do
        Class.new do
          attr_reader :data

          def initialize(data)
            @data = { given: data }
          end
        end
      end
      Given(:es_response) { Oj.load(File.read(fixture_file), symbol_keys: true) }

      When(:es_collection) { ArtirixDataModels::EsCollection.new(model_class, response: es_response) }

      Then { es_collection.total == 1234 }
      Then { es_collection.results == [] }

      Then { es_collection.aggregations.size == 2 }

      Then { es_collection.aggregations.first.name == :publication_types }
      Then { es_collection.aggregations.first.buckets.size == 8 }

      Then { es_collection.aggregations.first.buckets.first.name == 'Expert Opinion' }
      Then { es_collection.aggregations.first.buckets.first.count == 1798 }
      Then { es_collection.aggregations.first.buckets.last.name == 'Guidelines' }
      Then { es_collection.aggregations.first.buckets.last.count == 33 }


      Then { es_collection.aggregations.last.name == :taxonomy_level_1 }
      Then { es_collection.aggregations.last.buckets.size == 4 }

      Then { es_collection.aggregations.last.buckets.first.name == 'Treatment' }
      Then { es_collection.aggregations.last.buckets.first.count == 2404 }
      Then { es_collection.aggregations.last.buckets.first.aggregations.size == 1 }
      Then { es_collection.aggregations.last.buckets.first.aggregations.first.name == :taxonomy_level_2 }
      Then { es_collection.aggregations.last.buckets.first.aggregations.first.buckets.size == 7 }
      Then { es_collection.aggregations.last.buckets.first.aggregations.first.buckets.first.name == 'Drug Treatments' }
      Then { es_collection.aggregations.last.buckets.first.aggregations.first.buckets.first.count == 977 }
      Then { es_collection.aggregations.last.buckets.first.aggregations.first.buckets.last.name == 'Complementary and Alternative Therapies' }
      Then { es_collection.aggregations.last.buckets.first.aggregations.first.buckets.last.count == 14 }


      Then { es_collection.aggregations.last.buckets.last.name == 'Living' }
      Then { es_collection.aggregations.last.buckets.last.count == 365 }
      Then { es_collection.aggregations.last.buckets.last.aggregations.size == 1 }
      Then { es_collection.aggregations.last.buckets.last.aggregations.first.name == :taxonomy_level_2 }
      Then { es_collection.aggregations.last.buckets.last.aggregations.first.buckets.size == 8 }
      Then { es_collection.aggregations.last.buckets.last.aggregations.first.buckets.first.name == 'Emotional Impact' }
      Then { es_collection.aggregations.last.buckets.last.aggregations.first.buckets.first.count == 104 }
      Then { es_collection.aggregations.last.buckets.last.aggregations.first.buckets.last.name == 'Cognitive Impact' }
      Then { es_collection.aggregations.last.buckets.last.aggregations.first.buckets.last.count == 3 }
    end

    context 'with nested aggregations of single doc_count' do
      Given(:fixture_file) { fixture_pathname('editorial_content_search_dl.json') }

      Given(:model_class) do
        Class.new do
          attr_reader :data

          def initialize(data)
            @data = { given: data }
          end
        end
      end

      Given(:es_response) { Oj.load(File.read(fixture_file), symbol_keys: true) }

      When(:es_collection) { ArtirixDataModels::EsCollection.new(model_class, response: es_response) }
      Then { es_collection.aggregations.size == 3 }

      Then { es_collection.aggregations.first.name == :topics }
      Then { es_collection.aggregations.first.buckets.size == 4 }

      Then { es_collection.aggregations.first.buckets.first.name == 'Same Topics' }
      Then { es_collection.aggregations.first.buckets.first.count == 6 }
      Then { es_collection.aggregations.first.buckets.last.name == 'adaisada' }
      Then { es_collection.aggregations.first.buckets.last.count == 1 }


      Then { es_collection.aggregations.second.name == :content_types }
      Then { es_collection.aggregations.second.buckets.size == 3 }

      Then { es_collection.aggregations.second.buckets.first.name == 'article' }
      Then { es_collection.aggregations.second.buckets.first.count == 11 }
      Then { es_collection.aggregations.second.buckets.last.name == 'video' }
      Then { es_collection.aggregations.second.buckets.last.count == 1 }


      Then { es_collection.aggregations.third.name == :published_states }
      Then { es_collection.aggregations.third.buckets.size == 4 }

      Then { es_collection.aggregations.third.buckets.first.name == 'live_soon' }
      Then { es_collection.aggregations.third.buckets.first.count == 0 }
      Then { es_collection.aggregations.third.buckets.second.name == 'draft' }
      Then { es_collection.aggregations.third.buckets.second.count == 3 }
      Then { es_collection.aggregations.third.buckets.third.name == 'expired' }
      Then { es_collection.aggregations.third.buckets.third.count == 0 }
      Then { es_collection.aggregations.third.buckets.last.name == 'live' }
      Then { es_collection.aggregations.third.buckets.last.count == 12 }
    end
  end

end
