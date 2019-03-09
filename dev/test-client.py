import asyncio, socket

request = None

try:
    while request != 'quit':
        request = input('>> ')
        if request:
            server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            server.connect(('localhost', 15555))
            request += "\n"
            server.send(request.encode('utf8'))
            command = "<<CLASSIFY>>\n"
            server.send(command.encode('utf8'))
            response = server.recv(255).decode('utf8')
            print(response)
            server.close()

            server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            server.connect(('localhost', 15555))
            server.send(request.encode('utf8'))
            command = "CLASSIFIER=cld2\n"
            server.send(command.encode('utf8'))
            command = "<<CLASSIFY>>\n"
            server.send(command.encode('utf8'))
            response = server.recv(255).decode('utf8')
            print("cld2: " + response)
            server.close()

            server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            server.connect(('localhost', 15555))
            server.send(request.encode('utf8'))
            command = "CLASSIFIER=cld2\n"
            server.send(command.encode('utf8'))
            command = "LANGHINT=de\n"
            server.send(command.encode('utf8'))
            command = "<<CLASSIFY>>\n"
            server.send(command.encode('utf8'))
            response = server.recv(255).decode('utf8')
            print("cld2 + langhint: " + response)
            server.close()

except KeyboardInterrupt:
    server.close()
