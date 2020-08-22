# Wraps google sheets api classes
class GoogleSheet
  GOOGLE_APPLICATION_CREDENTIALS = Base64.decode64(ENV['ENCODED_GOOGLE_APPLICATION_CREDENTIALS'])

  class << self
    def worksheet(spreadsheet_key, range, hash_array: false)
      worksheet = exponential_backoff do
        google_sheets.get_spreadsheet_values(spreadsheet_key, range).values
      end
      hash_array ? to_hash_array(worksheet) : worksheet
    end

    def range(spreadsheet_key, range)
      Hash.new({}).tap do |the_range|
        worksheet = exponential_backoff do
          google_sheets.get_spreadsheet_values(spreadsheet_key, range)
        end
        the_range[:values] = worksheet.values
        the_range[:boundaries] = boundaries(worksheet.range)
      end
    end

    private def boundaries(a1notation_range)
      Hash.new({}).tap do |the_boundaries|
        a1_notation = a1notation_range.split('!').last.split(':')
        the_boundaries[:start_column], the_boundaries[:start_row] = a1_notation.first.scan(/\D+|\d+/)
        the_boundaries[:end_column], the_boundaries[:end_row] = a1_notation.last.split(':').last.scan(/\D+|\d+/)
      end
    end

    def spreadsheet(spreadsheet_key)
      # We use a backoff here to avoid hitting the Google Sheets API rate limit per 100 seconds
      exponential_backoff do
        google_sheets.get_spreadsheet(spreadsheet_key)
      end
    end

    def exponential_wait_time(n)
      2**n.tap { |wait_time| puts "wait time: #{wait_time}s" }
    end

    # rubocop:disable Style/RescueStandardError
    def exponential_backoff
      (0..10).each do |n|
        return yield
      rescue => error
        puts error.inspect
        sleep(exponential_wait_time(n))
        next
      end
      raise 'max number of retries for rate limit exceeded'
    end
    # rubocop:enable Style/RescueStandardError

    def google_sheets
      Google::Apis::SheetsV4::SheetsService.new.tap do |service|
        service.authorization = decoded_google_authorization_from_env
      end
    end

    def decoded_google_authorization_from_env
      Google::Auth::ServiceAccountCredentials.make_creds(
        scope: 'https://www.googleapis.com/auth/spreadsheets',
        json_key_io: StringIO.new(GOOGLE_APPLICATION_CREDENTIALS)
      )
    end

    def to_hash_array(cells_with_header_row)
      cells_with_header_row.drop(1).map do |row|
        # need to remove leading and trailing whitespace from all cells or there will be subtle bugs
        stripped = row.map(&:strip)
        cells_with_header_row[0].zip(stripped).to_h
      end
    end

    def title(spreadsheet_key)
      spreadsheet(spreadsheet_key).properties.title
    end
  end
end
