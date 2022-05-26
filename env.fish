# To load, run one of: 
# $ source env.fish
# $ . env.fish

set file ".env"
set contents (grep -v '^#' "$file")

for line in $contents
    set name (echo $line | cut -d '=' -f 1)
    set value (echo $line | cut -d '=' -f 2-)
    set -xg "$name" "$value"
    # echo set -xg "$name" "$value"
end
