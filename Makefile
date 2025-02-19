OBJS = \
	main.o

%.o: %.asm
	rgbasm -o $@ $<

shawffle.gb: $(OBJS)
	rgblink -o $@ $^ -m shawffle-symbols.txt \
	&& rgbfix --color-only -v -p 0xff -m mbc1 $@ \
	--title Shawffle

.PHONY: clean all

clean:
	rm -f $(OBJS) shawffle.gb

main.o: letter-tiles.bin

letter-tiles.bin: letter-tiles.png make-binary-letter-tiles.py
	./make-binary-letter-tiles.py letter-tiles.png letter-tiles.bin

all: shawffle.gb
