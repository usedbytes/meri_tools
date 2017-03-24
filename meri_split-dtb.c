/*
 * Copyright 2017 Brian Starkey <stark3y@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * Splits the monolithic, multi-target dtb into its component dtb parts, by
 * looking for dtb magic headers
 */
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdint.h>
#include <fcntl.h>

int dump_dtb(const void *p, size_t len, const char *filename)
{
	int ret = 0, fd;

	printf("Writing %s\n", filename);

	fd = open(filename, O_CREAT | O_RDWR, 0644);
	if (fd < 0) {
		fprintf(stderr, "open error. %s\n", strerror(errno));
		return -1;
	}

	if (write(fd, p, len) != len) {
		fprintf(stderr, "write error. %s\n", strerror(errno));
		ret = -1;
	}

	close(fd);

	return ret;
}

int main(int argc, char *argv[])
{
	int fd, ret, i = 0;
	char filename[128];
	uint8_t *p;
	struct stat s;
	off_t off = 0, start_off = 0;
	uint8_t magic[] = { 0xd0, 0x0d, 0xfe, 0xed };

	if (argc != 2) {
		fprintf(stderr, "Usage: %s infile\n"
			"\tSplit a multi-dtb file at d00dfeed delimiters\n",
			argv[0]);
		return 1;
	}

	ret = stat(argv[1], &s);
	if (ret != 0) {
		fprintf(stderr, "stat error. %s\n", strerror(errno));
		return 1;
	}

	fd = open(argv[1], O_RDONLY);
	if (fd < 0) {
		fprintf(stderr, "open error. %s\n", strerror(errno));
		return 1;
	}

	p = mmap(NULL, s.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
	if (p == MAP_FAILED) {
		fprintf(stderr, "mmap error. %s\n", strerror(errno));
		ret = 1;
		goto done;
	}

	off += sizeof(magic);
	while (off < s.st_size) {
		if (!memcmp(p + off, magic, sizeof(magic))) {
			snprintf(filename, 128, "%s.%d", argv[1], i++);
			if (dump_dtb(p + start_off, off - start_off, filename))
				goto done;
			start_off = off;
		}
		off++;
	}

	snprintf(filename, 128, "%s.%d", argv[1], i++);
	dump_dtb(p + start_off, off - start_off, filename);

done:
	if (p && p != MAP_FAILED)
		munmap(p, s.st_size);
	close(fd);
	return ret;
}

