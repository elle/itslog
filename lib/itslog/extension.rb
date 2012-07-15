module Itslog
  module BufferedLoggerExtension
    extend ActiveSupport::Concern
    include Itslog::Configure
    attr_accessor :namespace

    def namespace
      @namespace ||= ''
    end

    def add_with_format(severity, message = nil, progname = nil, &block)
      return if (@level && @level > severity) || message.nil?

      time    = Time.now.strftime(Itslog::Configure.timestamp_format)
      message = Itslog::Configure.message_color + message.to_s.strip
      msg     = namespace.present? ? '' : "\n"
      msg     << Itslog::Configure.color(namespace, severity)
      msg     << Itslog::Configure.format.dup

      { '%t'  => time,
        '%n_' => namespace.present? ? namespace + ' ' : namespace,
        '%n'  => namespace,
        '%m'  => message
      }.each do |k,v|
        msg.gsub! k,v
      end

      @namespace = ''

      add_without_format severity, msg, progname, &block
    end

    included do
      alias_method_chain :add, :format
    end
  end

  module LogSubscriberExtension
    extend ActiveSupport::Concern

    def call_with_namespace(message, *args)
      namespace = message.split('.').last if logger
      if logger.respond_to?(:namespace=)
        logger.namespace = namespace.present? ? namespace : ''
      end
      call_without_namespace(message, *args)
    end

    included do
      alias_method_chain :call, :namespace
    end
  end
end

if defined? Mongoid::Logger
  class Mongoid::Logger
    delegate :namespace=, :to => :logger, :allow_nil => true
  end

  class Mongo::Connection
    def log_operation_with_namespace(name, payload)
      @logger.namespace = 'mongo' if @logger
      log_operation_without_namespace(name, payload)
    end

    alias_method_chain :log_operation, :namespace
  end
end
