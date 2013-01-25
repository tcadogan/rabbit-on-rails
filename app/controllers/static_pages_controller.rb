require 'bunny'
require 'json'

class StaticPagesController < ApplicationController
  def home
  end
  def create
  end


  # Extracts the connection string for the rabbitmq service from the
  # service information provided by Cloud Foundry in an environment
  # variable.
  def self.amqp_url
    services = JSON.parse(ENV['VCAP_SERVICES'], :symbolize_names => true)
    url = services.values.map do |srvs|
      srvs.map do |srv|
        if srv[:label] =~ /^rabbitmq-/
          srv[:credentials][:url]
        else
          []
        end
      end
    end.flatten!.first
  end

  # Opens a client connection to the RabbitMQ service, if one isn't
  # already open.  This is a class method because a new instance of
  # the controller class will be created upon each request.  But AMQP
  # connections can be long-lived, so we would like to re-use the
  # connection across many requests.
  def self.client
    unless @client
      c = Bunny.new(amqp_url)
      c.start
      @client = c
    end
    @client
  end

  # Return the "nameless exchange", pre-defined by AMQP as a means to
  # send messages to specific queues.  Again, we use a class method to
  # share this across requests.
  def self.nameless_exchange
    @nameless_exchange ||= client.exchange('')
  end

  # Return a queue named "messages".  This will create the queue on
  # the server, if it did not already exist.  Again, we use a class
  # method to share this across requests.
  def self.messages_queue
    @messages_queue ||= client.queue("messages")
  end

  # The action for our publish form.
  def publish
    # Send the message from the form's input box to the "messages"
    # queue, via the nameless exchange.  The name of the queue to
    # publish to is specified in the routing key.
    StaticPagesController.nameless_exchange.publish params[:message],
                                             :key => "messages"
    # Notify the user that we published.
    flash[:published] = true
    redirect_to home_index_path
  end

  def get
    # Synchronously get a message from the queue
    msg = StaticPagesController.messages_queue.pop
    # Show the user what we got
    flash[:got] = msg[:payload]
    redirect_to home_index_path
  end
end

