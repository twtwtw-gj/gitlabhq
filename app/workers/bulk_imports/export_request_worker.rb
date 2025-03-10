# frozen_string_literal: true

module BulkImports
  class ExportRequestWorker
    include ApplicationWorker

    data_consistency :always

    idempotent!
    worker_has_external_dependencies!
    feature_category :importers

    def perform(entity_id)
      entity = BulkImports::Entity.find(entity_id)

      entity.update!(source_xid: entity_source_xid(entity)) if entity.source_xid.nil?

      request_export(entity)

      BulkImports::EntityWorker.perform_async(entity_id)
    rescue BulkImports::NetworkError => e
      log_export_failure(e, entity)

      entity.fail_op!
    end

    private

    def request_export(entity)
      http_client(entity).post(entity.export_relations_url_path)
    end

    def http_client(entity)
      @client ||= Clients::HTTP.new(
        url: entity.bulk_import.configuration.url,
        token: entity.bulk_import.configuration.access_token
      )
    end

    def log_export_failure(exception, entity)
      Gitlab::Import::Logger.error(
        structured_payload(
          log_attributes(exception, entity).merge(
            bulk_import_id: entity.bulk_import_id,
            bulk_import_entity_type: entity.source_type
          )
        )
      )

      BulkImports::Failure.create(log_attributes(exception, entity))
    end

    def log_attributes(exception, entity)
      {
        bulk_import_entity_id: entity.id,
        pipeline_class: 'ExportRequestWorker',
        exception_class: exception.class.to_s,
        exception_message: exception.message.truncate(255),
        correlation_id_value: Labkit::Correlation::CorrelationId.current_or_new_id
      }
    end

    def graphql_client(entity)
      @graphql_client ||= BulkImports::Clients::Graphql.new(
        url: entity.bulk_import.configuration.url,
        token: entity.bulk_import.configuration.access_token
      )
    end

    def entity_source_xid(entity)
      query = entity_query(entity)
      client = graphql_client(entity)

      response = client.execute(
        client.parse(query.to_s),
        { full_path: entity.source_full_path }
      ).original_hash

      ::GlobalID.parse(response.dig(*query.data_path, 'id')).model_id
    rescue StandardError => e
      Gitlab::Import::Logger.error(
        structured_payload(
          log_attributes(e, entity).merge(
            message: 'Failed to fetch source entity id',
            bulk_import_id: entity.bulk_import_id,
            bulk_import_entity_type: entity.source_type
          )
        )
      )

      nil
    end

    def entity_query(entity)
      if entity.group?
        BulkImports::Groups::Graphql::GetGroupQuery.new(context: nil)
      else
        BulkImports::Projects::Graphql::GetProjectQuery.new(context: nil)
      end
    end
  end
end
