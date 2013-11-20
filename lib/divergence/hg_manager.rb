module Divergence
  # Manages the configured Git repository
  class HgManager
    attr_reader :current_branch

    def initialize(path)
      @repo_path = path
      @repo = Mercurial::Repository.open(@repo_path)
      @log = Logger.new('./log/git.log')
      @current_branch = current_branch
    end

    def switch(branch, force=false)
      return @repo_path if is_current?(branch) and !force

      update branch
      @repo_path
    end

    # Since underscores are technically not allowed in URLs,
    # but they are allowed in Git branch names, we have to do
    # some magic to possibly convert dashes to underscores
    # so we can load the right branch.
    # Also we have to lookup for features/#{branch} branch to work with HgFlow
    def discover(branch)
      return branch if is_branch?(branch)

      resp = Application.config.callback :on_branch_discover, @repo_path, branch

      unless resp.nil?
        return resp
      end

      #search for branch name ending with provided branch name using wildcard instead of '-'
      search_for = branch.gsub(/-/, '.')+'$'
      branch_regex = Regexp.new(search_for, Regexp::IGNORECASE)
      @repo.branches.each do |b|
        return b.name if branch_regex.match(b.name)
      end

      raise "Unable to automatically detect branch. Given = #{branch}"
    end

    def is_current?(branch)
      @current_branch.to_s == branch
    end

    private

    def current_branch
      @repo.shell.hg('branch')
    end

    def is_branch?(branch)
      !!@repo.branches.by_name(branch)
    end

    def update(branch)
      if @repo.pull
        Application.config.callback :before_pull, @repo_path

        @repo.shell.hg(['update -C ?', branch])

        Application.config.callback :after_pull, @repo_path
      end
    end
  end
end
