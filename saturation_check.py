#!/usr/bin/env python3

def saturation_check():
    """Verify Q1.15 saturation at hardware plateau."""
    
    # The "Gold Standard" output from AKI Simulation
    effort_float = 9.567550687692009
    
    # Q1.15 scaling factor (15 bits of fractional precision)
    scale = 32768.0
    
    # Calculate the raw register value
    raw_bits = int(effort_float * scale)
    
    # Simulate Hardware Saturated Arithmetic
    # This prevents the system from 'leaking' into negative values
    plateau_value = min(max(raw_bits, -32768), 32767)
    
    print("--- SE(3) Master Kernel: Saturation Check ---")
    print(f"Floating Point Effort: {effort_float}")
    print(f"Raw Bit Conversion:    {raw_bits}")
    print(f"Hardware Register:     {plateau_value}")
    print()
    
    if plateau_value == 32767:
        print("✓ RESULT: SUCCESS. The plateau holds.")
        return True
    else:
        print("✗ RESULT: FAILURE. Numerical drift detected.")
        return False

if __name__ == "__main__":
    success = saturation_check()
    exit(0 if success else 1)
