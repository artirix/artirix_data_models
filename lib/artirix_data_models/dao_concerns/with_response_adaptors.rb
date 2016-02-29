module ArtirixDataModels
  module DAOConcerns
    module WithResponseAdaptors

      def model_adaptor_factory
        ArtirixDataModels::GatewayResponseAdaptors::ModelAdaptor
      end

      def response_adaptor_for_reload(model_to_reload)
        model_adaptor_factory.with_block do |data_hash|
          model_to_reload.reload_with data_hash
        end
      end

      def response_adaptor_for_identity
        model_adaptor_factory.identity
      end

      def response_adaptor_for_single(effective_model_class = model_class)
        model_adaptor_factory.single effective_model_class
      end

      def response_adaptor_for_some(effective_model_class = model_class)
        model_adaptor_factory.some effective_model_class
      end

      def response_adaptor_for_collection(from, size, collection_element_model_class = model_class)
        model_adaptor_factory.collection collection_element_model_class, from, size
      end

      def response_adaptor_for_block(&block)
        model_adaptor_factory.with_block &block
      end

      def response_adaptor_for_callable(callable)
        model_adaptor_factory.with_callable callable
      end

    end
  end
end
