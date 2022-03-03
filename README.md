# mpdp2acd
mpd playlist to audio CD

A perl script to burn an audio CD from an mpd playlist. 
Made primarily for the tiny subset of people who love to use MPD but also for some reason need to still use Audio CDs (for older vehicles, perhaps)

## Dependencies
> Required tools/dependencies
> `ffmpeg`, `ffprobe`, `mpc`, `mpd`, `perl`, `perl-json`

> Audio CD dependencies
> `cdrdao`, `wavegain` (optional), `tar` (optional)

> mp3 disc dependencies
> `mkisofs`, `cdrecord`

## WAV or MP3?
The script will allow you to pick between an audio/"Red book" CD (lossless, but maximum of ~80 minutes of audio) or an ISO-9660 filesystem with mp3 files on it. Depending on the bitrate you pick for the mp3 files, you can fit far more music on it. At 256kbps (maximum supported by the script at this time) you can fit approximately 6 hours on a disc, and that time only goes up as you decrease the quality. You will also want to pick the ISO-9660 option if you intend on adding more files at a later date, as audio CDs typically do not support multi session.

## Why are some options unavailable?
The script only allows you to pick options that will actually fit on a CD. 
If your playlist is longer than 80 minutes, the WAV option is going to be grayed out. 
The MP3 options will also become unavailable as your playlist continues to grow in length (though this shouldn't really be a big issue unless you have 10+ hours of music)

## Notes
If the burn fails or the CD-Text data fails to be burned to the CD, try switching the driver in `burn.sh` from `generic-mmc:0x10` to `generic-mmc-raw`. This will just depend on what burner you're using. I have a TSSTcorp SH-224BB which I think may be a Samsung SH-224BB in disguise. Regardless, I had to use `generic-mmc:0x10`. 


I also notice that sometimes even when reading CD-Text back, `cdrdao` won't detect it. However, my car stereo (2011 Honda CR-V) does. 


Big thanks to [apocalyptech](https://apocalyptech.com/linux/cdtext/) as their site had a lot of the information I needed to get this project off the ground. 
