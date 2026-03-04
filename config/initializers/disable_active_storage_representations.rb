# In development, skip variant/representation processing to prevent infinite proxy loops.
# Blobs are served directly without transformation.
if Rails.env.development?
  ActiveSupport.on_load(:active_storage_blob) do
    ActiveStorage::Blob::Representable.prepend(
      Module.new do
        def representation(transformations)
          self
        end
      end
    )
  end
end
