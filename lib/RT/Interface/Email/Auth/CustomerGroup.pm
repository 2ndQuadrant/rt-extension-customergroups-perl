#!/usr/bin/perl

=head1 NAME

RT::Interface::Email::Auth::CustomerGroup - Map users to customer groups for incoming email

=head1 SYNOPSIS

To enable this plugin, add it to C<@MailPlugins> I<after> the default
C<RT::Interface::Email::Auth::MailFrom>, eg:

    Set(@MailPlugins, qw(Auth::MailFrom Auth::CustomerGroup));

As you can see in the above example RT prepends RT::Interface::Email:: to the
module names specified in @MailPlugins so you only specify the rest of the
module name.

=head1 DESCRIPTION

Once this mail plugin is enabled, newly created tickets will have the requestor
replaced with customer groups where the requesting user is a member of one or
more customer groups.

The authentication level will be passed through as-is, and if the user doesn't
match any customer groups it'll be passed through as-is as well.

If no RT user has been found by prior mail plugins this plugin will return
(undef,0), allowing later plugins to look users up. Note that
user-to-customer-group conversion won't occur for users who're looked up after
RT::Interface::Email::Auth::CustomerGroup in the chain, so you should generally
put it last.

You don't have to use RT::Interface::Email::Auth::MailFrom to look up users,
you can use anything you like that will return an RT user.

See L<RT::Extension::CustomerGroup> for details.

=head1 AUTHOR

Craig Ringer <craig@2ndquadrant.com>

=head1 COPYRIGHT

Copyright 2013 2ndQuadrant.com

=cut

package RT::Interface::Email::Auth::CustomerGroup;

use strict;
use warnings;

sub GetCurrentUser {
    my %args = ( Message     => undef,
                 CurrentUser => undef,
                 AuthLevel   => undef,
                 Ticket      => undef,
                 Queue       => undef,
                 Action      => undef,
                 @_ );

    if (!defined($args{CurrentUser})) {
        return (undef, $args{AuthLevel});
    }

    # look up if currentuser is member of group and replace if so
    my @incgroups = CustomerGroupsForUser($args{CurrentUser});
    if (scalar(@incgroups) > 1) {
        # Can't sub in more than one group; complain
        _UserIsMemberOfMultipleGroupsError($args{CurrentUser}, @incgroups);
        # Take no action since there's no clear correct course
        return ( $args{CurrentUser}, $args{AuthLevel} );
    } elsif (scalar(@incgroups) == 1) {
        my $g = $incgroups[0];
        RT::Logger->debug("CustomerGroups: Adding group " . $g->Name . " to ticket Requestor");
	# We return AuthLevel 1 even if the original user had a greater AuthLevel, since we don't
	# know that the other users in the same group should also have the greater AuthLevel.
        return ( $g, 1 );
    } else {
        # No match, return unchanged
        return ( $args{CurrentUser}, $args{AuthLevel} );
    }
}

sub _UserIsMemberOfMultipleGroupsError {
    my ($u, @g) = @_;
    my $grouplist = join ', ', map "$_->Id ($_->Name)", @g;
    my $msg = <<END;
CustomerGroups: Users sending tickets by email may only be a member of a single
customer-group due to rt-mailgate API limitations. The user $u->Id ($u->Name)
is a member of more than one customer group. No substitution will be performed.
User is a member of groups: $grouplist.
END
    RT::Logger->error($msg);
}
