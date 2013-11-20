module Divergence
  class Application
    def handle_webhook
      payload = JSON.parse(@req['payload'])

      # Check if we have this project
      # If not clone it and create required directory structure
      # If project exists update cached branch
      path = File.join(config.projects_path, payload['repository']['slug'])
      if File.exists?(path)
        payload['commits'].map { |commit| commit['branch'] }.uniq.each do |branch|
          if @cache.is_cached?(branch)
            Application.log.info "Webhook: updating branch #{branch} on project #{payload['repository']['slug']}"
            config.callback :before_webhook, path, :branch => branch
            hg = HgManager.new(path)
            @cache.sync(branch, hg.switch(branch, force: true))
            config.callback :after_webhook, @cache.path(branch), :branch => branch
          end
        end
      else
        Application.log.info "Webhook: creating project #{payload['repository']['slug']}"
        FileUtils.mkdir(path)
        Mercurial::Repository.clone('ssh://hg@bitbucket.org'+payload['repository']['absolute_url'], File.join(path, 'src'), {})
        FileUtils.ln_s(File.join(path, 'src'), File.join(path, 'app'))
        Application.log.info "Webhook: Successfully created project #{payload['repository']['slug']}"
      end

      ok
    end

    def ok
      [200, {"Content-Type" => "text/html"}, ["OK"]]
    end

    def ignore
      [200, {"Content-Type" => "text/html"}, ["IGNORE"]]
    end
  end
end