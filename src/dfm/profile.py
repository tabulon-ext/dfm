from os import getenv, makedirs
from os.path import expanduser, join, isdir
from urllib.parse import urlparse

from dfm.dotfile import DotfileRepo, dfm_dir


def is_http_url(url):
    try:
        result = urlparse(url)
        return bool(all([result.scheme, result.netloc]))
    except ValueError:
        return False


class Profile(DotfileRepo):
    """
    Profile is a DotfileRepo that supports modules, and has additional
    options around syncing and linking.

    Profile provides a new option for syncing called 'pull_only' which
    will not push to the remote repo.

    A Module (which is a Profile instance) has a known location on the
    filesystem, either auto-generated or manually specified, and if
    not found will attempt to clone the repository provided as the
    argument 'repo' into that location.

    Profile also feeds the pre or post property up to it's parent
    profile to determine when it should be linked in relation to that
    profile.
    """

    def __init__(
        self,
        location="",
        always_sync_modules=False,
        repo="",
        repository="",
        name="",
        pull_only=False,
        link="post",
        target_dir=getenv("HOME", ""),
        commit_msg=getenv("DFM_GIT_COMMIT_MSG", ""),
    ):

        self.always_sync_modules = always_sync_modules
        self.pull_only = pull_only
        self.link = link
        self.repo = repo if repo else repository
        self.name = name
        if not self.name:
            split = self.repo.split("/")
            if is_http_url(self.repo):
                if len(split) >= 2:
                    self.name = split[-2]
                elif split:
                    self.name = split[-1]
                else:
                    self.name = "unknown"
            else:
                # For a ssh git url git@github.com:username/reponame
                # our current split looks like:
                #
                #   [ git@github.com:username, reponame ]
                #
                # So to get the username split split[0] on : and get
                # the last element of that split
                self.name = split[0].split(":")[-1]

        self.location = expanduser(location)
        if not self.location:
            module_dir = join(dfm_dir(), "modules")
            if not isdir(module_dir):
                makedirs(module_dir)
            self.location = join(module_dir, self.name)

        if not isdir(self.location) and not getenv("DFM_DISABLE_MODULES"):
            self._git("clone {} {}".format(self.repo, self.location), cwd=None)

        super().__init__(
            self.location, target_dir=target_dir, commit_msg=commit_msg,
        )

        if self.config is None:
            return

        modules = self.config.pop("modules", [])
        self.modules = [Profile.from_dict(mod) for mod in modules]
        self.__dict__.update(self.config)

    def _generate_links(self):
        """Add module support to DotfileRepo's _generate_links."""
        for module in self.modules:
            if module.pre:
                self.links += module.link(dry_run=True)

        super()._generate_links()

        for module in self.modules:
            if module.post:
                self.links += module.link(dry_run=True)

    def sync(self, skip_modules=False):  # pylint: disable=arguments-differ
        """
        Sync this profile and all modules using git.

        If self.pull_only will only pull updates.

        If skip_modules is True modules will not be synced.
        """
        print("\n{}:".format(self.where))
        if self.pull_only:
            self._git("pull --rebase origin master")
        else:
            super().sync()

        if skip_modules:
            return

        for module in self.modules:
            module.sync()

    def link(self, dry_run=False, overwrite=False):
        """Wrap super()._generate_links"""
        if self.link_mode == "none":
            return []

        return super().link(dry_run=dry_run, overwrite=overwrite)

    @property
    def pre(self):
        """If True this module should be linked before the parent Profile."""
        return self.link_mode == "pre"

    @property
    def post(self):
        """
        If True this module should be linked after the parent Profile.

        This is useful for when you want files from a module to
        overwrite those from it's parent Profile.
        """
        return self.link_mode == "post"

    @classmethod
    def from_dict(cls, config):
        """Return a Module from the config dictionary"""
        return cls(**config)

    def exists(self):
        return isdir(self.where)