package RTx::Calendar;

use strict;
use DateTime;
use DateTime::Set;

our $VERSION = "0.02";

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

1;

__END__

=head1 NAME

RTx::Calendar - Calendar for RT

=head1 VERSION

This document describes version 0.02 of RTx::Calendar, released
06 April 2007

=head1 DESCRIPTION

This RT extension provides a calendar view for your tickets. You can
find it in the menu Tools->Calendar.

You can also add the portlet. To do that you must add MyCalendar to
$HomepageComponents in etc/RT_SiteConfig.pm like that :

Set($HomepageComponents, [qw(QuickCreate Quicksearch MyCalendar MyAdminQueues MySupportQueues MyReminders  RefreshHomepage)]);

And add it your preferences.

Idea borrowed from redmine's calendar (Thanks Jean-Philippe).

=head1 AUTHORS

Nicolas Chuche E<lt>nchuche@barna.beE<gt>

=head1 COPYRIGHT

Copyright 2007 by Nicolas Chuche E<lt>nchuche@barna.beE<gt>

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
