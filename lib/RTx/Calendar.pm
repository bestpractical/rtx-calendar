package RTx::Calendar;

use strict;
use DateTime;
use DateTime::Set;

our $VERSION = "1.05";

RT->AddStyleSheets('calendar.css');

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

# we can't use RT::Date::Date because it uses gmtime
# and we need localtime
sub LocalDate {
    my $ts = shift;
    my ( $d, $m, $y ) = ( localtime($ts) )[ 3 .. 5 ];
    sprintf "%4d-%02d-%02d", ( $y + 1900 ), ++$m, $d;
}

sub DatesClauses {
    my ( $Dates, $begin, $end ) = @_;

    my $clauses = "";

    my @DateClauses = map {
        "($_ >= '" . $begin . " 00:00:00' AND $_ <= '" . $end . " 23:59:59')"
    } @$Dates;
    $clauses .= " AND " . " ( " . join( " OR ", @DateClauses ) . " ) "
        if @DateClauses;

    return $clauses;
}

sub FindTickets {
    my ( $CurrentUser, $Query, $Dates, $begin, $end ) = @_;

    $Query .= DatesClauses( $Dates, $begin, $end )
        if $begin and $end;

    my $Tickets = RT::Tickets->new($CurrentUser);
    $Tickets->FromSQL($Query);

    my %Tickets;
    my %AlreadySeen;

    while ( my $Ticket = $Tickets->Next() ) {

        # How to find the LastContacted date ?
        for my $Date (@$Dates) {

            # $dateindex is the date to use as key in the Tickets Hash
            # in the YYYY-MM-DD format
            # Tickets are then groupd by date in the %Tickets hash
            my $dateindex;
            if ($Date =~ /^CF\./){
                my $cf = $Date;
                $cf =~ s/^CF\.\{(.*)\}/$1/;

                my $CFDateValue = $Ticket->FirstCustomFieldValue($cf);
                next unless $CFDateValue;
                my $CustomFieldObj = RT::CustomField->new($CurrentUser);
                $CustomFieldObj->LoadByName( Name => $cf );
                my $CustomFieldObjType = $CustomFieldObj->Type;
                my $DateObj            = RT::Date->new($CurrentUser);
                if ( $CustomFieldObjType eq 'Date' ) {
                    $DateObj->Set(
                        Format   => 'unknown',
                        Value    => $CFDateValue,
                        Timezone => 'utc'
                    );
                } else {
                    $DateObj->Set( Format => 'ISO', Value => $CFDateValue );
                }
                $dateindex = LocalDate( $DateObj->Unix );
            } else {
                my $DateObj = $Date . "Obj";
                $dateindex = LocalDate( $Ticket->$DateObj->Unix );
            }

            push @{ $Tickets{$dateindex } },
                $Ticket

                # if reminder, check it's refering to a ticket
                unless ( $Ticket->Type eq 'reminder'
                and not $Ticket->RefersTo->First )
                or $AlreadySeen{ $dateindex }
                {$Ticket}++;
        }
    }
    return %Tickets;
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
    my $EventIcon;
    my %CalendarIcons = RT->Config->Get('CalendarIcons');
CALENDAR_ICON:
    for my $DateField ( sort keys %{$DateTypes} ) {

      # Icon can be a combination of two dates such as Due-Created,
      # or CF.{Date Field}-Created. It can be also single date such as Created
        my @DatesToCompare = split( /,/, $DateField );
    DATE_COMPARE:
        for my $ComparedDate (@DatesToCompare) {
            # trim spaces
            $ComparedDate =~ s/^\s+|\s+$//g;
            if ( $DateField eq 'Reminder' ) {
                if ( $IsReminder
                    && RTx::Calendar::LocalDate( $Object->DueObj->Unix ) eq
                    $CurrentDate )
                {
                    $EventIcon = 'reminder.png';
                    last CALENDAR_ICON;
                }
            } elsif ( $DateField =~ /^CF\./ ) {
                my $cf = $DateField;
                $cf =~ s/^CF\.\{(.*)\}/$1/;
                my $DateValue = $Object->FirstCustomFieldValue($cf);
                next CALENDAR_ICON unless $DateValue;
                $DateValue =~ s/(.*) (.*)/$1/;
                next CALENDAR_ICON unless $DateValue eq $CurrentDate;
            } else {
                my $DateObj = $ComparedDate . "Obj";
                my $DateValue
                    = RTx::Calendar::LocalDate( $Object->$DateObj->Unix );
                next CALENDAR_ICON unless $DateValue eq $CurrentDate;
            }

            # If we are here, it means that all comparissons are true
            $EventIcon = $CalendarIcons{$DateField};
        }
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

Works with RT 5.

If you need to install this for RT 4.4.x, install version 1.05:

    cpanm RTx::Calendar@1.05

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

=head3 Displaying the owner

You can show the owner in each day box by adding this line to your
F<etc/RT_SiteConfig.pm>:

    Set($CalendarDisplayOwner, 1);

=head3 Choosing the fields to be displayed in the popup

You can change which fields show up in the popup display when you
mouse over a date in F<etc/RT_SiteConfig.pm>:

    Set(@CalendarPopupFields,
        ('Status',
         'OwnerObj->Name',
         'DueObj->ISO',
         'CustomField.{Maintenance Estimated Start Date/Time - ET}'));

=head3 Event sorting

You can set the order that the events will presented in the day cell with
the C<$CalendarSortEvents> setting.

This setting takes a subroutine reference that will receive an array of
L<RT::Ticket> objects and should return a sorted array of L<RT::Ticket>.

The following example sorts the events by status:

    Set($CalendarSortEvents, sub {
        my @Tickets = @_;
        my @SortedTickets = sort { lc($a->Status) cmp lc($b->Status) } @Tickets;
        return @SortedTickets;
    });

=head3 Event colors

It's also possible to change the color of the events in the calendar by
adding the C<$CalendarStatusColorMap> setting to your F<etc/RT_SiteConfig.pm>:

    Set(%CalendarStatusColorMap, (
        'new'                                   => 'blue',
        'open'                                  => 'blue',
        'approved'                              => 'green',
        'rejected'                              => 'red',
        'resolved'                              => '#aaa',
    ));

You can use any color declaration that CSS supports, including hex codes,
color names, and RGB values.

=head3 Event filtering by status

You can change the statuses available for filtering on the calendar by
adding the C<@CalendarFilterStatuses> setting to your
F<etc/RT_SiteConfig.pm>:

    Set(@CalendarFilterStatuses, qw(new open stalled rejected resolved));


=head3 Custom icons

Custom Icons can be defined for the events in the calendar by adding the
C<$CalendarIcons> setting to your F<etc/RT_SiteConfig.pm>:

    Set(%CalendarIcons, (
        'CF.{Maintenance Estimated Start Date/Time - ET}'
            => 'maint.png',
    ));

The images should be placed on F<local/static/images>.

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

This software is Copyright (c) 2010-2023 by Best Practical Solutions

Copyright 2007-2009 by Nicolas Chuche

This is free software, licensed under:

  The GNU General Public License, Version 2, June 1991

=cut
