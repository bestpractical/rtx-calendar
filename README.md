# RTx::Calendar

Calendar view for RT 6 ticket dates and custom fields.

Based on the original [RTx-Calendar](https://metacpan.org/dist/RTx-Calendar) by Best Practical Solutions, LLC. This fork adds several bug fixes, a modernized UI, view switcher (Day/Week/Month), and new dashboard widgets.

---

## Screenshots

### Month View
Full month overview with colour-coded event bars. Spanning tickets extend across multiple days. Today is highlighted in amber.

![Month View](docs/screenshots/NewCalendarMonthView.png)

### Week View
Seven-column week layout with full event cards showing ticket ID, subject, queue, status and owner.

![Week View](docs/screenshots/NewCalendarWeekView.png)

### Day View
Scrollable card list for a single day with sidebar filter, event types, status colours and help section.

![Day View](docs/screenshots/NewCalendarDayListView.png)

### MyCalendarToday Dashboard Widget
Today's tickets as cards — sorted by Due date, with queue, status, owner, requestor and date details.

![Today's Calendar Widget](docs/screenshots/TodaysListWidget.png)

### MyCalendar Dashboard Widget
Classic week portlet for embedding a compact calendar view on any RT dashboard.

![Week Widget](docs/screenshots/WeekWidget.png)

---

## Description

RTx::Calendar provides a calendar view to display tickets and reminders based on selected date fields. Once installed, a **Calendar** tab appears in ticket search results. Three calendar views are available: Month, Week, and Day. Multiple dashboard portlets are included.

---

## Requirements

- RT 6.0.0 or later

---

## Installation

```bash
perl Makefile.PL
make
sudo make install
```

Register the plugin in `/opt/rt6/etc/RT_SiteConfig.pm`:

```perl
Plugin('RTx::Calendar');
```

Clear the Mason cache and restart Apache:

```bash
sudo rm -rf /opt/rt6/var/mason_data/obj
sudo systemctl restart apache2
```

---

## Usage

### Search-based Calendar

Run a ticket search in the Query Builder, then click **Calendar** in the page menu. The calendar displays events based on the date fields included in your search format (Starts and Due by default).

Hover over an event to see ticket details. Click to open the ticket.

### View Switcher

The sidebar contains a **View** switcher with three options:

| View | Description |
|------|-------------|
| **Month** | Classic month grid with spanning event bars |
| **Week** | Current week — 7 columns with event cards (same style as Day view) |
| **Day** | Single day — scrollable list of event cards |

Navigation arrows move between months, weeks, or days depending on the active view.

### Displaying Other Date Fields

Add date fields to the search Format via the **Display Columns** section in the Query Builder or the **Advanced** tab. Example format string:

```
'<small>__Due__</small>',
'<small>__Starts__</small>',
'<small>__LastUpdated__</small>',
'<small>__CustomField.{Maintenance Date}__</small>'
```

### Displaying Reminders

Add the following clause to your query explicitly:

```
AND ( Type = 'ticket' OR Type = 'reminder' )
```

### Default Query

Save a search named `calendar` in the Query Builder to use it as the default query for all calendar portlets.

---

## Dashboard Portlets

Add portlets to `$HomepageComponents` in your `RT_SiteConfig.pm`:

```perl
Set($HomepageComponents, [qw(
    QuickCreate Quicksearch MyAdminQueues MySupportQueues MyReminders
    RefreshHomepage MyCalendar MyCalendarToday Calendar CalendarWithSidebar
)]);
```

| Portlet | Description |
|---------|-------------|
| `MyCalendar` | Week summary (±3 days around today) as a calendar grid |
| `MyCalendarToday` | Today's events as a card list, sorted by Due date |
| `Calendar` | Full month view without sidebar |
| `CalendarWithSidebar` | Full month view with sidebar (filter, legend, help) |

### MyCalendarToday

Shows all tickets for today where the current user is Owner or the ticket is unassigned (Owner = Nobody). Each card displays:

- Ticket ID and Subject (linked)
- Queue · Status · Owner
- Requestor (if set)
- Starts and Due dates (if set)
- Sorted by Due date ascending (earliest first, unset last)
- Hover highlight effect

---

## Configuration

### Event Colors

Colors are defined via CSS using ticket status classes. The `CalendarStatusColorMap` config maps statuses to accent colors used in the **MyCalendarToday** cards' left border. The month view uses accessible pastel backgrounds with dark text (light mode) and darker backgrounds with white text (dark mode).

Default config in `etc/RTxCalendar_Config.pm`:

```perl
Set(%CalendarStatusColorMap, (
    '_default_' => '#5555f8',
    'new'       => '#87873c',
    'open'      => '#5555f8',
    'rejected'  => '#FF0000',
    'resolved'  => '#72b872',
    'stalled'   => '#FF0000',
));
```

### Filter on Status

```perl
Set(@CalendarFilterStatuses,        qw(new open stalled rejected resolved));
Set(@CalendarFilterDefaultStatuses, qw(new open));
```

### Event Line Values

Controls what is shown on each event bar in the month view:

```perl
Set(@CalendarEventLineValues, qw(Queue Id Subject));
```

### Hover Popup Fields

```perl
Set(@CalendarPopupFields, (
    "OwnerObj->Name",
    "CreatedObj->ISO",
    "StartsObj->ISO",
    "StartedObj->ISO",
    "LastUpdatedObj->ISO",
    "DueObj->ISO",
    "ResolvedObj->ISO",
    "Status",
    "Priority",
    "Requestors->MemberEmailAddressesAsString",
));
```

### Custom Icons

```perl
Set(%CalendarIcons, (
    'Reminder'     => 'reminder.png',
    'Resolved'     => 'resolved.png',
    'Starts, Due'  => 'starts_due.png',
    'Due'          => 'due.png',
    'Starts'       => 'starts.png',
    'Started'      => 'started.png',
    'LastUpdated'  => 'updated.png',
));
```

Custom images go in `/opt/rt6/local/static/images/`. Recommended size: 10×7 px PNG with transparent background.

### Multiple Days Events

```perl
Set(%CalendarMultipleDaysEvents, (
    'Project Task' => {
        'Starts' => 'Starts',
        'Ends'   => 'Due',
    },
));
```

---

## Changes vs. Upstream

### Bug Fixes

- **Standalone view empty** — `FindTickets` was only called for HTMX `/Views/` requests. Direct access to `/Search/Calendar.html` showed an empty calendar. Fixed by also calling `FindTickets` when `$Standalone` is true.
- **Mason syntax error in CalendarEvent** — `grep { }` inside a `%`-line caused Mason parser confusion with nested curly braces. Moved the expression into a `<%perl>` block.
- **Dark mode wipes event colors** — `[data-bs-theme=dark] table.rtxcalendar * { background: unset !important }` removed all event backgrounds in dark mode. Replaced with explicit per-status dark mode color rules.
- **Phantom placeholder bars** — Empty positioning divs (`<div class="day">&nbsp;</div>`) received the fallback background color after moving colors to CSS. Fixed by scoping the background rule to `.day[class*="event-status"]`.

### UI Improvements

- **Download Spreadsheet link removed** from the calendar header.
- **Calendar height** set to 70vh in standalone mode for better use of screen space.
- **View switcher** (Day / Week / Month) added to the sidebar.
- **Week view** uses event cards (same style as Day view) instead of the spanning bar layout.
- **Day view** renders a scrollable card list for the selected day.
- **Accessible color scheme** for month view: pastel backgrounds with dark text in light mode, darker backgrounds with white text in dark mode. All colors WCAG AA compliant.
- **Event text clipping** — long titles are clipped with `text-overflow: ellipsis` rather than overflowing cell boundaries.
- **Right-side overflow fix** — last calendar column event bars no longer extend past the table edge.
- **Help section** moved from the page footer into the sidebar as a collapsible box.
- **MyCalendarToday portlet** — new widget showing today's events as cards, sorted by Due date.

---

## Author

Original: Best Practical Solutions, LLC  
Originally written by Nicolas Chuche &lt;nchuche@barna.be&gt;

Modifications: Torsten Brumm (2026)

## License

GNU General Public License, Version 2 — see [LICENSE](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)

Copyright (c) 2010–2025 Best Practical Solutions  
Copyright 2007–2009 Nicolas Chuche  
Modifications Copyright (c) 2026 Torsten Brumm
