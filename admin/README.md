
# create self-signed certificates

https://docs.microsoft.com/en-us/azure/application-gateway/self-signed-certificates


* create root key
openssl ecparam -out contoso.key -name prime256v1 -genkey

* create root certificate and sign it
openssl req -new -sha256 -key contoso.key -out contoso.csr
openssl x509 -req -sha256 -days 365 -in contoso.csr -signkey contoso.key -out contoso.crt


* create a server certificate

first the certificate key:
openssl ecparam -out fabrikam.key -name prime256v1 -genkey

next the certificate signing request
openssl req -new -sha256 -key fabrikam.key -out fabrikam.csr


* generate certificate
openssl x509 -req -in fabrikam.csr -CA contoso.crt -CAkey contoso.key -CAcreateserial -out fabrikam.crt -days 365 -sha256


* verify the certificate
openssl x509 -in fabrikam.crt -text -noout


* important files:

    contoso.crt
    contoso.key
    fabrikam.crt
    fabrikam.key
