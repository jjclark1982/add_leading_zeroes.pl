#!/usr/bin/perl -w
use strict;
select STDERR;

my $dirname = shift || '.';
opendir(FILES, $dirname) || die "can't opendir $dirname: $!";
my @files = sort grep { !/^\./ } readdir(FILES);

# Find the length of the longest number

my $longest_number = 0;
my $longest_name = 1;
foreach my $filename (@files) {
    $longest_name = length($filename) if length($filename) > $longest_name;
    foreach my $number (split(/\D+/, $filename)) {
        $longest_number = length($number) if length($number) > $longest_number;
    }
}

# Look for collisions if we were to pad everything to that length

my %changes = ();
foreach my $old (@files) {
    my $new = pad($old, $longest_number);
    
    if ($new ne $old) {
        # Ensure the new name is unique
        my $unique_str = 'a';
        while (exists $changes{$new} || -e "$dirname/$new") {
            $new = pad($old, $longest_number, $unique_str++);
        }
        $changes{$new} = $old;
    }
    # TODO: maybe only print if $new ne $old
    printf("%-${longest_name}s => %s\n", $old, $new);
}

# Commit the changes

if (!%changes) {
    print "No changes indicated.\n";
    exit;
}
if (-t STDIN) {
    print "Make these changes? (y/n) ";
    exit 1 unless <STDIN> =~ m/^y/i;
}
while (my ($new, $old) = each %changes) {
    # TODO: store $old in xattr -w com.apple.metadata:kMDItemFinderComment
    # how to keep the existing comment?
    #  xattr -p -x com.apple.metadata:kMDItemFinderComment 01 | perl -e 'map {print pack "H*", $_} split /\s/, join("",<>)'
    rename("$dirname/$old", "$dirname/$new") || die "could not move $old to $new: $!";
}
print "Done.\n";
exit;

# This subroutine does the actual name-mangling.
# Edit these regular expressions to change the overall behavior.
sub pad {
    my ($string, $number_length, $unique) = @_;

    # Do not change anything after the final "." for names like "*.mp3"
    my ($name, $extension) = ($string, '');
    if ($string =~ m/^(.*)(\..*?)$/) {
        ($name, $extension) = ($1, $2);
    }
    
    # Replace every number with itself padded to $number_length with zeroes
    $name =~ s/(\d+)/@{[sprintf("%0${number_length}d",$1)]}/g;

    # Append $unique to the first number
    $name =~ s/(\d+)/$1$unique/ if defined $unique;
    
    return $name . $extension;
}
