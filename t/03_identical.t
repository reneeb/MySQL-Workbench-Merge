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
        file_a =>  File::Spec->catfile( $base, '/test.mwb' ),
        file_b =>  File::Spec->catfile( $base, '/action.mwb' ),
    );

    my $foo = MySQL::Workbench::Merge->new(
        %options,
    );

    ok 1;
}

done_testing();
