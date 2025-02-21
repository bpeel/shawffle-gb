OBJS = \
	main.o \
	tilemap.o
TILE_FILES = \
	tile-tiles.bin \
	tile-palettes.bin
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
	rm -f $(OBJS) shawffle.gb $(TILE_FILES) $(SPRITE_FILES) font.bin

main.o: letter-tiles.bin $(TILE_FILES) $(SPRITE_FILES) puzzles.bin font.bin

letter-tiles.bin: letter-tiles.png make-binary-letter-tiles.py
	./make-binary-letter-tiles.py letter-tiles.png letter-tiles.bin

$(TILE_FILES): tile-tiles.png tile-palettes.txt
	rgbgfx \
	--colors hex:tile-palettes.txt \
	--color-curve \
	--columns \
	--output $@ \
	--palette tile-palettes.bin \
	$<

$(SPRITE_FILES): sprite-tiles.png sprite-palettes.txt
	rgbgfx \
	--colors hex:sprite-palettes.txt \
	--color-curve \
	--output $@ \
	--palette sprite-palettes.bin \
	$<

font.bin: font.png
	rgbgfx \
	--depth 1 \
	--output $@ \
	$<

all: shawffle.gb
