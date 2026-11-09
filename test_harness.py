import socket
import struct
import time

def calculate_swar_fold(packet_bytes: bytes) -> int:
    """
    Simulates the 64-bit SWAR XOR-fold integrity tag calculated on the CPU.
    XOR folds the first 7 u64 blocks (bytes 0..56).
    """
    checksum = 0
    # Explicitly pull index [0] to extract the raw integer out of the tuple layout
    for i in range(0, 56, 8):
        chunk = packet_bytes[i:i+8]
        val = struct.unpack("<Q", chunk)[0]
        checksum ^= val
    return checksum

def build_lan_frame(sequence: int, worker_id: int, task_id: int, completed_mask: int, opcode: int = 0x02) -> bytes:
    """
    Constructs a cache-aligned 64-byte LanFrame64 wire packet with a valid SWAR tag.
    """
    magic = 0x8B15
    gate = 0x62
    runnable_mask = 0xFFFFFFFFFFFFFFFF
    payload = b"\x00" * 24

    # Layout string matching the exact byte widths of the main.zig extern struct:
    # H (u16), B (u8), B (u8), H (u16), H (u16), Q (u64), Q (u64), Q (u64), 24s (24-byte payload array)
    base_format = "<H B B H H Q Q Q 24s"
    pre_packet = struct.pack(
        base_format,
        magic, gate, opcode,
        worker_id, task_id,
        sequence, runnable_mask, completed_mask,
        payload
    )

    # Append the final 64-bit SWAR fold checksum tag to close the 64-byte frame exactly
    fold_tag = calculate_swar_fold(pre_packet)
    return pre_packet + struct.pack("<Q", fold_tag)

def decode_lan_frame(packet_bytes: bytes):
    """
    Decodes an inbound 64-byte LanFrame64 network packet using explicit tuple indices.
    """
    if len(packet_bytes) != 64:
        return None
        
    base_format = "<H B B H H Q Q Q 24s Q"
    unpacked = struct.unpack(base_format, packet_bytes)
    return {
        "magic": unpacked[0],
        "gate": unpacked[1],
        "opcode": unpacked[2],
        "worker_id": unpacked[3],
        "task_id": unpacked[4],
        "sequence": unpacked[5],
        "runnable_mask": unpacked[6],
        "completed_mask": unpacked[7],
        "payload": unpacked[8].strip(b"\x00"),
        "fold_tag": unpacked[9]
    }

def run_validation_harness():
    UDP_IP = "127.0.0.1"
    AUDITOR_PORT = 18815

    # Establish full-duplex socket loopback
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((UDP_IP, 0)) # Bind to an ephemeral port to securely capture return feedback packets
    sock.settimeout(2.0)   # Protect the loop thread from freezing if a packet drops

    print("==================================================================")
    print("      8B CAGE SIMPLEX FULL-DUPLEX NETWORK HARNESS ACTIVE")
    print("==================================================================")
    print(f"Streaming target frames to auditor on {UDP_IP}:{AUDITOR_PORT}...")
    
    seq = 0
    try:
        while True:
            seq += 1
            print("-" * 66)
            
            # Scenario A: Pumping Stable Invariant Baselines
            if seq % 5 != 0:
                print(f"[Seq: {seq}] Transmitting valid trace -> Worker 1 (Normal Operations)")
                packet = build_lan_frame(sequence=seq, worker_id=1, task_id=2, completed_mask=5)
                sock.sendto(packet, (UDP_IP, AUDITOR_PORT))
                time.slice_duration = 1.0
                time.sleep(time.slice_duration)
                
            # Scenario B: Injecting the Anomaly to Trip Phase D
            else:
                print(f"⚠️  [Seq: {seq}] ADVERSARIAL INJECTION -> Simulating Cluster Drift on Worker 4...")
                packet = build_lan_frame(sequence=seq, worker_id=4, task_id=75, completed_mask=99999)
                sock.sendto(packet, (UDP_IP, AUDITOR_PORT))
                
                print("⏳ Blocking thread execution... listening for Allostatic Circuit Breaker feedback...")
                try:
                    # Intercept the auditor's rapid 0x0F stasis reply buffer from the network card
                    response_bytes, _ = sock.recvfrom(64)
                    frame = decode_lan_frame(response_bytes)
                    
                    if frame and frame["opcode"] == 0x0F:
                        print("\n🚨 [ALLOSTATIC COLLAPSE INTERCEPTED]")
                        print(f"  └─ Magic Signature Checked : {hex(frame['magic'])}")
                        print(f"  └─ Isolated Rogue Worker ID: {frame['worker_id']}")
                        print(f"  └─ Stasis Invariant Opcode : {hex(frame['opcode'])} (FORCED STASIS LAYOUT)")
                        print(f"  └─ Vector Violation Metric : {frame['completed_mask']} (Drift Invariant Numerator)")
                        print(f"  └─ Signed Payload Marker   : {frame['payload'].decode('utf-8')}")
                        print("✅ Success: Phase D Out-of-Band Circuit Breaker is operational.\n")
                    else:
                        print("❌ Error: Intercepted an unexpected or malformed packet response layout.")
                except socket.timeout:
                    print("❌ Failure: Auditor tool timed out. No Allostatic feedback signal captured.")
                
                time.sleep(2.0) # Allocation rest window after forcing branch stasis
                
    except KeyboardInterrupt:
        print("\n[Harness Terminated] Local cluster validation baseline complete.")
    finally:
        sock.close()

if __name__ == "__main__":
    run_validation_harness()

