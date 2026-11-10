# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

require 'json'

module MorphicHelix
  # Line-oriented JSON protocol ("mh-jsonl/1") used across every process boundary in the system.
  # One request per line, one response per line, both UTF-8 JSON objects.
  #
  # Request  {"protocol":"mh-jsonl/1","id":"<string>","op":"<string>","input":{...},
  #           "limits":{"timeout_s":<number>,"max_steps":<integer>}}
  # Response {"protocol":"mh-jsonl/1","id":"<same id>","op":"<same op>","ok":true|false,
  #           "result":<any|null>,"error":{"type":"<string>","message":"<string>"}|null,
  #           "evidence":{"tool":"<string>","argv":[...],"exit_status":<int|null>,
  #                       "duration_s":<number>,"transcript_sha256":"<hex>","transcript":"<text>"}}
  module Protocol
    VERSION = 'mh-jsonl/1'
    DEFAULT_LIMITS = { 'timeout_s' => 30, 'max_steps' => 10_000 }.freeze

    class ProtocolError < StandardError; end

    module_function

    def request(id:, op:, input:, limits: {})
      { 'protocol' => VERSION, 'id' => id.to_s, 'op' => op.to_s, 'input' => input,
        'limits' => DEFAULT_LIMITS.merge(limits.transform_keys(&:to_s)) }
    end

    def response(req, ok:, result: nil, error: nil, evidence: nil)
      { 'protocol' => VERSION, 'id' => req['id'], 'op' => req['op'], 'ok' => ok, 'result' => result,
        'error' => error, 'evidence' => evidence }
    end

    def encode(obj) = "#{JSON.generate(obj)}\n"

    def decode_request(line)
      obj = JSON.parse(line)
      raise ProtocolError, 'not a JSON object' unless obj.is_a?(Hash)
      raise ProtocolError, "unsupported protocol #{obj['protocol'].inspect}" unless obj['protocol'] == VERSION
      %w[id op input].each { |k| raise ProtocolError, "missing field #{k}" unless obj.key?(k) }
      raise ProtocolError, 'id must be a string' unless obj['id'].is_a?(String)
      raise ProtocolError, 'op must be a string' unless obj['op'].is_a?(String)
      raise ProtocolError, 'input must be an object' unless obj['input'].is_a?(Hash)

      obj['limits'] = DEFAULT_LIMITS.merge(obj['limits'] || {})
      obj
    rescue JSON::ParserError => e
      raise ProtocolError, "invalid JSON: #{e.message}"
    end

    def decode_response(line)
      obj = JSON.parse(line)
      raise ProtocolError, "unsupported protocol #{obj['protocol'].inspect}" unless obj['protocol'] == VERSION
      %w[id op ok].each { |k| raise ProtocolError, "missing field #{k}" unless obj.key?(k) }
      obj
    end
  end
end
