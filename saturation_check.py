#!/usr/bin/env python3
def saturation_check():
    effort_float = 9.567550687692009
    scale = 32768.0
    raw_bits = int(effort_float * scale)
    plateau_value = min(max(raw_bits, -32768), 32767)
    print("--- SE(3) Saturation Check ---")
    print(f"Value: {effort_float}")
    print(f"Register: {plateau_value}")
    if plateau_value == 32767:
        print("✓ SUCCESS")
        return True
    else:
        print("✗ FAILURE")
        return False
if __name__ == "__main__":
    success = saturation_check()
    exit(0 if success else 1)
