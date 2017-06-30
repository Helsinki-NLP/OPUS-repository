#!/bin/bash

export LANG=en_US.UTF-8

# update svn
echo "update svn"
cd /home/letsmt/svn/trunk
svn update --non-interactive

# make documentation
echo "update documentation"
make -C /home/letsmt/svn/trunk/dev/src/perllib/LetsMT/doc/ all


# nightly source tarball
echo "make a new source tarball"
weekday=`date +%A`
cd /tmp
svn export svn://stp.ling.uu.se/letsmt/trunk/dev/src LetsMT-${weekday}
cd LetsMT-${weekday}
svnversion > REVISION
cd ..
tar -zcf LetsMT-${weekday}.tar.gz LetsMT-${weekday}
mv LetsMT-${weekday}.tar.gz /home/letsmt/backup
rm -fr LetsMT-${weekday}

#
# This file is part of LetsMT! Resource Repository.
#
# LetsMT! Resource Repository is free software: you can redistribute it
# and/or modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# LetsMT! Resource Repository is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with LetsMT! Resource Repository.  If not, see
# <http://www.gnu.org/licenses/>.
#