
* increase number of persistent connections and reduce timeouts to increase performance level: edit `/etc/apache2/apache2.conf` and change `MaxKeepAliveRequests` and `KeepAliveTimeout`, for example

```
MaxKeepAliveRequests 500
KeepAliveTimeout 1
```

Don't forget to restart the server

```
sudo apache2ctl restart
```

