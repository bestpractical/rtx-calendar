use inc::Module::Install;

RTx('RTx-Calendar');

requires 'DateTime'      => 0;
requires 'DateTime::Set' => 0;

requires_rt '4.0.9';

sign();
WriteAll();
