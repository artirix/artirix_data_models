module ArtirixDataModels::GatewayResponseAdaptors
  class ModelAdaptor
    attr_reader :object_creator

    # The adaptor will create an `object_creator` callable object.
    # That callable object will be called with a `data_hash` as only argument.
    # The purpose of that callable object is to create an object with the given data.
    #
    # 3 options:
    # ==========
    #
    # 1) object_class_or_creator with the Class of the object to be initiated
    #   sma = ModelAdaptor.single(MyModel)
    #   res = sma.call({a: 1})
    #   res.class           # => MyModel
    #   res                 # => <MyModel a=1>
    #
    #
    # 2) block with 1 argument
    #   sma = ModelAdaptor.with_block do |data|
    #     { something: data }
    #   end
    #
    #   res = sma.call({a: 1})
    #   res.class           # => Hash
    #   res                 # => {something: {a: 1}}
    #
    #
    # 3) callable object (respond to `call`), like a lambda
    #   sma = ModelAdaptor.with_callable( ->(data) { { something: data } })
    #
    #   res = sma.call({a: 1})
    #   res.class           # => Hash
    #   res                 # => {something: {a: 1}}
    #
    #
    def initialize(object_creator)
      @object_creator = object_creator
    end

    private_class_method :new

    def self.single(model_class)
      new ->(data_hash) { model_class.new data_hash }
    end

    def self.some(model_class)
      new ->(data_list) { Array(data_list).map { |data_hash| model_class.new data_hash } }
    end

    def self.collection(object_class_or_factory, from = 0, size = nil)
      size ||= SimpleConfig.for(:site).search_page_size.default
      new ->(data_collection) { ArtirixDataModels::EsCollection.new object_class_or_factory, response: data_collection, from: from, size: size }
    end

    def self.with_block(&block)
      new block
    end

    def self.with_callable(callable)
      new callable
    end

    def call(data_hash)
      object_creator.call data_hash
    end
  end
end
