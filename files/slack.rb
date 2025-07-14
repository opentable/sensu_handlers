#!/usr/bin/env ruby

require "json"
require "net/http"
require "#{File.dirname(__FILE__)}/base"

class Slack < BaseHandler
  #SLACK_BOT_TOKEN = "see from global.yaml"
  def slack_token
    handler_settings['slack_bot_token']
  end

  def slack_channel
    # Get the channel name and remove leading # if present
    channel = team_data('notifications_slack_channel')
    return nil if channel.nil? || channel.empty?
    channel.gsub(/^#/, '')
  end

  def compact_messages
    team_compact = team_data('slack_compact_message')
    return team_compact unless team_compact.nil?
    handler_settings['compact_message'] || false
  end

  def check_name
    @event['check']['name']
  end

  def pager_channel_keys
    %w[ pages_slack_channel ]
  end

  def channel_keys
    %w[ slack_channels notifications_slack_channel ]
  end

  def default_pager_channel
    "##{team_name}-pages"
  end

  def message_attachment
    # Create rich text blocks attachment for the API call
    case @event['check']['status']
    when 0
      status_emoji = "white_check_mark"
      status = 'OK'
      color = "#4CBB17"  # Green
    when 1
      status_emoji = "warning"
      status = 'WARNING'
      color = "#FFA500"  # Orange
    when 2
      status_emoji = "x"
      status = 'CRITICAL'
      color = "#FF0000"  # Red
    else
      status_emoji = "question"
      status = 'UNKNOWN'
      color = "#800080"  # Purple
    end

    # Build rich text elements
    elements = []
    
    # Status line with emoji and bold text
    elements << {"type" => "emoji", "name" => status_emoji}
    elements << {"type" => "text", "text" => " "}
    elements << {"type" => "text", "text" => status, "style" => {"bold" => true}}
    elements << {"type" => "text", "text" => "\n"}
    
    # Host information
    elements << {"type" => "text", "text" => "Host:", "style" => {"bold" => true}}
    elements << {"type" => "text", "text" => " #{client_display_name}\n"}
    
    # Check information
    elements << {"type" => "text", "text" => "Check:", "style" => {"bold" => true}}
    elements << {"type" => "text", "text" => " "}
    elements << {"type" => "link", "url" => dashboard_link, "text" => check_name}
    elements << {"type" => "text", "text" => "\n"}
    
    # Output for warning/critical
    if event_is_critical? or event_is_warning?
      elements << {"type" => "text", "text" => "Output:", "style" => {"bold" => true}}
      elements << {"type" => "text", "text" => " "}
    end

    # Create the blocks structure
    blocks = [{"type" => "rich_text_section", "elements" => elements}]
    
    # Add preformatted output for warning/critical
    if event_is_critical? or event_is_warning?
      blocks << {
        "type" => "rich_text_preformatted",
        "elements" => [{"type" => "text", "text" => @event['check']['output']}]
      }
      
      # Add runbook if available
      if runbook && !runbook.empty?
        runbook_elements = [
          {"type" => "text", "text" => "Runbook:", "style" => {"bold" => true}},
          {"type" => "text", "text" => " "},
          {"type" => "link", "url" => runbook}
        ]
        blocks << {"type" => "rich_text_section", "elements" => runbook_elements}
      end
    end

    # Return attachment structure
    [{
      "color" => color,
      "blocks" => [{
        "type" => "rich_text",
        "block_id" => "sensu_alert_#{Time.now.to_i}",
        "elements" => blocks
      }]
    }]
  end

  def handle
    channel = slack_channel
    if channel.nil? || channel.empty?
      puts "No Slack channel configured for team #{team_name}"
      return
    end
    
    token = slack_token
    if token.nil? || token.empty?
      puts "No Slack bot token configured for team #{team_name}"
      return
    end
    
    post_to_slack(channel, token)
  end

  def post_to_slack(channel, token)
    puts "channel: #{channel}"
    puts "token: #{token ? 'present' : 'missing'}"
    puts "team_data: #{team_data.inspect}"
    
    # Prepare the API payload with attachments
    payload = {
      "channel" => channel,
      "username" => "Sensu",
      "attachments" => message_attachment
    }
    
    # Use Slack Web API
    uri = URI("https://slack.com/api/chat.postMessage?username=Sensu")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri.path)
    request['Authorization'] = "Bearer #{token}"
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json
    
    http.request(request).tap do |res|
      puts "Slack API response: #{res.code} - #{res.body}"
      log res.inspect unless res.is_a?(Net::HTTPSuccess)
    end
  end

end
