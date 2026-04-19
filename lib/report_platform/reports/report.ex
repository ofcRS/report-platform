defmodule ReportPlatform.Reports.Report do
  @moduledoc """
  Contract for a report. Implement in a module and add it to
  `ReportPlatform.Reports.Registry` to expose it in the UI.
  """

  @type metadata :: %{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          format: :xlsx | :pdf
        }

  @type params :: map()
  @type ctx :: map()

  @type form_field :: %{
          required(:name) => atom(),
          required(:label) => String.t(),
          required(:type) => :number | :text | :select,
          optional(:options) => [{String.t(), term()}],
          optional(:placeholder) => String.t(),
          optional(:hint) => String.t()
        }

  @callback metadata() :: metadata()

  @callback params_changeset(params) :: Ecto.Changeset.t()

  @callback generate(params, ctx) :: {:ok, binary()} | {:error, term()}

  @callback form_fields() :: [form_field()]
end
