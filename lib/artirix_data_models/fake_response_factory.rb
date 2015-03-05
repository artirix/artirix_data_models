class ArtirixDataModels::FakeResponseFactory

  def self.response_single_model(model, score: 14.5, aggregations: [])
    index_name    = model.class.to_s.demodulize.pluralize.underscore
    document_type = model.class.to_s.demodulize.singularize.underscore


    build_response document_type:     document_type,
                   index_name:        index_name,
                   present_max_score: score,
                   result_hits:       [model.compact_data_hash],
                   total_hits:        1,
                   total_max_score:   score,
                   aggregations:      aggregations
  end

  def self.response_by_results(result_hits, index_name: nil, document_type: nil, total_hits: nil, aggregations: [])

    total_hits ||= result_hits.size
    max_score  = total_hits * 10.2

    build_response document_type:     document_type,
                   index_name:        index_name,
                   present_max_score: max_score,
                   result_hits:       result_hits,
                   total_hits:        total_hits,
                   total_max_score:   max_score,
                   aggregations:      aggregations
  end

  def self.response(model_factory, factory_params: {}, from: 0, size: ArtirixDataModels::EsCollection::DEFAULT_SIZE, max_page: 10, traits: [], index_name: nil, document_type: nil, aggregations: [])
    max_page ||= 10

    current_page = (from / size) + 1

    total_hits = (size * (max_page - 0.5)).to_i

    if current_page > max_page
      # no results (page too high)
      current_hits = 0
    elsif current_page == max_page
      # final page
      current_hits = (size / 2).to_i
    else
      # other page
      current_hits = size
    end

    result_hits       = current_hits.times.collect { FactoryGirl.attributes_for(model_factory, *traits, factory_params) }

    # ensure that each element has a decreasing score

    # max score (1st element in search)
    total_max_score   = total_hits * 10.2

    # first element in this batch => has to be lower than any score from the previous batches
    present_max_score = (total_hits - from) * 10.2

    build_response document_type:     document_type,
                   index_name:        index_name,
                   present_max_score: present_max_score,
                   result_hits:       result_hits,
                   total_hits:        total_hits,
                   total_max_score:   total_max_score,
                   aggregations:      aggregations
  end

  private
  def self.build_response(document_type:, index_name:, present_max_score:, result_hits:, total_hits:, total_max_score:, aggregations: [])
    {
      hits:         {
        total:     total_hits,
        max_score: total_max_score,
        hits:      result_hits.map.with_index do |hit, index|
          {
            _index:  index_name,
            _type:   document_type,
            _id:     hit[:id],
            _score:  present_max_score - (index * 8.5),
            _source: hit
          }
        end
      },
      aggregations: aggregations
    }
  end

end