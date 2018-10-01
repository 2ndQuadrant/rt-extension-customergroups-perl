#!/usr/bin/perl

package RT::Action::AddCcsForCustomer;

use strict;
use warnings;
use RT::Extension::CustomerGroups;

use base qw(RT::Action);

=head1 NAME

RT::Action::AddCcsForCustomer - action to add members of a group as Ccs to new tickets

=head1 DESCRIPTION

On a newly created ticket, this action looks at the ticket's requestors and finds which
customer groups, if any, they are members of. For each such group, it looks for values
of that group's "AlwaysCc" custom field, which should be ids of groups
or users. Groups are expanded to lists of users; users are then added to the ticket's
Cc: list.

=head1 COPYRIGHT

See L<RT::Extension::CustomerGroups>

=cut

sub Prepare {
	my $self = shift;

	my @all_customer_groups;
	my $requestors = $self->TicketObj->Requestor->UserMembersObj;
	while(my $requestor = $requestors->Next) {
		for my $group ( RT::Extension::CustomerGroups::CustomerGroupsForUser($requestor) ) {
			push @all_customer_groups, $group unless grep { $_->Id == $group->Id } @all_customer_groups;
		}
	}

	# @all_customer_groups now contains all customer groups that any of the original requestors were members of

	for my $customer_group (@all_customer_groups) {
		my $alwayscc_values = $customer_group->CustomFieldValues('AlwaysCc');
		while(my $alwayscc_value = $alwayscc_values->Next) {
		  my $principal_id = $alwayscc_value->Content;
			my $principal = RT::Principal->new( RT->SystemUser );
			$principal->LoadById($principal_id);
			if($principal->IsUser()) {
				$self->TicketObj->Cc->AddMember($principal_id)
			} else {
				my $users = $principal->Object->UserMembersObj;
				while(my $user = $users->Next) {
					$self->TicketObj->Cc->AddMember($user->Id);
				}
			}
		}
	}

	return 1;
}
				
1;
