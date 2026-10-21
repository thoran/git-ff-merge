# git-ff-merge

## Description

Merge a branch by fast-forwarding its base branch and pushing it.

The merge buttons of hosts such as GitHub, GitLab and Bitbucket each make new commits: a merge commit, a squashed commit, or rebased copies. None of them are the commits which were pushed, and none carry their signatures. Fast-forwarding puts the pushed commits themselves on the base branch.

It knows nothing of any host, and works the same with or without a pull request. Where there is one, a host which marks a pull request merged once the pull request's head commit is on its base branch will do so. GitHub, GitLab and Bitbucket do; Gitea and Forgejo do where the repository has "autodetect manual merge" turned on.

It began as git-ff-merge-pr 0.1.0, less the pull request. git-ff-merge-pr continues as gh-ff-merge, which on GitHub also takes the base branch from the pull request, and deletes the branch on origin once GitHub has marked the pull request merged.

## Installation

```shell
$ brew tap thoran/tap
$ brew install git-ff-merge
```

## Usage

When the branch is pushed and ready to merge, from the branch:

```shell
$ git ff-merge
```

It merges into origin's default branch. Where the base branch is another, name it:

```shell
$ git ff-merge develop
```

It stops, pushing nothing, where:

- there is no remote called origin;
- it isn't on a branch, or is on the base branch;
- origin's default branch isn't known and no base branch is named;
- the base branch isn't on origin;
- the branch isn't on origin as it is locally, having commits which haven't been pushed or never having been pushed;
- the branch holds another branch on origin which the base branch doesn't, so that the base branch may not be its base;
- the base branch has moved on since the branch was cut, which wants the branch rebased and pushed again;
- the local base branch has commits of its own.

Each time it says what to do about it.

To delete the local branch as well, once merged:

```shell
$ git ff-merge -d
```

The branch on origin is kept, and the command to delete it is given. Deleting a pull request's head branch before the host has seen the merge can leave the pull request closed rather than merged, and with no knowledge of the host there is no telling when it has.

## Notes

1. It fetches from, and pushes to, the remote called origin.
2. Knowing nothing of any pull request, it cannot know a pull request's base branch, nor whether one is open. Where a pull request's base branch is other than origin's default branch, name it. The check for other branches catches a branch cut from one which is ahead of, or has diverged from, the default branch, but not one cut from a base branch with no commits of its own.
3. The local branch is deleted with `git branch -d`, so git refuses where it holds anything the base branch doesn't.

## Contributing

1. Fork it... `https://github.com/thoran/git-ff-merge/fork`
2. Create your feature branch... `git checkout -b my-new-feature`
3. Commit your changes... `git commit -am 'Add some feature'`
4. Push to the branch... `git push origin my-new-feature`
5. Create a new pull request


## License

MIT
