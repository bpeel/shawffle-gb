OBJS = \
	main.o \
	tilemap.o \
	game.o \
	utils.o \
	globals.o \
	tiles.o
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
	&& rgbfix --color-only -v -p 0xff -m mbc1 $@ \
	--title Shawffle

.PHONY: clean all

clean:
	rm -f $(OBJS) shawffle.gb $(BACKGROUND_FILES) $(SPRITE_FILES) font.bin
tiles.o: \
	background-tiles.bin \
	sprite-tiles.bin
main.o: \
	hardware.inc \
	font.bin \
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
utils.o: \
	hardware.inc
tilemap.o: charmap.inc

letter-tiles.bin: letter-tiles.png make-binary-letter-tiles.py
	./make-binary-letter-tiles.py letter-tiles.png letter-tiles.bin

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

all: shawffle.gb
