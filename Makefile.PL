use lib '.';
use inc::Module::Install;

RTx('RTx-Calendar');

requires 'DateTime';
requires 'DateTime::Set';

requires_rt '6.0.0';

sign();
WriteAll();
