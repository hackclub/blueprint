# Mitigates CVE-2026-66066 (GHSA-xr9x-r78c-5hrm).
#
# libvips backs many of its loaders with third-party libraries it marks as
# "unfuzzed" — unsafe for untrusted content. Since libvips picks its loader from
# the file's magic bytes rather than the declared Content-Type, a user upload
# claiming to be image/png can still reach one of those loaders, risking
# arbitrary file disclosure or RCE.
#
# Blocking them process-wide covers both Active Storage variant processing and
# the direct Vips::Image calls in app/services/ai_reviewer.
ENV["VIPS_BLOCK_UNTRUSTED"] ||= "true"

begin
  require "vips"
  Vips.block_untrusted(true)
rescue LoadError
end
