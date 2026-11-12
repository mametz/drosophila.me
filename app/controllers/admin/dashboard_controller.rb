module Admin
  class DashboardController < ApplicationController
    skip_after_action :record_usage
    before_action :require_admin

    def show
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @stats = UsageStats.new
      @overview = @stats.overview
      @engagement = @stats.engagement
      @growth = @stats.monthly_growth
      @cumulative = @stats.cumulative_accounts
      @recent = @stats.recent_activity
      @years = @stats.years
      @monthly_cohorts = @stats.cohorts("month", 12)
      @yearly_cohorts = @stats.cohorts("year", 12)
      @activation = @stats.activation
      @lifecycle = @stats.lifecycle
      @cross_sizes = @stats.size_buckets("crosses")
      @stock_sizes = @stats.size_buckets("stocks")
      @top_accounts = @stats.top_accounts
      @domains = @stats.domains
      @countries = @stats.countries
      @personal_share = @stats.personal_email_share
      @heatmap = @stats.heatmap
      @weekdays = @stats.weekday_split
      @cross_features = @stats.cross_features
      @generations = @stats.generations
      @balancers = @stats.top_list_entries("balancers")
      @lethal = @stats.top_list_entries("lethal")
      @sources = @stats.stock_sources
      @stock_features = @stats.stock_features
      @temperatures = @stats.room_temperatures
      @pages = @stats.pages
      @devices = @stats.devices
      @system = @stats.system
      @elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      response.headers["Cache-Control"] = "no-store"
    end

    private

    # Anyone else gets the ordinary not-found page, so the page's existence isn't advertised.
    def require_admin
      render file: Rails.public_path.join("404.html"), status: :not_found, layout: false unless Current.user&.admin?
    end
  end
end
