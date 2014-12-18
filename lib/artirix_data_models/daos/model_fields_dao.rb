# DAO responsible for checking the fields list in both FULL and PARTIAL modes for a given model name.
#
# It does so accessing the "fields list" entry point via the DataGateway
#
# The Information should not change so it is stored in a constant Hash, so it'll be accessed only once for each model and type
#
class ArtirixDataModels::ModelFieldsDAO
  PARTIAL_FIELDS = {}

  attr_reader :gateway

  def initialize(gateway: nil)
    @gateway = gateway || ArtirixDataModels::DAORegistry.gateway
  end

  def partial_mode_fields_for(model_name)
    model_name = model_name.to_s

    PARTIAL_FIELDS.fetch(model_name) do
      PARTIAL_FIELDS[model_name] = _get_partial model_name
    end
  end

  private

  def _get_partial(model_name)
    path = path_partial(model_name)
    gateway.get path
  rescue ArtirixDataModels::DataGateway::NotFound
    []
  end

  def path_partial(model_name)
    "/partial_fields/#{model_name}"
  end

end
