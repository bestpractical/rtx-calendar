use inc::Module::Install;

RTx('Calendar');
author('Nicolas Chuche <nchuche@barna.be>');
abstract('Calendar view');
license('perl');
WriteAll( sign => 1 );
requires(
    DateTime      => 0,
    DateTime::Set => 0,
    Data::ICal    => 0,
    Date::ICal    => 0,
)
