
* increase number of persistent connections and increase timeout to increase performance level: edit `/etc/apache2/apache2.conf` and change `MaxKeepAliveRequests` (0 menas unlimited) and `KeepAliveTimeout`, for example

```
MaxKeepAliveRequests 0
KeepAliveTimeout 60
```

Don't forget to restart the server

```
sudo apache2ctl restart
```

