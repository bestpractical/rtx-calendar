package RTx::Calendar;

use strict;
use DateTime;
use DateTime::Set;

our $VERSION = "1.05";

RT->AddStyleSheets('calendar.css');
RT->AddJavaScript('calendar.js');

sub FirstDay {
    my ( $year, $month, $matchday ) = @_;
    my $set
        = DateTime::Set->from_recurrence(
        next => sub { $_[0]->truncate( to => 'day' )->subtract( days => 1 ) }
        );

    my $day = DateTime->new( year => $year, month => $month );

    $day = $set->next($day) while $day->day_of_week != $matchday;
    $day;

}

sub LastDay {
    my ( $year, $month, $matchday ) = @_;
    my $set = DateTime::Set->from_recurrence(
        next => sub { $_[0]->truncate( to => 'day' )->add( days => 1 ) } );

    my $day = DateTime->last_day_of_month( year => $year, month => $month );

    $day = $set->next($day) while $day->day_of_week != $matchday;
    $day;
}

sub DatesClauses {
    my ( $Dates, $begin, $end ) = @_;

    my $clauses = "";

    my @DateClauses = map {
        "($_ >= '" . $begin . " 00:00:00' AND $_ <= '" . $end . " 23:59:59')"
    } @$Dates;

    # All multiple days events are already covered on the query above
    # The following code works for covering events that start before and ends
    # after the selected period.
    # Start and end fields of the multiple days must also be present on the
    # format.
    my $multiple_days_events = RT->Config->Get('CalendarMultipleDaysEvents');
    for my $event ( keys %$multiple_days_events ) {
        next unless
            grep { $_ eq $multiple_days_events->{$event}{'Starts'} } @$Dates;
        next unless
            grep { $_ eq $multiple_days_events->{$event}{'Ends'} } @$Dates;
        push @DateClauses,
            "("
            . $multiple_days_events->{$event}{Starts}
            . " <= '"
            . $end
            . " 00:00:00' AND "
            . $multiple_days_events->{$event}{Ends}
            . " >= '"
            . $begin
            . " 23:59:59')";
    }

    $clauses .= " AND " . " ( " . join( " OR ", @DateClauses ) . " ) "
        if @DateClauses;

    return $clauses;
}

sub FindTickets {
    my ( $CurrentUser, $Query, $Dates, $begin, $end ) = @_;

    my $multiple_days_events = RT->Config->Get('CalendarMultipleDaysEvents');
    my @multiple_days_fields;
    for my $event ( keys %$multiple_days_events ) {
        next unless
            grep { $_ eq $multiple_days_events->{$event}{'Starts'} } @$Dates;
        next unless
            grep { $_ eq $multiple_days_events->{$event}{'Ends'} } @$Dates;
        for my $type ( keys %{ $multiple_days_events->{$event} } ) {
            push @multiple_days_fields,
                $multiple_days_events->{$event}{$type};
        }
    }

    $Query .= DatesClauses( $Dates, $begin, $end )
        if $begin and $end;

    my $Tickets = RT::Tickets->new($CurrentUser);
    $Tickets->FromSQL($Query);
    $Tickets->OrderBy( FIELD => 'id', ORDER => 'ASC' );
    my %Tickets;
    my %AlreadySeen;
    my %TicketsSpanningDays;
    my %TicketsSpanningDaysAlreadySeen;

    while ( my $Ticket = $Tickets->Next() ) {
        # How to find the LastContacted date ?
        # Find single day events fields
        for my $Date (@$Dates) {
            # $dateindex is the date to use as key in the Tickets Hash
            # in the YYYY-MM-DD format
            # Tickets are then groupd by date in the %Tickets hash
            my $dateindex_obj = GetDate( $Date, $Ticket, $CurrentUser );
            next unless $dateindex_obj;
            my $dateindex = $dateindex_obj->ISO( Time => 0, Timezone => 'user' );
            push @{ $Tickets{$dateindex } },
                $Ticket

                # if reminder, check it's refering to a ticket
                unless ( $Ticket->Type eq 'reminder'
                and not $Ticket->RefersTo->First )
                or $AlreadySeen{ $dateindex }
                {$Ticket}++;
        }

        # Find spanning days of multiple days events
        for my $event (sort keys %$multiple_days_events) {
            next unless
                grep { $_ eq $multiple_days_events->{$event}{'Starts'} } @$Dates;
            next unless
                grep { $_ eq $multiple_days_events->{$event}{'Ends'} } @$Dates;
            my $starts_field = $multiple_days_events->{$event}{'Starts'};
            my $ends_field   = $multiple_days_events->{$event}{'Ends'};
            my $starts_date  = GetDate( $starts_field, $Ticket, $CurrentUser );
            my $ends_date    = GetDate( $ends_field,   $Ticket, $CurrentUser );
            next unless $starts_date and $ends_date;
            # Loop through all days between start and end and add the ticket
            # to it
            my $current_date = RT::Date->new($CurrentUser);
            $current_date->Set(
                Format => 'unix',
                Value => $starts_date->Unix,
            );

            my $end_date_unix = $ends_date->Unix;
            my $first_day = 1;
            while ( $current_date->Unix <= $end_date_unix )
            {
                my $dateindex = $current_date->ISO( Time => 0, Timezone => 'user' );

                push @{ $TicketsSpanningDays{$dateindex} }, $Ticket->id
                    unless $first_day
                    || $TicketsSpanningDaysAlreadySeen{$dateindex}
                    {$Ticket}++;
                push @{ $Tickets{$dateindex } },
                    $Ticket
                    # if reminder, check it's refering to a ticket
                    unless ( $Ticket->Type eq 'reminder'
                    and not $Ticket->RefersTo->First )
                    or $AlreadySeen{ $dateindex }
                    {$Ticket}++;

                $current_date->AddDay();
                $first_day = 0;
            }
        }
    }
    if ( wantarray ) {
        return ( \%Tickets, \%TicketsSpanningDays );
    } else {
        return \%Tickets;
    }
}

sub GetDate {
    my $date_field = shift;
    my $Ticket = shift;
    my $CurrentUser = shift;

    unless ($date_field) {
        $RT::Logger->debug("No date field provided. Using created date.");
        $date_field = 'Created';
    }

    if ($date_field =~ /^CF\./){
        my $cf = $date_field;
        $cf =~ s/^CF\.\{(.*)\}/$1/;
        my $CustomFieldObj = $Ticket->LoadCustomFieldByIdentifier($cf);
        unless ($CustomFieldObj->id) {
            RT->Logger->debug("$cf Custom Field is not available for this object.");
            return;
        }
        my $CFDateValue = $Ticket->FirstCustomFieldValue($cf);
        return unless $CFDateValue;
        my $CustomFieldObjType = $CustomFieldObj->Type;
        my $DateObj            = RT::Date->new($CurrentUser);
        if ( $CustomFieldObjType eq 'Date' ) {
            $DateObj->Set(
                Format   => 'unknown',
                Value    => $CFDateValue,
            );
        } else {
            $DateObj->Set( Format => 'ISO', Value => $CFDateValue );
        }
        return $DateObj;
    } else {
        my $DateObj = $date_field . "Obj";
        return $Ticket->$DateObj;
    }
}

#
# Take a user object and return the search with Description "calendar" if it exists
#
sub SearchDefaultCalendar {
    my $CurrentUser = shift;
    my $Description = "calendar";

    my $UserObj  = $CurrentUser->UserObj;
    my @searches = $UserObj->Attributes->Named('SavedSearch');
    for my $search (@searches) {
        next
            if ( $search->SubValue('SearchType')
            && $search->SubValue('SearchType') ne 'Ticket' );

        return $search
            if "calendar" eq $search->Description;
    }

    # search through user's groups as well
    my $Groups = RT::Groups->new($CurrentUser);
    $Groups->LimitToUserDefinedGroups;
    $Groups->WithCurrentUser;
    while ( my $group = $Groups->Next ) {
        @searches = $group->Attributes->Named('SavedSearch');
        for my $search (@searches) {
            next
                if ( $search->SubValue('SearchType')
                && $search->SubValue('SearchType') ne 'Ticket' );

            return $search
                if "calendar" eq $search->Description;
        }
    }

    # search thru system saved searches
    @searches = $RT::System->Attributes->Named('SavedSearch');
    for my $search (@searches) {
        next
            if ( $search->SubValue('SearchType')
            && $search->SubValue('SearchType') ne 'Ticket' );

        return $search
            if "calendar" eq $search->Description;
    }
}

sub GetEventImg {
    my $Object      = shift;
    my $CurrentDate = shift;
    my $DateTypes   = shift;
    my $IsReminder  = shift;
    my $CurrentUser = shift;
    my $EventIcon;
    my %CalendarIcons = RT->Config->Get('CalendarIcons');

CALENDAR_ICON:
    for my $legend ( sort { (split /\s*,\s*/, $b) <=> (split /\s*,\s*/, $a) or ($a cmp $b) } keys %CalendarIcons ) {
        if (   $legend eq 'Reminder'
            && $IsReminder
            && $Object->DueObj->ISO( Time => 0, Timezone => 'user' ) eq $CurrentDate )
        {
            $EventIcon = 'reminder.png';
            last;
        }

        for my $DateField ( split /\s*,\s*/, $legend ) {
            next CALENDAR_ICON unless $DateTypes->{$DateField};

            if ( $DateField =~ /^CF\./ ) {
                my $cf = $DateField;
                $cf =~ s/^CF\.\{(.*)\}/$1/;
                my $CustomFieldObj = $Object->LoadCustomFieldByIdentifier($cf);
                next CALENDAR_ICON unless $CustomFieldObj->id;
                my $DateValue = $Object->FirstCustomFieldValue($cf);
                next CALENDAR_ICON unless $DateValue;
                unless ( $CustomFieldObj->Type eq 'Date' ) {
                    my $DateObj = RT::Date->new( $CurrentUser );
                    $DateObj->Set( Format => 'ISO', Value => $DateValue );
                    $DateValue = $DateObj->ISO( Time => 0, Timezone => 'user' );
                }
                next CALENDAR_ICON unless $DateValue eq $CurrentDate;
            } else {
                my $DateObj = $DateField . "Obj";
                my $DateValue
                    = $Object->$DateObj->ISO( Time => 0, Timezone => 'user' );
                next CALENDAR_ICON unless $DateValue eq $CurrentDate;
            }
        }

        # If we are here, it means that all comparissons are true
        $EventIcon = $CalendarIcons{$legend};
        last;
    }

    if ($EventIcon) {
        return '<img src="' . $RT::WebImagesURL . '/' . $EventIcon . '" />';
    } else {
        return '';
    }
}


1;

__END__

=head1 NAME

RTx::Calendar - Calendar for RT due dates

=head1 DESCRIPTION

This RT extension provides a calendar view for your tickets and your
reminders so you see when is your next due ticket. You can find it in
ticket search sub navigation menu.

Date fields in the search results are displayed/used in the calendar,
for example if you have a ticket with a due date, it won't be displayed on
that date unless the Due field is included in the search result format.

There's a portlet to put on your home page (see Prefs/MyRT.html), see the
CONFIGURATION section below for details on adding it.

=head1 RT VERSION

Works with RT 4.2, 4.4, 5.0

=head1 INSTALLATION

=over

=item C<perl Makefile.PL>

=item C<make>

=item C<make install>

May need root permissions

=item patch RT

Apply for versions prior to 4.4.2:

    patch -p1 -d /path/to/rt < etc/tabs_privileged_callback.patch

=item Edit your F</opt/rt5/etc/RT_SiteConfig.pm>

Add this line:

    Plugin('RTx::Calendar');

=item Clear your mason cache

    rm -rf /opt/rt5/var/mason_data/obj

=item Restart your webserver

=back

=head1 CONFIGURATION

=head2 Base configuration

To use the C<MyCalendar> portlet, you must add C<MyCalendar> to
C<$HomepageComponents> in F<etc/RT_SiteConfig.pm>:

  Set($HomepageComponents, [qw(QuickCreate Quicksearch MyCalendar
     MyAdminQueues MySupportQueues MyReminders RefreshHomepage)]);

=head2 Display configuration

You can show the owner in each day box by adding this line to your
F<etc/RT_SiteConfig.pm>:

    Set($CalendarDisplayOwner, 1);

You can change which fields show up in the popup display when you
mouse over a date in F<etc/RT_SiteConfig.pm>:

    Set(@CalendarPopupFields, ('Status', 'OwnerObj->Name', 'DueObj->ISO'));

=head1 USAGE

A small help section is available in /Search/Calendar.html

=head1 AUTHOR

Best Practical Solutions, LLC E<lt>modules@bestpractical.comE<gt>

Originally written by Nicolas Chuche E<lt>nchuche@barna.beE<gt>

=head1 BUGS

All bugs should be reported via email to

    L<bug-RTx-Calendar@rt.cpan.org|mailto:bug-RTx-Calendar@rt.cpan.org>

or via the web at

    L<rt.cpan.org|http://rt.cpan.org/Public/Dist/Display.html?Name=RTx-Calendar>.

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2010-2022 by Best Practical Solutions

Copyright 2007-2009 by Nicolas Chuche

This is free software, licensed under:

  The GNU General Public License, Version 2, June 1991

=cut
