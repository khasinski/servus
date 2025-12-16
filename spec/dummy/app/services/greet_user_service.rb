# frozen_string_literal: true

class GreetUserService < Servus::Base
  emits :user_greeted, on: :success
  emits :greeting_failed, on: :failure

  def initialize(name:)
    @name = name
  end

  def call
    ensure_present!(name: @name)

    success(greeting: "Hello, #{@name}!")
  end
end