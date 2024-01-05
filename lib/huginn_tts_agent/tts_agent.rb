module Agents
  class TtsAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'never'

    description do
      <<-MD
      The Tts Agent interacts with different providers like Elevenlabs's api.

      The `provider` can be like elevenlabs.

      `debug` is used for verbose mode.

      `api_key` is mandatory for the authentication.

      `text` is the wanted text to convert.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "history_item_id": "XXXXXXXXXXXXXXXXXXXX",
            "request_id": "XXXXXXXXXXXXXXXXXXXX",
            "voice_id": "21m00Tcm4TlvDq8ikWAM",
            "model_id": "eleven_multilingual_v2",
            "voice_name": "XXXXXX",
            "voice_category": "premade",
            "text": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
            "date_unix": 1704351242,
            "character_count_change_from": 0,
            "character_count_change_to": XX,
            "content_type": "audio/mpeg",
            "state": "created",
            "settings": {
              "similarity_boost": 0.75,
              "stability": 0.5,
              "style": 0.0,
              "use_speaker_boost": true
            },
            "feedback": null,
            "share_link_id": null
          }
    MD

    def default_options
      {
        'type' => 'elevenlabs',
        'api_key' => '',
        'text' => '',
        'debug' => 'false',
        'expected_receive_period_in_days' => '2',
      }
    end

    form_configurable :type, type: :array, values: ['elevenlabs']
    form_configurable :api_key, type: :string
    form_configurable :text, type: :string
    form_configurable :debug, type: :boolean
    form_configurable :expected_receive_period_in_days, type: :string
    def validate_options
      errors.add(:base, "type has invalid value: should be 'elevenlabs'") if interpolated['type'].present? && !%w(elevenlabs).include?(interpolated['type'])

      unless options['api_key'].present? || !['elevenlabs'].include?(options['type'])
        errors.add(:base, "api_key is a required field")
      end

      unless options['text'].present?
        errors.add(:base, "text is a required field")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          log event
          trigger_action
        end
      end
    end

    def check
      trigger_action
    end

    private

    def set_credential(name, value)
      c = user.user_credentials.find_or_initialize_by(credential_name: name)
      c.credential_value = value
      c.save!
    end

    def log_curl_output(code,body)

      log "request status : #{code}"

      if interpolated['debug'] == 'true'
        log "request status : #{code}"
        log "body"
        log body
      end

    end

    def elevenlabs()

      uri = URI.parse("https://api.elevenlabs.io/v1/text-to-speech/21m00Tcm4TlvDq8ikWAM")
      request = Net::HTTP::Post.new(uri)
      request.content_type = "application/json"
      request["Xi-Api-Key"] = interpolated['api_key']
      request.body = JSON.dump({
        "model_id" => "eleven_multilingual_v2",
        "text" => interpolated['text']
      })

      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      log_curl_output(response.code,response.body)

      uri = URI.parse("https://api.elevenlabs.io/v1/history")
      request = Net::HTTP::Get.new(uri)
      request["Xi-Api-Key"] = interpolated['api_key']

      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      log_curl_output(response.code,response.body)

      payload = JSON.parse(response.body)

      last_item = payload['last_history_item_id']
      result_hash = payload['history'].find { |hash| hash["history_item_id"] == last_item }
      create_event payload: result_hash
    end

    def trigger_action

      case interpolated['type']
      when "elevenlabs"
        elevenlabs()
      else
        log "Error: type has an invalid value (#{type})"
      end
    end
  end
end
