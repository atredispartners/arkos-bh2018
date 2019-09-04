import struct
import sys

disk_files = []
disk_files.append((b'/home/atredis/map.png', open('./files/map.png', 'rb').read()))
disk_files.append((b'/etc/motd', open('./files/motd', 'rb').read()))
disk_files.append((b'/var/mail/spool/atredis', open('./files/mail', 'rb').read()))
disk_files.append((b'/home/atredis/.mail/attachment123.txt', open('./files/key.txt', 'rb').read()))


image_rest = b''
image_rest_sector = 0x40
image_header = b''

for i in range(0x40):
    if i >= len(disk_files):
        image_header += b'\x00' * 0x40
    else:
        f_name, f_data = disk_files[i]
        assert(len(f_name) < 0x2f)

        f_sector_count = int((len(f_data) + 0x3f) / 0x40)
        if len(f_data) % 0x40 != 0:
            padding = b'\x00' * (0x40 - (len(f_data) % 0x40))
            f_data += padding

        f_sector = image_rest_sector
        image_rest_sector += f_sector_count

        image_rest += f_data

        f_name += b'\x00'
        if len(f_name) < 0x30:
            f_name += b'\x00' * (0x30 - len(f_name))
        f_header = f_name + struct.pack('<HHIII', f_sector, f_sector_count, 0, 0, 0)
        image_header += f_header

image_path = sys.argv[1]
with open(image_path, 'wb') as f:
    f.write(image_header)
    f.write(image_rest)
