require 'time'

class ArchivesSpaceService < Sinatra::Base

  def self.next_available_number_for_year(year)
    used_numbers = DB.open(true) do |db|
      db[:accession]
        .where(:id_0 => year)
        .exclude(:id_1 => nil)
        .select_map(:id_1)
    end

    numeric_values = used_numbers.each_with_object({}) do |raw_value, acc|
      value = raw_value.to_s.strip
      next unless value.match?(/\A\d+\z/)

      acc[value.to_i] = true
    end

    candidate = 1
    candidate += 1 while numeric_values[candidate]
    candidate
  end

  Endpoint.post('/plugins/generate_accession_identifiers/next')
    .description("Generate a new identifier based on the year and a running number")
    .params()
    .permissions([])
    .returns([200, "{'year', 'YYYY', 'number', N}"]) \
  do
    year = Time.now.strftime('%Y')
    number = self.class.next_available_number_for_year(year)

    json_response(:year => year, :number => number)
  end

end
