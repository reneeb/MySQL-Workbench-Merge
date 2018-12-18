#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN {
	use_ok( 'MySQL::Workbench::Merge' );
}

my @methods = qw(
    new
    merge
);

can_ok( 'MySQL::Workbench::Merge', @methods );

{
    my $error;
    eval {
        MySQL::Workbench::Merge->new;
        1;
    } or $error = $@;
    like $error, qr/Missing required arguments: file_a, file_b/, 'check required params';
}

{
    my $error;
    eval {
        MySQL::Workbench::Merge->new( file_a => 'test' );
        1;
    } or $error = $@;
    like $error, qr/Missing required arguments: file_b/, 'check required params';
}

{
    my $error;
    eval {
        MySQL::Workbench::Merge->new( file_b => 'test' );
        1;
    } or $error = $@;
    like $error, qr/Missing required arguments: file_a/, 'check required params';
}


{
    my %options = (
        file_a =>  './test.mwb',
        file_b =>  './action.mwb',
    );

    my $foo = MySQL::Workbench::Merge->new(
        %options,
    );

    isa_ok( $foo, 'MySQL::Workbench::Merge', 'object is type M::W::D' );

    is( $options{file_a}, $foo->file_a, 'Checking file_a()' );
    is( $options{file_b}, $foo->file_b, 'Checking file_b()' );
}

done_testing();
