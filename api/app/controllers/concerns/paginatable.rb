module Paginatable
  extend ActiveSupport::Concern

  MAX_PER_PAGE = 100

  private

  def paginate(scope)
    page = [params.fetch(:page, 1).to_i, 1].max
    per = params.fetch(:per_page, 25).to_i.clamp(1, MAX_PER_PAGE)

    response.headers["X-Total-Count"] = scope.count.to_s
    response.headers["X-Page"] = page.to_s
    response.headers["X-Per-Page"] = per.to_s

    scope.offset((page - 1) * per).limit(per)
  end
end
