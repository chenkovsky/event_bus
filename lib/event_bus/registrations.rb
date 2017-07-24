require 'singleton'

class EventBus

  private

  class Registrations
    include Singleton

    def announce(event_name, payload)
      event_name = event_name.to_sym
      full_payload = {event_name: event_name}.merge(payload)
      return unless listeners.key? event_name
      listeners[event_name].each do |listener|
        pass_event_to listener, event_name, full_payload
      end
    end

    def clear
      listeners.clear
    end

    def add_method(pattern, listener, method_name)
      pattern = pattern.to_sym
      add_listeners pattern, Registration.new(pattern, listener, method_name)
    end

    def add_block(pattern, &blk)
      pattern = pattern.to_sym
      add_listeners pattern, BlockRegistration.new(pattern, blk)
    end

    def on_error(&blk)
      @error_handler = blk
    end

    def remove_subscriber(subscriber)
      return unless subscriber.is_a?(Registration) ||
                    subscriber.is_a?(BlockRegistration)
      return unless listeners.key?(subscriber.pattern)
      arr = listeners[subscriber.pattern]
      arr.delete subscriber
      listeners.delete subscriber.pattern if arr.empty?
    end

    def remove_event(event_name)
      listeners.delete event_name
    end

    def last_subscriber(event_name)
      return nil unless listeners.key? event_name
      arr = listeners[event_name]
      return nil if arr.empty?
      arr[-1]
    end

    private

    def listeners
      @listeners ||= {}
    end

    def add_listeners(pattern, registration)
      listeners[pattern] ||= []
      listeners[pattern] << registration
    end

    def error_handler
      @error_handler
    end

    def pass_event_to(listener, event_name, payload)
      begin
        listener.respond(event_name, payload)
      rescue => error
        error_handler.call(listener.receiver, payload.merge(error: error)) if error_handler
      end
    end

    Registration = Struct.new(:pattern, :listener, :method_name) do
      def respond(event_name, payload)
        listener.send(method_name, payload) if pattern === event_name
      end

      def receiver
        listener
      end
    end

    BlockRegistration = Struct.new(:pattern, :block) do
      def respond(event_name, payload)
        block.call(payload) if pattern === event_name
      end

      def receiver
        block
      end
    end

  end

end

