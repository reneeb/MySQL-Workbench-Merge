package MySQL::Workbench::Merge;

use v5.10;

use warnings;
use strict;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Archive::Zip::Member;
use Carp;
use File::Copy qw(copy);
use Moo;
use MySQL::Workbench::Parser;

# ABSTRACT: (tries to) merge two Workbench files (.mwb)

our $VERSION = '0.01';

has file_a => ( is => 'ro', required => 1 );
has file_b => ( is => 'ro', required => 1 );

has _file_parser_a => ( is => 'rwp' );
has _file_parser_b => ( is => 'rwp' );

around new => sub {
    my ($next, $class, %args) = @_;

    my @missing;
    for my $needed (qw/file_a file_b/) {
        push @missing, $needed if !defined $args{$needed};
    }

    if ( @missing ) {
        croak "Missing required arguments: ", join ', ', @missing;
    }

    my $self = $class->$next( %args );

    my $parser_a = MySQL::Workbench::Parser->new( file => $self->file_a );
    $self->_set__file_parser_a( $parser_a );

    my $parser_b = MySQL::Workbench::Parser->new( file => $self->file_b );
    $self->_set__file_parser_b( $parser_b );

    return $self;
};

sub merge {
    my ($self, %opt) = @_;

    my %diff = $self->_diff;

    if ( !$diff{new_tables} && !$diff{new_columns} ) {
        say "No merge done..." if $opt{verbose};
        return;
    }

    my $zip = Archive::Zip->new;
    if ( $zip->read( $self->file_a ) != AZ_OK ) {
        croak "can't read file " . $self->file_a;
    }

    my $dom = $self->_file_parser_a->dom;

    my $schema_xpath  = './/value[@content-struct-name="db.mysql.Table"]';
    my ($schema)      = $dom->documentElement->findnodes( $schema_xpath );

    my $diagram_xpath = './/value[@content-struct-name="workbench.physical.Diagram"]';
    my ($diagram)     = $dom->documentElement->findnodes( $diagram_xpath );

    for my $table ( sort keys %{ $diff{new_tables} || {} } ) {
        print STDERR sprintf "Merge %s into schema\n", $table;
        my $info   = $diff{new_tables}->{$table};
        my $node   = $info->{node};
        my $figure = $info->{figure};

        $schema->addChild( $node );
        $diagram->addChild( $figure ) if $figure;
    }

    for my $table ( sort keys %{ $diff{new_columns} || {} } ) {
        for my $col ( @{ $diff{new_columns}->{$table} } ) {
            my $node     = $col->{node};
            my $table_id = $col->{orig_table};
            my $xpath    = sprintf './/value[@id="%s"]/value[@content-struct-name="db.mysql.Column"]',
                $table_id;

            print STDERR "TABLE ID: $table_id\n";

            my ($schema) = $dom->documentElement->findnodes( $xpath );
            $schema->addChild( $node );
        }
    }

    my $member = Archive::Zip::Member->newFromString( $dom->toString, 'document.mwb.xml' );
    $zip->replaceMember( 'document.mwb.xml', $member );

    my $target = $opt{write_to};

    if ( !$opt{write_to} ) {
        my $copied = copy $self->file_a, $self->file_a . '.bak';
        croak 'Cannot create backup file' if !$copied;

        $target = $self->file_a;
        unlink $self->file_a;
    }

    if ( $zip->writeToFileNamed( $target ) != AZ_OK ) {
        croak "can't write file " . $target;
    }
}

sub diff {
    my ($self) = @_;

    my %diff = $self->_diff;

    my @diff_output = (
        {
            key         => 'new_tables',
            description => 'New tables',
            level       => 1,
            level_key   => undef,
        },
        {
            key         => 'new_columns',
            description => 'New columns',
            level       => 2,
            level_key   => 'name',
        },
        {
            key         => 'column_changes',
            description => 'Changed columns',
            level       => 2,
            level_key   => 'def',
        },
        {
            key         => 'new_relations',
            description => 'New Relations',
            level       => 1,
            level_key   => 'name',
        },
    );

    PART:
    for my $part ( @diff_output ) {
        my $key       = $part->{key};
        my $desc      = $part->{description};
        my $level     = $part->{level};
        my $level_key = $part->{level_key};

        next PART if !$diff{$key};

        say "\n$desc";

        TABLE:
        for my $table ( sort keys %{ $diff{$key} || {} } ) {
            my $info  = $diff{$key}->{$table} || {};
            my $label = ( $level_key && $level == 1 ) ? $info->{$level_key} : $table;

            say "  + $label";

            next TABLE if $level == 1;

            for my $sublevel ( @{ $info } ) {
                my $label = $level_key ? $sublevel->{$level_key} : $sublevel;
                say "    + $label";
            }
        }
    }
}

sub _diff {
    my ($self) = @_;

    my %existing_tables = $self->_build_existing_data;
    my %diff            = $self->_build_diff( \%existing_tables );

    return %diff;
}

sub _build_diff {
    my ($self, $ref) = @_;

    my $parser = $self->_file_parser_b;
    my @tables = @{ $parser->tables };
    my $dom    = $parser->dom;
    my %diff;

    my %figures;
    my @figures_list = $dom->documentElement->findnodes(
        './/value[@struct-name="workbench.physical.Diagram"]'
    );

    my $table_xpath = './/value[@struct-name="workbench.physical.TableFigure"]/link[@struct-name="db.Table"]';
    for my $figure ( @figures_list ) {
        my ($id_node) = $figure->findvalue( $table_xpath );
        print STDERR "ID: $id_node\n";

        $figures{$id_node} = $figure;
    }

    TABLE:
    for my $table ( @tables ) {
        my $name = $table->name;

        if ( !exists $ref->{$name} ) {
            my $node     = $table->node;
            my $table_id = $node->findvalue('@id');

            $diff{new_tables}->{$name} = {
                name   => $name,
                node   => $table->node,
                figure => $figures{$table_id},
            };

            next TABLE;
        }

        my @columns = @{ $table->columns || [] };
        for my $col ( @columns ) {
            my $col_name      = $col->name;
            my $table_columns = $ref->{$name}->{columns};

            if ( !exists $table_columns->{$col_name} ) {
                push @{ $diff{new_columns}->{$name} }, {
                    table      => $name,
                    orig_table => $ref->{$name}->{id},
                    name       => $col_name,
                    node       => $col->node,
                };
            }
            elsif ( $table_columns->{$col_name} ne $col->as_string ) {
                push @{ $diff{column_changes}->{$name} }, {
                    table      => $name,
                    orig_table => $ref->{$name}->{id},
                    name       => $col_name,
                    node       => $col->node,
                    def        => $col->as_string,
                };
            }
        }
    }

    return %diff;
}

sub _build_existing_data {
    my ($self) = @_;

    my @tables = @{ $self->_file_parser_a->tables };

    my %existing_tables;
    for my $table ( @tables ){
        my $name = $table->name;
        my $id   = $table->node->findvalue('@id');

        $existing_tables{$name} = {
            id => $id,
        };

        my @columns = @{ $table->columns };
        for my $col ( @columns ) {
            my $col_name = $col->name;

            $existing_tables{$name}->{columns}->{$col_name} = $col->as_string;
        }
    }

    return %existing_tables;
}

1;

__END__

=head1 DESCRIPTION

Check the differences in two ER models and merge the second one into the first one.
Currently it detects new tables, new columns in existing tables, changed column
definitions and new relations.

Changed column definitions aren't merged as it isn't easy to know which definition
is newer...

=head1 SYNOPSIS

    use MySQL::Workbench::Merge;

    my $foo = MySQL::Workbench::Merge->new(
        file_a => '/path/to/file.mwb',
        file_b => '/path/to/file_b.mwb',
    );

    $foo->merge( write_to => '/path/to/new.mwb' );

=head1 METHODS

=head2 new

Creates a new object of MySQL::Workbench::Merge. You can pass some parameters
to new:

    my $foo = MySQL::Workbench::Merge->new(
        file_a => '/path/to/file.mwb',
        file_b => '/path/to/file_b.mwb',
    );

=head2 merge

Merges new tables, columns and/or relations into I<file_a>. If you want to create
a new file, you can pass the path of the new file to C<merge>.

    $foo->merge(); # merges into "file_a"
    $foo->merge( write_to => '/path/to/new.mwb' );

=head2 diff

Shows some kind of "diff": It lists the new tables, new columns in existing tables
and new relations:

    New tables:
      + sessions
      + jobs

    New columns:
      + users
         + age

    Changed columns:
      + users
         + username: varchar(255)

    New relations:
      + users -> sessions

=head1 ATTRIBUTES

=over 4

=item * file_a

=item * file_b

=back
