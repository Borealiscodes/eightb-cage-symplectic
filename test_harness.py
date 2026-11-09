import socket
import struct
import time

def calculate_swar_fold(packet_bytes: bytes) -> int:
    """
    Simulates the 64-bit SWAR XOR-fold integrity tag calculated on the CPU.
    XOR folds the first 7 u64 blocks (bytes 0..56).
    """
    checksum = 0
    # Process the first 56 bytes as seven 64-bit unsigned integers
    for i in range(0, 56, 8):
        chunk = packet_bytes[i:i+8]
        # Unpack as little-endian unsigned 64-bit integer
        val = struct.unpack("<Q", chunk)[0]
        checksum ^= val
    return checksum

def send_mock_frame(sequence: int, worker_id: int, task_id: int, completed_mask: int):
    # Target address matching our main.zig UDP configurations
    UDP_IP = "127.0.0.1"
    UDP_PORT = 18815

    # Structure Definition Mapping:
    # 0..2   magic          (u16)  -> 0x8B15
    # 2..3   gate           (u8)   -> 0x62
    # 3..4   opcode         (u8)   -> 0x02 (TaskDispatch)
    # 4..6   worker_id      (u16)
    # 6..8   task_id        (u16)
    # 8..16  sequence       (u64)
    # 16..24 runnable_mask  (u64)
    # 24..32 completed_mask (u64)
    # 32..56 payload        (24u8) -> Padded with zeros
    
    magic = 0x8B15
    gate = 0x62
    opcode = 0x02
    runnable_mask = 0xFFFFFFFFFFFFFFFF
    payload = b"\x00" * 24

    # Pack the first 56 bytes using standard little-endian formats
    # Layout string: <H B B H H Q Q Q 24s
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
    final_packet = pre_packet + struct.pack("<Q", fold_tag)

    # Fire raw packet buffer directly through local socket interfaces
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(final_packet, (UDP_IP, UDP_PORT))
    sock.close()

if __name__ == "__main__":
    print("=== STARTING 8B CAGE SIMPLEX NETWORK INGESTION VALIDATOR ===")
    print("Streaming live frames into loopback 127.0.0.1:18815...")
    
    seq = 0
    try:
        while True:
            seq += 1
            # Run stable baseline trajectories
            if seq % 5 != 0:
                print(f"Sending valid trace packet [Seq: {seq}]...")
                send_mock_frame(sequence=seq, worker_id=1, task_id=2, completed_mask=5)
            # Inject a dynamic anomaly packet every 5 loops to trigger the circuit-breaker
            else:
                print(f"⚠️  Injecting anomalous perturbation packet [Seq: {seq}]...")
                send_mock_frame(sequence=seq, worker_id=4, task_id=75, completed_mask=99999)
                
            time.sleep(1.0)
    except KeyboardInterrupt:
        print("\nTesting validation complete.")
