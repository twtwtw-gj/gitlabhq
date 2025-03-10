# frozen_string_literal: true

module Resolvers
  class BulkLabelsResolver < BaseResolver
    include Gitlab::Graphql::Authorize::AuthorizeResource

    type Types::LabelType.connection_type, null: true

    def resolve
      authorize!(object)

      BatchLoader::GraphQL.for(object.id).batch(cache: false) do |ids, loader, args|
        labels = Label.for_targets(ids, object.class.name).group_by(&:target_id)

        ids.each do |id|
          loader.call(id, labels[id] || [])
        end
      end
    end

    private

    def authorized_resource?(object)
      Ability.allowed?(current_user, :read_label, object.issuing_parent)
    end
  end
end
