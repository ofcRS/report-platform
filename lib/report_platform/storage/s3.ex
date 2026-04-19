defmodule ReportPlatform.Storage.S3 do
  @moduledoc """
  Deferred. Production would upload the artifact to an S3-compatible
  bucket and persist the object key as the run's artifact_path.

  TODO(production):
    * add `ex_aws` + `ex_aws_s3` (or `req_s3`)
    * config keys: bucket, region, access_key_id, secret_access_key
    * `put/2` uploads under `reports/<yyyy>/<mm>/<dd>/<uuid>-<filename>`
    * `read/1` streams via presigned URL from the download controller
      instead of loading into memory
    * add `delete/1` and a retention job (Oban cron) to enforce TTL
  """

  @behaviour ReportPlatform.Storage

  @impl true
  def put(_binary, _filename), do: {:error, :not_implemented}

  @impl true
  def read(_path), do: {:error, :not_implemented}
end
