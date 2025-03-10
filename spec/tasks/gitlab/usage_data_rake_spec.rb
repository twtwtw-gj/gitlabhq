# frozen_string_literal: true

require 'rake_helper'

RSpec.describe 'gitlab:usage data take tasks', :silence_stdout do
  include StubRequests
  include UsageDataHelpers

  let(:metrics_file) { Rails.root.join('tmp', 'test', 'sql_metrics_queries.json') }

  before do
    Rake.application.rake_require 'tasks/gitlab/usage_data'

    # stub prometheus external http calls https://gitlab.com/gitlab-org/gitlab/-/issues/245277
    stub_prometheus_queries
    stub_database_flavor_check
  end

  after do
    FileUtils.rm_rf(metrics_file)
  end

  describe 'dump_sql_in_yaml' do
    it 'dumps SQL queries in yaml format' do
      expect { run_rake_task('gitlab:usage_data:dump_sql_in_yaml') }.to output(/.*recorded_at:.*/).to_stdout
    end
  end

  describe 'dump_sql_in_json' do
    it 'dumps SQL queries in json format' do
      expect { run_rake_task('gitlab:usage_data:dump_sql_in_json') }.to output(/.*"recorded_at":.*/).to_stdout
    end
  end

  describe 'dump_non_sql_in_json' do
    it 'dumps non SQL data in json format' do
      expect { run_rake_task('gitlab:usage_data:dump_non_sql_in_json') }.to output(/.*"recorded_at":.*/).to_stdout
    end
  end

  describe 'generate_sql_metrics_fixture' do
    it 'generates fixture file correctly' do
      run_rake_task('gitlab:usage_data:generate_sql_metrics_queries')

      expect(Pathname.new(metrics_file)).to exist
    end
  end

  describe 'generate_and_send' do
    let(:service_ping_payload_url) do
      File.join(ServicePing::SubmitService::STAGING_BASE_URL, ServicePing::SubmitService::USAGE_DATA_PATH)
    end

    let(:service_ping_metadata_url) do
      File.join(ServicePing::SubmitService::STAGING_BASE_URL, ServicePing::SubmitService::METADATA_PATH)
    end

    let(:payload) { { recorded_at: Time.current } }

    before do
      allow_next_instance_of(ServicePing::BuildPayload) do |service|
        allow(service).to receive(:execute).and_return(payload)
      end
      stub_response(body: payload.merge(conv_index: { usage_data_id: 123 }))
      stub_response(body: nil, url: service_ping_metadata_url, status: 201)
    end

    it 'generates and sends Service Ping payload' do
      expect { run_rake_task('gitlab:usage_data:generate_and_send') }.to output(/.*201.*/).to_stdout
    end

    describe 'generate_ci_template_events' do
      it "generates #{Gitlab::UsageDataCounters::CiTemplateUniqueCounter::KNOWN_EVENTS_FILE_PATH}" do
        FileUtils.rm(Gitlab::UsageDataCounters::CiTemplateUniqueCounter::KNOWN_EVENTS_FILE_PATH)
        run_rake_task('gitlab:usage_data:generate_ci_template_events')

        expect(File.exist?(Gitlab::UsageDataCounters::CiTemplateUniqueCounter::KNOWN_EVENTS_FILE_PATH)).to be true
      end
    end

    private

    def stub_response(url: service_ping_payload_url, body:, status: 201)
      stub_full_request(url, method: :post)
        .to_return(
          headers: { 'Content-Type' => 'application/json' },
          body: body.to_json,
          status: status
        )
    end
  end
end
