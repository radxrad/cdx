module Reports
  class Base
    def self.process(*args)
      new(*args).process
    end

    attr_reader :current_user, :context, :data, :filter, :options, :results

    def initialize(current_user, context, options={})
      @filter ||= {}
      @current_user = current_user
      @context = context
      @data = []
      @options = options
      setup
    end

    def process
      @results = TestResult.query(filter, current_user).execute
      return self
    end

    def sort_by_month
      11.downto(0).each do |i|
        date = Date.today - i.months
        date_key = date.strftime('%Y-%m')
        date_results = results_by_day[date_key]
        data << {
          label: label_monthly(date),
          values: [date_results ? date_results.count : 0]
        }
      end
      return data
    end

    private

    def label_monthly(date)
      "#{I18n.t("date.abbr_month_names")[date.month]}#{date.month == 1 ? " #{date.strftime("%y")}" : ""}"
    end

    def report_since
      filter['since'] = options['since'] || (Date.today - 1.year).iso8601
    end

    def results_by_day
      results['tests'].group_by do |t|
        Date.parse(t['test']['start_time']).strftime('%Y-%m')
      end
    end

    def setup
      site_or_institution
      report_since
    end

    def site_or_institution
      filter['institution.uuid'] = context.institution.uuid if context.institution
      filter['site.path'] = context.site.uuid if context.site
    end

    def users
      results['tests'].group_by { |t| t['test.start_time'] }
    end
  end
end
