
# TokyoTyrant

TokyoTyrant may slow down substantially for large databases. Consider the following:

- tcrmgr optimize -port 1980 localhost (this is done in cronjobs as well)
- optimize bnum and xmsiz
- host database on ext2 filesystem (no journaling) instead of ext3/ext4
- see also: https://stackoverflow.com/questions/1051847/why-does-tokyo-tyrant-slow-down-exponentially-even-after-adjusting-bnum/2394599

## Troubleshooting

If access seems impossible and optimising the DB doesn't really work:
- move to a new partition without journaling
- do `cat metadata* > /dev/null` - that somehow seem to help
