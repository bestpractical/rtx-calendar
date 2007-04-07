package RTx::Calendar;

use strict;
use Time::Local;

our $VERSION = "0.01";

sub FirstMonday {
    my $date = shift;
    $date->Set(Format => 'unix', Value => Time::Local::timelocal( 0,0,3,1,(localtime $date->Unix)[4..5] ) );
    # search previous monday
    my $wday = (localtime($date->Unix))[6];
    $date->Set(Format => 'unix', Value => $date->Unix - (($wday - 1) % 7) * 24 * 60 * 60);
    $date;
}

sub NextSunday {
    my $date = shift;
    my ($month,$year) = (localtime($date->Unix))[4,5];
    ++$month; $year += 1900;
    if ($month > 11) {
	$month = 0; $year++;
    }
    $date->Set(Format => 'unix', Value => Time::Local::timelocal( 0,0,3,1,$month,$year) );
    my $wday = (localtime($date->Unix))[6];
    $date->Set(Format => 'unix', Value => $date->Unix + ((0 - $wday) % 7 + 1) * 24 * 60 * 60);
    $date;
}

# wrong in many case
sub WeekNumber {
    my $timestamp = shift;
    my $yearday = (localtime $timestamp)[7];
    return my $weeknum = int( $yearday / 7 ) + 1;
}

1;

__END__

=head1 NAME

RTx::Calendar - Calendar for RT

=head1 VERSION

This document describes version 0.01 of RTx::Calendar, released
06 April 2007

=head1 DESCRIPTION

This RT extension provides a calendar view for your tickets. You can
find it in the menu Tools->Calendar.

Idea borrowed from redmine's calendar (Thanks Jean-Philippe).

=head1 AUTHORS

Nicolas Chuche E<lt>nchuche@barna.beE<gt>

=head1 COPYRIGHT

Copyright 2007 by Nicolas Chuche E<lt>nchuche@barna.beE<gt>

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
