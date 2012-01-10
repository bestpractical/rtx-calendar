use inc::Module::Install;

RTx('RTx-Calendar');
author('Nicolas Chuche <nchuche@barna.be>');
abstract('Calendar view');
license('perl');
readme_from('lib/RTx/Calendar.pm');

requires 'DateTime'      => 0;
requires 'DateTime::Set' => 0;
requires 'Data::ICal'    => 0;
requires 'Date::ICal'    => 0;

no_index(package => 'RT::Interface::Web::Menu');

WriteAll();
