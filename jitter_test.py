#!/usr/bin/env python3
def jitter_test():
    current_state = 32767
    langevin_kick = -0.05 * 32768.0
    updated_state = int(current_state + langevin_kick)
    print("--- SE(3) Jitter Test ---")
    print(f"Plateau: {current_state}")
    print(f"Updated: {updated_state}")
    if updated_state < current_state:
        print("✓ DYNAMIC")
        return True
    else:
        print("✗ STAGNANT")
        return False
if __name__ == "__main__":
    success = jitter_test()
    exit(0 if success else 1)
