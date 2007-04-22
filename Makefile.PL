use inc::Module::Install;

RTx('Calendar');
author('Nicolas Chuche <nchuche@barna.be>');
abstract('Calendar view');
license('perl');

requires 'DateTime'      => 0;
requires 'DateTime::Set' => 0;
requires 'Data::ICal'    => 0;
requires 'Date::ICal'    => 0;

WriteAll();
