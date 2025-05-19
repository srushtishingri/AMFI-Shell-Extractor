#!/bin/bash

# Script to extract Scheme Name and Asset Value from AMFI NAV data
# and save as TSV file

echo "Fetching AMFI NAV data..."
OUTPUT_TSV="amfi_nav_data.tsv"
OUTPUT_JSON="amfi_nav_data.json"
URL="https://www.amfiindia.com/spages/NAVAll.txt"

# Create temporary file
TEMP_FILE=$(mktemp)

# Download the data
if command -v curl &> /dev/null; then
    curl -s "$URL" > "$TEMP_FILE"
elif command -v wget &> /dev/null; then
    wget -q -O "$TEMP_FILE" "$URL"
else
    echo "Error: Neither curl nor wget is installed. Please install one of them."
    exit 1
fi

# Check if download was successful
if [ ! -s "$TEMP_FILE" ]; then
    echo "Error: Failed to download data or file is empty."
    rm "$TEMP_FILE"
    exit 1
fi

echo "Data downloaded successfully."

# Create TSV file with header
echo -e "Scheme Name\tScheme Code\tISIN\tNAV Value\tDate" > "$OUTPUT_TSV"

# Process the file
current_scheme=""
line_count=0
processed_count=0

while IFS= read -r line; do
    # Skip empty lines and headers
    if [[ -z "$line" || "$line" == ";"* || "$line" == *"Open Ended Schemes"* ]]; then
        continue
    fi
    
    # Check if this is a scheme name line (doesn't start with a number)
    if [[ ! "$line" =~ ^[0-9] ]]; then
        current_scheme=$(echo "$line" | sed 's/;/,/g' | sed 's/\r//g')
    else
        # This is a data line with NAV value
        IFS=';' read -ra parts <<< "$line"
        if [ ${#parts[@]} -ge 5 ]; then
            scheme_code=$(echo "${parts[0]}" | sed 's/^\s*//;s/\s*$//')
            isin=$(echo "${parts[1]}" | sed 's/^\s*//;s/\s*$//')
            nav_value=$(echo "${parts[4]}" | sed 's/^\s*//;s/\s*$//')
            date=""
            if [ ${#parts[@]} -ge 6 ]; then
                date=$(echo "${parts[5]}" | sed 's/^\s*//;s/\s*$//')
            fi
            
            # Escape any tab characters in the scheme name
            safe_scheme_name=$(echo "$current_scheme" | sed 's/\t/ /g')
            
            # Write to TSV file
            echo -e "$safe_scheme_name\t$scheme_code\t$isin\t$nav_value\t$date" >> "$OUTPUT_TSV"
            processed_count=$((processed_count + 1))
        fi
    fi
    
    line_count=$((line_count + 1))
done < "$TEMP_FILE"

echo "Processed $line_count lines, extracted $processed_count entries."
echo "Data saved as TSV to $OUTPUT_TSV"

# Clean up
rm "$TEMP_FILE"

# Display sample data (first 3 lines after header)
echo -e "\nSample data (first 3 entries):"
head -n 4 "$OUTPUT_TSV" | tail -n 3 | while IFS=$'\t' read -r scheme_name scheme_code isin nav_value date; do
    echo -e "\n--- Entry ---"
    echo "Scheme Name: $scheme_name"
    echo "Scheme Code: $scheme_code"
    echo "NAV Value: $nav_value"
    echo "Date: $date"
done

echo -e "\nQuestion: Should this data be in JSON instead?"
echo "Answer: TSV format is more compact and easier to import into spreadsheet applications."
echo "However, JSON would be more flexible for programmatic use and preserves data types better."
echo "The choice depends on your specific use case."