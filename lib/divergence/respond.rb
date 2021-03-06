module Divergence
  class Application < Rack::Proxy
    # The main entry point for the application. This is called
    # by Rack.
    def call(env)
      @req = RequestParser.new(env)

      # First, lets find out what subdomain/git branch
      # we're dealing with (if any).
      unless @req.has_subdomain?
        # No subdomain, simply proxy the request.
        return proxy(env)
      end

      # Handle webhooks from Github for updating the current
      # branch if necessary.
      if @req.is_webhook?
        return handle_webhook
      end

      # Lets get down to business.
      begin
        project, branch_name = @req.project_and_branch
        @hg = HgManager.new(repo_path(project))

        # Get the proper branch name using a touch of magic
        branch = @hg.discover(branch_name)

        # Prepare the branch and cache if needed
        path = prepare(branch)
        path.inspect
        
        # If we're requesting a different branch than the
        # one currently loaded, we'll need to link it to
        # the application directory.
        link!(app_path(project), path) unless path.nil?
        
        @active_branch = branch
      rescue Exception => e
        Application.log.error e.message
        return error!(branch)
      end

      # We're finished, pass the request through.
      proxy(env)
    end

    private

    def proxy(env)
      fix_environment!(env)
      
      status, header, body = perform_request(env)

      # By some reason we get arrays instead of strings in headers hash
      # So we need to convert these arrays to strings to make Rack::Lint happy
      header.each_key do |key|
        header[key] = header[key].first if header[key].kind_of?(Array)
      end

      # Remove unwanted headers
      %w(Status status).each do |h|
        header.delete(h) if header.has_key?(h)
      end

      [status, header, body]
    end

    # Sets the forwarding host for the request. This is where
    # the proxy comes in.
    def fix_environment!(env)
      env["HTTP_HOST"] = "#{config.forward_host}:#{config.forward_port}"
    end

    def error!(branch)
      Application.log.error "Branch #{branch} does not exist"
      Application.log.error @req.raw

      public_path = File.expand_path('../../../public', __FILE__)
      file = File.open("#{public_path}/404.html", "r")
      contents = file.read
      file.close

      [404, {"Content-Type" => "text/html"}, [contents]]
    end
  end
end