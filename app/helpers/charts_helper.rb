# Small inline SVG charts for the admin stats page, so it needs no chart library.
# Colours come from the stylesheet, so they follow light and dark mode.
module ChartsHelper
  WIDTH = 720
  LEFT = 52
  BOTTOM = 28
  TOP = 10

  # points: [[Date or label, number], ...]. Each bar shows its value on hover.
  def column_chart(points, summary:, height: 190, label: ->(key) { key.to_s }, tip: label, css: "series-1")
    return empty_chart if points.empty?

    max = nice_ceiling(points.map(&:last).max)
    plot_h = height - BOTTOM - TOP
    slot = (WIDTH - LEFT).to_f / points.size
    bar_w = [ slot * 0.78, 1 ].max
    bars = points.each_with_index.map do |(key, value), i|
      h = max.zero? ? 0 : (value.to_f / max * plot_h)
      x = LEFT + i * slot + (slot - bar_w) / 2
      tag.rect(x: x.round(2), y: (TOP + plot_h - h).round(2), width: bar_w.round(2), height: [ h, value.positive? ? 1 : 0 ].max.round(2),
               class: css, rx: [ bar_w / 6, 2 ].min.round(2)) do
        tag.title("#{tip.call(key)}: #{number_with_delimiter(value)}")
      end
    end
    svg_frame(height, summary, grid(max, plot_h) + safe_join(bars) + x_labels(points, slot, height, label))
  end

  # A filled line, used for running totals.
  def line_chart(points, summary:, height: 190, label: ->(key) { key.to_s }, tip: label)
    return empty_chart if points.size < 2

    max = nice_ceiling(points.map(&:last).max)
    plot_h = height - BOTTOM - TOP
    step = (WIDTH - LEFT).to_f / (points.size - 1)
    coords = points.each_with_index.map do |(_, value), i|
      [ (LEFT + i * step).round(2), (TOP + plot_h - (max.zero? ? 0 : value.to_f / max * plot_h)).round(2) ]
    end
    line = coords.map { |x, y| "#{x},#{y}" }.join(" ")
    area = "#{LEFT},#{TOP + plot_h} #{line} #{coords.last[0]},#{TOP + plot_h}"
    dots = points.each_with_index.map do |(key, value), i|
      tag.circle(cx: coords[i][0], cy: coords[i][1], r: 6, class: "chart-hit") { tag.title("#{tip.call(key)}: #{number_with_delimiter(value)}") }
    end
    body = grid(max, plot_h) + tag.polygon(points: area, class: "chart-area") +
           tag.polyline(points: line, class: "chart-line") + safe_join(dots) +
           x_labels(points, step, height, label, offset: 0)
    svg_frame(height, summary, body)
  end

  # rows: [[label, number], ...] as horizontal bars in HTML.
  def bar_list(rows, total: nil, format: ->(n) { number_with_delimiter(n) })
    max = rows.map(&:last).max.to_f
    tag.div(class: "bar-list") do
      safe_join(rows.map do |label, value|
        share = total.to_f.positive? ? " · #{number_to_percentage(value * 100.0 / total, precision: 0)}" : ""
        tag.div(class: "bar-row") do
          tag.span(label, class: "bar-label") +
            tag.span(class: "bar-track") { tag.span(class: "bar-fill", style: "width: #{max.positive? ? (value / max * 100).round(1) : 0}%") } +
            tag.span("#{format.call(value)}#{share}", class: "bar-value")
        end
      end)
    end
  end

  # A cell shaded by value between 0 and 1.
  def heat_cell(text, share, title: nil)
    tag.td(text, class: "heat", style: "--v: #{share.to_f.clamp(0, 1).round(3)}", title: title)
  end

  def percent(part, whole, precision: 0)
    return "–" if whole.to_f.zero? || part.nil?

    number_to_percentage(part.to_f * 100 / whole.to_f, precision: precision)
  end

  # "+12% vs the 30 days before", or a plain note when there's nothing to compare.
  def change(current, previous, days)
    return tag.span("none in the #{days} days before", class: "delta") if previous.to_i.zero?

    diff = (current - previous) * 100.0 / previous
    tag.span("#{diff >= 0 ? "+" : "−"}#{number_to_percentage(diff.abs, precision: 0)} vs the #{days} days before",
             class: [ "delta", diff >= 0 ? "delta-up" : "delta-down" ])
  end

  def month_label = ->(date) { date.strftime("%b %Y") }
  def month_tip = ->(date) { date.strftime("%B %Y") }
  def day_label = ->(date) { date.strftime("%-d %b") }
  def week_tip = ->(date) { "Week of #{date.strftime("%-d %b %Y")}" }

  private

  def svg_frame(height, summary, body)
    tag.svg(body, viewBox: "0 0 #{WIDTH} #{height}", class: "chart", role: "img", "aria-label": summary,
            preserveAspectRatio: "xMidYMid meet")
  end

  def empty_chart
    tag.p("No data yet.", class: "muted small")
  end

  def grid(max, plot_h)
    safe_join([ 0, max / 2.0, max ].uniq.map do |v|
      y = (TOP + plot_h - (max.zero? ? 0 : v / max * plot_h)).round(2)
      tag.line(x1: LEFT, x2: WIDTH, y1: y, y2: y, class: "chart-grid") +
        content_tag(:text, compact_number(v), x: LEFT - 6, y: y + 4, class: "chart-axis", "text-anchor": "end")
    end)
  end

  # About six labels, spread evenly, plus the last one.
  def x_labels(points, slot, height, label, offset: nil)
    every = [ (points.size / 6.0).ceil, 1 ].max
    offset ||= slot / 2
    picks = (0...points.size).select { |i| (i % every).zero? }
    last = points.size - 1
    picks.pop if picks.size > 1 && last - picks.last < every
    picks << last unless picks.include?(last)
    safe_join(picks.map do |i|
      x = i.zero? ? LEFT : (i == last ? WIDTH : (LEFT + i * slot + offset).round(2))
      anchor = i.zero? ? "start" : (i == last ? "end" : "middle")
      content_tag(:text, label.call(points[i][0]), x: x, y: height - 6, class: "chart-axis", "text-anchor": anchor)
    end)
  end

  def nice_ceiling(value)
    value = value.to_f
    return 1 if value <= 1

    magnitude = 10**Math.log10(value).floor
    [ 1, 2, 2.5, 5, 10 ].map { |m| m * magnitude }.find { |n| n >= value }
  end

  def compact_number(value)
    value >= 10_000 ? "#{(value / 1000.0).round}k" : (value % 1).zero? ? value.to_i.to_s : value.round(1).to_s
  end
end
