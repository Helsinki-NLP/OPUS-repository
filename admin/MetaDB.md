
# TokyoTyrant

TokyoTyrant may slow downsubstantially for large databases. Consider the following:

- tcrmgr optimize -port 1980 localhost (this is done in cronjobs as well)
- optimize bnum and xmsiz
- host database on ext2 filesystem (no journaling) instead of ext3/ext4
- see also: https://stackoverflow.com/questions/1051847/why-does-tokyo-tyrant-slow-down-exponentially-even-after-adjusting-bnum/2394599

