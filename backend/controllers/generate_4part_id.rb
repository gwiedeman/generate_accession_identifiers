require 'time'
require 'sequel'
require 'json'

class ArchivesSpaceService < Sinatra::Base

  def next_available_number_for_year(year, repo_id = nil)
    #puts "DEBUG-Accession-ID Starting next_available_number_for_year with year: #{year}, repo_id: #{repo_id.inspect}"

    used_numbers = DB.open(true) do |db|
      #puts "DEBUG-Accession-ID Opening database connection"

      ds = db[:accession].exclude(identifier: nil)
      ds = ds.where(repo_id: repo_id) if repo_id

      rows = ds.select_map(:identifier)

      #puts "DEBUG-Accession-ID Identifier row count: #{rows.count}"
      #puts "DEBUG-Accession-ID Identifier sample: #{rows.first(5).inspect}"

      numbers = rows.map do |ident|
        parsed =
          case ident
          when String
            begin
              JSON.parse(ident)
            rescue JSON::ParserError
              nil
            end
          when Array
            ident
          else
            nil
          end

        # Expecting something like ["2026", "001", nil, nil]
        next nil unless parsed.is_a?(Array)
        next nil unless parsed[0].to_s == year.to_s
        next nil unless parsed[1].to_s =~ /\A\d+\z/

        parsed[1].to_i
      end.compact

      #puts "DEBUG-Accession-ID Parsed number count: #{numbers.count}"
      #puts "DEBUG-Accession-ID Parsed number sample: #{numbers.sort.first(20).inspect}"

      numbers
    end

    numeric_values = used_numbers.each_with_object({}) do |n, acc|
      acc[n] = true
    end

    #puts "DEBUG-Accession-ID Final numeric_values hash keys sample: #{numeric_values.keys.sort.first(20).inspect}"

    candidate = 1
    candidate += 1 while numeric_values[candidate]

    #puts "DEBUG-Accession-ID Final candidate number: #{candidate}"
    candidate
  end

  Endpoint.post('/plugins/generate_accession_identifiers/next')
    .description("Generate a new identifier based on the year and a running number")
    .params()
    .permissions([])
    .returns([200, "{'year', 'YYYY', 'number', N}"]) \
  do
    #puts "DEBUG-Accession-ID Endpoint called"

    year = Time.now.strftime('%Y')
    #puts "DEBUG-Accession-ID Current year: #{year}"

    # If you know the repo, set it here; otherwise nil searches all repos.
    repo_id = nil

    begin
      number = next_available_number_for_year(year, repo_id)
      #puts "DEBUG-Accession-ID Calculated number: #{number}"

      json_response(:year => year, :number => number)
    rescue => e
      puts "DEBUG-Accession-ID ERROR: #{e.class}"
      puts "DEBUG-Accession-ID ERROR MESSAGE: #{e.message}"
      puts "DEBUG-Accession-ID ERROR BACKTRACE:"
      puts e.backtrace.first(10).map { |line| "  #{line}" }.join("\n")
      raise
    end
  end

end