# frozen_string_literal: true

module QA
  RSpec.describe 'Create' do
    describe 'A project wiki' do
      let(:initial_wiki) { Resource::Wiki::ProjectPage.fabricate_via_api! }
      let(:new_path) { "a/new/path-with-spaces" }

      before do
        Flow::Login.sign_in
      end

      it 'can change the directory path of a page',
testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347821' do
        initial_wiki.visit!

        Page::Project::Wiki::Show.perform(&:click_edit)

        Page::Project::Wiki::Edit.perform do |edit|
          edit.set_title("#{new_path}/home")
          edit.set_message('changing the path of the home page')
        end

        Page::Project::Wiki::Edit.perform(&:click_submit)

        Page::Project::Wiki::Show.perform do |wiki|
          expect(wiki).to have_directory('a')
          expect(wiki).to have_directory('new')
          expect(wiki).to have_directory('path with spaces')
        end
      end
    end
  end
end
