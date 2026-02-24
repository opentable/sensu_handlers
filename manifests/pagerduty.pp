# == Class: sensu_handlers::pagerduty
#
# Sensu handler for communicating with Pagerduty
#
class sensu_handlers::pagerduty (
  $dependencies = {
    'redphone' => { provider => $gem_provider },
  }
) inherits sensu_handlers {

  create_resources(
    package,
    $dependencies,
    { before => Sensuclassic::Handler['pagerduty'] }
  )

  sensuclassic::filter { 'page_filter':
    attributes => { 'check' => { 'page' => true } },
  } ->
  sensuclassic::filter { 'execution_timed_out_page_filter':
    attributes => { 'check' => { 'output' => 'Execution timed out' } },
    negate     => true,
  } ->
  sensuclassic::filter { 'unknown_no_metrics_received_page_filter':
    attributes => { 'check' => { 'output' => "UNKNOWN: no metrics received from graphite\n" } },
    negate     => true,
  } ->
  sensuclassic::handler { 'pagerduty':
    type    => 'pipe',
    source  => 'puppet:///modules/sensu_handlers/pagerduty.rb',
    config  => {
      teams => $teams,
    },
    filters => flatten([
      'page_filter',
      'execution_timed_out_page_filter',
      'unknown_no_metrics_received_page_filter',
      $sensu_handlers::num_occurrences_filter_for_pagerduty,
    ]),
  } ->
  # If we are going to send pagerduty alerts, we need to be sure it actually is up
  mon_check { 'check_pagerduty':
    check_every => '60m',
    command  => '/usr/lib/nagios/plugins/check_http -S -H events.pagerduty.com -e 404',
    runbook  => $sensu_handlers::pagerduty_runbook,
  }

}
