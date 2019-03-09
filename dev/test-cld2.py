import pycld2 as cld2

# detectedLangName, detectedLangCode, isReliable, textBytesFound, details 


isReliable, textBytesFound, details = cld2.detect("This is my sample text", bestEffort=True)
# print '  detected: %s' % detectedLangName
print('  reliable: %s' % (isReliable != 0))
print('  textBytes: %s' % textBytesFound)
print('  details: %s' % str(details))

# The output look lie so:
#  detected: ENGLISH
#  reliable: True
#  textBytes: 25
#  details: [('ENGLISH', 'en', 64, 20.25931928687196), ('FRENCH', 'fr', 36, 8.221993833504625)]




## python -c "import cld2; help(cld2.detect)"



# https://github.com/scrapinghub/python-cld2
# https://metacpan.org/pod/distribution/Inline-Python/Python.pod
# https://github.com/google/cld3
