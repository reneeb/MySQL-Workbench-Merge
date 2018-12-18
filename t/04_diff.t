#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Capture::Tiny qw/capture_stdout/;
use File::Basename;
use File::Spec;
use MySQL::Workbench::Merge;
use Test::LongString;

my $base = dirname __FILE__;

{
    my %options = (
        file_a =>  File::Spec->catfile( $base, '/test.mwb' ),
        file_b =>  File::Spec->catfile( $base, '/actions.mwb' ),
    );

    my $foo = MySQL::Workbench::Merge->new(
        %options,
    );

    my $diff = capture_stdout {
        $foo->diff;
    };

    my $check = q~
New tables
  + groups
  + user_groups
  + users
~;

    is_string $diff, $check;
}

{
    my %options = (
        file_a =>  File::Spec->catfile( $base, '/actions.mwb' ),
        file_b =>  File::Spec->catfile( $base, '/actions2.mwb' ),
    );

    my $foo = MySQL::Workbench::Merge->new(
        %options,
    );

    my $diff = capture_stdout {
        $foo->diff;
    };

    my $check = q~
New tables
  + group_level

New columns
  + groups
    + level_id
  + users
    + registrated

Changed columns
  + users
    + sig VARCHAR(45) NOT NULL
~;

    is_string $diff, $check;
}

done_testing();
