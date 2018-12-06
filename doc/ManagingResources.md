
# Managing resources in the repository


* Converting aligned bitexts to TMX

Either one specific bitext or all bitexts in a subtree of the repository directory:

```
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/corpus/user/xml/en-sv/4.xml?uid=user&run=make_tmx"
$LETSMT_CONNECT -X PUT "$LETSMT_URL/job/corpus/user/xml/en-sv?uid=user&run=make_tmx"
```



* Sending resource by e-mail (zip archives or plain files):

Just add the argument `email` with the e-mail address to send to:

```
$LETSMT_CONNECT -X GET "$LETSMT_URL/storage/corpus/user/xml/en/test.html?uid=user&action=download&email=name@domain.org"
$LETSMT_CONNECT -X GET "$LETSMT_URL/storage/corpus/user/xml/en/test.html?uid=user&action=download&archive=no&email=name@domain.org"
```