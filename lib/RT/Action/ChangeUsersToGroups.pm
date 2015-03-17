#!/usr/bin/perl

package RT::Action::ChangeUsersToGroups;

use strict;
use warnings;
use RT::Extension::CustomerGroups;

use base qw(RT::Action::SendEmail);

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

This action will also expand the customer groups into a list of email
addresses, removing the original users from the list, and send an email
using the action's template. So in combination with RT's standard "On
Create Autoreply To Requestors" scrip, it will send the same email to
all members of the group when one member raises a ticket.

See L<RT::Extension::CustomerGroups> for details.

=head1 COPYRIGHT

See L<RT::Extension::CustomerGroups>

=cut

sub Prepare {
	my $self = shift;
	RT::Logger->debug("CustomerGroups: ChangeUsersToGroups::Prepare(" . $self->Argument . ")");
	if (!length($self->Argument)) {
		RT::Logger->error("CustomerGroups: Action requires an argument, see perldoc RT::Extension::CustomerGroups");
	}

	my %useremailaddresses;
	for my $arg(split(',', $self->Argument)) {
		map {++$useremailaddresses{$_}} RT::Extension::CustomerGroups::GetEmailAddressesForGroup($self->TicketObj, $arg);
		for($self->TicketObj->$arg->MemberEmailAddresses) {
			delete $useremailaddresses{$_}
		}
	}

	push(@{$self->{'To'}}, keys %useremailaddresses);
	$self->SUPER::Prepare();

	return 1;
}

sub Commit {
	my $self = shift;
	RT::Logger->debug("CustomerGroups: ChangeUsersToGroups::Commit(" . $self->Argument . " )");
	for my $arg (split(',', $self->Argument)) {
		RT::Extension::CustomerGroups::ConvertTicketUsersToGroup($self->TicketObj, $arg);
	}

	$self->SUPER::Commit();
	return 1;
}

1;
