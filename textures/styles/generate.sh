#!/bin/sh
# Generates the texture styles in this folder with ImageMagick.
# Each style folder holds replacements for files in textures/; anything a
# style does not replace falls back to the classic texture.
#   floor_a.png   1x256 and floor_b.png 256x1: the two strips the default
#                 floor mode (FLOOR_DETAIL 3) blends into the grid; white
#                 marks a grid line, black is empty floor
#   floor.png     256x256 grid tile for the single texture floor mode
#   dir_wall.png  256x256 trail texture, tinted with the player colour;
#                 image top = top of the trail
#   rim_wall.png  256x256 arena wall; image bottom = bottom of the wall
#   cycle_body.png, cycle_wheel.png  the cycle's textures, derived from the
#                 classic ones so they still fit the model; transparent
#                 pixels show the player colour, opaque ones their grey
# Usage: sh textures/styles/generate.sh   (from the repository root)
set -e
cd "$(dirname "$0")"

# floor <out> <background> <edge colour> <edge width per side> [<half-line colour> <half-line width>]
floor() {
    out=$1; bg=$2; edge=$3; ew=$4; mid=$5; mw=$6
    draw="fill $edge rectangle 0,0 255,$((ew-1)) rectangle 0,$((256-ew)) 255,255 rectangle 0,0 $((ew-1)),255 rectangle $((256-ew)),0 255,255"
    if [ -n "$mid" ]; then
        a=$((128-mw/2)); b=$((a+mw-1))
        draw="$draw fill $mid rectangle 0,$a 255,$b rectangle $a,0 $b,255"
    fi
    convert -size 256x256 "xc:$bg" -draw "$draw" -colorspace Gray -strip "$out"
}

# strips <dir> <edge grey 0-255> <edge width per side> [<half-line grey> <half-line width>]
# writes floor_a.png (1x256, with alpha like the original) and floor_b.png (256x1)
strips() {
    dir=$1; edge=$2; ew=$3; mid=$4; mw=$5
    draw="fill gray($edge) rectangle 0,0 0,$((ew-1)) rectangle 0,$((256-ew)) 0,255"
    if [ -n "$mid" ]; then
        a=$((128-mw/2)); b=$((a+mw-1))
        draw="$draw fill gray($mid) rectangle 0,$a 0,$b"
    fi
    convert -size 1x256 xc:black -draw "$draw" -colorspace Gray -alpha opaque -strip "PNG32:$dir/floor_a.tmp.png"
    convert "$dir/floor_a.tmp.png" -colorspace Gray -define png:color-type=4 -strip "$dir/floor_a.png"
    convert "$dir/floor_a.tmp.png" -rotate 90 -alpha off -colorspace Gray -strip "$dir/floor_b.png"
    rm -f "$dir/floor_a.tmp.png"
}

# trail <out> <body> <top colour> <top height> [<line colour> <line height>] [<bottom colour> <bottom height>]
trail() {
    out=$1; body=$2; top=$3; th=$4; line=$5; lh=$6; bot=$7; bh=$8
    draw="fill $top rectangle 0,0 255,$((th-1))"
    [ -n "$line" ] && draw="$draw fill $line rectangle 0,$th 255,$((th+lh-1))"
    [ -n "$bot" ] && draw="$draw fill $bot rectangle 0,$((256-bh)) 255,255"
    convert -size 256x256 "xc:$body" -draw "$draw" -colorspace Gray -strip "$out"
}

# rim <out> <wall> <band colour> <band top row> <line colour> <line height> [<base colour> <base height>]
rim() {
    out=$1; wall=$2; band=$3; bt=$4; line=$5; lh=$6; base=$7; bh=$8
    draw="fill $band rectangle 0,$bt 255,255 fill $line rectangle 0,$bt 255,$((bt+lh-1))"
    [ -n "$base" ] && draw="$draw fill $base rectangle 0,$((256-bh)) 255,255"
    convert -size 256x256 "xc:$wall" -draw "$draw" -strip "PNG24:$out"
}

# cycle <dir> <mode>: derive the cycle textures from the classic ones
#   outline: keep the dark lines and wheels black, everything else player colour
#   white:   turn the dark lines and wheels white, everything else player colour
#   solid:   player colour only
cycle() {
    dir=$1; mode=$2
    for f in cycle_body cycle_wheel; do
        src="../$f.png"
        # dark, opaque pixels of the classic texture: lines and tyres
        convert "$src" -alpha on \( +clone -alpha extract \) \( -clone 0 -alpha off -colorspace Gray \) \
            -delete 0 -fx "u>0.5 && v<0.3 ? 1 : 0" "$dir/$f.mask.png"
        case $mode in
            outline) convert "$dir/$f.mask.png" -negate "$dir/$f.grey.png" ;;
            white)   convert "$dir/$f.mask.png" "$dir/$f.grey.png" ;;
            solid)   convert "$dir/$f.mask.png" -evaluate set 0 "$dir/$f.grey.png"
                     convert "$dir/$f.mask.png" -evaluate set 0 "$dir/$f.mask.png" ;;
        esac
        # grey = the visible shade, alpha = where it shows (elsewhere player colour)
        convert "$dir/$f.grey.png" "$dir/$f.mask.png" -alpha off -compose CopyOpacity -composite \
            -colorspace Gray -define png:color-type=4 -strip "$dir/$f.png"
        rm -f "$dir/$f.mask.png" "$dir/$f.grey.png"
    done
}

mkdir -p clean contrast minimal

# Clean: calm and readable
floor clean/floor.png    '#06080b' '#9aa4b0' 5 '#3a424c' 4
strips clean 225 3 70 4
trail clean/dir_wall.png '#8c8c8c' '#ffffff' 18 '' '' '#cfcfcf' 6
rim   clean/rim_wall.png '#0b0e14' '#1c212a' 200 '#e6edf5' 4 '#5a6270' 3
cycle clean outline

# High Contrast: maximum separation
floor contrast/floor.png    '#000000' '#ffffff' 7 '#7a7a7a' 5
strips contrast 255 5 150 6
trail contrast/dir_wall.png '#e6e6e6' '#ffffff' 16 '#2a2a2a' 4 '#ffffff' 6
rim   contrast/rim_wall.png '#000000' '#2c2c2c' 212 '#ffffff' 5 '#ffffff' 3
cycle contrast white

# Minimal: nothing but what you need
floor minimal/floor.png    '#000000' '#4a5058' 3
strips minimal 120 2
trail minimal/dir_wall.png '#a0a0a0' '#c8c8c8' 6
rim   minimal/rim_wall.png '#101215' '#101215' 228 '#4a4f57' 2
cycle minimal solid

echo "generated: $(ls */*.png | tr '\n' ' ')"
