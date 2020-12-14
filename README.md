# mpdp2acd
mpd playlist to audio CD

A perl script to burn an audio CD from an mpd playlist. 
Made primarily for the tiny subset of people who love to use MPD but also for some reason need to still use Audio CDs (for older vehicles, perhaps)

## Dependencies
`cdrdao`, `ffmpeg`, `ffprobe`, `mpc`, `mpd`, `perl`, `perl-json`, `wavegain` (optional), `tar`, (optional)

## Notes
If the burn fails or the CD-Text data fails to be burned to the CD, try switching the driver in `burn.sh` from `generic-mmc:0x10` to `generic-mmc-raw`. This will just depend on what burner you're using. I have a TSSTcorp SH-224BB which I think may be a Samsung SH-224BB in disguise. Regardless, I had to use `generic-mmc:0x10`. 


I also notice that sometimes even when reading CD-Text back, `cdrdao` won't detect it. However, my car stereo (2011 Honda CR-V) does. 


Big thanks to [apocalyptech](https://apocalyptech.com/linux/cdtext/) as their site had a lot of the information I needed to get this project off the ground. 
