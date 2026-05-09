#!/usr/bin/perl
# tat_find.pl — TatFind 1.4 algorithm reimplementation
#
# Implements the twin-arginine signal peptide detection algorithm described in:
#   Rose RW, Brüser T, Kissinger JC, Pohlschröder M (2002).
#   Adaptation of protein secretion to extremely high-salt conditions by
#   extensive use of the twin-arginine translocation pathway.
#   Molecular Microbiology 45(4):943-950. doi:10.1046/j.1365-2958.2002.03090.x
#
# Algorithm:
#   Search N-terminal region (first TAT_WINDOW aa) for the twin-arginine motif:
#     [LIVMF][LIVMF]-RR-x-[LIVMF]-x (consensus n-region + RR + h-region start)
#   Optionally also allow KR in place of RR (less strict mode).
#
# Usage: perl tat_find.pl <input.faa> [--strict]
#   --strict  Use only RR (default: also allow KR)
#   Output: TSV to stdout — protein_id, match, motif_start, motif, window_seq

use strict;
use warnings;

my $TAT_WINDOW  = 35;    # only search first N residues (Rose et al. use ~35)
# TatFind 1.4 consensus: [LIVMF][LIVMF]RR[^DE][LIVMF]  (h-region seed follows RR)
# Extended: also flag [LIVMF][LIVMF]KR[^DE][LIVMF] as weaker Tat signal
my $MOTIF_RR    = qr/([LIVMF][LIVMF]RR[^DE][LIVMF])/;
my $MOTIF_KR    = qr/([LIVMF][LIVMF]KR[^DE][LIVMF])/;

my $strict = grep { $_ eq '--strict' } @ARGV;
my ($input) = grep { !/^--/ } @ARGV;

die "Usage: tat_find.pl <input.faa> [--strict]\n" unless $input && -f $input;

print join("\t", qw(protein_id tat_signal motif_start motif window_seq)), "\n";

local $/ = undef;
open(my $fh, '<', $input) or die "Cannot open $input: $!\n";
my $content = <$fh>;
close $fh;

# Split on FASTA records
my @records = split /(?=>)/, $content;
for my $rec (@records) {
    $rec =~ s/\A\s+|\s+\z//g;
    next unless length $rec;
    my ($header, @seq_lines) = split /\n/, $rec;
    my $protein_id = $header;
    $protein_id =~ s/^>//;
    $protein_id =~ s/\s.*//;   # first word only
    my $seq = join('', @seq_lines);
    $seq =~ s/\s//g;
    $seq = uc $seq;

    # Search only N-terminal window
    my $window = substr($seq, 0, $TAT_WINDOW);

    my ($found, $motif_start, $motif_seq) = (0, '.', '.');
    my $signal_type = 'no';

    if ($window =~ $MOTIF_RR) {
        $found = 1;
        $motif_seq = $1;
        $signal_type = 'yes_RR';
        # find 1-based start position
        $window =~ /\Q$motif_seq\E/;
        $motif_start = $-[0] + 1;
    } elsif (!$strict && $window =~ $MOTIF_KR) {
        $found = 1;
        $motif_seq = $1;
        $signal_type = 'yes_KR';
        $window =~ /\Q$motif_seq\E/;
        $motif_start = $-[0] + 1;
    }

    print join("\t", $protein_id, $signal_type, $motif_start, $motif_seq, $window), "\n";
}
