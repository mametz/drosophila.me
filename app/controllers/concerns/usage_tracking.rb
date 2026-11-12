# Counts requests for the admin stats page: which kinds of page are used, and
# which accounts were active on which day. Bots and failed requests are skipped.
module UsageTracking
  extend ActiveSupport::Concern

  BOT = /bot|crawl|spider|slurp|facebookexternalhit|preview|monitor|uptime|curl|wget|python|go-http|headless/i

  included do
    after_action :record_usage
  end

  private

  def record_usage
    return if response.status >= 400 || request.user_agent.blank? || request.user_agent.match?(BOT)

    user = authenticated? && Current.user
    user = nil if user&.destroyed?
    ActiveRecord::Base.transaction(requires_new: true) do
      PageView.record(usage_page_key, signed_in: user.present?)
      ActivityDay.record(user) if user
    end
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.warn("Usage tracking skipped: #{e.class}: #{e.message}")
  end

  def usage_page_key
    key = "#{controller_path}##{action_name}"
    format = request.format&.symbol
    format.nil? || %i[html turbo_stream].include?(format) ? key : "#{key}.#{format}"
  end
end
