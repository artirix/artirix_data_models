# :nocov:
shared_examples_for 'has attributes' do
  describe 'responds to the given attribute getters and setters' do
    When(:subject) { described_class.new }

    describe 'getters' do
      Then { has_public_getters?(attributes) }
    end

    describe 'private setters' do
      Then { has_private_setters?(attributes) }
    end

    describe 'presence' do
      Then { has_presence_methods?(attributes) }
    end

    def has_public_getters?(attributes)
      attributes.reject { |at| subject.respond_to? at }.empty?
    end

    def has_private_setters?(attributes)
      attributes.reject do |at|
        setter = "#{at}="
        subject.respond_to?(setter, true) && !subject.respond_to?(setter)
      end.empty?
    end

    def has_presence_methods?(attributes)
      attributes.reject { |at| subject.respond_to? "#{at}?" }.empty?
    end
  end
end

# :nocov: