#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use File::Basename;
use File::Spec;
use MySQL::Workbench::Merge;

my $base = dirname __FILE__;

{
    my %options = (
        file_a =>  File::Spec->catfile( $base, 'test.mwb' ),
        file_b =>  File::Spec->catfile( $base, 'action.mwb' ),
    );

    my $foo = MySQL::Workbench::Merge->new(
        %options,
    );

    my $target = File::Spec->catfile( $base, $$ . '_test.mwb' );
    my $error  = '';

    eval {
        $foo->merge( write_to => $target );
        1;
    } or do {
        $error = $@;
    };

    like $error, qr/can't read file/;
}

{
    my %options = (
        file_a =>  File::Spec->catfile( $base, 'test.mwb' ),
        file_b =>  File::Spec->catfile( $base, 'actions.mwb' ),
    );

    my $foo = MySQL::Workbench::Merge->new(
        %options,
    );

    my $target = File::Spec->catfile( $base, $$ . '_test.mwb' );
    my $error  = '';

    eval {
        $foo->merge( write_to => $target );
        1;
    } or do {
        $error = $@;
    };

    is $error, '';
    diag $target;
    die 'hallo';
}

done_testing();
