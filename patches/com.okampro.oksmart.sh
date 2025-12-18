#!/usr/bin/env bash

target_dir="$1"
EXIT_CODE=0

if [ -z "$target_dir" ]; then
    echo "Error: com.okampro.oksmart.sh requires a directory argument"
    exit 1
fi

echo "Applying patches for com.okampro.oksmart..."

# Patch libOKSMARTJIAMI.so
so_file="${target_dir}/root/lib/armeabi-v7a/libOKSMARTJIAMI.so"
if [ -f "$so_file" ]; then
    echo "Checking $so_file..."
    
    # Check for original bytes
    # Sequence: 28 46 41 46 ff f7 ce ec 00 28 08 bf
    if perl -0777 -ne 'exit 0 if /\x28\x46\x41\x46\xff\xf7\xce\xec\x00\x28\x08\xbf/; exit 1' "$so_file"; then
        echo "  Target bytes found. Patching..."
        perl -i -pe 's/\x28\x46\x41\x46\xff\xf7\xce\xec\x00\x28\x08\xbf/\x28\x46\x41\x46\x00\xbf\x00\xbf\x00\x28\x08\xbf/g' "$so_file"
        # Verify that the patched bytes are now present
        if [ $? -eq 0 ] && perl -0777 -ne 'exit 0 if /\x28\x46\x41\x46\x00\xbf\x00\xbf\x00\x28\x08\xbf/; exit 1' "$so_file"; then
            echo "  Patch applied successfully."
        else
            echo "  Error: Patch command did not update target bytes."
            EXIT_CODE=1
        fi
    # Check for already patched bytes
    # Sequence: 28 46 41 46 00 bf 00 bf 00 28 08 bf
    elif perl -0777 -ne 'exit 0 if /\x28\x46\x41\x46\x00\xbf\x00\xbf\x00\x28\x08\xbf/; exit 1' "$so_file"; then
        echo "  Target bytes already patched. Skipping."
    else
        echo "  Error: Target bytes not found in $so_file."
        EXIT_CODE=1
    fi
else
    echo "Warning: $so_file not found."
    EXIT_CODE=1
fi

exit $EXIT_CODE
