# Wraps google sheets api classes
class GoogleSheet
  GOOGLE_APPLICATION_CREDENTIALS = Base64.decode64(ENV['ENCODED_GOOGLE_APPLICATION_CREDENTIALS'])

  class << self
    def worksheet(spreadsheet_key, range, value_render_option: nil, hash_array: false)
      worksheet = exponential_backoff do
        google_sheets.get_spreadsheet_values(
          spreadsheet_key, range, value_render_option: value_render_option
        ).values
      end
      hash_array ? to_hash_array(worksheet) : worksheet
    end

    def spreadsheet(spreadsheet_key)
      exponential_backoff do
        google_sheets.get_spreadsheet(spreadsheet_key)
      end
    end

    def exponential_backoff
      (0..5).each do |n|
        begin
          return yield
        rescue => error
          puts error.inspect
          sleep(wait_time(n))
          next
        end
      end
      raise 'max number of retries for rate limit exceeded'
    end

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
