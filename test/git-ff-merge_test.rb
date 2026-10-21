# test/git-ff-merge_test.rb

# 20261022
# 0.0.0

# Each test runs git-ff-merge as a subprocess in a clone of a bare repository
# made for the purpose, standing in for origin, and asserts upon where the
# branches on origin and in the clone end up.

require 'minitest/autorun'
require 'open3'
require 'tmpdir'

BIN = File.expand_path('../bin/git-ff-merge', __dir__)

ENV['GIT_CONFIG_COUNT'] = '2'
ENV['GIT_CONFIG_KEY_0'] = 'commit.gpgsign'
ENV['GIT_CONFIG_VALUE_0'] = 'false'
ENV['GIT_CONFIG_KEY_1'] = 'advice.detachedHead'
ENV['GIT_CONFIG_VALUE_1'] = 'false'

def git(*arguments)
  system('git', *arguments, out: File::NULL, err: File::NULL) || raise("git #{arguments.join(' ')} failed")
end

def commit_on(branch, message)
  git('checkout', branch)
  git('commit', '--allow-empty', '-m', message)
end

def branch_from(start, branch, *messages)
  git('checkout', '-b', branch, start)
  messages.each{|message| git('commit', '--allow-empty', '-m', message)}
end

def sha(ref)
  `git rev-parse --verify --quiet #{ref}`.strip
end

def origin_sha(branch)
  `git ls-remote origin refs/heads/#{branch}`.split.first
end

def in_clone
  Dir.mktmpdir do |directory|
    Dir.chdir(directory) do
      git('init', '--bare', '-b', 'master', 'origin.git')
      git('clone', 'origin.git', 'seed')
      Dir.chdir('seed'){git('commit', '--allow-empty', '-m', 'first'); git('push', 'origin', 'master')}
      git('clone', 'origin.git', 'clone')
      Dir.chdir('clone'){yield}
    end
  end
end

def ff_merge(*arguments)
  stdout, stderr, status = Open3.capture3(BIN, *arguments)
  [status.exitstatus, stdout + stderr]
end

describe 'git-ff-merge' do
  it "fast-forwards origin's default branch to a pushed branch" do
    in_clone do
      branch_from('master', 'fix', 'the fix')
      git('push', 'origin', 'fix')
      status, output = ff_merge
      _(status).must_equal 0
      _(output).must_include 'Merged fix into master.'
      _(origin_sha('master')).must_equal sha('fix')
      _(sha('HEAD')).must_equal sha('fix')
    end
  end

  it 'stops where the branch has commits not pushed' do
    in_clone do
      branch_from('master', 'fix', 'the fix')
      git('push', 'origin', 'fix')
      git('commit', '--allow-empty', '-m', 'not pushed')
      master = origin_sha('master')
      status, output = ff_merge
      _(status).must_equal 1
      _(output).must_include "fix isn't on origin as it is here."
      _(origin_sha('master')).must_equal master
    end
  end

  it 'stops where the branch was never pushed' do
    in_clone do
      branch_from('master', 'fix', 'the fix')
      status, output = ff_merge
      _(status).must_equal 1
      _(output).must_include "fix isn't on origin as it is here."
    end
  end

  it 'stops where the base branch has moved on' do
    in_clone do
      branch_from('master', 'fix', 'the fix')
      git('push', 'origin', 'fix')
      branch_from('master', 'other', 'elsewhere')
      git('push', 'origin', 'other:master')
      git('checkout', 'fix')
      master = origin_sha('master')
      status, output = ff_merge
      _(status).must_equal 1
      _(output).must_include 'master has moved on since fix was cut.'
      _(origin_sha('master')).must_equal master
    end
  end

  it 'stops where the local base branch has commits of its own' do
    in_clone do
      branch_from('master', 'fix', 'the fix')
      git('push', 'origin', 'fix')
      commit_on('master', 'local only')
      git('checkout', 'fix')
      master = origin_sha('master')
      status, output = ff_merge
      _(status).must_equal 1
      _(output).must_include 'master has commits of its own'
      _(origin_sha('master')).must_equal master
    end
  end

  it 'stops on the base branch' do
    in_clone do
      status, output = ff_merge
      _(status).must_equal 1
      _(output).must_include 'master is the base branch.'
    end
  end

  it "stops where origin's default branch isn't known and no base is named" do
    in_clone do
      git('config', 'remote.origin.followRemoteHEAD', 'never')
      git('remote', 'set-head', 'origin', '--delete')
      branch_from('master', 'fix', 'the fix')
      git('push', 'origin', 'fix')
      status, output = ff_merge
      _(status).must_equal 1
      _(output).must_include "origin's default branch isn't known."
    end
  end

  it 'stops where the named base branch is not on origin' do
    in_clone do
      branch_from('master', 'fix', 'the fix')
      git('push', 'origin', 'fix')
      status, output = ff_merge('nonesuch')
      _(status).must_equal 1
      _(output).must_include 'There is no nonesuch on origin.'
    end
  end

  describe 'where the base branch is not the default' do
    it 'stops rather than fast-forward the default branch past a branch ahead of it' do
      in_clone do
        branch_from('master', 'develop', 'on develop')
        git('push', 'origin', 'develop')
        branch_from('develop', 'fix', 'the fix')
        git('push', 'origin', 'fix')
        master = origin_sha('master')
        status, output = ff_merge
        _(status).must_equal 1
        _(output).must_include 'fix holds origin/develop, which origin/master doesn'
        _(origin_sha('master')).must_equal master
      end
    end

    it 'stops rather than advise rebasing onto a default branch it has diverged from' do
      in_clone do
        branch_from('master', 'release', 'on release')
        git('push', 'origin', 'release')
        commit_on('master', 'on master')
        git('push', 'origin', 'master')
        branch_from('release', 'fix', 'the fix')
        git('push', 'origin', 'fix')
        status, output = ff_merge
        _(status).must_equal 1
        _(output).must_include 'fix holds origin/release'
        _(output).wont_include 'has moved on'
      end
    end

    it 'fast-forwards the named base branch' do
      in_clone do
        branch_from('master', 'develop', 'on develop')
        git('push', 'origin', 'develop')
        branch_from('develop', 'fix', 'the fix')
        git('push', 'origin', 'fix')
        master = origin_sha('master')
        status, output = ff_merge('develop')
        _(status).must_equal 0
        _(output).must_include 'Merged fix into develop.'
        _(origin_sha('develop')).must_equal sha('fix')
        _(origin_sha('master')).must_equal master
      end
    end
  end

  describe '-d' do
    it 'deletes the local branch and leaves the one on origin' do
      in_clone do
        branch_from('master', 'fix', 'the fix')
        git('push', 'origin', 'fix')
        fix = sha('fix')
        status, output = ff_merge('-d')
        _(status).must_equal 0
        _(output).must_include 'git push origin --delete fix'
        _(sha('refs/heads/fix')).must_be_empty
        _(origin_sha('fix')).must_equal fix
      end
    end
  end
end
