# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issues::CreateService do
  include AfterNextHelpers

  let_it_be(:group) { create(:group, :crm_enabled) }
  let_it_be_with_reload(:project) { create(:project, :public, group: group) }
  let_it_be(:user) { create(:user) }

  let(:spam_params) { double }

  it_behaves_like 'rate limited service' do
    let(:key) { :issues_create }
    let(:key_scope) { %i[project current_user external_author] }
    let(:application_limit_key) { :issues_create_limit }
    let(:created_model) { Issue }
    let(:service) { described_class.new(project: project, current_user: user, params: { title: 'title' }, spam_params: double) }
  end

  describe '#execute' do
    let_it_be(:assignee) { create(:user) }
    let_it_be(:milestone) { create(:milestone, project: project) }

    let(:result) { described_class.new(project: project, current_user: user, params: opts, spam_params: spam_params).execute }
    let(:issue) { result[:issue] }

    before do
      stub_spam_services
    end

    context 'when params are invalid' do
      let(:opts) { { title: '' } }

      before_all do
        project.add_guest(assignee)
      end

      it 'returns an error service response' do
        expect(result).to be_error
        expect(result.errors).to include("Title can't be blank")
        expect(issue).not_to be_persisted
      end
    end

    context 'when params are valid' do
      let_it_be(:labels) { create_pair(:label, project: project) }

      before_all do
        project.add_guest(user)
        project.add_guest(assignee)
      end

      let(:opts) do
        { title: 'Awesome issue',
          description: 'please fix',
          assignee_ids: [assignee.id],
          label_ids: labels.map(&:id),
          milestone_id: milestone.id,
          milestone: milestone,
          due_date: Date.tomorrow }
      end

      context 'when an unauthorized project_id is provided' do
        let(:unauthorized_project) { create(:project) }

        before do
          opts[:project_id] = unauthorized_project.id
        end

        it 'ignores the project_id param and creates issue in the given project' do
          expect(issue.project).to eq(project)
          expect(unauthorized_project.reload.issues.count).to eq(0)
        end
      end

      describe 'authorization' do
        let_it_be(:project) { create(:project, :private, group: group).tap { |project| project.add_guest(user) } }

        let(:opts) { { title: 'private issue', description: 'please fix' } }

        context 'when the user is authorized' do
          it 'allows the user to create an issue' do
            expect(result).to be_success
            expect(issue).to be_persisted
          end
        end

        context 'when the user is not authorized' do
          let(:user) { create(:user) }

          it 'does not allow the user to create an issue' do
            expect(result).to be_error
            expect(result.errors).to contain_exactly('Operation not allowed')
            expect(result.http_status).to eq(403)
            expect(issue).to be_nil
          end
        end
      end

      it 'works if base work item types were not created yet' do
        WorkItems::Type.delete_all

        expect do
          issue
        end.to change(Issue, :count).by(1)
      end

      it 'creates the issue with the given params' do
        expect(Issuable::CommonSystemNotesService).to receive_message_chain(:new, :execute)

        expect(result).to be_success
        expect(issue).to be_persisted
        expect(issue).to be_a(::Issue)
        expect(issue.title).to eq('Awesome issue')
        expect(issue.assignees).to eq([assignee])
        expect(issue.labels).to match_array(labels)
        expect(issue.milestone).to eq(milestone)
        expect(issue.due_date).to eq(Date.tomorrow)
        expect(issue.work_item_type.base_type).to eq('issue')
        expect(issue.issue_customer_relations_contacts).to be_empty
      end

      it 'calls NewIssueWorker with correct arguments' do
        expect(NewIssueWorker).to receive(:perform_async).with(Integer, user.id, 'Issue')

        issue
      end

      context 'when a build_service is provided' do
        let(:result) { described_class.new(project: project, current_user: user, params: opts, spam_params: spam_params, build_service: build_service).execute }

        let(:issue_from_builder) { WorkItem.new(project: project, title: 'Issue from builder') }
        let(:build_service) { double(:build_service, execute: issue_from_builder) }

        it 'uses the provided service to build the issue' do
          expect(result).to be_success
          expect(issue).to be_persisted
          expect(issue).to be_a(WorkItem)
        end
      end

      context 'when skip_system_notes is true' do
        let(:issue) { described_class.new(project: project, current_user: user, params: opts, spam_params: spam_params).execute(skip_system_notes: true) }

        it 'does not call Issuable::CommonSystemNotesService' do
          expect(Issuable::CommonSystemNotesService).not_to receive(:new)

          issue
        end
      end

      context 'when setting a position' do
        let(:issue_before) { create(:issue, project: project, relative_position: 10) }
        let(:issue_after) { create(:issue, project: project, relative_position: 50) }

        before do
          opts.merge!(move_between_ids: [issue_before.id, issue_after.id])
        end

        it 'sets the correct relative position' do
          expect(result).to be_success
          expect(issue).to be_persisted
          expect(issue.relative_position).to be_present
          expect(issue.relative_position).to be_between(issue_before.relative_position, issue_after.relative_position)
        end
      end

      it_behaves_like 'not an incident issue'

      context 'when issue is incident type' do
        before do
          opts.merge!(issue_type: 'incident')
        end

        let(:current_user) { user }

        subject { issue }

        context 'as reporter' do
          let_it_be(:reporter) { create(:user) }

          let(:user) { reporter }

          before_all do
            project.add_reporter(reporter)
          end

          it_behaves_like 'incident issue'

          it 'calls IncidentManagement::Incidents::CreateEscalationStatusService' do
            expect_next(::IncidentManagement::IssuableEscalationStatuses::CreateService, a_kind_of(Issue))
              .to receive(:execute)

            issue
          end

          it 'calls IncidentManagement::TimelineEvents::CreateService.create_incident' do
            expect(IncidentManagement::TimelineEvents::CreateService)
              .to receive(:create_incident)
              .with(a_kind_of(Issue), reporter)

            issue
          end

          it 'calls NewIssueWorker with correct arguments' do
            expect(NewIssueWorker).to receive(:perform_async).with(Integer, reporter.id, 'Issue')

            issue
          end

          context 'when invalid' do
            before do
              opts.merge!(title: '')
            end

            it 'does not apply an incident label prematurely' do
              expect { subject }.to not_change(LabelLink, :count).and not_change(Issue, :count)
            end
          end
        end

        context 'as guest' do
          it_behaves_like 'not an incident issue'
        end
      end

      it 'refreshes the number of open issues', :use_clean_rails_memory_store_caching do
        expect do
          issue

          BatchLoader::Executor.clear_current
        end.to change { project.open_issues_count }.from(0).to(1)
      end

      context 'when current user cannot set issue metadata in the project' do
        let_it_be(:non_member) { create(:user) }

        it 'filters out params that cannot be set without the :set_issue_metadata permission' do
          result = described_class.new(project: project, current_user: non_member, params: opts, spam_params: spam_params).execute
          issue = result[:issue]

          expect(result).to be_success
          expect(issue).to be_persisted
          expect(issue.title).to eq('Awesome issue')
          expect(issue.description).to eq('please fix')
          expect(issue.assignees).to be_empty
          expect(issue.labels).to be_empty
          expect(issue.milestone).to be_nil
          expect(issue.due_date).to be_nil
        end

        it 'can create confidential issues' do
          result = described_class.new(project: project, current_user: non_member, params: opts.merge(confidential: true), spam_params: spam_params).execute
          issue = result[:issue]

          expect(result).to be_success
          expect(issue.confidential).to be_truthy
        end
      end

      it 'moves the issue to the end, in an asynchronous worker' do
        expect(Issues::PlacementWorker).to receive(:perform_async).with(be_nil, Integer)

        described_class.new(project: project, current_user: user, params: opts, spam_params: spam_params).execute
      end

      context 'when label belongs to project group' do
        let(:group) { create(:group) }
        let(:group_labels) { create_pair(:group_label, group: group) }

        let(:opts) do
          {
            title: 'Title',
            description: 'Description',
            label_ids: group_labels.map(&:id)
          }
        end

        before do
          project.update!(group: group)
        end

        it 'assigns group labels' do
          expect(issue.labels).to match_array group_labels
        end
      end

      context 'when label belongs to different project' do
        let(:label) { create(:label) }

        let(:opts) do
          { title: 'Title',
            description: 'Description',
            label_ids: [label.id] }
        end

        it 'does not assign label' do
          expect(issue.labels).not_to include label
        end
      end

      context 'when labels is nil' do
        let(:opts) do
          { title: 'Title',
            description: 'Description',
            labels: nil }
        end

        it 'does not assign label' do
          expect(issue.labels).to be_empty
        end
      end

      context 'when labels is nil and label_ids is present' do
        let(:opts) do
          { title: 'Title',
            description: 'Description',
            labels: nil,
            label_ids: labels.map(&:id) }
        end

        it 'assigns group labels' do
          expect(issue.labels).to match_array labels
        end
      end

      context 'when milestone belongs to different project' do
        let(:milestone) { create(:milestone) }

        let(:opts) do
          { title: 'Title',
            description: 'Description',
            milestone_id: milestone.id }
        end

        it 'does not assign milestone' do
          expect(issue.milestone).not_to eq milestone
        end
      end

      context 'when assignee is set' do
        let(:opts) do
          { title: 'Title',
            description: 'Description',
            assignees: [assignee] }
        end

        it 'invalidates open issues counter for assignees when issue is assigned' do
          project.add_maintainer(assignee)

          described_class.new(project: project, current_user: user, params: opts, spam_params: spam_params).execute

          expect(assignee.assigned_open_issues_count).to eq 1
        end
      end

      context 'when duplicate label titles are given' do
        let(:label) { create(:label, project: project) }

        let(:opts) do
          { title: 'Title',
            description: 'Description',
            labels: [label.title, label.title] }
        end

        it 'assigns the label once' do
          expect(issue.labels).to contain_exactly(label)
        end
      end

      context 'when sentry identifier is given' do
        before do
          sentry_attributes = { sentry_issue_attributes: { sentry_issue_identifier: 42 } }
          opts.merge!(sentry_attributes)
        end

        it 'does not assign the sentry error' do
          expect(issue.sentry_issue).to eq(nil)
        end

        context 'user is reporter or above' do
          before do
            project.add_developer(user)
          end

          it 'assigns the sentry error' do
            expect(issue.sentry_issue).to be_kind_of(SentryIssue)
          end
        end
      end

      it 'executes issue hooks when issue is not confidential' do
        opts = { title: 'Title', description: 'Description', confidential: false }

        expect(project).to receive(:execute_hooks).with(an_instance_of(Hash), :issue_hooks)
        expect(project).to receive(:execute_integrations).with(an_instance_of(Hash), :issue_hooks)

        described_class.new(project: project, current_user: user, params: opts, spam_params: spam_params).execute
      end

      it 'executes confidential issue hooks when issue is confidential' do
        opts = { title: 'Title', description: 'Description', confidential: true }

        expect(project).to receive(:execute_hooks).with(an_instance_of(Hash), :confidential_issue_hooks)
        expect(project).to receive(:execute_integrations).with(an_instance_of(Hash), :confidential_issue_hooks)

        described_class.new(project: project, current_user: user, params: opts, spam_params: spam_params).execute
      end

      context 'after_save callback to store_mentions' do
        context 'when mentionable attributes change' do
          let(:opts) { { title: 'Title', description: "Description with #{user.to_reference}" } }

          it 'saves mentions' do
            expect_next_instance_of(Issue) do |instance|
              expect(instance).to receive(:store_mentions!).and_call_original
            end
            expect(issue.user_mentions.count).to eq 1
          end
        end

        context 'when save fails' do
          let(:opts) { { title: '', label_ids: labels.map(&:id), milestone_id: milestone.id } }

          it 'does not call store_mentions' do
            expect_next_instance_of(Issue) do |instance|
              expect(instance).not_to receive(:store_mentions!).and_call_original
            end
            expect(issue.valid?).to be false
            expect(issue.user_mentions.count).to eq 0
          end
        end
      end

      it 'schedules a namespace onboarding create action worker' do
        expect(Onboarding::IssueCreatedWorker).to receive(:perform_async).with(project.namespace.id)

        issue
      end
    end

    context 'issue create service' do
      context 'assignees' do
        before_all do
          project.add_maintainer(user)
        end

        it 'removes assignee when user id is invalid' do
          opts = { title: 'Title', description: 'Description', assignee_ids: [-1] }

          result = described_class.new(project: project, current_user: user, params: opts, spam_params: spam_params).execute
          issue = result[:issue]

          expect(result).to be_success
          expect(issue.assignees).to be_empty
        end

        it 'removes assignee when user id is 0' do
          opts = { title: 'Title', description: 'Description', assignee_ids: [0] }

          result = described_class.new(project: project, current_user: user, params: opts, spam_params: spam_params).execute
          issue = result[:issue]

          expect(result).to be_success
          expect(issue.assignees).to be_empty
        end

        it 'saves assignee when user id is valid' do
          project.add_maintainer(assignee)
          opts = { title: 'Title', description: 'Description', assignee_ids: [assignee.id] }

          result = described_class.new(project: project, current_user: user, params: opts, spam_params: spam_params).execute
          issue = result[:issue]

          expect(result).to be_success
          expect(issue.assignees).to eq([assignee])
        end

        context "when issuable feature is private" do
          before do
            project.project_feature.update!(issues_access_level: ProjectFeature::PRIVATE,
                                            merge_requests_access_level: ProjectFeature::PRIVATE)
          end

          levels = [Gitlab::VisibilityLevel::INTERNAL, Gitlab::VisibilityLevel::PUBLIC]

          levels.each do |level|
            it "removes not authorized assignee when project is #{Gitlab::VisibilityLevel.level_name(level)}" do
              project.update!(visibility_level: level)
              opts = { title: 'Title', description: 'Description', assignee_ids: [assignee.id] }

              result = described_class.new(project: project, current_user: user, params: opts, spam_params: spam_params).execute
              issue = result[:issue]

              expect(result).to be_success
              expect(issue.assignees).to be_empty
            end
          end
        end
      end
    end

    it_behaves_like 'issuable record that supports quick actions' do
      let(:issuable) { described_class.new(project: project, current_user: user, params: params, spam_params: spam_params).execute[:issue] }
    end

    context 'Quick actions' do
      context 'with assignee, milestone, and contact in params and command' do
        let_it_be(:contact) { create(:contact, group: group) }

        let(:opts) do
          {
            assignee_ids: [create(:user).id],
            milestone_id: 1,
            title: 'Title',
            description: %(/assign @#{assignee.username}\n/milestone %"#{milestone.name}"),
            add_contacts: [contact.email]
          }
        end

        before_all do
          group.add_maintainer(user)
          project.add_maintainer(assignee)
        end

        it 'assigns, sets milestone, and sets contact to issuable from command' do
          expect(result).to be_success
          expect(issue).to be_persisted
          expect(issue.assignees).to eq([assignee])
          expect(issue.milestone).to eq(milestone)
          expect(issue.issue_customer_relations_contacts.last.contact).to eq(contact)
        end
      end

      context 'with external_author' do
        let_it_be(:contact) { create(:contact, group: group) }

        context 'when CRM contact exists with matching e-mail' do
          let(:opts) do
            {
              title: 'Title',
              external_author: contact.email
            }
          end

          context 'with permission' do
            it 'assigns contact to issue' do
              group.add_reporter(user)

              expect(result).to be_success
              expect(issue).to be_persisted
              expect(issue.issue_customer_relations_contacts.last.contact).to eq(contact)
            end
          end

          context 'without permission' do
            it 'does not assign contact to issue' do
              group.add_guest(user)

              expect(result).to be_success
              expect(issue).to be_persisted
              expect(issue.issue_customer_relations_contacts).to be_empty
            end
          end
        end

        context 'when no CRM contact exists with matching e-mail' do
          let(:opts) do
            {
              title: 'Title',
              external_author: 'example@gitlab.com'
            }
          end

          it 'does not assign contact to issue' do
            group.add_reporter(user)
            expect(issue).to be_persisted
            expect(issue.issue_customer_relations_contacts).to be_empty
          end
        end
      end

      context 'with alert bot author' do
        let_it_be(:user) { User.alert_bot }
        let_it_be(:label) { create(:label, project: project) }

        let(:opts) do
          {
            title: 'Title',
            description: %(/label #{label.to_reference(format: :name)}")
          }
        end

        it 'can apply labels' do
          expect(result).to be_success
          expect(issue).to be_persisted
          expect(issue.labels).to eq([label])
        end
      end
    end

    context 'resolving discussions' do
      let_it_be(:discussion) { create(:diff_note_on_merge_request).to_discussion }
      let_it_be(:merge_request) { discussion.noteable }
      let_it_be(:project) { merge_request.source_project }

      before_all do
        project.add_maintainer(user)
      end

      describe 'for a single discussion' do
        let(:opts) { { discussion_to_resolve: discussion.id, merge_request_to_resolve_discussions_of: merge_request.iid } }

        it 'resolves the discussion' do
          described_class.new(project: project, current_user: user, params: opts, spam_params: spam_params).execute
          discussion.first_note.reload

          expect(discussion.resolved?).to be(true)
        end

        it 'added a system note to the discussion' do
          described_class.new(project: project, current_user: user, params: opts, spam_params: spam_params).execute

          reloaded_discussion = MergeRequest.find(merge_request.id).discussions.first

          expect(reloaded_discussion.last_note.system).to eq(true)
        end

        it 'sets default title and description values if not provided' do
          result = described_class.new(
            project: project, current_user: user,
            params: opts,
            spam_params: spam_params
          ).execute
          issue = result[:issue]

          expect(result).to be_success
          expect(issue).to be_persisted
          expect(issue.title).to eq("Follow-up from \"#{merge_request.title}\"")
          expect(issue.description).to include("The following discussion from #{merge_request.to_reference} should be addressed")
        end

        it 'takes params from the request over the default values' do
          result = described_class.new(
            project: project,
            current_user: user,
            params: opts.merge(
              description: 'Custom issue description',
              title: 'My new issue'
            ),
            spam_params: spam_params
          ).execute
          issue = result[:issue]

          expect(result).to be_success
          expect(issue).to be_persisted
          expect(issue.description).to eq('Custom issue description')
          expect(issue.title).to eq('My new issue')
        end
      end

      describe 'for a merge request' do
        let(:opts) { { merge_request_to_resolve_discussions_of: merge_request.iid } }

        it 'resolves the discussion' do
          described_class.new(project: project, current_user: user, params: opts, spam_params: spam_params).execute
          discussion.first_note.reload

          expect(discussion.resolved?).to be(true)
        end

        it 'added a system note to the discussion' do
          described_class.new(project: project, current_user: user, params: opts, spam_params: spam_params).execute

          reloaded_discussion = MergeRequest.find(merge_request.id).discussions.first

          expect(reloaded_discussion.last_note.system).to eq(true)
        end

        it 'sets default title and description values if not provided' do
          result = described_class.new(
            project: project, current_user: user,
            params: opts,
            spam_params: spam_params
          ).execute
          issue = result[:issue]

          expect(result).to be_success
          expect(issue).to be_persisted
          expect(issue.title).to eq("Follow-up from \"#{merge_request.title}\"")
          expect(issue.description).to include("The following discussion from #{merge_request.to_reference} should be addressed")
        end

        it 'takes params from the request over the default values' do
          result = described_class.new(
            project: project,
            current_user: user,
            params: opts.merge(
              description: 'Custom issue description',
              title: 'My new issue'
            ),
            spam_params: spam_params
          ).execute
          issue = result[:issue]

          expect(result).to be_success
          expect(issue).to be_persisted
          expect(issue.description).to eq('Custom issue description')
          expect(issue.title).to eq('My new issue')
        end
      end
    end

    context 'add related issue' do
      let_it_be(:related_issue) { create(:issue, project: project) }

      let(:opts) do
        { title: 'A new issue', add_related_issue: related_issue }
      end

      it 'ignores related issue if not accessible' do
        expect { issue }.not_to change { IssueLink.count }
        expect(result).to be_success
        expect(issue).to be_persisted
      end

      context 'when user has access to the related issue' do
        before do
          project.add_developer(user)
        end

        it 'adds a link to the issue' do
          expect { issue }.to change { IssueLink.count }.by(1)
          expect(result).to be_success
          expect(issue).to be_persisted
          expect(issue.related_issues(user)).to eq([related_issue])
        end
      end
    end

    context 'checking spam' do
      let(:params) do
        {
          title: 'Spam issue'
        }
      end

      subject do
        described_class.new(project: project, current_user: user, params: params, spam_params: spam_params)
      end

      it 'executes SpamActionService' do
        expect_next_instance_of(
          Spam::SpamActionService,
          {
            spammable: kind_of(Issue),
            spam_params: spam_params,
            user: an_instance_of(User),
            action: :create
          }
        ) do |instance|
          expect(instance).to receive(:execute)
        end

        subject.execute
      end
    end
  end
end
