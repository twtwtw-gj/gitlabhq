# frozen_string_literal: true

module QA
  module Resource
    class Issue < Base
      attr_writer :milestone, :template, :weight

      attribute :project do
        Project.fabricate! do |resource|
          resource.name = 'project-for-issues'
          resource.description = 'project for adding issues'
          resource.api_client = api_client
        end
      end

      attributes :id,
                 :iid,
                 :assignee_ids,
                 :labels,
                 :title,
                 :description

      def initialize
        @assignee_ids = []
        @labels = []
        @title = "Issue title #{SecureRandom.hex(8)}"
        @description = "Issue description #{SecureRandom.hex(8)}"
      end

      def fabricate!
        project.visit!

        Page::Project::Show.perform(&:go_to_new_issue)

        Page::Project::Issue::New.perform do |new_page|
          new_page.fill_title(@title)
          new_page.choose_template(@template) if @template
          new_page.fill_description(@description) if @description && !@template
          new_page.choose_milestone(@milestone) if @milestone
          new_page.create_new_issue
        end
      end

      def api_get_path
        "/projects/#{project.id}/issues/#{iid}"
      end

      def api_post_path
        "/projects/#{project.id}/issues"
      end

      def api_put_path
        "/projects/#{project.id}/issues/#{iid}"
      end

      def api_comments_path
        "#{api_get_path}/notes"
      end

      def api_post_body
        {
          assignee_ids: assignee_ids,
          labels: labels,
          title: title
        }.tap do |hash|
          hash[:milestone_id] = @milestone.id if @milestone
          hash[:weight] = @weight if @weight
          hash[:description] = @description if @description
        end
      end

      def set_issue_assignees(assignee_ids:)
        put_body = { assignee_ids: assignee_ids }
        response = put Runtime::API::Request.new(api_client, api_put_path).url, put_body

        unless response.code == HTTP_STATUS_OK
          raise(
            ResourceUpdateFailedError,
            "Could not update issue assignees to #{assignee_ids}. Request returned (#{response.code}): `#{response}`."
          )
        end

        QA::Runtime::Logger.debug("Successfully updated issue assignees to #{assignee_ids}")
      end

      # Get issue comments
      #
      # @return [Array]
      def comments(auto_paginate: false, attempts: 0)
        return parse_body(api_get_from(api_comments_path)) unless auto_paginate

        auto_paginated_response(
          Runtime::API::Request.new(api_client, api_comments_path, per_page: '100').url,
          attempts: attempts
        )
      end

      # Create a new comment
      #
      # @param [String] body
      # @param [Boolean] confidential
      # @return [Hash]
      def add_comment(body:, confidential: false)
        api_post_to(api_comments_path, body: body, confidential: confidential)
      end

      # Issue label events
      #
      # @param [Boolean] auto_paginate
      # @param [Integer] attempts
      # @return [Array<Hash>]
      def label_events(auto_paginate: false, attempts: 0)
        events("label", auto_paginate: auto_paginate, attempts: attempts)
      end

      # Issue state events
      #
      # @param [Boolean] auto_paginate
      # @param [Integer] attempts
      # @return [Array<Hash>]
      def state_events(auto_paginate: false, attempts: 0)
        events("state", auto_paginate: auto_paginate, attempts: attempts)
      end

      # Issue milestone events
      #
      # @param [Boolean] auto_paginate
      # @param [Integer] attempts
      # @return [Array<Hash>]
      def milestone_events(auto_paginate: false, attempts: 0)
        events("milestone", auto_paginate: auto_paginate, attempts: attempts)
      end

      protected

      # Return subset of fields for comparing issues
      #
      # @return [Hash]
      def comparable
        reload! if api_response.nil?

        api_resource.slice(
          :state,
          :description,
          :type,
          :title,
          :labels,
          :milestone,
          :upvotes,
          :downvotes,
          :merge_requests_count,
          :user_notes_count,
          :due_date,
          :has_tasks,
          :task_status,
          :confidential,
          :discussion_locked,
          :issue_type,
          :task_completion_status,
          :closed_at,
          :created_at
        )
      end

      private

      # Issue events
      #
      # @param [String] name event name
      # @param [Boolean] auto_paginate
      # @param [Integer] attempts
      # @return [Array<Hash>]
      def events(name, auto_paginate:, attempts:)
        return parse_body(api_get_from("#{api_get_path}/resource_#{name}_events")) unless auto_paginate

        auto_paginated_response(
          Runtime::API::Request.new(api_client, "#{api_get_path}/resource_#{name}_events", per_page: '100').url,
          attempts: attempts
        )
      end
    end
  end
end
