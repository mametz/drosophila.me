module ApplicationHelper
  def nav_link(label, path, section: nil)
    current = section ? controller_name == section : current_page?(path)
    link_to label, path, "aria-current": ("page" if current)
  end

  def tab_link(label, path, current)
    link_to label, path, "aria-current": ("page" if current)
  end
end
