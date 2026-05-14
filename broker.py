#!/usr/bin/env python3
import socket
import threading
import sqlite3
import libvirt
import pam
import logging
import time
import subprocess

BROKER_PORT = 2222
DB_PATH = "/var/lib/broker/users.db"
LOG_PATH = "/var/log/broker/broker.log"

logging.basicConfig(
    filename=LOG_PATH,
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s"
)

def get_vm_ip(vm_name):
    try:
        conn = libvirt.open("qemu:///system")
        dom = conn.lookupByName(vm_name)
        xml = dom.XMLDesc()
        mac = None
        for line in xml.split("\n"):
            if "mac address" in line:
                mac = line.strip().split("'")[1]
                break
        conn.close()
        if not mac:
            return None
        # Ping scan хийж ARP cache дүүргэх
        try:
            subprocess.run(
                "for i in $(seq 170 190); do ping -c1 -W1 192.168.10.$i >/dev/null 2>&1 & done; wait",
                shell=True, timeout=15
            )
        except:
            pass
        # ARP-ээс IP хайх
        try:
            result = subprocess.run(
                ["arp", "-n"], capture_output=True, text=True
            )
            for line in result.stdout.split("\n"):
                if mac.lower() in line.lower():
                    return line.split()[0]
        except:
            pass
        # dnsmasq lease файлаас хайх
        try:
            with open("/var/lib/misc/dnsmasq.leases") as f:
                for line in f:
                    parts = line.strip().split()
                    if len(parts) >= 3 and parts[1].lower() == mac.lower():
                        return parts[2]
        except:
            pass
        return None
    except Exception as e:
        logging.error(f"get_vm_ip error: {e}")
        return None

def resume_vm(vm_name):
    try:
        conn = libvirt.open("qemu:///system")
        dom = conn.lookupByName(vm_name)
        state, _ = dom.state()
        if state == libvirt.VIR_DOMAIN_PAUSED:
            dom.resume()
            logging.info(f"Resumed VM: {vm_name}")
        elif state == libvirt.VIR_DOMAIN_SHUTOFF:
            dom.create()
            logging.info(f"Started VM: {vm_name}")
        conn.close()
        time.sleep(3)
    except Exception as e:
        logging.error(f"resume_vm error: {e}")

def handle_client(conn, addr):
    logging.info(f"Connection from {addr}")
    try:
        data = conn.recv(1024).decode().strip()
        parts = data.split(" ", 2)
        if len(parts) != 3 or parts[0] != "AUTH":
            conn.send(b"ERROR invalid_request\n")
            return

        _, username, password = parts

        p = pam.pam()
        p.service = "broker"
        if not p.authenticate(username, password):
            logging.warning(f"Auth failed: {username} from {addr}")
            conn.send(b"ERROR auth_failed\n")
            return

        db = sqlite3.connect(DB_PATH)
        cur = db.cursor()
        cur.execute("SELECT vm_name FROM users WHERE username=?", (username,))
        row = cur.fetchone()
        db.close()

        if not row:
            logging.warning(f"No VM for user: {username}")
            conn.send(b"ERROR no_vm\n")
            return

        vm_name = row[0]
        resume_vm(vm_name)

        # IP хайх — 10 удаа, 2 секунд зайтай
        vm_ip = None
        for _ in range(10):
            vm_ip = get_vm_ip(vm_name)
            if vm_ip:
                break
            time.sleep(2)

        if not vm_ip:
            conn.send(b"ERROR vm_no_ip\n")
            return

        # last_login шинэчлэх
        db2 = sqlite3.connect(DB_PATH)
        db2.execute(
            "UPDATE users SET last_login=datetime('now') WHERE username=?",
            (username,)
        )
        db2.commit()
        db2.close()

        response = f"OK vm_ip:{vm_ip}\n"
        conn.send(response.encode())
        logging.info(f"User {username} → {vm_name} ({vm_ip})")

    except Exception as e:
        logging.error(f"Error: {e}")
        conn.send(b"ERROR server_error\n")
    finally:
        conn.close()

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("0.0.0.0", BROKER_PORT))
    server.listen(10)
    logging.info(f"Broker listening on port {BROKER_PORT}")
    print(f"Broker started on port {BROKER_PORT}")
    while True:
        client, addr = server.accept()
        t = threading.Thread(target=handle_client, args=(client, addr))
        t.daemon = True
        t.start()

if __name__ == "__main__":
    main()
