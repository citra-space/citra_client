defmodule CitraClient.Entities.ImageUploadParams do
  defstruct [
    :aws_access_key_id,
    :content_type,
    :key,
    :policy,
    :signature,
    :filename,
    :results_url,
    :upload_url,
    :upload_id
  ]

  @type t :: %__MODULE__{
          aws_access_key_id: String.t(),
          content_type: String.t(),
          key: String.t(),
          policy: String.t(),
          signature: String.t(),
          filename: String.t(),
          results_url: String.t(),
          upload_url: String.t(),
          upload_id: String.t()
        }
end
