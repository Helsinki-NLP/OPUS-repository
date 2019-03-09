#!/usr/bin/env python3

import asyncio, socket
import langid
import pycld2 as cld2

from langid.langid import LanguageIdentifier, model
identifier = LanguageIdentifier.from_modelstring(model, norm_probs=True)

# adapted from
# https://stackoverflow.com/questions/48506460/python-simple-socket-client-server-using-asyncio
# with changes from
# https://stackoverflow.com/questions/43948454/python-invalid-syntax-with-async-def

@asyncio.coroutine
def handle_client(reader, writer):
    request = None
    classifier = 'langid'
    langhint = None
    received = '';
    while not '<<CLASSIFY>>' in received:
        request = (yield from reader.read(255)).decode('utf8')
        if (request):
            # print("received "+request)
            received += request

    response = None
    text = '';
    received = received.replace('<<CLASSIFY>>','')
    lines = received.split("\n")
    for l in lines:
        if ('CLASSIFIER=' in l):
            classifier = l.split('=')[1]
        elif ('LANGHINT=' in l):
            langhint = l.split('=')[1]
        else:
            text += l

    # print("classify "+text)
    if (classifier == 'cld2'):
        if (langhint):
            isReliable, textBytesFound, details = cld2.detect(text, bestEffort=True, hintLanguage=langhint)
        else:
            isReliable, textBytesFound, details = cld2.detect(text, bestEffort=True)
        response = str((details[0][1],isReliable,details))
    else:
        response = str(identifier.classify(text))
    writer.write(response.encode('utf8'))


loop = asyncio.get_event_loop()
loop.create_task(asyncio.start_server(handle_client, 'localhost', 15555))
loop.run_forever()
