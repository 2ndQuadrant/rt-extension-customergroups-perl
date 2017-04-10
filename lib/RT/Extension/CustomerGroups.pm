#!/usr/bin/perl

package RT::Extension::CustomerGroups;

=pod

=head1 NAME

RT::Extension::CustomerGroups - Make RT operate on "customers" not individual accounts

=head1 SYNOPSIS

You don't generally use this module directly from your own code, it's an RT
extension. See L</"CONFIGURATION">

=head1 DESCRIPTION

RT::Extension::CustomerGroups is designed to give RT the concept of a
"customer" entity, a collection of one or more user accounts who should all
share access to the same tickets and all be notified about the same events.
It's designed to limit the amount of maintenance required when managing groups
of contacts by ensuring that contacts that're newly added to a customer are
automatically given access to the customer's history.

This is a workaround for RT's lack of a two-level account entity like a
"customer" that has-many "contacts". We use RT users as contacts, and designate
select groups as "customer" entities. I<If RT's lack of multiple email addresses
per user is driving you insane, this module is designed to help>.

When tickets are created or users are added to a ticket as Requestor/Cc/Admincc
and the user in question is a member of one or more customer group(s) the user
entry is replaced by the customer group(s) found. So if "bob@example.com"
submits a ticket his Requestor entry will be replaced with an entry for the
customer group "customer-ExampleDotCom" . If the user is a member of more than
one customer group all will be added.

It is recommended that the customer contacts be given unprivileged accounts,
and all privileges the customer should have be assigned to the group they're a
member of. Since individual users will get replaced by groups using unprivileged
users will avoid confusion caused when not all users in the group have the same
rights. The extension will work fine with privileged users, you might just have
to think about your granted rights a little more.

=head1 ROADMAP AND FUTURE WORK

A future goal for this extension is to add a subclass of RT::Group and fields
that make RT aware of these customer groups as first class entities. For now,
they're just ordinary groups that're recognised as customer groups by a naming
pattern match or a custom field.

=head1 INSTALLATION

Install RT::Extension::CustomerGroups using CPAN or using the usual:

  perl Makefile.PL
  make
  sudo make install

For the first installation only you can also:

  make initdb

to add the scrip actions to the database. Alternately, you can add the actions
to the database manually.

Do not run "make initdb" multiple times, you'll get multiple actions in the
database. If you do this accidentally you can remove any scrips that use them,
then delete the actions directly from the database.

process.

=head1 CONFIGURATION

 # Add the plugin to your RT_SiteConfig.pm's plugin list. (Append to any existing
 # @Plugins setting rather than adding a new one).
 #
 Set(@Plugins, qw(RT::Extension::CustomerGroups));

You can now apply the actions to scrips. The actions send no email so
their templates should be left blank.

=head1 AUTHOR 

Craig Ringer <craig@2ndquadrant.com>

=head1 COPYRIGHT 

Copyright 2013-2017 2nd Quadrant

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included with this module.

=cut

use 5.10.1;
use strict;
use warnings;

BEGIN {
        our $VERSION = '1.00';
}

=head2 ConvertTicketUsersToGroup

If the passed user is a customer, as determined by its membership in one or more
customer- groups using CustomerGroupsForUser, and if those groups have the
ReplaceMemberWithGroup custom field set, add the customer groups
to the ticket's Requestor list and remove the original user.

The 2nd argument must be a comma-separated list of ticket pseudo-group categories:

	Cc
	AdminCc
	Requestors

=cut

sub ConvertTicketUsersToGroup {
	my $ticket = shift @_;
	my $ticketgrouptype = shift @_;

	# Normalize arg that's sometimes plural, sometimes not;
	# RT's inconsistent use of Requestor vs Requestors can be
	# hard to remember so we just clean it up.
	$ticketgrouptype = 'Requestors' if ($ticketgrouptype eq 'Requestor');

	($ticketgrouptype =~ /Requestors|Cc|AdminCc/)
	    || die ("2nd argument must be one of Requestors|Cc|AdminCc, not $ticketgrouptype");

	RT::Logger->debug("CustomerGroups: Checking " . $ticketgrouptype);

	# The watcher category is Requestors for Ticket group method Requestor . Consistency ftw.
	my $watchertgt = ($ticketgrouptype eq 'Requestors' ? 'Requestor' : $ticketgrouptype);

	my $tg = $ticket->$ticketgrouptype->UserMembersObj;
        while (my $u = $tg->Next) {
		foreach my $g (CustomerGroupsForUser($u)) {
			next unless $g->FirstCustomFieldValue('ReplaceMemberWithGroup') // 0;
			RT::Logger->debug("CustomerGroups: Adding group " . $g->Name . " to ticket " . $watchertgt);
			$ticket->AddWatcher( Type => $watchertgt, PrincipalId => $g->Id);
			RT::Logger->debug("CustomerGroups: Removing user " . $u->Name . " from ticket " . $watchertgt);
			$ticket->DeleteWatcher( Type => $watchertgt, PrincipalId => $u->Id);
		}
        }
	RT::Logger->debug("CustomerGroups: Done checking " . $ticketgrouptype);
}

=head2 GetEmailAddressesForGroup

Takes a ticket and pseudo-group as for ConvertTicketUsersToGroup; returns
a list of email addresses for the corresponding customer group.

=cut

sub GetEmailAddressesForGroup {
	my $ticket = shift @_;
	my $ticketgrouptype = shift @_;
	my @returnusers;

	$ticketgrouptype = 'Requestors' if ($ticketgrouptype eq 'Requestor');

	($ticketgrouptype =~ /^(Requestors|Cc|AdminCc)$/)
		|| die ("2nd argument must be one of Requestors|Cc|AdminCc, not $ticketgrouptype");
	
	RT::Logger->debug("CustomerGroups: checking email addresses for " . $ticketgrouptype);

	my $tg = $ticket->$ticketgrouptype->UserMembersObj;
	while (my $u = $tg->Next) {
		foreach my $g (CustomerGroupsForUser($u)) {
			push @returnusers, $g->MemberEmailAddresses
		}
	}
	return @returnusers;
}

=head2 CustomerGroupsForUser

Return an array of the customer groups (RT::Group) this user is a member of, or
the empty array if the user is a member of no customer groups. An RT::User must
be passed.

Only groups that the passed user has permission to see will be returned.

At this time, a group is determined to be a "customer" group if it is prefixed
with "customer-".

=cut

sub CustomerGroupsForUser {
	my $user = shift @_;
	my @incgroups = ();
	my $groups = $user->OwnGroups;
	while ( my $group = $groups->Next ) {
		if ($group->Name =~ /^customer-/) {
			push(@incgroups, $group);
		}
	}
	return @incgroups;
}

1;
