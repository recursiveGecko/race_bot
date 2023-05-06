# To load, run one of: 
# $ source env.fish
# $ . env.fish

set file ".env"
set contents (grep -v '^#' "$file" | grep "=")

for line in $contents
    set name (echo $line | cut -d '=' -f 1)
    set value (echo $line | cut -d '=' -f 2-)
    set --export --global "$name" "$value"
end
