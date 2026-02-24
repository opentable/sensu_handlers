require 'spec_helper'

describe 'sensu_handlers::pagerduty' do
  let(:facts) {{
    :osfamily => 'Debian',
    :lsbdistid => 'debian',
  }}
  let(:teams) {{
    'operations' => {}
  }}
  let(:pre_condition) do
    "class { 'sensu_handlers': teams => #{teams} }"
  end
  let(:hiera_data) {{
    'sensu_handlers::teams' => teams,
  }}

  it { should compile }

  it 'creates page_filter' do
    should contain_sensu__filter('page_filter').with(
      :attributes => { 'check' => { 'page' => true } }
    )
  end

  it 'creates execution_timed_out_page_filter with negate' do
    should contain_sensu__filter('execution_timed_out_page_filter').with(
      :attributes => { 'check' => { 'output' => 'Execution timed out' } },
      :negate     => true
    )
  end

  it 'creates unknown_no_metrics_received_page_filter with negate' do
    should contain_sensu__filter('unknown_no_metrics_received_page_filter').with(
      :attributes => { 'check' => { 'output' => "UNKNOWN: no metrics received from graphite\n" } },
      :negate     => true
    )
  end

  it 'configures pagerduty handler with all filters' do
    should contain_sensu__handler('pagerduty').with_filters(
      ['page_filter', 'execution_timed_out_page_filter', 'unknown_no_metrics_received_page_filter']
    )
  end
end
