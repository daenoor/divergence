module Divergence
  class RequestParser
    def initialize(env)
      @req = Rack::Request.new(env)
    end

    def raw
      @req
    end

    def is_webhook?
      subdomain == "divergence" and 
      @req.env['PATH_INFO'] == "/update" and
      @req.post?
    end

    def host_parts
      @req.host.split(".")
    end

    def has_subdomain?
      host_parts.length > 2
    end

    def subdomain
      if has_subdomain?
        host_parts.shift
      else
        nil
      end
    end

    def project_and_branch
      if has_subdomain?
        host_parts.reverse.drop(3)
      end
    end

    def branch
      if has_subdomain?
        project, branch = project_and_branch
        hg = HgManager.new(find_repo(project))

        hg.discover(branch)
      else
        nil
      end
    end

    def method_missing(meth, *args, &block)
      raw.send(meth, *args)
    end
  end
end