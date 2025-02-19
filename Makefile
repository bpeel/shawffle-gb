OBJS = \
	main.o \
	tilemap.o
TILE_FILES = \
	tile-tiles.bin \
	tile-palettes.bin \

%.o: %.asm
	rgbasm -o $@ $<

shawffle.gb: $(OBJS)
	rgblink -o $@ $^ -m shawffle-symbols.txt \
	&& rgbfix --color-only -v -p 0xff -m mbc1 $@ \
	--title Shawffle

.PHONY: clean all

clean:
	rm -f $(OBJS) shawffle.gb $(TILE_FILES)

main.o: letter-tiles.bin $(TILE_FILES)

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

all: shawffle.gb
