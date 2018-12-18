#!/usr/bin/env perl

use Test::More tests => 1;

BEGIN {
	use_ok( 'MySQL::Workbench::Merge' );
}

diag( "Testing MySQL::Workbench::Merge $MySQL::Workbench::Merge::VERSION, Perl $], $^X" );
