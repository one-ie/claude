# Google Calendar — call sequence

Find availability before creating an event, so you never double-book.

## Schedule a meeting

1. `GOOGLECALENDAR_FIND_FREE_SLOTS` for the desired window → pick an open slot.
2. `GOOGLECALENDAR_CREATE_EVENT` with that slot's start/end.

## Why the order matters

`GOOGLECALENDAR_CREATE_EVENT` will happily create overlapping events. Check free slots first and create only into a confirmed-open window.

## Prerequisite

- `googlecalendar` toolkit connected (OAuth2). If not connected, emit a `connect` card instead of calling.
