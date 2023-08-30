Set(%CalendarStatusColorMap, (
    'new'                                   => '#87873c',
    'open'                                  => '#5555f8',
    'rejected'                              => '#FF0000',
    'resolved'                              => '#72b872',
    'stalled'                               => '#FF0000',
));

Set($CalendarSortEvents, sub {
    my @Tickets = @_;
    my @SortedTickets = sort { lc($a->Status) cmp lc($b->Status) } @Tickets;
    return @SortedTickets;
});

Set(@CalendarFilterStatuses, qw(new open stalled rejected resolved));

1;
