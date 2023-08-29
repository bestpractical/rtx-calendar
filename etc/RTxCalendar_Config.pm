Set($CalendarSortEvents, sub {
    my @Tickets = @_;
    my @SortedTickets = sort { lc($a->Status) cmp lc($b->Status) } @Tickets;
    return @SortedTickets;
});

Set(@CalendarFilterStatuses, qw(new open stalled rejected resolved));

1;
