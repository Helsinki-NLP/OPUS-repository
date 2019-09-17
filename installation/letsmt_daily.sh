#!/bin/bash

find /var/tmp -atime +7 -delete
find /tmp -atime +7 -delete
