#!/usr/bin/perl

package RT::Action::ChangeUsersToGroups;

use strict;
use warnings;
use RT::Extension::CustomerGroups;

use base qw(RT::Action);

=head1 NAME

RT::Action::ChangeUsersToGroups - Action to change requestor, admincc etc from users to customer groups

=head1 DESCRIPTION

When run on a ticket, this action will look for users on the ticket that're
members of customer groups. Any users found will be replaced with the
associated customer groups.

The argument must be one or more comma-separated values from the list:

    Requestor
    Cc
    AdminCc

The replacement takes place when the action's Prepare method is invoked,
so scrips which run later will see the effects.

See L<RT::Extension::CustomerGroups> for details.

=head1 COPYRIGHT

See L<RT::Extension::CustomerGroups>

=cut

sub Prepare {
	my $self = shift;

	if (!length($self->Argument)) {
		RT::Logger->error("CustomerGroups: Action requires an argument, see perldoc RT::Extension::CustomerGroups");
	}

	for my $arg (split(',', $self->Argument)) {
		RT::Extension::CustomerGroups::ConvertTicketUsersToGroup($self->TicketObj, $arg);
	}

	return 1;
}

1;
