module Sidekiq
  module Failures
    module WebExtension
      def self.registered(app)
        view_path = File.join(File.expand_path("..", __FILE__), "views")

        app.get "/failures" do
          @count = (params[:count] || 25).to_i
          (@current_page, @total_size, @failures) = page(LIST_KEY, params[:page], @count, reverse: true)
          @failures = @failures.map { |msg, score| Sidekiq::SortedEntry.new(nil, score, msg) }

          render(:erb, File.read(File.join(view_path, "failures.erb")))
        end

        app.get "/failures/:key" do
          halt 404 unless params["key"]

          @failure = FailureSet.new.fetch(*parse_params(params["key"])).first
          redirect "#{root_path}failures" if @failure.nil?
          render(:erb, File.read(File.join(view_path, "failure.erb")))
        end

        app.post "/failures" do
          halt 404 unless params["key"]

          params["key"].each do |key|
            job = FailureSet.new.fetch(*parse_params(key)).first
            next unless job

            if params["retry"]
              job.retry_failure
            elsif params["delete"]
              job.delete
            end
          end

          redirect_with_query("#{root_path}failures")
        end

        app.post "/failures/:key" do
          halt 404 unless params["key"]

          job = FailureSet.new.fetch(*parse_params(params["key"])).first
          if job
            if params["retry"]
              job.retry_failure
            elsif params["delete"]
              job.delete
            end
          end
          redirect_with_query("#{root_path}failures")
        end

        app.post "/failures/all/reset" do
          Sidekiq::Failures.reset_failure_count
          redirect "#{root_path}failures"
        end

        app.post "/failures/all/delete" do
          FailureSet.new.clear
          redirect "#{root_path}failures"
        end

        app.post "/failures/all/retry" do
          FailureSet.new.retry_all_failures
          redirect "#{root_path}failures"
        end

        app.get "/filter/failures" do
          redirect "#{root_path}failures"
        end

        app.post "/filter/failures" do
          @failures = Sidekiq::Failures::FailureSet.new.scan("*#{params[:substr]}*")
          @current_page = 1
          @count = @total_size = @failures.count
          render(:erb, File.read(File.join(view_path, "failures.erb")))
        end
      end
    end
  end
end
