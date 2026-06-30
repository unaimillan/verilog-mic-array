import socket

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(('0.0.0.0', 8888))

while True:
    data, addr = sock.recvfrom(1024)
    if len(data) == 8:
        import struct
        v0, v1, v2, v3 = struct.unpack('<hhhh', data)  # '<' for little-endian
        print(f"Received: {v0} {v1} {v2} {v3}")
