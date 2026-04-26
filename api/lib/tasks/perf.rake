namespace :perf do
  desc "Generate a large multi-tenant dataset (use DATABASE_NAME=spendflow_perf)"
  task seed: :environment do
    abort "Refusing to run against #{ActiveRecord::Base.connection.current_database}" unless
      ActiveRecord::Base.connection.current_database.end_with?("_perf")

    require_relative "../perf/dataset"
    Perf::Dataset.new(
      companies: ENV.fetch("COMPANIES", 10).to_i,
      requisitions: ENV.fetch("REQUISITIONS", 400_000).to_i
    ).generate!
  end
end

namespace :perf do
  desc "Benchmark hot queries; LABEL=baseline|indexed writes docs/perf/LABEL.json"
  task benchmark: :environment do
    require_relative "../perf/benchmark"
    Perf::Benchmark.new(label: ENV.fetch("LABEL", "run")).run!
  end
end
