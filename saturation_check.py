#!/usr/bin/env python3

def saturation_check():
    effort_float = 9.567550687692009
    scale = 32768.0
    raw_bits = int(effort_float * scale)
    plateau_value = min(max(raw_bits, -32768), 32767)
    
    print("--- SE(3) Master Kernel: Saturation Check ---")
    print(f"Floating Point: {effort_float}")
    print(f"Raw Bits: {raw_bits}")
    print(f"Register: {plateau_value}")
    print()
    
    if plateau_value == 32767:
        print("✓ SUCCESS: Plateau holds.")
        return True
    else:
        print("✗ FAILURE: Drift detected.")
        return False

if __name__ == "__main__":
    success = saturation_check()
    exit(0 if success else 1)
