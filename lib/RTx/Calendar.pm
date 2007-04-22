package RTx::Calendar;

use strict;
use DateTime;
use DateTime::Set;

our $VERSION = "0.04";

sub FirstMonday {
    my ($year, $month) = (shift, shift);
    my $set = DateTime::Set->from_recurrence(
	next => sub { $_[0]->truncate( to => 'day' )->subtract( days => 1 ) }
    );

    my $day = DateTime->new( year => $year, month => $month );

    $day = $set->next($day) while $day->day_of_week != 1;
    $day;

}

sub LastSunday {
    my ($year, $month) = (shift, shift);
    my $set = DateTime::Set->from_recurrence(
	next => sub { $_[0]->truncate( to => 'day' )->add( days => 1 ) }
    );

    my $day = DateTime->last_day_of_month( year => $year, month => $month );

    $day = $set->next($day) while $day->day_of_week != 7;
    $day;
}

# we can't use RT::Date::Date because it uses gmtime
# and we need localtime
sub LocalDate {
  my $ts = shift;
  my ($d,$m,$y) = (localtime($ts))[3..5];
  sprintf "%4d-%02d-%02d", ($y + 1900), ++$m, $d;
}

1;

__END__

=head1 NAME

RTx::Calendar - Calendar for RT due tasks

=head1 VERSION

This document describes version 0.04 of RTx::Calendar

=head1 DESCRIPTION

This RT extension provides a calendar view for your tickets and your
reminders so you see when is your next due ticket. You can find it in
the menu Search->Calendar.

There's a portlet to put on your home page (see Prefs/MyRT.html)

You can also enable ics (ICal) feeds for your default calendar and all
your private searches in Prefs/Calendar.html. Authentication is magic
number based so that you can give those feeds to other people.

You can find screenshots on
http://gaspard.mine.nu/dotclear/index.php?tag/rtx-calendar

=head1 INSTALLATION

If you upgrade from 0.02, see next part before.

Install it like a standard perl module

 perl Makefile.PL
 make
 make install

To use MyCalendar portlet you must add MyCalendar to
$HomepageComponents in etc/RT_SiteConfig.pm like that :

  Set($HomepageComponents, [qw(QuickCreate Quicksearch MyCalendar
     MyAdminQueues MySupportQueues MyReminders RefreshHomepage)]);

To enable private searches ICal feeds, you need to give
CreateSavedSearch and LoadSavedSearch rights to your users.

=head1 ADVANCED USAGE

If you want to see reminders in a search you need to go in the
"advanced" tab of the query builder and add something like that :

  AND ( Type = 'ticket' OR Type = 'reminder' )

=head1 UPGRADE FROM 0.02

As I've change directory structure, if you upgrade from 0.02 you need
to delete old files manually. Go in RTHOME/share/html (by default
/opt/rt3/share/html) and delete those files :

  rm -rf Callbacks/RTx-Calendar
  rm Tools/Calendar.html

RTx-Calendar may work without this but it's not very clean.

=head1 BUGS

=over

=item *
compatible only with RT 3.6 for the moment. If someone need
compatibility with 3.4 I can work on this. And I will work on 3.7
compatibility later.

=back

=head1 AUTHORS

Nicolas Chuche E<lt>nchuche@barna.beE<gt>

Idea borrowed from redmine's calendar (Thanks Jean-Philippe).

=head1 COPYRIGHT

Copyright 2007 by Nicolas Chuche E<lt>nchuche@barna.beE<gt>

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
