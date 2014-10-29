class Repositext

  # Represents the git content repository
  class Repository

    # @param[String, optional] path_to_file_in_repo defaults to current directory
    def initialize(path_to_file_in_repo = Dir.pwd)
      @repo = Rugged::Repository.discover(path_to_file_in_repo)
      @repo_path = @repo.path
      @head_ref = @repo.head
    end

    # Returns the path to the directory that contains the `.git` dir
    def base_dir
      @repo.workdir
    end

    # Returns the repo name, based on name of parent directory
    def name
      @repo.workdir.split('/').last
    end

    # Returns sha of latest commit that included filename
    # @param[String] filename
    # @return[Rugged::Commit] a commit git object. Responds to the following
    # methods:
    # * #time (the time of the commit)
    # * #oid (the sha of the commit)
    def latest_commit(filename)
      @repo.lookup(latest_commit_sha_local(filename))
    end

    # Returns name of currently checked out branch
    def current_branch_name
      @head_ref.name.sub(/^refs\/heads\//, '')
    end

    # Delegates #lookup method to Rugged::Repository
    def lookup(oid)
      @repo.lookup(oid)
    rescue Rugged::InvalidError => e
      puts "Lookup of oid in remote didn't work. If this is a new repository, at least one commit needs to be at the remote."
      raise
    end

    # We shell out to git log to get the latest commit's sha. This is orders of
    # magnitudes faster than using Rugged walker. See this ticket for more info:
    # https://github.com/libgit2/rugged/issues/343#issue-30232795
    # @param[String, optional] filename if given will return latest commit that
    #   included filename
    # @return[String] the sha1 of the commit
    def latest_commit_sha_local(filename = '')
      s, _ = Open3.capture2(
        [
          "git",
          "--git-dir=#{ @repo_path }",
          "log",
          "-1",
          "--pretty=format:'%H'",
          "--",
          filename.sub(/#{ @repo.workdir }\//, ''),
        ].join(' ')
      )
      s
    end

    # Returns the latest commit oid from origin_master. Fetches origin master.
    # NOTE: I tried to use rugged and remote.ls to get the latest commit's
    # oid, however I had trouble authenticating at github. So I fell back to
    # executing git commands directly and parsing the output.
    # @param[String, optional] remote_name defaults to 'origin'
    # @param[String, optional] branch_name defaults to 'master'
    def latest_commit_sha_remote(remote_name = 'origin', branch_name = 'master')
      most_recent_commit_oid = ''
      cmd = %(cd #{ @repo_path } && git ls-remote #{ remote_name } | awk '/refs\\/heads\\/#{ branch_name }/ {print $1}')
      Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
        exit_status = wait_thr.value
        if exit_status.success?
          most_recent_commit_oid = stdout.read.strip
        else
          msg = %(Could not read oid of #{ remote_name.inspect }/#{ branch_name.inspect }'s most recent commit:\n\n)
          abort(msg + stderr.read)
        end
      end
      most_recent_commit_oid
    end

    # Returns an array of hashes, one for each of the 10 most recent commits in @repo
    # @param[String, optional] filepath
    def latest_commits_local(filepath = '', max_number_of_commits = 20)
      s, _ = Open3.capture2(
        [
          "git",
          "--git-dir=#{ @repo_path }",
          "log",
          "-n#{ max_number_of_commits }",
          "--pretty=format:'%h|%an|%ad|%s'",
          "--date=short",
          "--",
          filepath.sub(/#{ @repo.workdir }\//, ''),
        ].join(' ')
      )
      if s.index('|')
        # Contains commits
        s.split("\n").map do |line|
          commit_hash, author, date, message = line.split('|')
          {
            :commit_hash => commit_hash,
            :author => author,
            :date => date,
            :message => message,
          }
        end
      else
        # No commits found, return empty array
        []
      end
    end

  end
end
