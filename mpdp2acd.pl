#!/usr/bin/perl
##requires: mpd, mpc, cdrdao
@playlists = split("\n", `mpc lsplaylists`);
printf("Available playlists:\n");
for (my $i = 0; $i < scalar @playlists; $i++) {
    printf("%d: %s\n", $i, $playlists[$i]);
}
printf("Choose a playlist to convert:");
$selection = <>;
chomp($selection);
if ($selection+0 < 0 || $selection+0 >= (scalar @playlists)) {
    printf("Invalid index\n");
    exit;
}
@songs = split("\n", `mpc playlist -f '\%file\%' $playlists[$selection]`);
$tmp_dir = "/tmp/mpdp2acd-$playlists[$selection]";
my $exit_code = system("mkdir \"$tmp_dir\"");
if ($exit_code != 0) {
    printf("Failed to create tmp directory\n");
    exit;
}

for (my $i = 0; $i < scalar @songs; $i++) {
    my $song = $songs[$i];
    my $exit = system("ffmpeg -loglevel quiet -i \"$song\" -map_metadata 0 \"$tmp_dir/$i.wav\"");
}
#TODO create TOC for cdrdao