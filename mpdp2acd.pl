#!/usr/bin/perl
##requires: mpd, mpc, cdrdao
use strict;
use warnings;
use JSON;
use File::Temp "tempdir";
use File::Basename;

sub Info {
    print("[\033[36;1mINFO\033[0m] $_[0]\n");
}

sub Warn {
    print("[\033[33;1mWARN\033[0m] $_[0]\n");
}

sub Error {
    print("[\033[31;1mWARN\033[0m] $_[0]\n");
}

sub YesNo {
    print("$_[0] [\033[1mY\033[0m/n]");
    my $chosen = <>;
    chomp($chosen);
    $chosen = lc($chosen);
    return ($chosen eq "" || $chosen eq "y")
}

sub GenTrackTextBlock { # song URI, index
    my ($filename) = @_;
    $filename =~ s/'/'\\''/g;
    my $output = `ffprobe -v quiet -print_format json -show_format "$filename"`;
    my $json = decode_json($output);
    my $title = $json->{"format"}{"tags"}{"title"};
    my $artist = $json->{"format"}{"tags"}{"artist"};
    if (!defined $artist) {
        my $temp = $json->{"format"}{"tags"}{"album_artist"};
        if (defined $temp) {
            Info("Using fallback album_artist for $_[0]\n");
            $artist = $temp;
        }
    }

    if (!defined $title) {
        $title = $json->{"format"}{"tags"}{"TITLE"};
    }

    #Ensure title meta is valid
    if (!defined $title) {
        my $add_metadata = YesNo("The track $_[0] does not have title metadata. Do you want to add a title?");
        if ($add_metadata) {
            Info("Set title for $_[0]:");
            $title = <>;
        } else {
            $title = "";
        }
    }
    if ($title =~ /[^\x00-\x7F]/) {
        Warn("The track \033[1m$_[0]\033[0m contains characters that may not render properly on some CD players.\n")
    }
    if (length($title) >=21) {
        Warn("The track $_[0] has title metadata that is longer than 21 characters, it may not be fully visible on some CD players.\n")
    }

    #Ensure artist meta is valid
    if (!defined $artist) {
        my $add_metadata = YesNo("The track $_[0] does not have artist metadata. Do you want to add an artist?");
        if ($add_metadata) {
            print("Set artist for $_[0]:");
            $artist = <>;
        } else {
            $artist = "";
        }
    }
    if ($artist =~ /[^\x00-\x7F]/) {
        Warn("The artist of track $_[0] contains characters that may not render properly on some CD players.\n")
    }
    if (length($artist) >=21) {
        Warn("The artist track $_[0] has title metadata that is longer than 21 characters, it may not be fully visible on some CD players.\n")
    }
    
    #Remove whitespace and generate the block
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

#parameter order:
# 0: source file path 1: desired bitrate 2: dest file path
sub ConvMP3 {
    my $fname = fileparse($_[0]);
    my @formats = (".mp3");
    my $destpath = $_[2]."/".$fname.".mp3";
    my $ffmpeg_cmd = "ffmpeg -loglevel quiet -i \"$_[0]\" -map_metadata 0 -b:a $_[1]k \"$destpath\"";
    my $exit = system($ffmpeg_cmd);
    if ($exit != 0) {
        Error("Failed to convert ".$_[0]);
    }
}

my $HOME = $ENV{"HOME"};
my @mpd_configs = ("$HOME/.mpdconf", "$HOME/.config/mpd/mpd.conf","/etc/mpd.conf");
sub DetermineMpdMusicDirectory {
    my $music_dir = undef;
    foreach my $config_file (@mpd_configs) {
        if (-e $config_file) {
            open my $FH, '<', $config_file;
            while (<$FH>) {
                my $line = $_ if $_ =~ /music_directory\s.*"/;
                if (!defined $line) {
                    next;
                }
                my @split_str = split(" ", $line);
                $music_dir = substr $split_str[1], 1, -1;
            }
        }
    }
    if (!defined $music_dir) {
        die("Cannot determine mpd music directory\n");
    }
    return $music_dir;
}

sub DeterminePlaylistLength {
    my $total_seconds = 0;
    my @lengths = split("\n", `mpc playlist -f '\%time\%' '$_[0]'`);
    foreach my $length (@lengths) {
        my @split = split(":", $length);
        $total_seconds += $split[1];
        $total_seconds += $split[0]*60;
    }
    return $total_seconds;
}

sub CommandExists {
    my $exit = `sh -c 'command -v $_[0]'`;
    return $exit;
}

my @required_commands = ("ffmpeg", "ffprobe", "mpc", "cdrdao");
my @mp3_req_commands = ("cdrecord", "mkisofs");
my $mp3_avail = 1;

for (my $i = 0; $i < scalar @required_commands; $i++) {
    my $cmd = $required_commands[$i];
    if (!CommandExists($cmd)) {
        Error("Cannot find required command $cmd, exiting");
        exit 1;
    }
}

for (my $i = 0; $i < scalar @mp3_req_commands; $i++) {
    my $cmd = $mp3_req_commands[$i];
    if (!CommandExists($cmd)) {
        Warn("Cannot find command $cmd, which is necessary for MP3 format discs. Only WAV will be available.");
        $mp3_avail = 0;
    }
}

my $mpd_music_directory = DetermineMpdMusicDirectory();
$mpd_music_directory =~ s/~/\$HOME/g;
print("Enter music directory (leave blank for $mpd_music_directory):");
my $mpd_dir_input = <>;
chomp($mpd_dir_input);
if ($mpd_dir_input ne "") {
    $mpd_music_directory = $mpd_dir_input;
}

my @playlists = split("\n", `mpc lsplaylists`);
printf("Available playlists:\n");
for (my $i = 0; $i < @playlists; $i++) {
    printf("%d: %s\n", $i, $playlists[$i]);
}
printf("Choose a playlist to convert:");
my $selection = <>;
chomp($selection);
while ($selection < 0 || $selection >= (scalar @playlists)) {
    Error("Invalid index");
    printf("Choose a playlist to convert:");
    $selection = <>;
}

#print out playlist quality options

my $playlist_length_seconds = DeterminePlaylistLength($playlists[$selection]);
Info("Playlist length is ".$playlist_length_seconds." seconds");
my $cd_format_choice = "";
my @mp3_formats = (64,96,128,196,256);
my @valid = ();
for (my $i = 0; $i < scalar @mp3_formats; $i++) {
    my $bitrate = $mp3_formats[$i];
    my $total_size = $playlist_length_seconds * (($bitrate)/(8*1024)); # total size in megabytes
    my $color = "\033[1m";
    my $extra = "";
    if ($total_size > 650 || !$mp3_avail) {
        $color = "\033[90;1m";
        $extra = "(unavailable)";
    } else {
        push(@valid, ($i+1));
    }
    printf("%s%d - MP3 [%dkbps] (~%.1f MB) %s\033[0m\n", $color, $i+1, $bitrate, $total_size, $extra);
}
if ($playlist_length_seconds > 80*60) { #80 minutes
    printf("\033[90;1m%d - WAV (unavailable)\033[0m\n", scalar @mp3_formats+1);
} else {
    push(@valid, (scalar @mp3_formats+1));
    printf("\033[1m%d - WAV\033[0m\n", scalar @mp3_formats+1);
}

my $format_selection = -1;
while (!($format_selection ~~ @valid)) {
    printf("Please select an option:");
    $format_selection = <>;
    chomp($format_selection);
}
$format_selection--; #move it into valid range

my @songs = split("\n", `mpc playlist -f '\%file\%' '$playlists[$selection]'`);

my $tmp_dir = tempdir(CLEANUP => 1);
my @cdtext_info = ();
for (my $i = 0; $i < scalar @songs; $i++) {
    my $song = $mpd_music_directory."/".$songs[$i];
    if ($format_selection eq scalar @mp3_formats) { #for WAV
        my $song_index = $i+1;
        $cdtext_info[$i] = GenTrackTextBlock($song, $song_index);
        my $ffmpeg_cmd = "ffmpeg -loglevel quiet -i \"$song\" -map_metadata 0 -ar 44100 \"$tmp_dir/$song_index.wav\"";
        my $exit = system($ffmpeg_cmd);
    } else { # for mp3
        Info("Converting ".($i+1)."/".scalar @songs);
        ConvMP3($song, $mp3_formats[$format_selection], $tmp_dir); #convert it to mp3 in the temp directory
    }
}

#cd text/artist

print("CD Text Title (leave blank for $playlists[$selection]):");
my $cdtext_title = <>;
chomp($cdtext_title);
if ($cdtext_title eq "") {
    $cdtext_title = $playlists[$selection];
}
print("CD Text Artist:");
my $cdtext_artist = <>;
chomp($cdtext_artist);

if ($format_selection eq scalar @mp3_formats) { #for WAV
    my $final_cdtext = undef;
    my $formatted_cdtext_info = join("\n", @cdtext_info);
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
        Info("wavegain processing completed\n");
    }

    my $burn_cmd = "cdrdao write --device /dev/sr0 --driver generic-mmc:0x10 -v 2 --eject toc.txt";
    my $burn_immediately = YesNo("Do you want to immediately burn this data to disc? (If no, a tar archive will be generated in your home directory)");
    if ($burn_immediately) {
        my $exit_code = system($burn_cmd);
        if ($exit_code != 0) {
            die("Failed to burn CD: cdrdao returned non-zero exit code $exit_code");
        }
    } else {
        open(FH, '>', "$tmp_dir/burn.sh");
        print FH $burn_cmd;
        print FH "\n# If this command fails (or if the cd-text data isn't present on the disc), try switching the driver to generic-mmc-raw instead. Using generic-mmc:0x10 worked for me with a TSSTcorp SH-224BB.";
        close(FH);
        my $tar_filename = "mpdp2acd-$playlists[$selection].tar.gz";
        my $exit_code = system("cd $tmp_dir && tar -czf ~/$tar_filename *");
        print("A file named $tar_filename has been placed in your home directory, run burn.sh to begin the burning process.");
    }
} else { #mp3 handling logic, need to use different software
    Info("Creating CD session...");
    my $isoname = "mpdp2acd-".$cdtext_title.".iso";
    my $exit = system("mkisofs -V \"$cdtext_title\" -J -r -o \"$isoname\" $tmp_dir");
    if ($exit != 0) {
        Error("Failed to create CD session.");
        exit 1;
    }
    Info("CD session generated.");
    my $burn_now = YesNo("Would you like to burn this to disc immediately?");
    if ($burn_now) {
        printf("Path to CD drive [leave blank for /dev/sr0]:");
        my $cd_dev = <>;
        chomp($cd_dev);
        if ($cd_dev eq "") {
            $cd_dev = "/dev/sr0";
        }

    } else {
        Info("An iso is available in the current directory.");
    }
}