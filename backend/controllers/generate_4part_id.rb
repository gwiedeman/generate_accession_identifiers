require 'time'
require 'sequel'

class ArchivesSpaceService < Sinatra::Base

  def next_available_number_for_year(year)
    puts "[DEBUG] Starting next_available_number_for_year with year: #{year}"
    
    used_numbers = DB.open(true) do |db|
      puts "[DEBUG] Opening database connection"
      
      result = db[:accession]
        .where(id_0: year)
        .where_not(id_1: nil)
        .select_map(:id_1)
      
      puts "[DEBUG] Query result type: #{result.class}"
      puts "[DEBUG] Query result count: #{result.count}"
      puts "[DEBUG] Query result sample: #{result.first(5).inspect}"
      
      result
    end

    numeric_values = used_numbers.each_with_object({}) do |raw_value, acc|
      puts "[DEBUG] Processing raw_value: #{raw_value.inspect} (class: #{raw_value.class})"
      
      value = raw_value.to_s.strip
      puts "[DEBUG] After to_s.strip: #{value.inspect}"
      
      if value =~ /\A\d+\z/
        puts "[DEBUG] Value matches numeric pattern, converting: #{value.to_i}"
        acc[value.to_i] = true
      else
        puts "[DEBUG] Value does NOT match numeric pattern, skipping"
      end
      
      next unless value =~ /\A\d+\z/
    end

    puts "[DEBUG] Final numeric_values hash: #{numeric_values.inspect}"
    
    candidate = 1
    puts "[DEBUG] Starting candidate search from: #{candidate}"
    candidate += 1 while numeric_values[candidate]
    
    puts "[DEBUG] Final candidate number: #{candidate}"
    candidate
  end

  Endpoint.post('/plugins/generate_accession_identifiers/next')
    .description("Generate a new identifier based on the year and a running number")
    .params()
    .permissions([])
    .returns([200, "{'year', 'YYYY', 'number', N}"]) \
  do
    puts "[DEBUG] Endpoint called"
    
    year = Time.now.strftime('%Y')
    puts "[DEBUG] Current year: #{year}"
    
    begin
      number = next_available_number_for_year(year)
      puts "[DEBUG] Calculated number: #{number}"
      
      json_response(:year => year, :number => number)
    rescue => e
      puts "[DEBUG] ERROR: #{e.class}"
      puts "[DEBUG] ERROR MESSAGE: #{e.message}"
      puts "[DEBUG] ERROR BACKTRACE:"
      puts e.backtrace.first(10).map { |line| "  #{line}" }.join("\n")
      raise
    end
  end

end