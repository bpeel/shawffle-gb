OBJS = \
	main.o \
	tilemap.o \
	game.o \
	utils.o \
	globals.o \
	tiles.o \
	level-select.o
BACKGROUND_FILES = \
	background-tiles.bin \
	background-palettes.bin
SPRITE_FILES = \
	sprite-tiles.bin \
	sprite-palettes.bin

%.o: %.asm
	rgbasm -o $@ $<

shawffle.gb: $(OBJS)
	rgblink -o $@ $^ --map shawffle-map.txt \
	--sym shawffle.sym \
	&& rgbfix --color-only -v -p 0xff $@ \
	--mbc-type "MBC1+RAM+BATTERY" \
	--ram 2 \
	--title Shawffle

.PHONY: clean all

clean:
	rm -f $(OBJS) shawffle.gb $(BACKGROUND_FILES) $(SPRITE_FILES) font.bin \
	level-select-palettes.bin level-select-sprite-palettes.bin \
	letter-tiles.bin
tiles.o: \
	background-tiles.bin \
	sprite-tiles.bin \
	font.bin \
	utils.inc \
	hardware.inc
main.o: \
	hardware.inc \
	utils.inc
game.o: \
	letter-tiles.bin \
	background-palettes.bin \
	sprite-palettes.bin \
	puzzles.bin \
	charmap.inc \
	utils.inc \
	globals.inc \
	hardware.inc
level-select.o: \
	charmap.inc \
	utils.inc \
	globals.inc \
	hardware.inc \
	level-select-palettes.bin \
	level-select-sprite-palettes.bin
utils.o: \
	hardware.inc
tilemap.o: charmap.inc

letter-tiles.bin: letter-tiles.png
	rgbgfx --depth 1 --columns --output $@ $<

$(BACKGROUND_FILES): background-tiles.png background-palettes.txt
	rgbgfx \
	--colors hex:background-palettes.txt \
	--color-curve \
	--columns \
	--output background-tiles.bin \
	--palette background-palettes.bin \
	$<

$(SPRITE_FILES): sprite-tiles.png sprite-palettes.txt
	rgbgfx \
	--colors hex:sprite-palettes.txt \
	--color-curve \
	--output sprite-tiles.bin \
	--palette sprite-palettes.bin \
	$<

font.bin: font.png
	rgbgfx \
	--depth 1 \
	--output $@ \
	$<


level-select-palettes.bin: level-select-palettes.txt
	rgbgfx --palette $@ --color-curve --colors hex:$<

level-select-sprite-palettes.bin: level-select-sprite-palettes.txt
	rgbgfx --palette $@ --color-curve --colors hex:$<

all: shawffle.gb
