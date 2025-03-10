# rubocop:disable Naming/FileName
# frozen_string_literal: true

require_relative 'cdn/google_cdn'

module ObjectStorage
  module CDN
    module Concern
      extend ActiveSupport::Concern

      include Gitlab::Utils::StrongMemoize

      UrlResult = Struct.new(:url, :used_cdn)

      def cdn_enabled_url(project, ip_address)
        if Feature.enabled?(:ci_job_artifacts_cdn, project) && use_cdn?(ip_address)
          UrlResult.new(cdn_signed_url, true)
        else
          UrlResult.new(url, false)
        end
      end

      def use_cdn?(request_ip)
        return false unless cdn_options.is_a?(Hash) && cdn_options['provider']
        return false unless cdn_provider

        cdn_provider.use_cdn?(request_ip)
      end

      def cdn_signed_url
        cdn_provider&.signed_url(path)
      end

      private

      def cdn_provider
        strong_memoize(:cdn_provider) do
          provider = cdn_options['provider']&.downcase

          next unless provider
          next GoogleCDN.new(cdn_options) if provider == 'google'

          raise "Unknown CDN provider: #{provider}"
        end
      end

      def cdn_options
        return {} unless options.object_store.key?('cdn')

        options.object_store.cdn
      end
    end
  end
end

# rubocop:enable Naming/FileName
