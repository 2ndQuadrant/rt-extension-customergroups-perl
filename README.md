RT::Extension::CustomerGroups
--

This README applies to the git distribution of RT::Extension::CustomerGroups.
If you downloaded a tarball from CPAN you should not see this file. Please
report a bug if this file appears in the CPAN distribution.

Most users should read [`perldoc
lib/RT/Extension/CustomerGroups.pm`](lib/RT/Extension/CustomerGroups.pm) or the
README file that's generated from it in the tarball distribution.

Using RT::Extension::CustomerGroups from git
--

The git repo, unlike the dist releases, does not contain the Module::Install include files, README,
manifest, META.yml, or other generated files.

If you run:

    perl Makefile.PL

on a system without Module::Install on it, you'll get an error like:

    Can't locate inc/Module/Install.pm in @INC (@INC contains: ....) at Makefile.PL line 1.

You need to install Module::Install from distro packages or CPAN to use this
module from git. Module::Install::AutoManifest, Module::Install::ReadmeFromPod
and Module::Install::RTx are also required.

On Fedora, you'd use:

sudo yum install perl-Module-Install.noarch perl-Module-Install-AutoManifest.noarch perl-Module-Install-ReadmeFromPod.noarch

then install Module::Install::RTx from CPAN.

Otherwise, just install the whole lot from CPAN.

Once you run `perl Makefile.PL` successfully you'll have everything you need to
follow the README's instructions as nornal.

Packaging a release
--

CPAN releases are prepared with:

    make dist
