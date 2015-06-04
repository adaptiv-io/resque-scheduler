# vim:fileencoding=utf-8
require_relative 'base'

module Resque
  module Scheduler
    module Lock
      class ResilientEval < Base
        LOCKED_SCRIPT = <<-EOF.gsub(/^ {10}/, '')
          if redis.call('GET', KEYS[1]) == ARGV[1]
          then
            redis.call('EXPIRE', KEYS[1], ARGV[2])

            if redis.call('GET', KEYS[1]) == ARGV[1]
            then
              return 1
            end
          end

          return 0
        EOF
        LOCKED_SCRIPT_SHA = "33ec86128053babcacf5e6ce2ab38650016944f6"

        ACQUIRE_SCRIPT = <<-EOF.gsub(/^ {10}/, '')
          if redis.call('SETNX', KEYS[1], ARGV[1]) == 1
          then
            redis.call('EXPIRE', KEYS[1], ARGV[2])
            return 1
          else
            return 0
          end
        EOF
        ACQUIRE_SCRIPT_SHA = "e8b32206079dc65b924a300f12ba621192049d7e"

        def acquire!
          Resque.redis.evalsha(ACQUIRE_SCRIPT_SHA, keys: [key], argv: [value, timeout]).to_i == 1
        rescue
          Resque.redis.eval(ACQUIRE_SCRIPT, keys: [key], argv: [value, timeout]).to_i == 1
        end

        def locked?
          Resque.redis.evalsha(LOCKED_SCRIPT_SHA, keys: [key], argv: [value, timeout]).to_i == 1
        rescue
          Resque.redis.eval(LOCKED_SCRIPT, keys: [key], argv: [value, timeout]).to_i == 1
        end

        def timeout=(seconds)
          if locked?
            @timeout = seconds
          end
          @timeout
        end
      end
    end
  end
end
