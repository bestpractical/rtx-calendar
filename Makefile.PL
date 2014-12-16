use inc::Module::Install;

RTx('RTx-Calendar');

requires 'DateTime'      => 0;
requires 'DateTime::Set' => 0;

no_index(package => 'RT::Interface::Web::Menu');

sign();
WriteAll();
