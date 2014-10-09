Branches
========

* **upstream**: The upstream sources from `git://zsh.git.sf.net/gitroot/zsh/zsh`.
* **debian**: The debian changes for the debian `zsh` package. Only
  difference to the upstream branch is the `debian` directory.
* master: This is the _old_ repository's main branch. Only kept for
  _historical_ reasons.
* Other branches: These branches are rather optional and not required
  for basic maintenance for of the `zsh` package. Most likely feature
  branches.


Workflow
========

This diagram outlines the workflow with git branches and
tags. Basically, the `debian` branch walks alongside the `upstream`
branch and upstream changes get merged into `debian` at defined points.
For the zsh package, this _must_ be upstream commit tags -- otherwise
Jenkins
[fails to build the source package](http://jenkins.grml.org/view/Debian/job/zsh-source/219/console).

            * debian/4.3.11-4
            |
            |   * debian/4.3.11-5
            |   |
            |   |       * debian/4.3.12-1
            |   |       |
            |   |       |   * debian/4.3.12-2
            |   |       |   |
            |   |       |   |           * debian/4.3.13-1
            |   |       |   |           |
            |   |       |   |           | * debian/4.3.13-2
            |   |       |   |           | |
            |   |       |   |           | |   * debian/4.3.13-3
            |   |       |   |           | |   |
            |   |       |   |           | |   |
          a-b-c-d---e-f-g-h-i-------j-k-l-m-n-o-p   debian
         /         /               /
      A-B-C-D-E-F-G-H-I-J-K-L-M-N-O-P-Q             upstream
        |         |               |
        |         |               |
        |         |               * zsh-4.3.13
        |         * zsh-4.3.12
        |
        * zsh-4.3.11

Working on the package
----------------------

### Patching upstream code

Every change to the source (outside the `debian` directory) must be
done by adding quilt patches.

#### Patch naming conventions

* File names of patches which are not meant for upstream should be
  prefixed with `debian-`.
* File names of patches which are cherry-picked from upstream should be prefixed
  with `cherry-pick-$shortcommitid` where `$shortcommitid` are the
  first 8 characters of the upstream git commit id.

In case a vast number of patches are required, quilt patches should be
prefixed by ascending numbers according to the order in which "quilt
series" would list them.

#### Patch format

Every patch should have
[DEP3 conforming patch headers](http://dep.debian.net/deps/dep3/)
above the actual unified diff content, outlining the status of the
patch.

Except for the obvious case of a cherry-picked patch from upstream
(which should contain an `Origin: commit $commitid` header), it is
important that the fields `Forwarded` and `Applied-Upstream` are kept
uptodate to know whether a change is already applied upstream.  This
helps to drop the right patches before merging a new upstream release
into the `debian` branch.


#### Example of adding a fix via a quilt patch

Let's say, there is an issue _#12345_ which can be fixed by patching
`Functions/Misc/colors`. Here is how you could add that patch
(assuming clean git working directory):

First, push all existing patches, so the new one is added on top.

    % quilt push -a

Alternatively push the patches one by one (by calling `quilt push`
multiple times) until you are at the patch queue position where you
want to insert the patch.

##### Adding a patch from a file or by editing

Add the new patch (say, the topmost patch is 0002-foo.diff).

    % quilt new fix-colors.diff

Tell quilt which files are going to be changed.

    % quilt add Functions/Misc/colors

Import the fix either manually using your favourite editor…

    % $EDITOR Functions/Misc/colors

… or by patching:

    % patch -p$n < ../patch_from_somewhere_else.diff

##### Cherry-picking patches from upstream

When there is an existing patch (e.g. from upstream's git repository),
the above can be largely automated if the patch applies to the current
state of the debian branch.

    % patchname="cherry-pick-$shortcommitid-description-with-dashes"
    % git show $commitid > debian/patches/$patchname
    % sed -e '1 s/^commit/Origin: commit/' -i debian/patches/$patchname
    % echo $patchname >> debian/patches/series

Patches from upstream will likely include changes to the ChangeLog
file. Those changes will probably not apply cleanly, so just open the
created patch file and delete all hunks that do changes in ChangeLog.

    % $EDITOR debian/patches/$patchname

Check if the patch applies

    % quilt push

##### Finish import of the patch

Refresh the patch to get rid of any fuzz or offset:

    % quilt refresh

Pop all patches again to clean up the upstream source.

    % quilt pop -a

Edit the patch headers according to
[DEP3](http://dep.debian.net/deps/dep3/).

    % $EDITOR debian/patches/$patchname

Commit the new patch and the changed `series` file to git.

    % git add debian/patches/fix-colors.diff
    % git add debian/patches/series
    % git commit -m 'Fixing foo in colors function (Closes: #12345)'

That's all.

### Releases

When a change justifies the release of a new package version, the
debian/changelog file should be updated and the resulting commit
should be tagged `debian/${zsh_version}-${n+1}`.


### Updating debian/changelog

This file should *not* be updated manually. The changes should be
inserted by running the `git-dch` tool from the package
`git-buildpackage` before a new release is about to be made.

Changelog entries should be prefixed by a `[$hashsum] ` string, where
`$hashsum` is a string that represents the first eight characters of
commit the changelog entry was generated from.

Also, if multiple authors are involved in a changelog entry-set, each
author should only appear once in the series with all her/his changes
listed below her/him in chronological order.

Given that `debian/gbp.conf` is up-to-date, using the git-dch(1) tool
will result in the desired changelog format:

    % git-dch

If you absolutely *must* make changelog entries by other means, you
should make sure that you prefix any resulting commits with
"[dch-ignore] ", so those commits can be weeded out easily.

There is a helper script `debian/bin/do-dch` which takes care of all
formatting options as well as the "[dch-ignore] " weeding. The
script should be used unless there is a good reason not to.


Transitioning to a new upstream version
---------------------------------------

When upstream releases a new version, we should follow these steps:

### Merging new upstream tag (`zsh-$version`) into our upstream branch

    % git checkout upstream
    % git pull origin
    % git fetch zsh
    % git merge --ff-only zsh-$version

If that doesn't do a fast-forward merge, a fast-forward merge can be
enforced as follows:

    % git checkout upstream
    % git reset --hard zsh-$version

### Create the fake orig tar ball (until we can work with upstream's tarball)

    % version=5.0.7
    % git archive --format=tar --output=../zsh_${version}.orig.tar --prefix=zsh-${version}/ zsh-$version
    % xz -7vf ../zsh_${version}.orig.tar

### Remove all quilt patches which are applied upstream

All patches applied should be removed from `debian/patches` directory,
unless they fix an issue that was *not* addressed upstream and is
therefore missing from upstream's code base.

### Merging the branch upstream into the branch debian

After the `debian/patches` directory was cleaned up in the previous
step, merging `upstream` into `debian` should generally lead to a
working package again.

If old patches were still around, that could lead to conflicts
when those would be applied during the build process.

The message for the merge commit should be set to "New upstream
release" to allow `git-dch` to pick it up correctly later. **TODO**:
Doesn't really work.

### Insert initial changelog for the new upstream release

`git-dch` seems to be in trouble with non-linear histories. Therefore
we introduced a small helper script that will help `git-dch` to a
linear history again.

Basically, you after merging the upstream release tag into the debian
branch, you'll be left with an history that looks something like this:

    *    Updating autotools patches
    M    Merge commit 'zsh-4.3.13' into debian
    |'*  unposted: released 4.3.13
    | *  …
    | *  … lots of other upstream commits …
    | *  …
    * |  Removing upstream patches due to new release
    * |  Last debian/4.3.12-* commit
    * |  …
    * |  … lot's of other debian/4.3.12-* commits
    * |  …
    M´   Merge commit 'zsh-4.3.12' into debian
    |'*  unposted: released 4.3.12
    …    older history

And what you really want added to debian/changelog is the "Updating
autotools patches" and the "Removing upstream patches due to new
release" commits. You need to figure out the sha1 sums of the commits
and then call this:

    % debian/bin/urcl -p=zsh -v=4.3.13-1 b495ba1e f575f568

… where `4.3.13-1` is the version of the upcoming debian package and
`b495ba1e` and `f575f568` are the SHA1 hashsums of the wanted commits.

At the end the script will drop you into an editor pointed at the
changelog file so you can sanity-check the generated output.

At this point it would also make sense to add a line like this:

    * New upstream release

or, if someone explicitly requested a package of this upstream
release, with mentioning of the according bug report number:

    * New upstream release (Closes: #1234567)

If the upstream release fixes additional bugs reported in Debian or
security relevant bugs, the corresponding upstream commits should be
listed indented by two spaces, together with a short description and
the according bug report and/or CVE numbers, e.g. like this:

    * New upstream release
      + [abcdefgh] Fixes foo (Closes: #1234567)
      + [deadcafe] Adds Completion for bar (Closes: #987654)
      + [babeabed] Fixes CVE-2014-9876

When creating a commit with these changelog changes, you may want to
prefix the commit message with `[dch-ignore] ` or add `-m "Git-Dch:
Ignore"` to the commit command so it doesn't come up in later git-dch
runs.


### Fix outstanding bugs

If *any* outstanding bugs are known, they should be fixed before
releasing a new package. Obviously, if any of the known bugs are very
hard to fix and the issue is not serious in nature, releasing the
package with the issue may be more important.

Again, all changes to non `debian/*` files should be done via quilt
patches.


### Verify that the package builds

There are many ways to do this. Important is:

* Use a clean and uptodate Debian Sid chroot (e.g. by using `sbuild`,
  or `pbuilder` and friends) to make a comprehensive test or for
  uploading.

  Axel prefers: `pdebuild --debbuildopts -j6`

* For a quick sanity check, a simple `dpkg-buildpackage -B` (just
  builds the architecture-dependent binary packages or a `debuild -uc
  -us` (builds source and binary packages, runs `lintian` afterwards)
  may suffice.

* Use `gbp buildpackage` to automatically make sure, you are on the
  correct branch and that the working directory is clean.


### Update changelog again for the release

The `do-dch` helper script should be used to do this. It wraps git-dch
with appropriate options and weeds out any commits that are prefixed
with "[dch-ignore] ". All options to the script are turned over to
git-dch and at least `--since=…` should be used.

At this particular point the sha1 of the previous initial changelog
update commit would be a good idea. Also "-R" to tell git-dch to
prepare the changelog for an actual commit. So:

    % debian/bin/do-dch --since=1234deadbeef -R

You'll be dropped into an editor again to double check the generated
changelog.


### Tag debian/${new_zsh_version}-1

After fixes for all serious and trivially fixable issues have been
added and it has been verified that the package builds and `do-dch`
has updated `debian/changelog` and the resulting commit should be
tagged as `debian/${new_zsh_version}-1`.


Generating packages
-------------------

### git-buildpackage aka gbp

Alternatively, `git-buildpackage` (short `gbp`) also provides ways of
building packages from our packaging codebase. And since we are using
the `gbp dch` command (formerly `git-dch` tool from this utility suite
anyway, the tool should be available already.

`git-buildpackage` allows building the package from within the
package repository and is currently avial

    % gbp buildpackage

Make sure that the local repository is cleaned up after doing this
before working on the package again, to avoid accidentially committing
anything. See *Cleaning up the local repository* below for details.

`git-buildpackage` is available as Debian package or from
https://honk.sigxcpu.org/piki/projects/git-buildpackage/


Git repository setup
--------------------

Getting the basic pkg-zsh git repository is quite easy. If you want
a read only clone, use this:

    % gbp clone git://anonscm.debian.org/collab-maint/zsh.git pkg-zsh

If you are reading this, though, you probably want write access. To
get a thusly cloned repository, first get an alioth login and upload
an ssh-public key. As soon as the key made it to all involved
machines, use this:

    % gbp clone $user@git.debian.org:/git/collab-maint/zsh.git pkg-zsh

Where `$user` is your Alioth login. (Note, that this may be something
with a `-guest` suffix, in case you're not a Debian Developer.)

### Branches

Like described earlier, pkg-zsh development involves two branches;
`debian` and `upstream`. The former is checked out by default for
freshly cloned repositories.

If you cloned the repository with `gbp clone` as shown above, gbp
already took care of also creating a local `upstream` branch.

If you didn't, you can get a local version of the `upstream` branch by
calling

    % git checkout -b upstream origin/upstream

This is useful to update the remote upstream branch with ongoing
development from the zsh project.

### Remotes

There is one remote repository with direct interest for pkg-zsh, and
that is the zsh project's git repository. Currently, this is only a
mirror of the project's cvs repository. But it is updated every ten
minutes by one of zsh's developers. (Also note, that there has been a
brief discussion about whether git may become the official VCS for git
after a bigger future release.)

In order to have zsh's ongoing development available from within
your pkg-zsh repository, do this:

    % git remote add zsh.git git://zsh.git.sf.net/gitroot/zsh/zsh -t master
    % git fetch zsh.git

### Merging and pushing upstream changes

To get updates back into `origin/upstream`, do this:

Get the latest updates.

    % git fetch zsh.git

Switch to the local `upstream` branch for integration.

    % git checkout upstream

Merge upstream's changes (*).

    % git merge zsh.git/master

Push the code into pkg-zsh's central repository.

    % git push origin

Make sure the central repository also has all tags.

    % git push --tags origin

(*) This step should *always* result in a fast-forward merge. If it
does not, something went terribly wrong. Investigate and fix the
situation *before* pushing to origin.

### Dealing with quilt's .pc directory

When quilt works, it keeps track of what it does in a directory by the
name `.pc`. This directory will show up in the output of `git status`
etc. It should *never* *ever* by committed to the git repository at
any point.

We cannot add the directory to `.gitignore` because we would change
the zsh source directly instead of via `debian/patches`.

To deal with the directory, there is another git-facility, that we can
use for fun and profit.

    % echo .pc/ >> .git/info/exclude

Now git will ignore quilt's directory for this repository.
Unfortunately, this has to be done for each checkout. Luckily, this
only has an impact for people who want to work on *pkg-zsh*. Everyone
else can savely ignore the directory.


General Git Hints
-----------------

### Keeping the local repository clean

Before making changes of any kind, it should be made sure that the
local repository you are working on is in a clean state. To clean up
the local repository do this:

     % git clean -xdf
     % git reset --hard

That will make sure that any non-tracked files are removed and that
any changes in tracked files are reverted. The latter will also make
sure that no parts of a quilt patch-queue are still applied.


TODO
====

* How and when to tag releases → `gbp buildpackage --git-tag` or even
  `gbp buildpackage --git-tag-only` only after the upload has been
  uploaded/accepted.
* How and when to push tags. Debian Perl Group's `dpt push` (from the
  package `pkg-perl-tools`) comes in handy.
* `git commit -m 'Something unimportant' -m 'Git-Dch: Ignore'`
* `export QUILT_PATCHES=debian/patches` should be mentioned under
  *Repository setup*, not under *Verify that the package builds*.
* `* New upstream release` changelog entries should have the git
  commit id of the upstream tag.
