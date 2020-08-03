#!/usr/bin/perl
##requires: mpd, mpc, cdrdao
use strict;
use warnings;
use JSON;
use File::Temp "tempdir";

sub YesNo {
    print("$_[0] [Y/n]\n");
    my $chosen = <>;
    chomp($chosen);
    $chosen = lc($chosen);
    return ($chosen eq "" || $chosen eq "y")
}

sub GenTrackTextBlock { # song URI, index
    my ($filename) = @_;
    $filename =~ s/'/'\\''/g;
    my $output = `ffprobe -v quiet -print_format json -show_format '$filename'`;
    my $json = decode_json($output);
    my $title = $json->{"format"}{"tags"}{"title"};
    my $artist = $json->{"format"}{"tags"}{"artist"} // $json->{"format"}{"tags"}{"album_artist"};
    if (!defined $title || $title =~ /[^\x00-\x7F]/) {
        my $add_metadata = YesNo("The track $_[0] does not have title metadata, or it contains characters that may not display properly. Do you want to edit the title?");
        if ($add_metadata) {
            print("Set title for $_[0]:");
            $title = <>;
        } else {
            $title = "";
        }
    }
    if (!defined $artist || $artist =~ /[^\x00-\x7F]/) {
        my $add_metadata = YesNo("The track $_[0] does not have artist metadata, or it contains characters that may not display properly. Do you want to edit the artist?");
        if ($add_metadata) {
            print("Set artist for $_[0]:");
            $artist = <>;
        } else {
            $artist = "";
        }
    }
    chomp($title);
    chomp($artist);
    return "TRACK AUDIO
CD_TEXT {
    LANGUAGE 0 {
        TITLE \"$title\"
        PERFORMER \"$artist\"
    }
}
FILE \"$_[1].wav\" 0
"
}

my @playlists = split("\n", `mpc lsplaylists`);
printf("Available playlists:\n");
for (my $i = 0; $i < @playlists; $i++) {
    printf("%d: %s\n", $i, $playlists[$i]);
}
printf("Choose a playlist to convert:");
my $selection = <>;
chomp($selection);
if ($selection < 0 || $selection >= (scalar @playlists)) {
    die("Invalid index");
}
my @songs = split("\n", `mpc playlist -f '\%file\%' $playlists[$selection]`);

my $tmp_dir =  tempdir(CLEANUP => 0);
my @cdtext_info = ();
for (my $i = 0; $i < scalar @songs; $i++) {
    my $song = $songs[$i];
    my $song_index = $i+1;
    $cdtext_info[$i] = GenTrackTextBlock($song, $song_index);
    my $exit = system("ffmpeg -loglevel quiet -i \"$song\" -map_metadata 0 -ar 44100 \"$tmp_dir/$song_index.wav\"");
}
my $final_cdtext = undef;
my $formatted_cdtext_info = join("\n", @cdtext_info);
print("CD Text Title (leave blank for $playlists[$selection]):");
my $cdtext_title = <>;
chomp($cdtext_title);
if ($cdtext_title eq "") {
    $cdtext_title = $playlists[$selection];
}
print("CD Text Artist:");
my $cdtext_artist = <>;
chomp($cdtext_artist);
$final_cdtext = 
"CD_DA

CD_TEXT {
    LANGUAGE_MAP {
        0 : EN
    }
    LANGUAGE 0 {
        TITLE \"$cdtext_title\"
        PERFORMER \"$cdtext_artist\"
    }
}

$formatted_cdtext_info
";
open(FH, '>', "$tmp_dir/toc.txt");
print FH $final_cdtext;
close(FH);

my $use_wavegain = YesNo("Would you like to use wavegain to normalize volume levels?");
if ($use_wavegain) {
    my $exit_code = system("cd $tmp_dir && wavegain -y $tmp_dir/*.wav 2>/dev/null");
    if ($exit_code != 0) {
        die("wavegain returned non-zero exit code $exit_code");
    }
    print("wavegain processing completed\n");
}