module SortHelper
  def sort_link(relation, column, title, options = {})
    matching_column = column.to_s == params[:sort]
    direction = if matching_column
      (params[:direction] == "asc") ? "desc" : "asc"
    else
      "asc"
    end

    css_classes = ["sortable-link"]
    css_classes << "active" if matching_column
    css_classes += Array(options[:class])

    link_to request.params.merge(sort: column, direction: direction),
      options.merge(class: css_classes.join(" ")) do
      concat title
      concat icon(:"sort_#{direction}") if matching_column
    end
  end
end
